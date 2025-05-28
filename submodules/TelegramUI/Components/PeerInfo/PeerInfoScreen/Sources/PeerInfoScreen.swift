import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import TelegramStringFormatting
import PhoneNumberFormat
import AppBundle
import PresentationDataUtils
import NotificationMuteSettingsUI
import NotificationSoundSelectionUI
import OverlayStatusController
import ShareController
import PhotoResources
import PeerAvatarGalleryUI
import TelegramIntents
import PeerInfoUI
import SearchBarNode
import SearchUI
import ContextUI
import OpenInExternalAppUI
import SafariServices
import GalleryUI
import LegacyUI
import MapResourceToAvatarSizes
import LegacyComponents
import WebSearchUI
import LocationResources
import LocationUI
import Geocoding
import TextFormat
import StatisticsUI
import StickerResources
import SettingsUI
import ChatListUI
import CallListUI
import AccountUtils
import PassportUI
import DeviceAccess
import LegacyMediaPickerUI
import TelegramNotices
import SaveToCameraRoll
import PeerInfoUI
import ListMessageItem
import GalleryData
import ChatInterfaceState
import TelegramVoip
import InviteLinksUI
import UndoUI
import MediaResources
import HashtagSearchUI
import ActionSheetPeerItem
import TelegramCallsUI
import PeerInfoAvatarListNode
import PasswordSetupUI
import CalendarMessageScreen
import TooltipUI
import QrCodeUI
import TranslateUI
import ChatPresentationInterfaceState
import CreateExternalMediaStreamScreen
import PaymentMethodUI
import PremiumUI
import InstantPageCache
import EmojiStatusSelectionComponent
import AnimationCache
import MultiAnimationRenderer
import EntityKeyboard
import AvatarNode
import ComponentFlow
import EmojiStatusComponent
import ChatTitleView
import ForumCreateTopicScreen
import NotificationExceptionsScreen
import ChatTimerScreen
import NotificationPeerExceptionController
import StickerPackPreviewUI
import ChatListHeaderComponent
import ChatControllerInteraction
import StorageUsageScreen
import AvatarEditorScreen
import SendInviteLinkScreen
import PeerInfoVisualMediaPaneNode
import PeerInfoStoryGridScreen
import StoryContainerScreen
import ChatAvatarNavigationNode
import PeerReportScreen
import WebUI
import ShareWithPeersScreen
import ItemListPeerItem
import PeerNameColorScreen
import PeerAllowedReactionsScreen
import ChatMessageSelectionInputPanelNode
import ChatHistorySearchContainerNode
import PeerInfoPaneNode
import MediaPickerUI
import AttachmentUI
import BoostLevelIconComponent
import PeerInfoChatPaneNode
import PeerInfoChatListPaneNode
import GroupStickerPackSetupController
import PeerNameColorItem
import PeerSelectionScreen
import UIKitRuntimeUtils
import OldChannelsController
import UrlHandling
import VerifyAlertController
import GiftViewScreen

public enum PeerInfoAvatarEditingMode {
    case generic
    case accept
    case suggest
    case custom
    case fallback
}

protocol PeerInfoScreenItem: AnyObject {
    var id: AnyHashable { get }
    func node() -> PeerInfoScreenItemNode
}

class PeerInfoScreenItemNode: ASDisplayNode, AccessibilityFocusableNode {
    var bringToFrontForHighlight: (() -> Void)?
    
    func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        preconditionFailure()
    }
    
    override open func accessibilityElementDidBecomeFocused() {
//        (self.supernode as? ListView)?.ensureItemNodeVisible(self, animated: false, overflow: 22.0)
    }
}

private final class PeerInfoScreenItemSectionContainerNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let itemContainerNode: ASDisplayNode
    
    private var currentItems: [PeerInfoScreenItem] = []
    fileprivate var itemNodes: [AnyHashable: PeerInfoScreenItemNode] = [:]
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.itemContainerNode = ASDisplayNode()
        self.itemContainerNode.clipsToBounds = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.itemContainerNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
    }
    
    func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, hasCorners: Bool, presentationData: PresentationData, items: [PeerInfoScreenItem], transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.topSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        self.topSeparatorNode.isHidden = hasCorners
        self.bottomSeparatorNode.isHidden = hasCorners
        
        var contentHeight: CGFloat = 0.0
        var contentWithBackgroundHeight: CGFloat = 0.0
        var contentWithBackgroundOffset: CGFloat = 0.0
        
        for i in 0 ..< items.count {
            let item = items[i]
            
            let itemNode: PeerInfoScreenItemNode
            var wasAdded = false
            if let current = self.itemNodes[item.id] {
                itemNode = current
            } else {
                wasAdded = true
                itemNode = item.node()
                self.itemNodes[item.id] = itemNode
                self.itemContainerNode.addSubnode(itemNode)
                itemNode.bringToFrontForHighlight = { [weak self, weak itemNode] in
                    guard let strongSelf = self, let itemNode = itemNode else {
                        return
                    }
                    strongSelf.view.bringSubviewToFront(itemNode.view)
                }
            }
            
            let itemTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            
            let topItem: PeerInfoScreenItem?
            if i == 0 {
                topItem = nil
            } else if items[i - 1] is PeerInfoScreenHeaderItem {
                topItem = nil
            } else {
                topItem = items[i - 1]
            }
            
            let bottomItem: PeerInfoScreenItem?
            if i == items.count - 1 {
                bottomItem = nil
            } else if items[i + 1] is PeerInfoScreenCommentItem {
                bottomItem = nil
            } else {
                bottomItem = items[i + 1]
            }
            
            let itemHeight = itemNode.update(context: context, width: width, safeInsets: safeInsets, presentationData: presentationData, item: item, topItem: topItem, bottomItem: bottomItem, hasCorners: hasCorners, transition: itemTransition)
            let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight))
            itemTransition.updateFrame(node: itemNode, frame: itemFrame)
            if wasAdded {
                itemNode.alpha = 0.0
                let alphaTransition: ContainedViewLayoutTransition = transition.isAnimated ? .animated(duration: 0.35, curve: .linear) : .immediate
                alphaTransition.updateAlpha(node: itemNode, alpha: 1.0)
            }
            
            if item is PeerInfoScreenCommentItem {
            } else {
                contentWithBackgroundHeight += itemHeight
            }
            contentHeight += itemHeight
            
            if item is PeerInfoScreenHeaderItem {
                contentWithBackgroundOffset = contentHeight
            }
        }
        
        var removeIds: [AnyHashable] = []
        for (id, _) in self.itemNodes {
            if !items.contains(where: { $0.id == id }) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                itemNode.view.superview?.sendSubviewToBack(itemNode.view)
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
        transition.updateFrame(node: self.itemContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: contentHeight)))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentWithBackgroundOffset), size: CGSize(width: width, height: max(0.0, contentWithBackgroundHeight - contentWithBackgroundOffset))))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentWithBackgroundOffset - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentWithBackgroundHeight), size: CGSize(width: width, height: UIScreenPixel)))
        
        if contentHeight.isZero {
            transition.updateAlpha(node: self.topSeparatorNode, alpha: 0.0)
            transition.updateAlpha(node: self.bottomSeparatorNode, alpha: 0.0)
        } else {
            transition.updateAlpha(node: self.topSeparatorNode, alpha: 1.0)
            transition.updateAlpha(node: self.bottomSeparatorNode, alpha: 1.0)
        }
        
        return contentHeight
    }
    
    func animateErrorIfNeeded() {
        for (_, itemNode) in self.itemNodes {
            if let itemNode = itemNode as? PeerInfoScreenMultilineInputItemNode {
                itemNode.animateErrorIfNeeded()
            }
        }
    }
}

final class PeerInfoSelectionPanelNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    
    private let deleteMessages: () -> Void
    private let shareMessages: () -> Void
    private let forwardMessages: () -> Void
    private let reportMessages: () -> Void
    private let displayCopyProtectionTip: (ASDisplayNode, Bool) -> Void
    
    let selectionPanel: ChatMessageSelectionInputPanelNode
    let separatorNode: ASDisplayNode
    let backgroundNode: NavigationBackgroundNode
    
    var viewForOverlayContent: UIView? {
        return self.selectionPanel.viewForOverlayContent
    }
    
    init(context: AccountContext, presentationData: PresentationData, peerId: PeerId, deleteMessages: @escaping () -> Void, shareMessages: @escaping () -> Void, forwardMessages: @escaping () -> Void, reportMessages: @escaping () -> Void, displayCopyProtectionTip: @escaping (ASDisplayNode, Bool) -> Void) {
        self.context = context
        self.peerId = peerId
        self.deleteMessages = deleteMessages
        self.shareMessages = shareMessages
        self.forwardMessages = forwardMessages
        self.reportMessages = reportMessages
        self.displayCopyProtectionTip = displayCopyProtectionTip
        
        let presentationData = presentationData
        
        self.separatorNode = ASDisplayNode()
        self.backgroundNode = NavigationBackgroundNode(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor)
        
        self.selectionPanel = ChatMessageSelectionInputPanelNode(theme: presentationData.theme, strings: presentationData.strings, peerMedia: true)
        self.selectionPanel.context = context
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, cancelMessageSelection: { _ in
        }, deleteSelectedMessages: {
            deleteMessages()
        }, reportSelectedMessages: {
            reportMessages()
        }, reportMessages: { _, _ in
        }, blockMessageAuthor: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
            forwardMessages()
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, updateForwardOptionsState: { _ in
        }, presentForwardOptions: { _ in
        }, presentReplyOptions: { _ in
        }, presentLinkOptions: { _ in
        }, shareSelectedMessages: {
            shareMessages()
        }, updateTextInputStateAndMode: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, openStickers: {
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
        }, openLinkEditing: {
        }, displaySlowmodeTooltip: { _, _ in
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
        }, openSendAsPeer: { _, _ in
        }, presentChatRequestAdminInfo: {
        }, displayCopyProtectionTip: { node, save in
            displayCopyProtectionTip(node, save)
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
        
        self.selectionPanel.interfaceInteraction = interfaceInteraction
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.selectionPanel)
    }
    
    func update(layout: ContainerViewLayout, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        
        let interfaceState = ChatPresentationInterfaceState(chatWallpaper: .color(0), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, limitsConfiguration: .defaultValue, fontSize: .regular, bubbleCorners: PresentationChatBubbleCorners(mainRadius: 16.0, auxiliaryRadius: 8.0, mergeBubbleCorners: true), accountPeerId: self.context.account.peerId, mode: .standard(.default), chatLocation: .peer(id: self.peerId), subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil, threadData: nil, isGeneralThreadClosed: nil, replyMessage: nil, accountPeerColor: nil, businessIntro: nil)
        let panelHeight = self.selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: UIEdgeInsets(), maxHeight: layout.size.height, isSecondary: false, transition: transition, interfaceState: interfaceState, metrics: layout.metrics, isMediaInputExpanded: false)
        
        transition.updateFrame(node: self.selectionPanel, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: panelHeight)))
        
        let panelHeightWithInset = panelHeight + layout.intrinsicInsets.bottom
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: panelHeightWithInset)))
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        return panelHeightWithInset
    }
}

private enum PeerInfoBotCommand {
    case settings
    case help
    case privacy
}

private enum PeerInfoParticipantsSection {
    case members
    case admins
    case banned
    case memberRequests
}

private enum PeerInfoMemberAction {
    case promote
    case restrict
    case remove
    case openStories(sourceView: UIView)
}

private enum PeerInfoContextSubject {
    case bio
    case phone(String)
    case link(customLink: String?)
    case businessHours(String)
    case businessLocation(String)
    case birthday
}

private enum PeerInfoSettingsSection {
    case avatar
    case edit
    case proxy
    case stories
    case savedMessages
    case recentCalls
    case devices
    case chatFolders
    case notificationsAndSounds
    case privacyAndSecurity
    case passwordSetup
    case dataAndStorage
    case appearance
    case language
    case stickers
    case premium
    case premiumGift
    case passport
    case watch
    case support
    case faq
    case tips
    case phoneNumber
    case username
    case addAccount
    case logout
    case rememberPassword
    case emojiStatus
    case powerSaving
    case businessSetup
    case profile
    case premiumManagement
    case stars
}

private enum PeerInfoReportType {
    case `default`
    case user
    case reaction(MessageId)
}

private enum TopicsLimitedReason {
    case participants(Int)
    case discussion
}

private final class PeerInfoInteraction {
    let openChat: (EnginePeer.Id?) -> Void
    let openUsername: (String, Bool, Promise<Bool>?) -> Void
    let openPhone: (String, ASDisplayNode, ContextGesture?, Promise<Bool>?) -> Void
    let editingOpenNotificationSettings: () -> Void
    let editingOpenSoundSettings: () -> Void
    let editingToggleShowMessageText: (Bool) -> Void
    let requestDeleteContact: () -> Void
    let suggestPhoto: () -> Void
    let setCustomPhoto: () -> Void
    let resetCustomPhoto: () -> Void
    let openAddContact: () -> Void
    let updateBlocked: (Bool) -> Void
    let openReport: (PeerInfoReportType) -> Void
    let openShareBot: () -> Void
    let openAddBotToGroup: () -> Void
    let performBotCommand: (PeerInfoBotCommand) -> Void
    let editingOpenPublicLinkSetup: () -> Void
    let editingOpenNameColorSetup: () -> Void
    let editingOpenInviteLinksSetup: () -> Void
    let editingOpenDiscussionGroupSetup: () -> Void
    let editingOpenPostSuggestionsSetup: () -> Void
    let editingOpenRevenue: () -> Void
    let editingOpenStars: () -> Void
    let openParticipantsSection: (PeerInfoParticipantsSection) -> Void
    let openRecentActions: () -> Void
    let openChannelMessages: () -> Void
    let openStats: (ChannelStatsSection) -> Void
    let editingOpenPreHistorySetup: () -> Void
    let editingOpenAutoremoveMesages: () -> Void
    let openPermissions: () -> Void
    let editingOpenStickerPackSetup: () -> Void
    let openLocation: () -> Void
    let editingOpenSetupLocation: () -> Void
    let openPeerInfo: (Peer, Bool) -> Void
    let performMemberAction: (PeerInfoMember, PeerInfoMemberAction) -> Void
    let openPeerInfoContextMenu: (PeerInfoContextSubject, ASDisplayNode, CGRect?) -> Void
    let performBioLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    let requestLayout: (Bool) -> Void
    let openEncryptionKey: () -> Void
    let openSettings: (PeerInfoSettingsSection) -> Void
    let openPaymentMethod: () -> Void
    let switchToAccount: (AccountRecordId) -> Void
    let logoutAccount: (AccountRecordId) -> Void
    let accountContextMenu: (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void
    let updateBio: (String) -> Void
    let openDeletePeer: () -> Void
    let openFaq: (String?) -> Void
    let openAddMember: () -> Void
    let openQrCode: () -> Void
    let editingOpenReactionsSetup: () -> Void
    let dismissInput: () -> Void
    let openForumSettings: () -> Void
    let displayTopicsLimited: (TopicsLimitedReason) -> Void
    let openPeerMention: (String, ChatControllerInteractionNavigateToPeer) -> Void
    let openBotApp: (AttachMenuBot) -> Void
    let openEditing: () -> Void
    let updateBirthdate: (TelegramBirthday??) -> Void
    let updateIsEditingBirthdate: (Bool) -> Void
    let openBioPrivacy: () -> Void
    let openBirthdatePrivacy: () -> Void
    let openPremiumGift: () -> Void
    let editingOpenPersonalChannel: () -> Void
    let openUsernameContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openBioContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openWorkingHoursContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openBusinessLocationContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let openBirthdayContextMenu: (ASDisplayNode, ContextGesture?) -> Void
    let editingOpenAffiliateProgram: () -> Void
    let editingOpenVerifyAccounts: () -> Void
    let editingToggleAutoTranslate: (Bool) -> Void
    let displayAutoTranslateLocked: () -> Void
    let getController: () -> ViewController?
    
    init(
        openUsername: @escaping (String, Bool, Promise<Bool>?) -> Void,
        openPhone: @escaping (String, ASDisplayNode, ContextGesture?, Promise<Bool>?) -> Void,
        editingOpenNotificationSettings: @escaping () -> Void,
        editingOpenSoundSettings: @escaping () -> Void,
        editingToggleShowMessageText: @escaping (Bool) -> Void,
        requestDeleteContact: @escaping () -> Void,
        suggestPhoto: @escaping () -> Void,
        setCustomPhoto: @escaping () -> Void,
        resetCustomPhoto: @escaping () -> Void,
        openChat: @escaping (EnginePeer.Id?) -> Void,
        openAddContact: @escaping () -> Void,
        updateBlocked: @escaping (Bool) -> Void,
        openReport: @escaping (PeerInfoReportType) -> Void,
        openShareBot: @escaping () -> Void,
        openAddBotToGroup: @escaping () -> Void,
        performBotCommand: @escaping (PeerInfoBotCommand) -> Void,
        editingOpenPublicLinkSetup: @escaping () -> Void,
        editingOpenNameColorSetup: @escaping () -> Void,
        editingOpenInviteLinksSetup: @escaping () -> Void,
        editingOpenDiscussionGroupSetup: @escaping () -> Void,
        editingOpenPostSuggestionsSetup: @escaping () -> Void,
        editingOpenRevenue: @escaping () -> Void,
        editingOpenStars: @escaping () -> Void,
        openParticipantsSection: @escaping (PeerInfoParticipantsSection) -> Void,
        openRecentActions: @escaping () -> Void,
        openChannelMessages: @escaping () -> Void,
        openStats: @escaping (ChannelStatsSection) -> Void,
        editingOpenPreHistorySetup: @escaping () -> Void,
        editingOpenAutoremoveMesages: @escaping () -> Void,
        openPermissions: @escaping () -> Void,
        editingOpenStickerPackSetup: @escaping () -> Void,
        openLocation: @escaping () -> Void,
        editingOpenSetupLocation: @escaping () -> Void,
        openPeerInfo: @escaping (Peer, Bool) -> Void,
        performMemberAction: @escaping (PeerInfoMember, PeerInfoMemberAction) -> Void,
        openPeerInfoContextMenu: @escaping (PeerInfoContextSubject, ASDisplayNode, CGRect?) -> Void,
        performBioLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void,
        requestLayout: @escaping (Bool) -> Void,
        openEncryptionKey: @escaping () -> Void,
        openSettings: @escaping (PeerInfoSettingsSection) -> Void,
        openPaymentMethod: @escaping () -> Void,
        switchToAccount: @escaping (AccountRecordId) -> Void,
        logoutAccount: @escaping (AccountRecordId) -> Void,
        accountContextMenu: @escaping (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void,
        updateBio: @escaping (String) -> Void,
        openDeletePeer: @escaping () -> Void,
        openFaq: @escaping (String?) -> Void,
        openAddMember: @escaping () -> Void,
        openQrCode: @escaping () -> Void,
        editingOpenReactionsSetup: @escaping () -> Void,
        dismissInput: @escaping () -> Void,
        openForumSettings: @escaping () -> Void,
        displayTopicsLimited: @escaping (TopicsLimitedReason) -> Void,
        openPeerMention: @escaping (String, ChatControllerInteractionNavigateToPeer) -> Void,
        openBotApp: @escaping (AttachMenuBot) -> Void,
        openEditing: @escaping () -> Void,
        updateBirthdate: @escaping (TelegramBirthday??) -> Void,
        updateIsEditingBirthdate: @escaping (Bool) -> Void,
        openBioPrivacy: @escaping () -> Void,
        openBirthdatePrivacy: @escaping () -> Void,
        openPremiumGift: @escaping () -> Void,
        editingOpenPersonalChannel: @escaping () -> Void,
        openUsernameContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openBioContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openWorkingHoursContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openBusinessLocationContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        openBirthdayContextMenu: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        editingOpenAffiliateProgram: @escaping () -> Void,
        editingOpenVerifyAccounts: @escaping () -> Void,
        editingToggleAutoTranslate: @escaping (Bool) -> Void,
        displayAutoTranslateLocked: @escaping () -> Void,
        getController: @escaping () -> ViewController?
    ) {
        self.openUsername = openUsername
        self.openPhone = openPhone
        self.editingOpenNotificationSettings = editingOpenNotificationSettings
        self.editingOpenSoundSettings = editingOpenSoundSettings
        self.editingToggleShowMessageText = editingToggleShowMessageText
        self.requestDeleteContact = requestDeleteContact
        self.suggestPhoto = suggestPhoto
        self.setCustomPhoto = setCustomPhoto
        self.resetCustomPhoto = resetCustomPhoto
        self.openChat = openChat
        self.openAddContact = openAddContact
        self.updateBlocked = updateBlocked
        self.openReport = openReport
        self.openShareBot = openShareBot
        self.openAddBotToGroup = openAddBotToGroup
        self.performBotCommand = performBotCommand
        self.editingOpenPublicLinkSetup = editingOpenPublicLinkSetup
        self.editingOpenNameColorSetup = editingOpenNameColorSetup
        self.editingOpenInviteLinksSetup = editingOpenInviteLinksSetup
        self.editingOpenDiscussionGroupSetup = editingOpenDiscussionGroupSetup
        self.editingOpenPostSuggestionsSetup = editingOpenPostSuggestionsSetup
        self.editingOpenRevenue = editingOpenRevenue
        self.editingOpenStars = editingOpenStars
        self.openParticipantsSection = openParticipantsSection
        self.openRecentActions = openRecentActions
        self.openChannelMessages = openChannelMessages
        self.openStats = openStats
        self.editingOpenPreHistorySetup = editingOpenPreHistorySetup
        self.editingOpenAutoremoveMesages = editingOpenAutoremoveMesages
        self.openPermissions = openPermissions
        self.editingOpenStickerPackSetup = editingOpenStickerPackSetup
        self.openLocation = openLocation
        self.editingOpenSetupLocation = editingOpenSetupLocation
        self.openPeerInfo = openPeerInfo
        self.performMemberAction = performMemberAction
        self.openPeerInfoContextMenu = openPeerInfoContextMenu
        self.performBioLinkAction = performBioLinkAction
        self.requestLayout = requestLayout
        self.openEncryptionKey = openEncryptionKey
        self.openSettings = openSettings
        self.openPaymentMethod = openPaymentMethod
        self.switchToAccount = switchToAccount
        self.logoutAccount = logoutAccount
        self.accountContextMenu = accountContextMenu
        self.updateBio = updateBio
        self.openDeletePeer = openDeletePeer
        self.openFaq = openFaq
        self.openAddMember = openAddMember
        self.openQrCode = openQrCode
        self.editingOpenReactionsSetup = editingOpenReactionsSetup
        self.dismissInput = dismissInput
        self.openForumSettings = openForumSettings
        self.displayTopicsLimited = displayTopicsLimited
        self.openPeerMention = openPeerMention
        self.openBotApp = openBotApp
        self.openEditing = openEditing
        self.updateBirthdate = updateBirthdate
        self.updateIsEditingBirthdate = updateIsEditingBirthdate
        self.openBioPrivacy = openBioPrivacy
        self.openBirthdatePrivacy = openBirthdatePrivacy
        self.openPremiumGift = openPremiumGift
        self.editingOpenPersonalChannel = editingOpenPersonalChannel
        self.openUsernameContextMenu = openUsernameContextMenu
        self.openBioContextMenu = openBioContextMenu
        self.openWorkingHoursContextMenu = openWorkingHoursContextMenu
        self.openBusinessLocationContextMenu = openBusinessLocationContextMenu
        self.openBirthdayContextMenu = openBirthdayContextMenu
        self.editingOpenAffiliateProgram = editingOpenAffiliateProgram
        self.editingOpenVerifyAccounts = editingOpenVerifyAccounts
        self.editingToggleAutoTranslate = editingToggleAutoTranslate
        self.displayAutoTranslateLocked = displayAutoTranslateLocked
        self.getController = getController
    }
}

private let enabledPublicBioEntities: EnabledEntityTypes = [.allUrl, .mention, .hashtag]
private let enabledPrivateBioEntities: EnabledEntityTypes = [.internalUrl, .mention, .hashtag]

private enum SettingsSection: Int, CaseIterable {
    case edit
    case phone
    case accounts
    case myProfile
    case proxy
    case apps
    case shortcuts
    case advanced
    case payment
    case extra
    case support
}

private func settingsItems(data: PeerInfoScreenData?, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction, isExpanded: Bool) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    var items: [SettingsSection: [PeerInfoScreenItem]] = [:]
    for section in SettingsSection.allCases {
        items[section] = []
    }
    
    let setPhotoTitle: String
    let displaySetPhoto: Bool
    if let peer = data.peer, !peer.profileImageRepresentations.isEmpty {
        setPhotoTitle = presentationData.strings.Settings_ChangeProfilePhoto
        displaySetPhoto = true
    } else {
        setPhotoTitle = presentationData.strings.Settings_SetProfilePhotoOrVideo
        displaySetPhoto = true
    }
    
    var setStatusTitle: String = ""
    let displaySetStatus: Bool
    var hasEmojiStatus = false
    if let peer = data.peer as? TelegramUser, peer.isPremium {
        if peer.emojiStatus != nil {
            hasEmojiStatus = true
            setStatusTitle = presentationData.strings.PeerInfo_ChangeEmojiStatus
        } else {
            setStatusTitle = presentationData.strings.PeerInfo_SetEmojiStatus
        }
        displaySetStatus = true
    } else {
        displaySetStatus = false
    }
    
    if displaySetStatus {
        items[.edit]!.append(PeerInfoScreenActionItem(id: 0, text: setStatusTitle, icon: UIImage(bundleImageName: hasEmojiStatus ? "Settings/EditEmojiStatus" : "Settings/SetEmojiStatus"), action: {
            interaction.openSettings(.emojiStatus)
        }))
    }
    
    if displaySetPhoto {
        items[.edit]!.append(PeerInfoScreenActionItem(id: 1, text: setPhotoTitle, icon: UIImage(bundleImageName: "Settings/SetAvatar"), action: {
            interaction.openSettings(.avatar)
        }))
    }
    if let peer = data.peer, (peer.addressName ?? "").isEmpty {
        items[.edit]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_SetUsername, icon: UIImage(bundleImageName: "Settings/SetUsername"), action: {
            interaction.openSettings(.username)
        }))
    }
    
    if let settings = data.globalSettings {
        if settings.premiumGracePeriod {
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: "Your access to Telegram Premium will expire soon!", text: .markdown("Unfortunately, your latest payment didn't come through. To keep your access to exclusive features, please renew the subscription."), isWarning: true, linkAction: nil))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: "Restore Subscription", action: {
                interaction.openSettings(.premiumManagement)
            }))
        } else if settings.suggestPhoneNumberConfirmation, let peer = data.peer as? TelegramUser {
            let phoneNumber = formatPhoneNumber(context: context, number: peer.phone ?? "")
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_CheckPhoneNumberTitle(phoneNumber).string, text: .markdown(presentationData.strings.Settings_CheckPhoneNumberText), linkAction: { link in
                if case .tap = link {
                    interaction.openFaq(presentationData.strings.Settings_CheckPhoneNumberFAQAnchor)
                }
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.Settings_KeepPhoneNumber(phoneNumber).string, action: {
                let _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.validatePhoneNumber.id).startStandalone()
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_ChangePhoneNumber, action: {
                interaction.openSettings(.phoneNumber)
            }))
        } else if settings.suggestPasswordConfirmation {
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_CheckPasswordTitle, text: .markdown(presentationData.strings.Settings_CheckPasswordText), linkAction: { _ in
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.Settings_KeepPassword, action: {
                let _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.validatePassword.id).startStandalone()
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_TryEnterPassword, action: {
                interaction.openSettings(.rememberPassword)
            }))
        } else if settings.suggestPasswordSetup {
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_SuggestSetupPasswordTitle, text: .markdown(presentationData.strings.Settings_SuggestSetupPasswordText), linkAction: { _ in
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_SuggestSetupPasswordAction, action: {
                interaction.openSettings(.passwordSetup)
            }))
        }
        
        if !settings.accountsAndPeers.isEmpty {
            for (peerAccountContext, peer, badgeCount) in settings.accountsAndPeers {
                let mappedContext = ItemListPeerItem.Context.custom(ItemListPeerItem.Context.Custom(
                    accountPeerId: peerAccountContext.account.peerId,
                    postbox: peerAccountContext.account.postbox,
                    network: peerAccountContext.account.network,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    isPremiumDisabled: false,
                    resolveInlineStickers: { fileIds in
                        return context.engine.stickers.resolveInlineStickers(fileIds: fileIds)
                    }
                ))
                let member: PeerInfoMember = .account(peer: RenderedPeer(peer: peer._asPeer()))
                items[.accounts]!.append(PeerInfoScreenMemberItem(id: member.id, context: mappedContext, enclosingPeer: nil, member: member, badge: badgeCount > 0 ? "\(compactNumericCountString(Int(badgeCount), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))" : nil, isAccount: true, action: { action in
                    switch action {
                    case .open:
                        interaction.switchToAccount(peerAccountContext.account.id)
                    case .remove:
                        interaction.logoutAccount(peerAccountContext.account.id)
                    default:
                        break
                    }
                }, contextAction: { node, gesture in
                    interaction.accountContextMenu(peerAccountContext.account.id, node, gesture)
                }))
            }
            
            items[.accounts]!.append(PeerInfoScreenActionItem(id: 100, text: presentationData.strings.Settings_AddAccount, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), action: {
                interaction.openSettings(.addAccount)
            }))
        }
        
        items[.myProfile]!.append(PeerInfoScreenDisclosureItem(id: 0, text: presentationData.strings.Settings_MyProfile, icon: PresentationResourcesSettings.myProfile, action: {
            interaction.openSettings(.profile)
        }))
        
        if !settings.proxySettings.servers.isEmpty {
            let proxyType: String
            if settings.proxySettings.enabled, let activeServer = settings.proxySettings.activeServer {
                switch activeServer.connection {
                case .mtp:
                    proxyType = presentationData.strings.SocksProxySetup_ProxyTelegram
                case .socks5:
                    proxyType = presentationData.strings.SocksProxySetup_ProxySocks5
                }
            } else {
                proxyType = presentationData.strings.Settings_ProxyDisabled
            }
            items[.proxy]!.append(PeerInfoScreenDisclosureItem(id: 0, label: .text(proxyType), text: presentationData.strings.Settings_Proxy, icon: PresentationResourcesSettings.proxy, action: {
                interaction.openSettings(.proxy)
            }))
        }
    }
    
    var appIndex = 1000
    if let settings = data.globalSettings {
        for bot in settings.bots {
            let iconSignal: Signal<UIImage?, NoError>
            if let peer = PeerReference(bot.peer._asPeer()), let icon = bot.icons[.iOSSettingsStatic] {
                let fileReference: FileMediaReference = .attachBot(peer: peer, media: icon)
                iconSignal = instantPageImageFile(account: context.account, userLocation: .other, fileReference: fileReference, fetched: true)
                |> map { generator -> UIImage? in
                    let size = CGSize(width: 29.0, height: 29.0)
                    let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: .zero))
                    return context?.generateImage()
                }
                let _ = freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: fileReference).startStandalone()
            } else {
                iconSignal = .single(UIImage())
            }
            let label: PeerInfoScreenDisclosureItem.Label = bot.flags.contains(.notActivated) || bot.flags.contains(.showInSettingsDisclaimer) ? .titleBadge(presentationData.strings.Settings_New, presentationData.theme.list.itemAccentColor) : .none
            items[.apps]!.append(PeerInfoScreenDisclosureItem(id: bot.peer.id.id._internalGetInt64Value(), label: label, text: bot.shortName, icon: nil, iconSignal: iconSignal, action: {
                interaction.openBotApp(bot)
            }))
            appIndex += 1
        }
    }
    
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_SavedMessages, icon: PresentationResourcesSettings.savedMessages, action: {
        interaction.openSettings(.savedMessages)
    }))
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 2, text: presentationData.strings.CallSettings_RecentCalls, icon: PresentationResourcesSettings.recentCalls, action: {
        interaction.openSettings(.recentCalls)
    }))
    
    let devicesLabel: String
    if let settings = data.globalSettings, let otherSessionsCount = settings.otherSessionsCount {
        if settings.enableQRLogin {
            devicesLabel = otherSessionsCount == 0 ? presentationData.strings.Settings_AddDevice : "\(otherSessionsCount + 1)"
        } else {
            devicesLabel = otherSessionsCount == 0 ? "" : "\(otherSessionsCount + 1)"
        }
    } else {
        devicesLabel = ""
    }
    
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 3, label: .text(devicesLabel), text: presentationData.strings.Settings_Devices, icon: PresentationResourcesSettings.devices, action: {
        interaction.openSettings(.devices)
    }))
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 4, text: presentationData.strings.Settings_ChatFolders, icon: PresentationResourcesSettings.chatFolders, action: {
        interaction.openSettings(.chatFolders)
    }))
    
    let notificationsWarning: Bool
    if let settings = data.globalSettings {
        notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: settings.notificationAuthorizationStatus, suppressed:  settings.notificationWarningSuppressed)
    } else {
        notificationsWarning = false
    }
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 0, label: notificationsWarning ? .badge("!", presentationData.theme.list.itemDestructiveColor) : .none, text: presentationData.strings.Settings_NotificationsAndSounds, icon: PresentationResourcesSettings.notifications, action: {
        interaction.openSettings(.notificationsAndSounds)
    }))
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_PrivacySettings, icon: PresentationResourcesSettings.security, action: {
        interaction.openSettings(.privacyAndSecurity)
    }))
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 2, text: presentationData.strings.Settings_ChatSettings, icon: PresentationResourcesSettings.dataAndStorage, action: {
        interaction.openSettings(.dataAndStorage)
    }))
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 3, text: presentationData.strings.Settings_Appearance, icon: PresentationResourcesSettings.appearance, action: {
        interaction.openSettings(.appearance)
    }))
    
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 6, label: .text(data.isPowerSavingEnabled == true ? presentationData.strings.Settings_PowerSavingOn : presentationData.strings.Settings_PowerSavingOff), text: presentationData.strings.Settings_PowerSaving, icon: PresentationResourcesSettings.powerSaving, action: {
        interaction.openSettings(.powerSaving)
    }))
    
    let languageName = presentationData.strings.primaryComponent.localizedName
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 4, label: .text(languageName.isEmpty ? presentationData.strings.Localization_LanguageName : languageName), text: presentationData.strings.Settings_AppLanguage, icon: PresentationResourcesSettings.language, action: {
        interaction.openSettings(.language)
    }))
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
    if !isPremiumDisabled || context.isPremium {
        items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 100, label: .text(""), text: presentationData.strings.Settings_Premium, icon: PresentationResourcesSettings.premium, action: {
            interaction.openSettings(.premium)
        }))
    }
    if let starsState = data.starsState {
        if !isPremiumDisabled || abs(starsState.balance.value) > 0 {
            let balanceText: NSAttributedString
            if abs(starsState.balance.value) > 0 {
                let formattedLabel = formatStarsAmountText(starsState.balance, dateTimeFormat: presentationData.dateTimeFormat)
                let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                let labelColor = presentationData.theme.list.itemSecondaryTextColor
                balanceText = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
            } else {
                balanceText = NSAttributedString()
            }
            items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 102, label: .attributedText(balanceText), text: presentationData.strings.Settings_Stars, icon: PresentationResourcesSettings.stars, action: {
                interaction.openSettings(.stars)
            }))
        }
    }
    if !isPremiumDisabled || context.isPremium {
        items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 103, label: .text(""), additionalBadgeLabel: nil, text: presentationData.strings.Settings_Business, icon: PresentationResourcesSettings.business, action: {
            interaction.openSettings(.businessSetup)
        }))
    }
    if let starsState = data.starsState {
        if !isPremiumDisabled || starsState.balance > StarsAmount.zero {
            items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 104, label: .text(""), text: presentationData.strings.Settings_SendGift, icon: PresentationResourcesSettings.premiumGift, action: {
                interaction.openSettings(.premiumGift)
            }))
        }
    }
    
    if let settings = data.globalSettings {
        if settings.hasPassport {
            items[.extra]!.append(PeerInfoScreenDisclosureItem(id: 0, text: presentationData.strings.Settings_Passport, icon: PresentationResourcesSettings.passport, action: {
                interaction.openSettings(.passport)
            }))
        }
        if settings.hasWatchApp {
            items[.extra]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_AppleWatch, icon: PresentationResourcesSettings.watch, action: {
                interaction.openSettings(.watch)
            }))
        }
    }
    
    items[.support]!.append(PeerInfoScreenDisclosureItem(id: 0, text: presentationData.strings.Settings_Support, icon: PresentationResourcesSettings.support, action: {
        interaction.openSettings(.support)
    }))
    items[.support]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_FAQ, icon: PresentationResourcesSettings.faq, action: {
        interaction.openSettings(.faq)
    }))
    items[.support]!.append(PeerInfoScreenDisclosureItem(id: 2, text: presentationData.strings.Settings_Tips, icon: PresentationResourcesSettings.tips, action: {
        interaction.openSettings(.tips)
    }))
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in SettingsSection.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}

private func settingsEditingItems(data: PeerInfoScreenData?, state: PeerInfoState, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction, isMyProfile: Bool) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    enum Section: Int, CaseIterable {
        case help
        case bio
        case birthday
        case info
        case account
        case logout
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    let ItemNameHelp = 0
    let ItemBio: AnyHashable = AnyHashable("bio_edit")
    let ItemBioHelp = 2
    let ItemPhoneNumber = 3
    let ItemUsername = 4
    let ItemAddAccount = 5
    let ItemAddAccountHelp = 6
    let ItemLogout = 7
    let ItemPeerColor = 8
    let ItemBirthday = 9
    let ItemBirthdayPicker = 10
    let ItemBirthdayRemove = 11
    let ItemBirthdayHelp = 12
    let ItemPeerPersonalChannel = 13
    
    items[.help]!.append(PeerInfoScreenCommentItem(id: ItemNameHelp, text: presentationData.strings.EditProfile_NameAndPhotoOrVideoHelp))
    
    if let cachedData = data.cachedData as? CachedUserData {
        items[.bio]!.append(PeerInfoScreenMultilineInputItem(id: ItemBio, text: state.updatingBio ?? (cachedData.about ?? ""), placeholder: presentationData.strings.UserInfo_About_Placeholder, textUpdated: { updatedText in
            interaction.updateBio(updatedText)
        }, action: {
            interaction.dismissInput()
        }, maxLength: Int(data.globalSettings?.userLimits.maxAboutLength ?? 70)))
        items[.bio]!.append(PeerInfoScreenCommentItem(id: ItemBioHelp, text: presentationData.strings.Settings_About_PrivacyHelp, linkAction: { _ in
            interaction.openBioPrivacy()
        }))
    }
    
    
    var birthday: TelegramBirthday?
    if let updatingBirthDate = state.updatingBirthDate {
        birthday = updatingBirthDate
    } else {
        birthday = (data.cachedData as? CachedUserData)?.birthday
    }
    
    var birthDateString: String
    if let birthday {
        birthDateString = stringForCompactBirthday(birthday, strings: presentationData.strings)
    } else {
        birthDateString = presentationData.strings.Settings_Birthday_Add
    }
    
    let isEditingBirthDate = state.isEditingBirthDate
    items[.birthday]!.append(PeerInfoScreenDisclosureItem(id: ItemBirthday, label: .coloredText(birthDateString, isEditingBirthDate ? .accent : .generic), text: presentationData.strings.Settings_Birthday, icon: nil, hasArrow: false, action: {
        interaction.updateIsEditingBirthdate(!isEditingBirthDate)
    }))
    if isEditingBirthDate, let birthday {
        items[.birthday]!.append(PeerInfoScreenBirthdatePickerItem(id: ItemBirthdayPicker, value: birthday, valueUpdated: { value in
            interaction.updateBirthdate(value)
        }))
        items[.birthday]!.append(PeerInfoScreenActionItem(id: ItemBirthdayRemove, text: presentationData.strings.Settings_Birthday_Remove, alignment: .natural, action: {
            interaction.updateBirthdate(.some(nil))
            interaction.updateIsEditingBirthdate(false)
        }))
    }
    
    
    var birthdayIsForContactsOnly = false
    if let birthdayPrivacy = data.globalSettings?.privacySettings?.birthday, case .enableContacts = birthdayPrivacy {
        birthdayIsForContactsOnly = true
    }
    items[.birthday]!.append(PeerInfoScreenCommentItem(id: ItemBirthdayHelp, text: birthdayIsForContactsOnly ? presentationData.strings.Settings_Birthday_ContactsHelp : presentationData.strings.Settings_Birthday_Help, linkAction: { _ in
        interaction.openBirthdatePrivacy()
    }))
    
    if let user = data.peer as? TelegramUser {
        items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemPhoneNumber, label: .text(user.phone.flatMap({ formatPhoneNumber(context: context, number: $0) }) ?? ""), text: presentationData.strings.Settings_PhoneNumber, action: {
            interaction.openSettings(.phoneNumber)
        }))
    }
    var username = ""
    if let addressName = data.peer?.addressName, !addressName.isEmpty {
        username = "@\(addressName)"
    }
    items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(username), text: presentationData.strings.Settings_Username, action: {
          interaction.openSettings(.username)
    }))
    
    if let peer = data.peer as? TelegramUser {
        var colors: [PeerNameColors.Colors] = []
        if let nameColor = peer.nameColor.flatMap({ context.peerNameColors.get($0, dark: presentationData.theme.overallDarkAppearance) }) {
            colors.append(nameColor)
        }
        if let profileColor = peer.profileColor.flatMap({ context.peerNameColors.getProfile($0, dark: presentationData.theme.overallDarkAppearance, subject: .palette) }) {
            colors.append(profileColor)
        }
        let colorImage = generateSettingsMenuPeerColorsLabelIcon(colors: colors)
        
        items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemPeerColor, label: .image(colorImage, colorImage.size), text: presentationData.strings.Settings_YourColor, icon: nil, action: {
            interaction.editingOpenNameColorSetup()
        }))
        
        var displayPersonalChannel = false
        if data.personalChannel != nil {
            displayPersonalChannel = true
        } else if let personalChannels = state.personalChannels, !personalChannels.isEmpty {
            displayPersonalChannel = true
        }
        if displayPersonalChannel {
            var personalChannelTitle: String?
            if let personalChannel = data.personalChannel, let peer = personalChannel.peer.chatOrMonoforumMainPeer {
                personalChannelTitle = peer.compactDisplayTitle
            }
            
            items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemPeerPersonalChannel, label: .text(personalChannelTitle ?? presentationData.strings.Settings_PersonalChannelEmptyValue), text: presentationData.strings.Settings_PersonalChannelItem, icon: nil, action: {
                interaction.editingOpenPersonalChannel()
            }))
        }
    }
    
    items[.account]!.append(PeerInfoScreenActionItem(id: ItemAddAccount, text: presentationData.strings.Settings_AddAnotherAccount, alignment: .center, action: {
        interaction.openSettings(.addAccount)
    }))
    
    var hasPremiumAccounts = false
    if data.peer?.isPremium == true && !context.account.testingEnvironment {
        hasPremiumAccounts = true
    }
    if let settings = data.globalSettings {
        for (accountContext, peer, _) in settings.accountsAndPeers {
            if !accountContext.account.testingEnvironment {
                if peer.isPremium {
                    hasPremiumAccounts = true
                    break
                }
            }
        }
    }
    
    items[.account]!.append(PeerInfoScreenCommentItem(id: ItemAddAccountHelp, text: hasPremiumAccounts ? presentationData.strings.Settings_AddAnotherAccount_PremiumHelp : presentationData.strings.Settings_AddAnotherAccount_Help))
    
    items[.logout]!.append(PeerInfoScreenActionItem(id: ItemLogout, text: presentationData.strings.Settings_Logout, color: .destructive, alignment: .center, action: {
        interaction.openSettings(.logout)
    }))
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in Section.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}

private enum InfoSection: Int, CaseIterable {
    case groupLocation
    case calls
    case personalChannel
    case peerInfo
    case balances
    case permissions
    case peerInfoTrailing
    case peerSettings
    case peerMembers
    case botAffiliateProgram
}

private func infoItems(data: PeerInfoScreenData?, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction, nearbyPeerDistance: Int32?, reactionSourceMessageId: MessageId?, callMessages: [Message], chatLocation: ChatLocation, isOpenedFromChat: Bool, isMyProfile: Bool) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    var currentPeerInfoSection: InfoSection = .peerInfo
        
    var items: [InfoSection: [PeerInfoScreenItem]] = [:]
    for section in InfoSection.allCases {
        items[section] = []
    }
    
    let bioContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBioContextMenu(node, gesture)
    }
    let bioLinkAction: (TextLinkItemActionType, TextLinkItem, ASDisplayNode, CGRect?, Promise<Bool>?) -> Void = { action, item, _, _, _ in
        interaction.performBioLinkAction(action, item)
    }
    let workingHoursContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openWorkingHoursContextMenu(node, gesture)
    }
    let businessLocationContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBusinessLocationContextMenu(node, gesture)
    }
    let birthdayContextAction: (ASDisplayNode, ContextGesture?, CGPoint?) -> Void = { node, gesture, _ in
        interaction.openBirthdayContextMenu(node, gesture)
    }
    
    if let user = data.peer as? TelegramUser {
        if !callMessages.isEmpty {
            items[.calls]!.append(PeerInfoScreenCallListItem(id: 20, messages: callMessages))
        }
        
        if let personalChannel = data.personalChannel {
            let peerId = personalChannel.peer.peerId
            var label: String?
            if let subscriberCount = personalChannel.subscriberCount {
                label = presentationData.strings.Conversation_StatusSubscribers(Int32(subscriberCount))
            }
            items[.personalChannel]?.append(PeerInfoScreenHeaderItem(id: 0, text: presentationData.strings.Profile_PersonalChannelSectionTitle, label: label))
            items[.personalChannel]?.append(PeerInfoScreenPersonalChannelItem(id: 1, context: context, data: personalChannel, controller: { [weak interaction] in
                guard let interaction else {
                    return nil
                }
                return interaction.getController()
            }, action: { [weak interaction] in
                guard let interaction else {
                    return
                }
                interaction.openChat(peerId)
            }))
        }
        
        if let phone = user.phone {
            let formattedPhone = formatPhoneNumber(context: context, number: phone)
            let label: String
            if formattedPhone.hasPrefix("+888 ") {
                label = presentationData.strings.UserInfo_AnonymousNumberLabel
            } else {
                label = presentationData.strings.ContactInfo_PhoneLabelMobile
            }
            items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 2, label: label, text: formattedPhone, textColor: .accent, action: { node, progress in
                interaction.openPhone(phone, node, nil, progress)
            }, longTapAction: nil, contextAction: { node, gesture, _ in
                interaction.openPhone(phone, node, gesture, nil)
            }, requestLayout: { animated in
                interaction.requestLayout(animated)
            }))
        }
        if let mainUsername = user.addressName {
            var additionalUsernames: String?
            let usernames = user.usernames.filter { $0.isActive && $0.username != mainUsername }
            if !usernames.isEmpty {
                additionalUsernames = presentationData.strings.Profile_AdditionalUsernames(String(usernames.map { "@\($0.username)" }.joined(separator: ", "))).string
            }
            
            items[currentPeerInfoSection]!.append(
                PeerInfoScreenLabeledValueItem(
                    id: 1,
                    label: presentationData.strings.Profile_Username,
                    text: "@\(mainUsername)",
                    additionalText: additionalUsernames,
                    textColor: .accent,
                    icon: .qrCode,
                    action: { _, progress in
                        interaction.openUsername(mainUsername, true, progress)
                    }, linkItemAction: { type, item, _, _, progress in
                        if case .tap = type {
                            if case let .mention(username) = item {
                                interaction.openUsername(String(username[username.index(username.startIndex, offsetBy: 1)...]), false, progress)
                            }
                        }
                    }, iconAction: {
                        interaction.openQrCode()
                    }, contextAction: { node, gesture, _ in
                        interaction.openUsernameContextMenu(node, gesture)
                    }, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }
                )
            )
        }
        
        if let cachedData = data.cachedData as? CachedUserData {
            if let birthday = cachedData.birthday {
                var hasBirthdayToday = false
                let today = Calendar.current.dateComponents(Set([.day, .month]), from: Date())
                if today.day == Int(birthday.day) && today.month == Int(birthday.month) {
                    hasBirthdayToday = true
                }
                
                var birthdayAction: ((ASDisplayNode, Promise<Bool>?) -> Void)?
                if isMyProfile {
                    birthdayAction = { node, _ in
                        birthdayContextAction(node, nil, nil)
                    }
                } else if hasBirthdayToday && cachedData.disallowedGifts != TelegramDisallowedGifts.All {
                    birthdayAction = { _, _ in
                        interaction.openPremiumGift()
                    }
                }
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 400, context: context, label: hasBirthdayToday ? presentationData.strings.UserInfo_BirthdayToday : presentationData.strings.UserInfo_Birthday, text: stringForCompactBirthday(birthday, strings: presentationData.strings, showAge: true), textColor: .primary, leftIcon: hasBirthdayToday ? .birthday : nil, icon: hasBirthdayToday ? .premiumGift : nil, action: birthdayAction, longTapAction: nil, iconAction: {
                    interaction.openPremiumGift()
                }, contextAction: birthdayContextAction, requestLayout: { _ in
                }))
            }
            
            var hasAbout = false
            if let about = cachedData.about, !about.isEmpty {
                hasAbout = true
            }
            
            var hasWebApp = false
            if let botInfo = user.botInfo, botInfo.flags.contains(.hasWebApp) {
                hasWebApp = true
            }
            
            if user.isFake {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: "", text: user.botInfo != nil ? presentationData.strings.UserInfo_FakeBotWarning : presentationData.strings.UserInfo_FakeUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            } else if user.isScam {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: user.botInfo != nil ? presentationData.strings.UserInfo_ScamBotWarning : presentationData.strings.UserInfo_ScamUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            } else if hasAbout || hasWebApp {
                var actionButton: PeerInfoScreenLabeledValueItem.Button?
                if hasWebApp {
                    actionButton = PeerInfoScreenLabeledValueItem.Button(title: presentationData.strings.PeerInfo_OpenAppButton, action: {
                        guard let parentController = interaction.getController() else {
                            return
                        }
                        
                        if let navigationController = parentController.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer {
                            for controller in minimizedContainer.controllers {
                                if let controller = controller as? AttachmentController, let mainController = controller.mainController as? WebAppController, mainController.botId == user.id && mainController.source == .generic {
                                    navigationController.maximizeViewController(controller, animated: true)
                                    return
                                }
                            }
                        }
                        
                        context.sharedContext.openWebApp(
                            context: context,
                            parentController: parentController,
                            updatedPresentationData: nil,
                            botPeer: .user(user),
                            chatPeer: nil,
                            threadId: nil,
                            buttonText: "",
                            url: "",
                            simple: true,
                            source: .generic,
                            skipTermsOfService: true,
                            payload: nil
                        )
                    })
                }
                
                var label: String = ""
                if let about = cachedData.about, !about.isEmpty {
                    label = user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo
                }
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: label, text: cachedData.about ?? "", textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.isPremium ? enabledPublicBioEntities : enabledPrivateBioEntities), action: isMyProfile ? { node, _ in
                    bioContextAction(node, nil, nil)
                } : nil, linkItemAction: bioLinkAction, button: actionButton, contextAction: bioContextAction, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: 800, text: presentationData.strings.PeerInfo_AppFooterAdmin, linkAction: { action in
                        if case let .tap(url) = action {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    }))
                    
                    currentPeerInfoSection = .peerInfoTrailing
                } else if actionButton != nil {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: 800, text: presentationData.strings.PeerInfo_AppFooter, linkAction: { action in
                        if case let .tap(url) = action {
                            context.sharedContext.applicationBindings.openUrl(url)
                        }
                    }))
                    
                    currentPeerInfoSection = .peerInfoTrailing
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                } else {
                    if let starRefProgram = cachedData.starRefProgram, starRefProgram.endDate == nil {
                        var canJoinRefProgram = false
                        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
                            if let value = value as? Double {
                                canJoinRefProgram = value != 0.0
                            } else if let value = value as? Bool {
                                canJoinRefProgram = value
                            }
                        }
                        
                        if canJoinRefProgram {
                            if items[.botAffiliateProgram] == nil {
                                items[.botAffiliateProgram] = []
                            }
                            let programTitleValue: String
                            programTitleValue = "\(formatPermille(starRefProgram.commissionPermille))%"
                            items[.botAffiliateProgram]!.append(PeerInfoScreenDisclosureItem(id: 0, label: .labelBadge(programTitleValue), additionalBadgeLabel: nil, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Title, icon: PresentationResourcesSettings.affiliateProgram, action: {
                                interaction.editingOpenAffiliateProgram()
                            }))
                            items[.botAffiliateProgram]!.append(PeerInfoScreenCommentItem(id: 1, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Footer(EnginePeer.user(user).compactDisplayTitle, formatPermille(starRefProgram.commissionPermille)).string))
                        }
                    }
                }
            }
            
            if let businessHours = cachedData.businessHours {
                items[currentPeerInfoSection]!.append(PeerInfoScreenBusinessHoursItem(id: 300, label: presentationData.strings.PeerInfo_BusinessHours_Label, businessHours: businessHours, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }, longTapAction: nil, contextAction: workingHoursContextAction))
            }
            
            if let businessLocation = cachedData.businessLocation {
                if let coordinates = businessLocation.coordinates {
                    let imageSignal = chatMapSnapshotImage(engine: context.engine, resource: MapSnapshotMediaResource(latitude: coordinates.latitude, longitude: coordinates.longitude, width: 90, height: 90))
                    items[currentPeerInfoSection]!.append(PeerInfoScreenAddressItem(
                        id: 301,
                        label: presentationData.strings.PeerInfo_Location_Label,
                        text: businessLocation.address,
                        imageSignal: imageSignal,
                        action: {
                            interaction.openLocation()
                        },
                        contextAction: businessLocationContextAction
                    ))
                } else {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenAddressItem(
                        id: 301,
                        label: presentationData.strings.PeerInfo_Location_Label,
                        text: businessLocation.address,
                        imageSignal: nil,
                        action: nil,
                        contextAction: businessLocationContextAction
                    ))
                }
            }
        }
        
        if !isMyProfile {
            if let reactionSourceMessageId = reactionSourceMessageId, !data.isContact {
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 3, text: presentationData.strings.UserInfo_SendMessage, action: {
                    interaction.openChat(nil)
                }))
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 4, text: presentationData.strings.ReportPeer_BanAndReport, color: .destructive, action: {
                    interaction.openReport(.reaction(reactionSourceMessageId))
                }))
            } else if let _ = nearbyPeerDistance {
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 3, text: presentationData.strings.UserInfo_SendMessage, action: {
                    interaction.openChat(nil)
                }))
                
                items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 4, text: presentationData.strings.ReportPeer_Report, color: .destructive, action: {
                    interaction.openReport(.user)
                }))
            } else {
                if !data.isContact {
                    if user.botInfo == nil {
                        items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 3, text: presentationData.strings.PeerInfo_AddToContacts, action: {
                            interaction.openAddContact()
                        }))
                    }
                }
                
                var isBlocked = false
                if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                    isBlocked = true
                }
                
                if isBlocked {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 4, text: user.botInfo != nil ? presentationData.strings.Bot_Unblock : presentationData.strings.Conversation_Unblock, action: {
                        interaction.updateBlocked(false)
                    }))
                } else {
                    if user.flags.contains(.isSupport) || data.isContact {
                    } else {
                        if user.botInfo == nil {
                            items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 4, text: presentationData.strings.Conversation_BlockUser, color: .destructive, action: {
                                interaction.updateBlocked(true)
                            }))
                        }
                    }
                }
                
                if let encryptionKeyFingerprint = data.encryptionKeyFingerprint {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenDisclosureEncryptionKeyItem(id: 5, text: presentationData.strings.Profile_EncryptionKey, fingerprint: encryptionKeyFingerprint, action: {
                        interaction.openEncryptionKey()
                    }))
                }
                                
                let revenueBalance = data.revenueStatsState?.balances.currentBalance ?? 0
                let overallRevenueBalance = data.revenueStatsState?.balances.overallRevenue ?? 0
                
                let starsBalance = data.starsRevenueStatsState?.balances.currentBalance ?? StarsAmount.zero
                let overallStarsBalance = data.starsRevenueStatsState?.balances.overallRevenue ?? StarsAmount.zero
                
                if overallRevenueBalance > 0 || overallStarsBalance > StarsAmount.zero {
                    items[.balances]!.append(PeerInfoScreenHeaderItem(id: 20, text: presentationData.strings.PeerInfo_BotBalance_Title))
                    if overallRevenueBalance > 0 {
                        let string = "*\(formatTonAmountText(revenueBalance, dateTimeFormat: presentationData.dateTimeFormat))"
                        let attributedString = NSMutableAttributedString(string: string, font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize), textColor: presentationData.theme.list.itemSecondaryTextColor)
                        if let range = attributedString.string.range(of: "*") {
                            attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .ton), range: NSRange(range, in: attributedString.string))
                            attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                        }
                        items[.balances]!.append(PeerInfoScreenDisclosureItem(id: 21, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_BotBalance_Ton, icon: PresentationResourcesSettings.ton, action: {
                            interaction.editingOpenRevenue()
                        }))
                    }

                    if overallStarsBalance > StarsAmount.zero {
                        let formattedLabel = formatStarsAmountText(starsBalance, dateTimeFormat: presentationData.dateTimeFormat)
                        let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                        let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                        let labelColor = presentationData.theme.list.itemSecondaryTextColor
                        let attributedString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                        attributedString.insert(NSAttributedString(string: "*", font: labelFont, textColor: labelColor), at: 0)
                        
                        if let range = attributedString.string.range(of: "*") {
                            attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                            attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                        }
                        items[.balances]!.append(PeerInfoScreenDisclosureItem(id: 22, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_BotBalance_Stars, icon: PresentationResourcesSettings.stars, action: {
                            interaction.editingOpenStars()
                        }))
                    }
                } else {
                    print()
                }
                
                if let _ = user.botInfo {
                    var canManageEmojiStatus = false
                    if let cachedData = data.cachedData as? CachedUserData, cachedData.flags.contains(.botCanManageEmojiStatus) {
                        canManageEmojiStatus = true
                    }
                    if canManageEmojiStatus || data.webAppPermissions?.emojiStatus?.isRequested == true {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: 31, text: presentationData.strings.PeerInfo_Permissions_EmojiStatus, value: canManageEmojiStatus, icon: UIImage(bundleImageName: "Chat/Info/Status"), isLocked: false, toggled: { value in
                            let _ = (context.engine.peers.toggleBotEmojiStatusAccess(peerId: user.id, enabled: value)
                                     |> deliverOnMainQueue).startStandalone()
                            
                            let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: user.id) { current in
                                return WebAppPermissionsState(location: current?.location, emojiStatus: WebAppPermissionsState.EmojiStatus(isRequested: true))
                            }.startStandalone()
                        }))
                    }
                    if data.webAppPermissions?.location?.isRequested == true || data.webAppPermissions?.location?.isAllowed == true {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: 32, text: presentationData.strings.PeerInfo_Permissions_Geolocation, value: data.webAppPermissions?.location?.isAllowed ?? false, icon: UIImage(bundleImageName: "Chat/Info/Location"), isLocked: false, toggled: { value in
                            let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: user.id) { current in
                                return WebAppPermissionsState(location: WebAppPermissionsState.Location(isRequested: true, isAllowed: value), emojiStatus: current?.emojiStatus)
                            }.startStandalone()
                        }))
                    }
                    if !"".isEmpty {
                        items[.permissions]!.append(PeerInfoScreenSwitchItem(id: 33, text: presentationData.strings.PeerInfo_Permissions_Biometry, value: true, icon: UIImage(bundleImageName: "Settings/Menu/TouchId"), isLocked: false, toggled: { value in
                          
                        }))
                    }
                    
                    if !items[.permissions]!.isEmpty {
                        items[.permissions]!.insert(PeerInfoScreenHeaderItem(id: 30, text: presentationData.strings.PeerInfo_Permissions_Title), at: 0)
                    }
                }
                
                if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenDisclosureItem(id: 10, label: .none, text: presentationData.strings.Bot_Settings, icon: UIImage(bundleImageName: "Chat/Info/SettingsIcon"), action: {
                        interaction.openEditing()
                    }))
                }
                
                if let botInfo = user.botInfo, !botInfo.flags.contains(.canEdit) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 6, text: presentationData.strings.ReportPeer_Report, action: {
                        interaction.openReport(.default)
                    }))
                }
                                
                if let verification = (data.cachedData as? CachedUserData)?.verification {
                    let description: String
                    let descriptionString = verification.description
                    let entities = generateTextEntities(descriptionString, enabledTypes: [.allUrl])
                    if let entity = entities.first {
                        let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                        let url = (descriptionString as NSString).substring(with: range)
                        description = descriptionString.replacingOccurrences(of: url, with: "[\(url)](\(url))")
                    } else {
                        description = descriptionString
                    }
                    let attributedPrefix = NSMutableAttributedString(string: "  ")
                    attributedPrefix.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: verification.iconFileId, file: nil), range: NSMakeRange(0, 1))
                    
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: 800, text: description, attributedPrefix: attributedPrefix, useAccentLinkColor: false, linkAction: { action in
                        if case let .tap(url) = action, let navigationController = interaction.getController()?.navigationController as? NavigationController {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    }))
                } else if let botInfo = user.botInfo, botInfo.flags.contains(.worksWithGroups) {
                    items[currentPeerInfoSection]!.append(PeerInfoScreenActionItem(id: 7, text: presentationData.strings.Bot_AddToChat, color: .accent, action: {
                        interaction.openAddBotToGroup()
                    }))
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: 8, text: presentationData.strings.Bot_AddToChatInfo))
                }
            }
        }
    } else if let channel = data.peer as? TelegramChannel {
        let ItemUsername = 1
        let ItemUsernameInfo = 2
        let ItemAbout = 3
        let ItemLocationHeader = 4
        let ItemLocation = 5
        let ItemAdmins = 6
        let ItemMembers = 7
        let ItemMemberRequests = 8
        let ItemBalance = 9
        let ItemEdit = 10
        
        if let _ = data.threadData {
            let mainUsername: String
            if let addressName = channel.addressName {
                mainUsername = addressName
            } else {
                mainUsername = "c/\(channel.id.id._internalGetInt64Value())"
            }
            
            var threadId: Int64 = 0
            if case let .replyThread(message) = chatLocation {
                threadId = message.threadId
            }
            
            let linkText = "https://t.me/\(mainUsername)/\(threadId)"
            
            items[currentPeerInfoSection]!.append(
                PeerInfoScreenLabeledValueItem(
                    id: ItemUsername,
                    label: presentationData.strings.Channel_LinkItem,
                    text: linkText,
                    textColor: .accent,
                    icon: .qrCode,
                    action: { _, progress in
                        interaction.openUsername(linkText, true, progress)
                    }, longTapAction: { sourceNode in
                        interaction.openPeerInfoContextMenu(.link(customLink: linkText), sourceNode, nil)
                    }, linkItemAction: { type, item, _, _, progress in
                        if case .tap = type {
                            if case let .mention(username) = item {
                                interaction.openUsername(String(username.suffix(from: username.index(username.startIndex, offsetBy: 1))), false, progress)
                            }
                        }
                    }, iconAction: {
                        interaction.openQrCode()
                    }, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }
                )
            )
            if let _ = channel.addressName {
                
            } else {
                items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: ItemUsernameInfo, text: presentationData.strings.PeerInfo_PrivateShareLinkInfo))
            }
        } else {
            if let location = (data.cachedData as? CachedChannelData)?.peerGeoLocation {
                items[.groupLocation]!.append(PeerInfoScreenHeaderItem(id: ItemLocationHeader, text: presentationData.strings.GroupInfo_Location.uppercased()))
                
                let imageSignal = chatMapSnapshotImage(engine: context.engine, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
                items[.groupLocation]!.append(PeerInfoScreenAddressItem(
                    id: ItemLocation,
                    label: "",
                    text: location.address.replacingOccurrences(of: ", ", with: "\n"),
                    imageSignal: imageSignal,
                    action: {
                        interaction.openLocation()
                    }
                ))
            }
            
            if let mainUsername = channel.addressName {
                var additionalUsernames: String?
                let usernames = channel.usernames.filter { $0.isActive && $0.username != mainUsername }
                if !usernames.isEmpty {
                    additionalUsernames = presentationData.strings.Profile_AdditionalUsernames(String(usernames.map { "@\($0.username)" }.joined(separator: ", "))).string
                }
                
                items[currentPeerInfoSection]!.append(
                    PeerInfoScreenLabeledValueItem(
                        id: ItemUsername,
                        label: presentationData.strings.Channel_LinkItem,
                        text: "https://t.me/\(mainUsername)",
                        additionalText: additionalUsernames,
                        textColor: .accent,
                        icon: .qrCode,
                        action: { _, progress in
                            interaction.openUsername(mainUsername, true, progress)
                        }, longTapAction: { sourceNode in
                            interaction.openPeerInfoContextMenu(.link(customLink: nil), sourceNode, nil)
                        }, linkItemAction: { type, item, sourceNode, sourceRect, progress in
                            if case .tap = type {
                                if case let .mention(username) = item {
                                    interaction.openUsername(String(username.suffix(from: username.index(username.startIndex, offsetBy: 1))), false, progress)
                                }
                            } else if case .longTap = type {
                                if case let .mention(username) = item {
                                    interaction.openPeerInfoContextMenu(.link(customLink: username), sourceNode, sourceRect)
                                }
                            }
                        }, iconAction: {
                            interaction.openQrCode()
                        }, requestLayout: { animated in
                            interaction.requestLayout(animated)
                        }
                    )
                )
            }
            if let cachedData = data.cachedData as? CachedChannelData {
                let aboutText: String?
                if channel.isFake {
                    if case .broadcast = channel.info {
                        aboutText = presentationData.strings.ChannelInfo_FakeChannelWarning
                    } else {
                        aboutText = presentationData.strings.GroupInfo_FakeGroupWarning
                    }
                } else if channel.isScam {
                    if case .broadcast = channel.info {
                        aboutText = presentationData.strings.ChannelInfo_ScamChannelWarning
                    } else {
                        aboutText = presentationData.strings.GroupInfo_ScamGroupWarning
                    }
                } else if let about = cachedData.about, !about.isEmpty {
                    aboutText = about
                } else {
                    aboutText = nil
                }
                
                if let aboutText = aboutText {
                    var enabledEntities = enabledPublicBioEntities
                    if case .group = channel.info {
                        enabledEntities = enabledPrivateBioEntities
                    }
                    items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: presentationData.strings.Channel_Info_Description, text: aboutText, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledEntities), action: isMyProfile ? { node, _ in
                        bioContextAction(node, nil, nil)
                    } : nil, linkItemAction: bioLinkAction, contextAction: bioContextAction, requestLayout: { animated in
                        interaction.requestLayout(animated)
                    }))
                }
                
                if let verification = (data.cachedData as? CachedChannelData)?.verification {
                    let description: String
                    let descriptionString = verification.description
                    let entities = generateTextEntities(descriptionString, enabledTypes: [.allUrl])
                    if let entity = entities.first {
                        let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                        let url = (descriptionString as NSString).substring(with: range)
                        description = descriptionString.replacingOccurrences(of: url, with: "[\(url)](\(url))")
                    } else {
                        description = descriptionString
                    }
                    
                    let attributedPrefix = NSMutableAttributedString(string: "  ")
                    attributedPrefix.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: verification.iconFileId, file: nil), range: NSMakeRange(0, 1))
                    
                    items[currentPeerInfoSection]!.append(PeerInfoScreenCommentItem(id: 800, text: description, attributedPrefix: attributedPrefix, useAccentLinkColor: false, linkAction: { action in
                        if case let .tap(url) = action, let navigationController = interaction.getController()?.navigationController as? NavigationController {
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                        }
                    }))
                }
                
                if case .broadcast = channel.info {
                    var canEditMembers = false
                    if channel.hasPermission(.banMembers) {
                        canEditMembers = true
                    }
                    if canEditMembers {
                        if channel.adminRights != nil || channel.flags.contains(.isCreator) {
                            let adminCount = cachedData.participantsSummary.adminCount ?? 0
                            let memberCount = cachedData.participantsSummary.memberCount ?? 0
                            
                            items[.peerMembers]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text("\(adminCount == 0 ? "" : "\(presentationStringsFormattedNumber(adminCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                                interaction.openParticipantsSection(.admins)
                            }))
                            items[.peerMembers]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text("\(memberCount == 0 ? "" : "\(presentationStringsFormattedNumber(memberCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.Channel_Info_Subscribers, icon: UIImage(bundleImageName: "Chat/Info/GroupMembersIcon"), action: {
                                interaction.openParticipantsSection(.members)
                            }))
                            
                            if let count = data.requests?.count, count > 0 {
                                items[.peerMembers]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                                    interaction.openParticipantsSection(.memberRequests)
                                }))
                            }
                        }
                    }
                }
                     
                if channel.adminRights != nil || channel.flags.contains(.isCreator) {
                    let section: InfoSection
                    if case .group = channel.info {
                        section = .peerSettings
                    } else {
                        section = .peerMembers
                    }
                    if cachedData.flags.contains(.canViewRevenue) || cachedData.flags.contains(.canViewStarsRevenue) {
                        let revenueBalance = data.revenueStatsState?.balances.currentBalance ?? 0
                        let starsBalance = data.starsRevenueStatsState?.balances.currentBalance ?? StarsAmount.zero
                        
                        let overallRevenueBalance = data.revenueStatsState?.balances.overallRevenue ?? 0
                        let overallStarsBalance = data.starsRevenueStatsState?.balances.overallRevenue ?? StarsAmount.zero
                        
                        if overallRevenueBalance > 0 || overallStarsBalance > StarsAmount.zero {
                            let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                            let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                            let labelColor = presentationData.theme.list.itemSecondaryTextColor
                            
                            let attributedString = NSMutableAttributedString()
                            if overallRevenueBalance > 0 {
                                attributedString.append(NSAttributedString(string: "#\(formatTonAmountText(revenueBalance, dateTimeFormat: presentationData.dateTimeFormat))", font: labelFont, textColor: labelColor))
                            }
                            if overallStarsBalance > StarsAmount.zero {
                                if !attributedString.string.isEmpty {
                                    attributedString.append(NSAttributedString(string: " ", font: labelFont, textColor: labelColor))
                                }
                                attributedString.append(NSAttributedString(string: "*", font: labelFont, textColor: labelColor))
                                
                                let formattedLabel = formatStarsAmountText(starsBalance, dateTimeFormat: presentationData.dateTimeFormat)
                                let starsAttributedString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                                attributedString.append(starsAttributedString)
                            }
                            if let range = attributedString.string.range(of: "#") {
                                attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .ton), range: NSRange(range, in: attributedString.string))
                                attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                            }
                            if let range = attributedString.string.range(of: "*") {
                                attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 1, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                                attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                            }
                            
                            items[section]!.append(PeerInfoScreenDisclosureItem(id: ItemBalance, label: .attributedText(attributedString), text: presentationData.strings.PeerInfo_Bot_Balance, icon: PresentationResourcesSettings.balance, action: {
                                interaction.openStats(.monetization)
                            }))
                        }
                    }
                    
                    let settingsTitle: String
                    switch channel.info {
                    case .broadcast:
                        settingsTitle = presentationData.strings.Channel_Info_Settings
                    case .group:
                        settingsTitle = presentationData.strings.Group_Info_Settings
                    }
                    items[section]!.append(PeerInfoScreenDisclosureItem(id: ItemEdit, label: .none, text: settingsTitle, icon: UIImage(bundleImageName: "Chat/Info/SettingsIcon"), action: {
                        interaction.openEditing()
                    }))
                }
            }
        }
    } else if let group = data.peer as? TelegramGroup {
        if let cachedData = data.cachedData as? CachedGroupData {
            let aboutText: String?
            if group.isFake {
                aboutText = presentationData.strings.GroupInfo_FakeGroupWarning
            } else if group.isScam {
                aboutText = presentationData.strings.GroupInfo_ScamGroupWarning
            } else if let about = cachedData.about, !about.isEmpty {
                aboutText = about
            } else {
                aboutText = nil
            }
            
            if let aboutText = aboutText {
                items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: presentationData.strings.Channel_Info_Description, text: aboutText, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledPrivateBioEntities), action: isMyProfile ? { node, _ in
                    bioContextAction(node, nil, nil)
                } : nil, linkItemAction: bioLinkAction, contextAction: bioContextAction, requestLayout: { animated in
                    interaction.requestLayout(animated)
                }))
            }
        }
    }
    
    if let peer = data.peer, let members = data.members, case let .shortList(_, memberList) = members {
        var canAddMembers = false
        if let group = data.peer as? TelegramGroup {
            switch group.role {
                case .admin, .creator:
                    canAddMembers = true
                case .member:
                    break
            }
            if !group.hasBannedPermission(.banAddMembers) {
                canAddMembers = true
            }
        } else if let channel = data.peer as? TelegramChannel {
            switch channel.info {
            case .broadcast:
                break
            case .group:
                if channel.flags.contains(.isCreator) || channel.hasPermission(.inviteMembers) {
                    canAddMembers = true
                }
            }
        }
        
        if canAddMembers {
            items[.peerMembers]!.append(PeerInfoScreenActionItem(id: 0, text: presentationData.strings.GroupInfo_AddParticipant, color: .accent, icon: UIImage(bundleImageName: "Contact List/AddMemberIcon"), alignment: .peerList, action: {
                interaction.openAddMember()
            }))
        }
        
        for member in memberList {
            let isAccountPeer = member.id == context.account.peerId
            items[.peerMembers]!.append(PeerInfoScreenMemberItem(id: member.id, context: .account(context), enclosingPeer: peer, member: member, isAccount: false, action: isAccountPeer ? nil : { action in
                switch action {
                case .open:
                    interaction.openPeerInfo(member.peer, true)
                case .promote:
                    interaction.performMemberAction(member, .promote)
                case .restrict:
                    interaction.performMemberAction(member, .restrict)
                case .remove:
                    interaction.performMemberAction(member, .remove)
                }
            }, openStories: { sourceView in
                interaction.performMemberAction(member, .openStories(sourceView: sourceView))
            }))
        }
    }
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in InfoSection.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}

private func editingItems(data: PeerInfoScreenData?, boostStatus: ChannelBoostStatus?, state: PeerInfoState, chatLocation: ChatLocation, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [(AnyHashable, [PeerInfoScreenItem])] {
    enum Section: Int, CaseIterable {
        case notifications
        case groupLocation
        case peerPublicSettings
        case peerDataSettings
        case peerVerifySettings
        case peerSettings
        case linkedMonoforum
        case peerAdditionalSettings
        case peerActions
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    if let data = data {
        if let user = data.peer as? TelegramUser {
            let ItemSuggest = 0
            let ItemCustom = 1
            let ItemReset = 2
            let ItemInfo = 3
            let ItemDelete = 4
            let ItemUsername = 5
            let ItemAffiliateProgram = 6
            
            let ItemVerify = 8
            
            let ItemIntro = 8
            let ItemCommands = 9
            let ItemBotSettings = 10
            let ItemBotInfo = 11
            
            if let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text("@\(user.addressName ?? "")"), text: presentationData.strings.PeerInfo_Bot_Username, icon: PresentationResourcesSettings.bot, action: {
                    interaction.editingOpenPublicLinkSetup()
                }))
                
                var canSetupRefProgram = false
                if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_program_allowed"] {
                    if let value = value as? Double {
                        canSetupRefProgram = value != 0.0
                    } else if let value = value as? Bool {
                        canSetupRefProgram = value
                    }
                }
                
                if canSetupRefProgram {
                    let programTitleValue: PeerInfoScreenDisclosureItem.Label
                    if let cachedData = data.cachedData as? CachedUserData, let starRefProgram = cachedData.starRefProgram, starRefProgram.endDate == nil {
                        programTitleValue = .labelBadge("\(formatPermille(starRefProgram.commissionPermille))%")
                    } else {
                        programTitleValue = .text(presentationData.strings.PeerInfo_ItemAffiliateProgram_ValueOff)
                    }
                    items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAffiliateProgram, label: programTitleValue, additionalBadgeLabel: presentationData.strings.Settings_New, text: presentationData.strings.PeerInfo_ItemAffiliateProgram_Title, icon: PresentationResourcesSettings.affiliateProgram, action: {
                        interaction.editingOpenAffiliateProgram()
                    }))
                }
                
                if let cachedUserData = data.cachedData as? CachedUserData, let _ = cachedUserData.botInfo?.verifierSettings {
                    items[.peerVerifySettings]!.append(PeerInfoScreenActionItem(id: ItemVerify, text: presentationData.strings.PeerInfo_VerifyAccounts, icon: UIImage(bundleImageName: "Peer Info/BotVerify"), action: {
                        interaction.editingOpenVerifyAccounts()
                    }))
                }
                                
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemIntro, text: presentationData.strings.PeerInfo_Bot_EditIntro, icon: UIImage(bundleImageName: "Peer Info/BotIntro"), action: {
                    interaction.openPeerMention("botfather", .withBotStartPayload(ChatControllerInitialBotStart(payload: "\(user.addressName ?? "")-intro", behavior: .interactive)))
                }))
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemCommands, text: presentationData.strings.PeerInfo_Bot_EditCommands, icon: UIImage(bundleImageName: "Peer Info/BotCommands"), action: {
                    interaction.openPeerMention("botfather", .withBotStartPayload(ChatControllerInitialBotStart(payload: "\(user.addressName ?? "")-commands", behavior: .interactive)))
                }))
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemBotSettings, text: presentationData.strings.PeerInfo_Bot_ChangeSettings, icon: UIImage(bundleImageName: "Peer Info/BotSettings"), action: {
                    interaction.openPeerMention("botfather", .withBotStartPayload(ChatControllerInitialBotStart(payload: user.addressName ?? "", behavior: .interactive)))
                }))
                items[.peerSettings]!.append(PeerInfoScreenCommentItem(id: ItemBotInfo, text: presentationData.strings.PeerInfo_Bot_BotFatherInfo, linkAction: { _ in
                    interaction.openPeerMention("botfather", .default)
                }))
            } else if !user.flags.contains(.isSupport) {
                let compactName = EnginePeer(user).compactDisplayTitle
                
                if let cachedData = data.cachedData as? CachedUserData, let _ = cachedData.sendPaidMessageStars {
                    
                } else {   
                    items[.peerDataSettings]!.append(PeerInfoScreenActionItem(id: ItemSuggest, text: presentationData.strings.UserInfo_SuggestPhoto(compactName).string, color: .accent, icon: UIImage(bundleImageName: "Peer Info/SuggestAvatar"), action: {
                        interaction.suggestPhoto()
                    }))
                }
                
                let setText: String
                if user.photo.first?.isPersonal == true || state.updatingAvatar != nil {
                    setText = presentationData.strings.UserInfo_ChangeCustomPhoto(compactName).string
                } else {
                    setText = presentationData.strings.UserInfo_SetCustomPhoto(compactName).string
                }
                
                items[.peerDataSettings]!.append(PeerInfoScreenActionItem(id: ItemCustom, text: setText, color: .accent, icon: UIImage(bundleImageName: "Settings/SetAvatar"), action: {
                    interaction.setCustomPhoto()
                }))
                
                if user.photo.first?.isPersonal == true || state.updatingAvatar != nil {
                    var representation: TelegramMediaImageRepresentation?
                    var originalIsVideo: Bool?
                    if let cachedData = data.cachedData as? CachedUserData, case let .known(photo) = cachedData.photo {
                        representation = photo?.representationForDisplayAtSize(PixelDimensions(width: 28, height: 28))
                        originalIsVideo = !(photo?.videoRepresentations.isEmpty ?? true)
                    }
                    
                    let removeText: String
                    if let originalIsVideo {
                        removeText = originalIsVideo ? presentationData.strings.UserInfo_ResetCustomVideo : presentationData.strings.UserInfo_ResetCustomPhoto
                    } else {
                        removeText = user.photo.first?.hasVideo == true ? presentationData.strings.UserInfo_RemoveCustomVideo : presentationData.strings.UserInfo_RemoveCustomPhoto
                    }
                    
                    let imageSignal: Signal<UIImage?, NoError>
                    if let representation, let signal = peerAvatarImage(account: context.account, peerReference: PeerReference(user), authorOfMessage: nil, representation: representation, displayDimensions: CGSize(width: 28.0, height: 28.0)) {
                        imageSignal = signal
                        |> map { data -> UIImage? in
                            return data?.0
                        }
                    } else {
                        imageSignal = peerAvatarCompleteImage(account: context.account, peer: EnginePeer(user), forceProvidedRepresentation: true, representation: representation, size: CGSize(width: 28.0, height: 28.0))
                    }
                    
                    items[.peerDataSettings]!.append(PeerInfoScreenActionItem(id: ItemReset, text: removeText, color: .accent, icon: nil, iconSignal: imageSignal, action: {
                        interaction.resetCustomPhoto()
                    }))
                }
                items[.peerDataSettings]!.append(PeerInfoScreenCommentItem(id: ItemInfo, text: presentationData.strings.UserInfo_CustomPhotoInfo(compactName).string))
            }
            
            if data.isContact {
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemDelete, text: presentationData.strings.UserInfo_DeleteContact, color: .destructive, action: {
                    interaction.requestDeleteContact()
                }))
            }
        } else if let channel = data.peer as? TelegramChannel {
            switch channel.info {
            case .broadcast:
                let ItemUsername = 1
                let ItemPeerColor = 2
                let ItemInviteLinks = 3
                let ItemDiscussionGroup = 4
                let ItemDeleteChannel = 5
                let ItemReactions = 6
                let ItemAdmins = 7
                let ItemMembers = 8
                let ItemMemberRequests = 9
                let ItemStats = 10
                let ItemBanned = 11
                let ItemRecentActions = 12
                let ItemAffiliatePrograms = 13
                let ItemPostSuggestionsSettings = 14
                let ItemPeerAutoTranslate = 15
                let ItemChannelMessages = 16
                
                let isCreator = channel.flags.contains(.isCreator)
                
                if isCreator {
                    let linkText: String
                    if let _ = channel.addressName {
                        linkText = presentationData.strings.Channel_Setup_TypePublic
                    } else {
                        linkText = presentationData.strings.Channel_Setup_TypePrivate
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(linkText), text: presentationData.strings.Channel_TypeSetup_Title, icon: UIImage(bundleImageName: "Chat/Info/GroupChannelIcon"), action: {
                        interaction.editingOpenPublicLinkSetup()
                    }))
                }

                if (isCreator && (channel.addressName?.isEmpty ?? true)) || (!channel.flags.contains(.isCreator) && channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                    let invitesText: String
                    if let count = data.invitations?.count, count > 0 {
                        invitesText = "\(count)"
                    } else {
                        invitesText = ""
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                        interaction.editingOpenInviteLinksSetup()
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    let discussionGroupTitle: String
                    if let _ = data.cachedData as? CachedChannelData {
                        if let peer = data.linkedDiscussionPeer {
                            if let addressName = peer.addressName, !addressName.isEmpty {
                                discussionGroupTitle = "@\(addressName)"
                            } else {
                                discussionGroupTitle = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            }
                        } else {
                            discussionGroupTitle = presentationData.strings.Channel_DiscussionGroupAdd
                        }
                    } else {
                        discussionGroupTitle = "..."
                    }
                    
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemDiscussionGroup, label: .text(discussionGroupTitle), text: presentationData.strings.Channel_DiscussionGroup, icon: UIImage(bundleImageName: "Chat/Info/GroupDiscussionIcon"), action: {
                        interaction.editingOpenDiscussionGroupSetup()
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    let label: String
                    if let cachedData = data.cachedData as? CachedChannelData, case let .known(reactionSettings) = cachedData.reactionSettings {
                        switch reactionSettings.allowedReactions {
                        case .all:
                            label = presentationData.strings.PeerInfo_LabelAllReactions
                        case .empty:
                            if let starsAllowed = reactionSettings.starsAllowed, starsAllowed {
                                label = "1"
                            } else {
                                label = presentationData.strings.PeerInfo_ReactionsDisabled
                            }
                        case let .limited(reactions):
                            var countValue = reactions.count
                            if let starsAllowed = reactionSettings.starsAllowed, starsAllowed {
                                countValue += 1
                            }
                            label = "\(countValue)"
                        }
                    } else {
                        label = ""
                    }
                    let additionalBadgeLabel: String? = nil
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), additionalBadgeLabel: additionalBadgeLabel, text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                        interaction.editingOpenReactionsSetup()
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    var colors: [PeerNameColors.Colors] = []
                    if let nameColor = channel.nameColor.flatMap({ context.peerNameColors.get($0, dark: presentationData.theme.overallDarkAppearance) }) {
                        colors.append(nameColor)
                    }
                    if let profileColor = channel.profileColor.flatMap({ context.peerNameColors.getProfile($0, dark: presentationData.theme.overallDarkAppearance, subject: .palette) }) {
                        colors.append(profileColor)
                    }
                    let colorImage = generateSettingsMenuPeerColorsLabelIcon(colors: colors)
                    
                    var boostIcon: UIImage?
                    if let approximateBoostLevel = channel.approximateBoostLevel, approximateBoostLevel < 1 {
                        boostIcon = generateDisclosureActionBoostLevelBadgeImage(text: presentationData.strings.Channel_Info_BoostLevelPlusBadge("1").string)
                    } else {
                        /*let labelText = NSAttributedString(string: presentationData.strings.Settings_New, font: Font.medium(11.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
                        let labelBounds = labelText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                        let labelSize = CGSize(width: ceil(labelBounds.width), height: ceil(labelBounds.height))
                        let badgeSize = CGSize(width: labelSize.width + 8.0, height: labelSize.height + 2.0 + 1.0)
                        boostIcon = generateImage(badgeSize, rotatedContext: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            
                            let rect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height - UIScreenPixel * 2.0))
                            
                            context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 5.0).cgPath)
                            context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                            context.fillPath()
                            
                            UIGraphicsPushContext(context)
                            labelText.draw(at: CGPoint(x: 4.0, y: 1.0 + UIScreenPixel))
                            UIGraphicsPopContext()
                        })*/
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPeerColor, label: .image(colorImage, colorImage.size), additionalBadgeIcon: boostIcon, text: presentationData.strings.Channel_Info_AppearanceItem, icon: UIImage(bundleImageName: "Chat/Info/NameColorIcon"), action: {
                        interaction.editingOpenNameColorSetup()
                    }))
                    
                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                    var isLocked = true
                    if let boostLevel = boostStatus?.level, boostLevel >= BoostSubject.autoTranslate.requiredLevel(group: false, context: context, configuration: premiumConfiguration) {
                        isLocked = false
                    }
                    items[.peerSettings]!.append(PeerInfoScreenSwitchItem(id: ItemPeerAutoTranslate, text: presentationData.strings.Channel_Info_AutoTranslate, value: channel.flags.contains(.autoTranslateEnabled), icon: UIImage(bundleImageName: "Settings/Menu/AutoTranslate"), isLocked: isLocked, toggled: { value in
                        if isLocked {
                            interaction.displayAutoTranslateLocked()
                        } else {
                            interaction.editingToggleAutoTranslate(value)
                        }
                    }))
                }
                
                if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                    let labelString: NSAttributedString
                    if channel.linkedMonoforumId != nil {
                        if let monoforumPeer = data.linkedMonoforumPeer as? TelegramChannel {
                            if let sendPaidMessageStars = monoforumPeer.sendPaidMessageStars {
                                let formattedLabel = formatStarsAmountText(sendPaidMessageStars, dateTimeFormat: presentationData.dateTimeFormat)
                                let smallLabelFont = Font.regular(floor(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 13.0))
                                let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                                let labelColor = presentationData.theme.list.itemSecondaryTextColor
                                let attributedString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                                attributedString.insert(NSAttributedString(string: "*", font: labelFont, textColor: labelColor), at: 0)
                                
                                if let range = attributedString.string.range(of: "*") {
                                    attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: attributedString.string))
                                    attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                                }
                                labelString = attributedString
                            } else {
                                let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                                let labelColor = presentationData.theme.list.itemSecondaryTextColor
                                
                                labelString = NSAttributedString(string: presentationData.strings.PeerInfo_AllowChannelMessages_Free, font: labelFont, textColor: labelColor)
                            }
                        } else {
                            let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                            let labelColor = presentationData.theme.list.itemSecondaryTextColor
                            
                            labelString = NSAttributedString(string: " ", font: labelFont, textColor: labelColor)
                        }
                    } else {
                        let labelFont = Font.regular(presentationData.listsFontSize.itemListBaseFontSize)
                        let labelColor = presentationData.theme.list.itemSecondaryTextColor
                        
                        labelString = NSAttributedString(string: presentationData.strings.PeerInfo_AllowChannelMessages_Off, font: labelFont, textColor: labelColor)
                    }
                    
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPostSuggestionsSettings, label: .attributedText(labelString), additionalBadgeLabel: presentationData.strings.Settings_New, text: presentationData.strings.PeerInfo_AllowChannelMessages, icon: PresentationResourcesSettings.channelMessages, action: {
                        interaction.editingOpenPostSuggestionsSetup()
                    }))
                    
                    if let personalChannel = data.personalChannel {
                        let peerId = personalChannel.peer.peerId
                        items[.linkedMonoforum]?.append(PeerInfoScreenPersonalChannelItem(id: 1, context: context, data: personalChannel, controller: { [weak interaction] in
                            guard let interaction else {
                                return nil
                            }
                            return interaction.getController()
                        }, action: { [weak interaction] in
                            guard let interaction else {
                                return
                            }
                            interaction.openChat(peerId)
                        }))
                    }
                }
                
                var canEditMembers = false
                if channel.hasPermission(.banMembers) && (channel.adminRights != nil || channel.flags.contains(.isCreator)) {
                    canEditMembers = true
                }
                if canEditMembers {
                    let adminCount: Int32
                    let memberCount: Int32
                    if let cachedData = data.cachedData as? CachedChannelData {
                        adminCount = cachedData.participantsSummary.adminCount ?? 0
                        memberCount = cachedData.participantsSummary.memberCount ?? 0
                    } else {
                        adminCount = 0
                        memberCount = 0
                    }
                    
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text("\(adminCount == 0 ? "" : "\(presentationStringsFormattedNumber(adminCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                        interaction.openParticipantsSection(.admins)
                    }))
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text("\(memberCount == 0 ? "" : "\(presentationStringsFormattedNumber(memberCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.Channel_Info_Subscribers, icon: UIImage(bundleImageName: "Chat/Info/GroupMembersIcon"), action: {
                        interaction.openParticipantsSection(.members)
                    }))
                    
                    if let count = data.requests?.count, count > 0 {
                        items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                            interaction.openParticipantsSection(.memberRequests)
                        }))
                    }
                }
                
                if let cachedData = data.cachedData as? CachedChannelData, cachedData.flags.contains(.canViewStats) {
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemStats, label: .none, text: presentationData.strings.Channel_Info_Stats, icon: UIImage(bundleImageName: "Chat/Info/StatsIcon"), action: {
                        interaction.openStats(.stats)
                    }))
                }
                
                if canEditMembers {
                    let bannedCount: Int32
                    if let cachedData = data.cachedData as? CachedChannelData {
                        bannedCount = cachedData.participantsSummary.kickedCount ?? 0
                    } else {
                        bannedCount = 0
                    }
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemBanned, label: .text("\(bannedCount == 0 ? "" : "\(presentationStringsFormattedNumber(bannedCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Permissions_Removed, icon: UIImage(bundleImageName: "Chat/Info/GroupRemovedIcon"), action: {
                        interaction.openParticipantsSection(.banned)
                    }))
                    
                    items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemRecentActions, label: .none, text: presentationData.strings.Group_Info_AdminLog, icon: UIImage(bundleImageName: "Chat/Info/RecentActionsIcon"), action: {
                        interaction.openRecentActions()
                    }))
                    
                    if channel.linkedMonoforumId != nil {
                        items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemChannelMessages, label: .none, text: presentationData.strings.PeerInfo_ChannelMessages, icon: PresentationResourcesSettings.channelMessages, action: {
                            interaction.openChannelMessages()
                        }))
                    }
                }
                
                if channel.hasPermission(.changeInfo) {
                    var canJoinRefProgram = false
                    if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
                        if let value = value as? Double {
                            canJoinRefProgram = value != 0.0
                        } else if let value = value as? Bool {
                            canJoinRefProgram = value
                        }
                    }
                    
                    if canJoinRefProgram {
                        items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAffiliatePrograms, label: .text(""), additionalBadgeLabel: nil, text: presentationData.strings.PeerInfo_ItemAffiliatePrograms_Title, icon: PresentationResourcesSettings.affiliateProgram, action: {
                            interaction.editingOpenAffiliateProgram()
                        }))
                    }
                }
                
                if isCreator { //if let cachedData = data.cachedData as? CachedChannelData, cachedData.flags.contains(.canDeleteHistory) {
                    items[.peerActions]!.append(PeerInfoScreenActionItem(id: ItemDeleteChannel, text: presentationData.strings.ChannelInfo_DeleteChannel, color: .destructive, icon: nil, alignment: .natural, action: {
                        interaction.openDeletePeer()
                    }))
                }
            case .group:
                let ItemUsername = 101
                let ItemInviteLinks = 102
                let ItemLinkedChannel = 103
                let ItemPreHistory = 104
                let ItemMembers = 106
                let ItemPermissions = 107
                let ItemAdmins = 108
                let ItemMemberRequests = 109
                let ItemRemovedUsers = 110
                let ItemRecentActions = 111
                let ItemLocationHeader = 112
                let ItemLocation = 113
                let ItemLocationSetup = 114
                let ItemDeleteGroup = 115
                let ItemReactions = 116
                let ItemTopics = 117
                let ItemTopicsText = 118
                let ItemAppearance = 119
                
                let isCreator = channel.flags.contains(.isCreator)
                let isPublic = channel.addressName != nil
                
                if let cachedData = data.cachedData as? CachedChannelData {
                    if isCreator, let location = cachedData.peerGeoLocation {
                        items[.groupLocation]!.append(PeerInfoScreenHeaderItem(id: ItemLocationHeader, text: presentationData.strings.GroupInfo_Location.uppercased()))
                        
                        let imageSignal = chatMapSnapshotImage(engine: context.engine, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
                        items[.groupLocation]!.append(PeerInfoScreenAddressItem(
                            id: ItemLocation,
                            label: "",
                            text: location.address.replacingOccurrences(of: ", ", with: "\n"),
                            imageSignal: imageSignal,
                            action: {
                                interaction.openLocation()
                            }
                        ))
                        if cachedData.flags.contains(.canChangePeerGeoLocation) {
                            items[.groupLocation]!.append(PeerInfoScreenActionItem(id: ItemLocationSetup, text: presentationData.strings.Group_Location_ChangeLocation, action: {
                                interaction.editingOpenSetupLocation()
                            }))
                        }
                    }
                    
                    if isCreator || (channel.adminRights != nil && channel.hasPermission(.pinMessages)) {
                        if cachedData.peerGeoLocation != nil {
                            if isCreator {
                                let linkText: String
                                if let username = channel.addressName {
                                    linkText = "@\(username)"
                                } else {
                                    linkText = presentationData.strings.GroupInfo_PublicLinkAdd
                                }
                                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(linkText), text: presentationData.strings.GroupInfo_PublicLink, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                                    interaction.editingOpenPublicLinkSetup()
                                }))
                            }
                        } else {
                            if cachedData.flags.contains(.canChangeUsername) {
                                items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(isPublic ? presentationData.strings.Group_Setup_TypePublic : presentationData.strings.Group_Setup_TypePrivate), text: presentationData.strings.GroupInfo_GroupType, icon: UIImage(bundleImageName: "Chat/Info/GroupTypeIcon"), action: {
                                    interaction.editingOpenPublicLinkSetup()
                                }))
                            }
                        }
                    }
                    
                    if (isCreator && (channel.addressName?.isEmpty ?? true) && cachedData.peerGeoLocation == nil) || (!isCreator && channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                        let invitesText: String
                        if let count = data.invitations?.count, count > 0 {
                            invitesText = "\(count)"
                        } else {
                            invitesText = ""
                        }
                        
                        items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                            interaction.editingOpenInviteLinksSetup()
                        }))
                    }
                            
                    if (isCreator || (channel.adminRights != nil && channel.hasPermission(.pinMessages))) && cachedData.peerGeoLocation == nil {
                        if let linkedDiscussionPeer = data.linkedDiscussionPeer {
                            let peerTitle: String
                            if let addressName = linkedDiscussionPeer.addressName, !addressName.isEmpty {
                                peerTitle = "@\(addressName)"
                            } else {
                                peerTitle = EnginePeer(linkedDiscussionPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            }
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemLinkedChannel, label: .text(peerTitle), text: presentationData.strings.Group_LinkedChannel, icon: UIImage(bundleImageName: "Chat/Info/GroupLinkedChannelIcon"), action: {
                                interaction.editingOpenDiscussionGroupSetup()
                            }))
                        }
                        
                        if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                            let label: String
                            if let cachedData = data.cachedData as? CachedChannelData, case let .known(reactionSettings) = cachedData.reactionSettings {
                                switch reactionSettings.allowedReactions {
                                case .all:
                                    label = presentationData.strings.PeerInfo_LabelAllReactions
                                case .empty:
                                    label = presentationData.strings.PeerInfo_ReactionsDisabled
                                case let .limited(reactions):
                                    label = "\(reactions.count)"
                                }
                            } else {
                                label = ""
                            }
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                                interaction.editingOpenReactionsSetup()
                            }))
                        }
                    } else {
                        if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                            let label: String
                            if let cachedData = data.cachedData as? CachedChannelData, case let .known(reactionSettings) = cachedData.reactionSettings {
                                switch reactionSettings.allowedReactions {
                                case .all:
                                    label = presentationData.strings.PeerInfo_LabelAllReactions
                                case .empty:
                                    label = presentationData.strings.PeerInfo_ReactionsDisabled
                                case let .limited(reactions):
                                    label = "\(reactions.count)"
                                }
                            } else {
                                label = ""
                            }
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                                interaction.editingOpenReactionsSetup()
                            }))
                        }
                    }
                    
                    if isCreator || channel.adminRights?.rights.contains(.canChangeInfo) == true {
                        var colors: [PeerNameColors.Colors] = []
                        if let nameColor = channel.nameColor.flatMap({ context.peerNameColors.get($0, dark: presentationData.theme.overallDarkAppearance) }) {
                            colors.append(nameColor)
                        }
                        if let profileColor = channel.profileColor.flatMap({ context.peerNameColors.getProfile($0, dark: presentationData.theme.overallDarkAppearance, subject: .palette) }) {
                            colors.append(profileColor)
                        }
                        let colorImage = generateSettingsMenuPeerColorsLabelIcon(colors: colors)
                        
                        var boostIcon: UIImage?
                        if let approximateBoostLevel = channel.approximateBoostLevel, approximateBoostLevel < 1 {
                            boostIcon = generateDisclosureActionBoostLevelBadgeImage(text: presentationData.strings.Channel_Info_BoostLevelPlusBadge("1").string)
                        } else {
                            boostIcon = nil
                            /*let labelText = NSAttributedString(string: presentationData.strings.Settings_New, font: Font.medium(11.0), textColor: presentationData.theme.list.itemCheckColors.foregroundColor)
                            let labelBounds = labelText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: [.usesLineFragmentOrigin], context: nil)
                            let labelSize = CGSize(width: ceil(labelBounds.width), height: ceil(labelBounds.height))
                            let badgeSize = CGSize(width: labelSize.width + 8.0, height: labelSize.height + 2.0 + 1.0)
                            boostIcon = generateImage(badgeSize, rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                
                                let rect = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height - UIScreenPixel * 2.0))
                                
                                context.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 5.0).cgPath)
                                context.setFillColor(presentationData.theme.list.itemCheckColors.fillColor.cgColor)
                                context.fillPath()
                                
                                UIGraphicsPushContext(context)
                                labelText.draw(at: CGPoint(x: 4.0, y: 1.0 + UIScreenPixel))
                                UIGraphicsPopContext()
                            })*/
                        }
                        items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAppearance, label: .image(colorImage, colorImage.size), additionalBadgeIcon: boostIcon, text: presentationData.strings.Channel_Info_AppearanceItem, icon: UIImage(bundleImageName: "Chat/Info/NameColorIcon"), action: {
                            interaction.editingOpenNameColorSetup()
                        }))
                    }
                    
                    if (isCreator || (channel.adminRights != nil && channel.hasPermission(.banMembers))) && cachedData.peerGeoLocation == nil, !isPublic, case .known(nil) = cachedData.linkedDiscussionPeerId, !channel.isForumOrMonoForum {
                        items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPreHistory, label: .text(cachedData.flags.contains(.preHistoryEnabled) ? presentationData.strings.GroupInfo_GroupHistoryVisible : presentationData.strings.GroupInfo_GroupHistoryHidden), text: presentationData.strings.GroupInfo_GroupHistoryShort, icon: UIImage(bundleImageName: "Chat/Info/GroupDiscussionIcon"), action: {
                            interaction.editingOpenPreHistorySetup()
                        }))
                    }
                                        
                    if isCreator, let appConfiguration = data.appConfiguration {
                        var minParticipants = 200
                        if let data = appConfiguration.data, let value = data["forum_upgrade_participants_min"] as? Double {
                            minParticipants = Int(value)
                        }
                        
                        var canSetupTopics = false
                        var topicsLimitedReason: TopicsLimitedReason?
                        if channel.flags.contains(.isForum) {
                            canSetupTopics = true
                        } else if case let .known(value) = cachedData.linkedDiscussionPeerId, value != nil {
                            canSetupTopics = true
                            topicsLimitedReason = .discussion
                        } else if let memberCount = cachedData.participantsSummary.memberCount {
                            canSetupTopics = true
                            if Int(memberCount) < minParticipants {
                                topicsLimitedReason = .participants(minParticipants)
                            }
                        }
                        
                        if canSetupTopics {
                            let label = channel.flags.contains(.isForum) ? presentationData.strings.PeerInfo_OptionTopics_Enabled : presentationData.strings.PeerInfo_OptionTopics_Disabled
                            items[.peerDataSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemTopics, label: .text(label), text: presentationData.strings.PeerInfo_OptionTopics, icon: UIImage(bundleImageName: "Settings/Menu/Topics"), action: {
                                if let topicsLimitedReason = topicsLimitedReason {
                                    interaction.displayTopicsLimited(topicsLimitedReason)
                                } else {
                                    interaction.openForumSettings()
                                }
                            }))
                            
                            items[.peerDataSettings]!.append(PeerInfoScreenCommentItem(id: ItemTopicsText, text: presentationData.strings.PeerInfo_OptionTopicsText))
                        }
                    }
                    
                    var canViewAdminsAndBanned = false
                    if let _ = channel.adminRights {
                        canViewAdminsAndBanned = true
                    } else if channel.flags.contains(.isCreator) {
                        canViewAdminsAndBanned = true
                    }
                    
                    if canViewAdminsAndBanned {
                        var activePermissionCount: Int?
                        if let defaultBannedRights = channel.defaultBannedRights {
                            var count = 0
                            for (right, _) in allGroupPermissionList(peer: .channel(channel), expandMedia: true) {
                                if right == .banSendMedia {
                                    if banSendMediaSubList().allSatisfy({ !defaultBannedRights.flags.contains($0.0) }) {
                                        count += 1
                                    }
                                } else {
                                    if !defaultBannedRights.flags.contains(right) {
                                        count += 1
                                    }
                                }
                            }
                            activePermissionCount = count
                        }
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text(cachedData.participantsSummary.memberCount.flatMap { "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" } ?? ""), text: presentationData.strings.Group_Info_Members, icon: UIImage(bundleImageName: "Chat/Info/GroupMembersIcon"), action: {
                            interaction.openParticipantsSection(.members)
                        }))
                        if !channel.flags.contains(.isGigagroup) {
                            items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList(peer: .channel(channel), expandMedia: true).count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, icon: UIImage(bundleImageName: "Settings/Menu/SetPasscode"), action: {
                                interaction.openPermissions()
                            }))
                        }
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text(cachedData.participantsSummary.adminCount.flatMap { "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" } ?? ""), text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                            interaction.openParticipantsSection(.admins)
                        }))
                        
                        if let count = data.requests?.count, count > 0 {
                            items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                                interaction.openParticipantsSection(.memberRequests)
                            }))
                        }
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemRemovedUsers, label: .text(cachedData.participantsSummary.kickedCount.flatMap { $0 > 0 ? "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" : "" } ?? ""), text: presentationData.strings.GroupInfo_Permissions_Removed, icon: UIImage(bundleImageName: "Chat/Info/GroupRemovedIcon"), action: {
                            interaction.openParticipantsSection(.banned)
                        }))
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemRecentActions, label: .none, text: presentationData.strings.Group_Info_AdminLog, icon: UIImage(bundleImageName: "Chat/Info/RecentActionsIcon"), action: {
                            interaction.openRecentActions()
                        }))
                    }
                    
                    if isCreator {
                        items[.peerActions]!.append(PeerInfoScreenActionItem(id: ItemDeleteGroup, text: presentationData.strings.Group_DeleteGroup, color: .destructive, icon: nil, alignment: .natural, action: {
                            interaction.openDeletePeer()
                        }))
                    }
                }
            }
        } else if let group = data.peer as? TelegramGroup {
            let ItemUsername = 101
            let ItemInviteLinks = 102
            let ItemPreHistory = 103
            let ItemPermissions = 104
            let ItemAdmins = 105
            let ItemMemberRequests = 106
            let ItemReactions = 107
            let ItemTopics = 108
            let ItemTopicsText = 109
            
            var canViewAdminsAndBanned = false
            
            if case .creator = group.role {
                if let cachedData = data.cachedData as? CachedGroupData {
                    if cachedData.flags.contains(.canChangeUsername) {
                        items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(presentationData.strings.Group_Setup_TypePrivate), text: presentationData.strings.GroupInfo_GroupType, icon: UIImage(bundleImageName: "Chat/Info/GroupTypeIcon"), action: {
                            interaction.editingOpenPublicLinkSetup()
                        }))
                    }
                }
                
                if (group.addressName?.isEmpty ?? true) {
                    let invitesText: String
                    if let count = data.invitations?.count, count > 0 {
                        invitesText = "\(count)"
                    } else {
                        invitesText = ""
                    }
                    
                    items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                        interaction.editingOpenInviteLinksSetup()
                    }))
                }
                                
                items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPreHistory, label: .text(presentationData.strings.GroupInfo_GroupHistoryHidden), text: presentationData.strings.GroupInfo_GroupHistoryShort, icon: UIImage(bundleImageName: "Chat/Info/GroupDiscussionIcon"), action: {
                    interaction.editingOpenPreHistorySetup()
                }))
                
                var canSetupTopics = false
                if case .creator = group.role {
                    canSetupTopics = true
                }
                var topicsLimitedReason: TopicsLimitedReason?
                if let appConfiguration = data.appConfiguration {
                    var minParticipants = 200
                    if let data = appConfiguration.data, let value = data["forum_upgrade_participants_min"] as? Double {
                        minParticipants = Int(value)
                    }
                    if Int(group.participantCount) < minParticipants {
                        topicsLimitedReason = .participants(minParticipants)
                    }
                }
                
                if canSetupTopics {
                    items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemTopics, label: .text(presentationData.strings.PeerInfo_OptionTopics_Disabled), text: presentationData.strings.PeerInfo_OptionTopics, icon: UIImage(bundleImageName: "Settings/Menu/Topics"), action: {
                        if let topicsLimitedReason = topicsLimitedReason {
                            interaction.displayTopicsLimited(topicsLimitedReason)
                        } else {
                            interaction.openForumSettings()
                        }
                    }))
                    
                    items[.peerPublicSettings]!.append(PeerInfoScreenCommentItem(id: ItemTopicsText, text: presentationData.strings.PeerInfo_OptionTopicsText))
                }
                
                let label: String
                if let cachedData = data.cachedData as? CachedGroupData, case let .known(reactionSettings) = cachedData.reactionSettings {
                    switch reactionSettings.allowedReactions {
                    case .all:
                        label = presentationData.strings.PeerInfo_LabelAllReactions
                    case .empty:
                        label = presentationData.strings.PeerInfo_ReactionsDisabled
                    case let .limited(reactions):
                        label = "\(reactions.count)"
                    }
                } else {
                    label = ""
                }
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                    interaction.editingOpenReactionsSetup()
                }))
                
                canViewAdminsAndBanned = true
            } else if case let .admin(rights, _) = group.role {
                let label: String
                if let cachedData = data.cachedData as? CachedGroupData, case let .known(reactionSettings) = cachedData.reactionSettings {
                    switch reactionSettings.allowedReactions {
                    case .all:
                        label = presentationData.strings.PeerInfo_LabelAllReactions
                    case .empty:
                        label = presentationData.strings.PeerInfo_ReactionsDisabled
                    case let .limited(reactions):
                        label = "\(reactions.count)"
                    }
                } else {
                    label = ""
                }
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                    interaction.editingOpenReactionsSetup()
                }))
                
                if rights.rights.contains(.canInviteUsers) {
                    let invitesText: String
                    if let count = data.invitations?.count, count > 0 {
                        invitesText = "\(count)"
                    } else {
                        invitesText = ""
                    }
                    
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemInviteLinks, label: .text(invitesText), text: presentationData.strings.GroupInfo_InviteLinks, icon: UIImage(bundleImageName: "Chat/Info/GroupLinksIcon"), action: {
                        interaction.editingOpenInviteLinksSetup()
                    }))
                }
                
                canViewAdminsAndBanned = true
            }
            
            if canViewAdminsAndBanned {
                var activePermissionCount: Int?
                if let defaultBannedRights = group.defaultBannedRights {
                    var count = 0
                    for (right, _) in allGroupPermissionList(peer: .legacyGroup(group), expandMedia: true) {
                        if right == .banSendMedia {
                            if banSendMediaSubList().allSatisfy({ !defaultBannedRights.flags.contains($0.0) }) {
                                count += 1
                            }
                        } else {
                            if !defaultBannedRights.flags.contains(right) {
                                count += 1
                            }
                        }
                    }
                    activePermissionCount = count
                }
                
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList(peer: .legacyGroup(group), expandMedia: true).count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, icon: UIImage(bundleImageName: "Settings/Menu/SetPasscode"), action: {
                    interaction.openPermissions()
                }))
                
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, text: presentationData.strings.GroupInfo_Administrators, icon: UIImage(bundleImageName: "Chat/Info/GroupAdminsIcon"), action: {
                    interaction.openParticipantsSection(.admins)
                }))
                
                if let count = data.requests?.count, count > 0 {
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMemberRequests, label: .badge(presentationStringsFormattedNumber(count, presentationData.dateTimeFormat.groupingSeparator), presentationData.theme.list.itemAccentColor), text: presentationData.strings.GroupInfo_MemberRequests, icon: UIImage(bundleImageName: "Chat/Info/GroupRequestsIcon"), action: {
                        interaction.openParticipantsSection(.memberRequests)
                    }))
                }
            }
        }
    }
    
    var result: [(AnyHashable, [PeerInfoScreenItem])] = []
    for section in Section.allCases {
        if let sectionItems = items[section], !sectionItems.isEmpty {
            result.append((section, sectionItems))
        }
    }
    return result
}

final class PeerInfoScreenNode: ViewControllerTracingNode, PeerInfoScreenNodeProtocol, ASScrollViewDelegate {
    private weak var controller: PeerInfoScreenImpl?
    
    private let context: AccountContext
    let peerId: PeerId
    private let isOpenedFromChat: Bool
    private let videoCallsEnabled: Bool
    private let callMessages: [Message]
    private let chatLocation: ChatLocation
    private let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    
    let isSettings: Bool
    let isMyProfile: Bool
    private let isMediaOnly: Bool
    let initialExpandPanes: Bool
    
    private var presentationData: PresentationData
    
    fileprivate let cachedDataPromise = Promise<CachedPeerData?>()
    
    let scrollNode: ASScrollNode
    
    let headerNode: PeerInfoHeaderNode
    private var regularSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    private var editingSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    private let paneContainerNode: PeerInfoPaneContainerNode
    private var ignoreScrolling: Bool = false
    private lazy var hapticFeedback = { HapticFeedback() }()

    private var customStatusData: (PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?)
    private let customStatusPromise = Promise<(PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?)>((nil, nil, nil))
    private var customStatusDisposable: Disposable?

    private var refreshMessageTagStatsDisposable: Disposable?
    
    private var searchDisplayController: SearchDisplayController?
    
    private var _interaction: PeerInfoInteraction?
    fileprivate var interaction: PeerInfoInteraction {
        return self._interaction!
    }
    
    private var _chatInterfaceInteraction: ChatControllerInteraction?
    private var chatInterfaceInteraction: ChatControllerInteraction {
        return self._chatInterfaceInteraction!
    }
    private var hiddenMediaDisposable: Disposable?
    private let hiddenAvatarRepresentationDisposable = MetaDisposable()
    
    private var autoTranslateDisposable: Disposable?
    
    private var resolvePeerByNameDisposable: MetaDisposable?
    private let navigationActionDisposable = MetaDisposable()
    private let enqueueMediaMessageDisposable = MetaDisposable()
    
    private(set) var validLayout: (ContainerViewLayout, CGFloat)?
    private(set) var data: PeerInfoScreenData?
    var state = PeerInfoState(
        isEditing: false,
        selectedMessageIds: nil,
        selectedStoryIds: nil,
        paneIsReordering: false,
        updatingAvatar: nil,
        updatingBio: nil,
        avatarUploadProgress: nil,
        highlightedButton: nil,
        isEditingBirthDate: false,
        updatingBirthDate: nil,
        personalChannels: nil
    )
    private var forceIsContactPromise = ValuePromise<Bool>(false)
    private let nearbyPeerDistance: Int32?
    private let reactionSourceMessageId: MessageId?
    private var dataDisposable: Disposable?
    
    private let activeActionDisposable = MetaDisposable()
    private let resolveUrlDisposable = MetaDisposable()
    private let toggleShouldChannelMessagesSignaturesDisposable = MetaDisposable()
    private let toggleMessageCopyProtectionDisposable = MetaDisposable()
    private let selectAddMemberDisposable = MetaDisposable()
    private let addMemberDisposable = MetaDisposable()
    private let preloadHistoryDisposable = MetaDisposable()
    private var shareStatusDisposable: MetaDisposable?
    private let joinChannelDisposable = MetaDisposable()
    
    let updateAvatarDisposable = MetaDisposable()
    private let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    private var groupMembersSearchContext: GroupMembersSearchContext?
    
    private let displayAsPeersPromise = Promise<[FoundPeer]>([])
    
    fileprivate let accountsAndPeers = Promise<[(AccountContext, EnginePeer, Int32)]>()
    fileprivate let activeSessionsContextAndCount = Promise<(ActiveSessionsContext, Int, WebSessionsContext)?>()
    private let notificationExceptions = Promise<NotificationExceptionsList?>()
    fileprivate let privacySettings = Promise<AccountPrivacySettings?>()
    private let archivedPacks = Promise<[ArchivedStickerPackItem]?>()
    private let blockedPeers = Promise<BlockedPeersContext?>(nil)
    private let hasTwoStepAuth = Promise<Bool?>(nil)
    private let twoStepAccessConfiguration = Promise<TwoStepVerificationAccessConfiguration?>(nil)
    private let twoStepAuthData = Promise<TwoStepAuthData?>(nil)
    private let supportPeerDisposable = MetaDisposable()
    private let tipsPeerDisposable = MetaDisposable()
    private let cachedFaq = Promise<ResolvedUrl?>(nil)
    
    private weak var copyProtectionTooltipController: TooltipController?
    weak var emojiStatusSelectionController: ViewController?
    
    private var forumTopicNotificationExceptions: [EngineMessageHistoryThread.NotificationException] = []
    private var forumTopicNotificationExceptionsDisposable: Disposable?
    
    private var translationState: ChatTranslationState?
    private var translationStateDisposable: Disposable?
    
    private var boostStatus: ChannelBoostStatus?
    private var boostStatusDisposable: Disposable?
    
    private var expiringStoryList: PeerExpiringStoryListContext?
    private var expiringStoryListState: PeerExpiringStoryListContext.State?
    private var expiringStoryListDisposable: Disposable?
    private var storyUploadProgressDisposable: Disposable?
    private var postingAvailabilityDisposable: Disposable?
    
    private let storiesReady = ValuePromise<Bool>(true, ignoreRepeated: true)
    
    private var personalChannelsDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    init(controller: PeerInfoScreenImpl, context: AccountContext, peerId: PeerId, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, nearbyPeerDistance: Int32?, reactionSourceMessageId: MessageId?, callMessages: [Message], isSettings: Bool, isMyProfile: Bool, hintGroupInCommon: PeerId?, requestsContext: PeerInvitationImportersContext?, profileGiftsContext: ProfileGiftsContext?, starsContext: StarsContext?, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, initialPaneKey: PeerInfoPaneKey?) {
        self.controller = controller
        self.context = context
        self.peerId = peerId
        self.isOpenedFromChat = isOpenedFromChat
        self.videoCallsEnabled = true
        self.presentationData = controller.presentationData
        self.nearbyPeerDistance = nearbyPeerDistance
        self.reactionSourceMessageId = reactionSourceMessageId
        self.callMessages = callMessages
        self.isSettings = isSettings
        self.isMyProfile = isMyProfile
        self.chatLocation = chatLocation
        self.chatLocationContextHolder = chatLocationContextHolder
        self.isMediaOnly = context.account.peerId == peerId && !isSettings && !isMyProfile
        self.initialExpandPanes = initialPaneKey != nil
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.canCancelAllTouchesInViews = true
        
        var forumTopicThreadId: Int64?
        if case let .replyThread(message) = chatLocation {
            forumTopicThreadId = message.threadId
        }
        self.headerNode = PeerInfoHeaderNode(context: context, controller: controller, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, isMediaOnly: self.isMediaOnly, isSettings: isSettings, isMyProfile: isMyProfile, forumTopicThreadId: forumTopicThreadId, chatLocation: self.chatLocation)
        self.paneContainerNode = PeerInfoPaneContainerNode(context: context, updatedPresentationData: controller.updatedPresentationData, peerId: peerId, chatLocation: chatLocation, chatLocationContextHolder: chatLocationContextHolder, isMediaOnly: self.isMediaOnly, initialPaneKey: initialPaneKey)
        
        super.init()
        
        self.paneContainerNode.parentController = controller
        
        self._interaction = PeerInfoInteraction(
            openUsername: { [weak self] value, isMainUsername, progress in
                self?.openUsername(value: value, isMainUsername: isMainUsername, progress: progress)
            },
            openPhone: { [weak self] value, node, gesture, progress in
                self?.openPhone(value: value, node: node, gesture: gesture, progress: progress)
            },
            editingOpenNotificationSettings: { [weak self] in
                self?.editingOpenNotificationSettings()
            },
            editingOpenSoundSettings: { [weak self] in
                self?.editingOpenSoundSettings()
            },
            editingToggleShowMessageText: { [weak self] value in
                self?.editingToggleShowMessageText(value: value)
            },
            requestDeleteContact: { [weak self] in
                self?.requestDeleteContact()
            },
            suggestPhoto: { [weak self] in
                self?.suggestPhoto()
            },
            setCustomPhoto: { [weak self] in
                self?.setCustomPhoto()
            },
            resetCustomPhoto: { [weak self] in
                self?.resetCustomPhoto()
            },
            openChat: { [weak self] peerId in
                self?.openChat(peerId: peerId)
            },
            openAddContact: { [weak self] in
                self?.openAddContact()
            },
            updateBlocked: { [weak self] block in
                self?.updateBlocked(block: block)
            },
            openReport: { [weak self] type in
                self?.openReport(type: type, contextController: nil, backAction: nil)
            },
            openShareBot: { [weak self] in
                self?.openShareBot()
            },
            openAddBotToGroup: { [weak self] in
                self?.openAddBotToGroup()
            },
            performBotCommand: { [weak self] command in
                self?.performBotCommand(command: command)
            },
            editingOpenPublicLinkSetup: { [weak self] in
                self?.editingOpenPublicLinkSetup()
            },
            editingOpenNameColorSetup: { [weak self] in
                self?.editingOpenNameColorSetup()
            },
            editingOpenInviteLinksSetup: { [weak self] in
                self?.editingOpenInviteLinksSetup()
            },
            editingOpenDiscussionGroupSetup: { [weak self] in
                self?.editingOpenDiscussionGroupSetup()
            },
            editingOpenPostSuggestionsSetup: { [weak self] in
                self?.editingOpenPostSuggestionsSetup()
            },
            editingOpenRevenue: { [weak self] in
                self?.editingOpenRevenue()
            },
            editingOpenStars: { [weak self] in
                self?.editingOpenStars()
            },
            openParticipantsSection: { [weak self] section in
                self?.openParticipantsSection(section: section)
            },
            openRecentActions: { [weak self] in
                self?.openRecentActions()
            },
            openChannelMessages: { [weak self] in
                self?.openChannelMessages()
            },
            openStats: { [weak self] section in
                self?.openStats(section: section)
            },
            editingOpenPreHistorySetup: { [weak self] in
                self?.editingOpenPreHistorySetup()
            },
            editingOpenAutoremoveMesages: { [weak self] in
                self?.editingOpenAutoremoveMesages()
            },
            openPermissions: { [weak self] in
                self?.openPermissions()
            },
            editingOpenStickerPackSetup: { [weak self] in
                self?.editingOpenStickerPackSetup()
            },
            openLocation: { [weak self] in
                self?.openLocation()
            },
            editingOpenSetupLocation: { [weak self] in
                self?.editingOpenSetupLocation()
            },
            openPeerInfo: { [weak self] peer, isMember in
                self?.openPeerInfo(peer: peer, isMember: isMember)
            },
            performMemberAction: { [weak self] member, action in
                self?.performMemberAction(member: member, action: action)
            },
            openPeerInfoContextMenu: { [weak self] subject, sourceNode, sourceRect in
                self?.openPeerInfoContextMenu(subject: subject, sourceNode: sourceNode, sourceRect: sourceRect)
            },
            performBioLinkAction: { [weak self] action, item in
                self?.performBioLinkAction(action: action, item: item)
            },
            requestLayout: { [weak self] animated in
                self?.requestLayout(animated: animated)
            },
            openEncryptionKey: { [weak self] in
                self?.openEncryptionKey()
            },
            openSettings: { [weak self] section in
                self?.openSettings(section: section)
            },
            openPaymentMethod: { [weak self] in
                self?.openPaymentMethod()
            },
            switchToAccount: { [weak self] accountId in
                self?.switchToAccount(id: accountId)
            },
            logoutAccount: { [weak self] accountId in
                self?.logoutAccount(id: accountId)
            },
            accountContextMenu: { [weak self] accountId, node, gesture in
                self?.accountContextMenu(id: accountId, node: node, gesture: gesture)
            },
            updateBio: { [weak self] bio in
                self?.updateBio(bio)
            },
            openDeletePeer: { [weak self] in
                self?.openDeletePeer()
            },
            openFaq: { [weak self] anchor in
                self?.openFaq(anchor: anchor)
            },
            openAddMember: { [weak self] in
                self?.openAddMember()
            },
            openQrCode: { [weak self] in
                self?.openQrCode()
            },
            editingOpenReactionsSetup: { [weak self] in
                self?.editingOpenReactionsSetup()
            },
            dismissInput: { [weak self] in
                self?.view.endEditing(true)
            },
            openForumSettings: { [weak self] in
                self?.openForumSettings()
            },
            displayTopicsLimited: { [weak self] reason in
                guard let self else {
                    return
                }
                
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                switch reason {
                case let .participants(minCount):
                    text = self.presentationData.strings.PeerInfo_TopicsLimitedParticipantCountText(Int32(minCount))
                case .discussion:
                    text = self.presentationData.strings.PeerInfo_TopicsLimitedDiscussionGroups
                }
                self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_topics", scale: 0.066, colors: [:], title: nil, text: text, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            },
            openPeerMention: { [weak self] mention, navigation in
                self?.openPeerMention(mention, navigation: navigation)
            },
            openBotApp: { [weak self] bot in
                self?.openBotApp(bot)
            },
            openEditing: { [weak self] in
                self?.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
            },
            updateBirthdate: { [weak self] birthDate in
                if let self {
                    self.state = self.state.withUpdatingBirthDate(birthDate)
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: birthDate == .some(nil) ? .animated(duration: 0.2, curve: .easeInOut) : .immediate, additive: false)
                    }
                }
            },
            updateIsEditingBirthdate: { [weak self] value in
                if let self {
                    if value {
                        if let data = self.data?.cachedData as? CachedUserData {
                            if data.birthday == nil && (self.state.updatingBirthDate == nil || self.state.updatingBirthDate == .some(nil)) {
                                self.state = self.state.withUpdatingBirthDate(TelegramBirthday(day: 1, month: 1, year: nil))
                            } else if self.state.updatingBirthDate == .some(nil) {
                                self.state = self.state.withUpdatingBirthDate(TelegramBirthday(day: 1, month: 1, year: nil))
                            }
                        }
                    }
                    self.state = self.state.withIsEditingBirthDate(value)
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut), additive: false)
                    }
                }
            },
            openBioPrivacy: { [weak self] in
                if let self {
                    self.openBioPrivacy()
                }
            },
            openBirthdatePrivacy: { [weak self] in
                if let self {
                    self.openBirthdatePrivacy()
                }
            },
            openPremiumGift: { [weak self] in
                if let self {
                    self.openPremiumGift()
                }
            },
            editingOpenPersonalChannel: { [weak self] in
                guard let self else {
                    return
                }
                self.editingOpenPersonalChannel()
            }, openUsernameContextMenu: { [weak self] node, gesture in
                guard let self else {
                    return
                }
                self.openUsernameContextMenu(node: node, gesture: gesture)
            }, openBioContextMenu: { [weak self] node, gesture in
                guard let self else {
                    return
                }
                self.openBioContextMenu(node: node, gesture: gesture)
            }, openWorkingHoursContextMenu: { [weak self] node, gesture in
                guard let self else {
                    return
                }
                self.openWorkingHoursContextMenu(node: node, gesture: gesture)
            }, openBusinessLocationContextMenu: { [weak self] node, gesture in
                guard let self else {
                    return
                }
                self.openBusinessLocationContextMenu(node: node, gesture: gesture)
            }, openBirthdayContextMenu: { [weak self] node, gesture in
                guard let self else {
                    return
                }
                self.openBirthdayContextMenu(node: node, gesture: gesture)
            }, editingOpenAffiliateProgram: { [weak self] in
                guard let self else {
                    return
                }
                self.editingOpenAffiliateProgram()
            }, editingOpenVerifyAccounts: { [weak self] in
                guard let self else {
                    return
                }
                self.editingOpenVerifyAccounts()
            }, editingToggleAutoTranslate: { [weak self] isEnabled in
                guard let self else {
                    return
                }
                self.toggleAutoTranslate(isEnabled: isEnabled)
            }, displayAutoTranslateLocked: { [weak self] in
                guard let self else {
                    return
                }
                self.displayAutoTranslateLocked()
            },
            getController: { [weak self] in
                return self?.controller
            }
        )
        
        self._chatInterfaceInteraction = ChatControllerInteraction(openMessage: { [weak self] message, _ in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.openMessage(id: message.id)
        }, openPeer: { [weak self] peer, navigation, _, _ in
            self?.openPeer(peerId: peer.id, navigation: navigation)
        }, openPeerMention: { _, _ in
        }, openMessageContextMenu: { [weak self] message, _, node, frame, anyRecognizer, _ in
            guard let strongSelf = self, let node = node as? ContextExtractedContentContainingNode else {
                return
            }
            
            strongSelf.context.engine.messages.ensureMessagesAreLocallyAvailable(messages: [EngineMessage(message)])
            
            var linkForCopying: String?
            var currentSupernode: ASDisplayNode? = node
            while true {
                if currentSupernode == nil {
                    break
                } else if let currentSupernode = currentSupernode as? ListMessageSnippetItemNode {
                    linkForCopying = currentSupernode.currentPrimaryUrl
                    break
                } else {
                    currentSupernode = currentSupernode?.supernode
                }
            }
            
            let gesture: ContextGesture? = anyRecognizer as? ContextGesture
            let _ = (strongSelf.context.sharedContext.chatAvailableMessageActions(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id], keepUpdated: false)
            |> deliverOnMainQueue).startStandalone(next: { actions in
                guard let strongSelf = self else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c?.dismiss(completion: {
                        if let strongSelf = self, let currentPeer = strongSelf.data?.peer, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                            if let channel = currentPeer as? TelegramChannel, channel.isForumOrMonoForum, let threadId = message.threadId {
                                let _ = strongSelf.context.sharedContext.navigateToForumThread(context: strongSelf.context, peerId: currentPeer.id, threadId: threadId, messageId: message.id, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .default, animated: true).startStandalone()
                            } else {
                                let targetLocation: NavigateToChatControllerParams.Location
                                if case let .replyThread(message) = strongSelf.chatLocation {
                                    targetLocation = .replyThread(message)
                                } else {
                                    targetLocation = .peer(EnginePeer(currentPeer))
                                }
                                
                                let currentPeerId = strongSelf.peerId
                                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: targetLocation, subject: .message(id: .id(message.id), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: false, purposefulAction: {
                                    var viewControllers = navigationController.viewControllers
                                    var indexesToRemove = Set<Int>()
                                    var keptCurrentChatController = false
                                    var index: Int = viewControllers.count - 1
                                    for controller in viewControllers.reversed() {
                                        if let controller = controller as? ChatController, case let .peer(peerId) = controller.chatLocation {
                                            if peerId == currentPeerId && !keptCurrentChatController {
                                                keptCurrentChatController = true
                                            } else {
                                                indexesToRemove.insert(index)
                                            }
                                        } else if controller is PeerInfoScreen {
                                            indexesToRemove.insert(index)
                                        }
                                        index -= 1
                                    }
                                    for i in indexesToRemove.sorted().reversed() {
                                        viewControllers.remove(at: i)
                                    }
                                    navigationController.setViewControllers(viewControllers, animated: false)
                                }))
                            }
                        }
                    })
                })))
                
                if let linkForCopying = linkForCopying {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuCopyLink, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss(completion: {})
                        UIPasteboard.general.string = linkForCopying
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    })))
                }
                
                if message.isCopyProtected() {
                    
                } else if message.id.peerId.namespace != Namespaces.Peer.SecretChat && message.minAutoremoveOrClearTimeout == nil {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss(completion: {
                            if let strongSelf = self {
                                strongSelf.forwardMessages(messageIds: Set([message.id]))
                            }
                        })
                    })))
                }
                if actions.options.contains(.deleteLocally) || actions.options.contains(.deleteGlobally) {
                    let context = strongSelf.context
                    let presentationData = strongSelf.presentationData
                    let peerId = strongSelf.peerId
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, _ in
                        c?.setItems(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: message.id.peerId))
                       |> map { peer -> ContextController.Items in
                            var items: [ContextMenuItem] = []
                            let messageIds = [message.id]
                            
                            if let peer = peer {
                                var personalPeerName: String?
                                var isChannel = false
                                if case let .user(user) = peer {
                                    personalPeerName = EnginePeer(user).compactDisplayTitle
                                } else if case let .channel(channel) = peer, case .broadcast = channel.info {
                                    isChannel = true
                                }
                                
                                if actions.options.contains(.deleteGlobally) {
                                    let globalTitle: String
                                    if isChannel {
                                        globalTitle = presentationData.strings.Conversation_DeleteMessagesForEveryone
                                    } else if let personalPeerName = personalPeerName {
                                        globalTitle = presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                                    } else {
                                        globalTitle = presentationData.strings.Conversation_DeleteMessagesForEveryone
                                    }
                                    items.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                        c?.dismiss(completion: {
                                            if let strongSelf = self {
                                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).startStandalone()
                                            }
                                        })
                                    })))
                                }
                                
                                if actions.options.contains(.deleteLocally) {
                                    var localOptionText = presentationData.strings.Conversation_DeleteMessagesForMe
                                    if context.account.peerId == peerId {
                                        if messageIds.count == 1 {
                                            localOptionText = presentationData.strings.Conversation_Moderate_Delete
                                        } else {
                                            localOptionText = presentationData.strings.Conversation_DeleteManyMessages
                                        }
                                    }
                                    items.append(.action(ContextMenuActionItem(text: localOptionText, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                        c?.dismiss(completion: {
                                            if let strongSelf = self {
                                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).startStandalone()
                                            }
                                        })
                                    })))
                                }
                            }
                            
                            return ContextController.Items(content: .list(items))
                        }, minHeight: nil, animated: true)
                    })))
                }
                if strongSelf.searchDisplayController == nil {
                    items.append(.separator)
                    
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuSelect, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss(completion: {
                            if let strongSelf = self {
                                strongSelf.chatInterfaceInteraction.toggleMessagesSelection([message.id], true)
                                strongSelf.expandTabs(animated: true)
                            }
                        })
                    })))
                }
                
                let controller = ContextController(presentationData: strongSelf.presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
                strongSelf.controller?.window?.presentInGlobalOverlay(controller)
            })
        }, openMessageReactionContextMenu: { _, _, _, _ in
        }, updateMessageReaction: { _, _, _, _ in
        }, activateMessagePinch: { _ in
        }, openMessageContextActions: { [weak self] message, node, rect, gesture in
            guard let strongSelf = self else {
                gesture?.cancel()
                return
            }
            
            let _ = (chatMediaListPreviewControllerData(context: strongSelf.context, chatLocation: .peer(id: message.id.peerId), chatFilterTag: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: strongSelf.controller?.navigationController as? NavigationController)
            |> deliverOnMainQueue).startStandalone(next: { previewData in
                guard let strongSelf = self else {
                    gesture?.cancel()
                    return
                }
                if let previewData = previewData {
                    let context = strongSelf.context
                    let strings = strongSelf.presentationData.strings
                    let items = strongSelf.context.sharedContext.chatAvailableMessageActions(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id], keepUpdated: false)
                    |> map { actions -> [ContextMenuItem] in
                        var items: [ContextMenuItem] = []
                        
                        items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            c?.dismiss(completion: {
                                if let strongSelf = self, let currentPeer = strongSelf.data?.peer, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                    if let channel = currentPeer as? TelegramChannel, channel.isForumOrMonoForum, let threadId = message.threadId {
                                        let _ = strongSelf.context.sharedContext.navigateToForumThread(context: strongSelf.context, peerId: currentPeer.id, threadId: threadId, messageId: message.id, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .default, animated: true).startStandalone()
                                    } else {
                                        let targetLocation: NavigateToChatControllerParams.Location
                                        if case let .replyThread(message) = strongSelf.chatLocation {
                                            targetLocation = .replyThread(message)
                                        } else {
                                            targetLocation = .peer(EnginePeer(currentPeer))
                                        }
                                        
                                        let currentPeerId = strongSelf.peerId
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: targetLocation, subject: .message(id: .id(message.id), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: false, purposefulAction: {
                                            var viewControllers = navigationController.viewControllers
                                            var indexesToRemove = Set<Int>()
                                            var keptCurrentChatController = false
                                            var index: Int = viewControllers.count - 1
                                            for controller in viewControllers.reversed() {
                                                if let controller = controller as? ChatController, case let .peer(peerId) = controller.chatLocation {
                                                    if peerId == currentPeerId && !keptCurrentChatController {
                                                        keptCurrentChatController = true
                                                    } else {
                                                        indexesToRemove.insert(index)
                                                    }
                                                } else if controller is PeerInfoScreen {
                                                    indexesToRemove.insert(index)
                                                }
                                                index -= 1
                                            }
                                            for i in indexesToRemove.sorted().reversed() {
                                                viewControllers.remove(at: i)
                                            }
                                            navigationController.setViewControllers(viewControllers, animated: false)
                                        }))
                                    }
                                }
                            })
                        })))
                        
                        if message.isCopyProtected() {
                            
                        } else if message.id.peerId.namespace != Namespaces.Peer.SecretChat {
                            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                                c?.dismiss(completion: {
                                    if let strongSelf = self {
                                        strongSelf.forwardMessages(messageIds: [message.id])
                                    }
                                })
                            })))
                        }
                        
                        if actions.options.contains(.deleteLocally) || actions.options.contains(.deleteGlobally) {
                            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, f in
                                c?.setItems(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: message.id.peerId))
                                |> map { peer -> ContextController.Items in
                                    var items: [ContextMenuItem] = []
                                    let messageIds = [message.id]
                                    
                                    if let peer = peer {
                                        var personalPeerName: String?
                                        var isChannel = false
                                        if case let .user(user) = peer {
                                            personalPeerName = EnginePeer(user).compactDisplayTitle
                                        } else if case let .channel(channel) = peer, case .broadcast = channel.info {
                                            isChannel = true
                                        }
                                        
                                        if actions.options.contains(.deleteGlobally) {
                                            let globalTitle: String
                                            if isChannel {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                                            } else if let personalPeerName = personalPeerName {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                                            } else {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                                            }
                                            items.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                                c?.dismiss(completion: {
                                                    if let strongSelf = self {
                                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                        let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).startStandalone()
                                                    }
                                                })
                                            })))
                                        }
                                        
                                        if actions.options.contains(.deleteLocally) {
                                            var localOptionText = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                                            if strongSelf.context.account.peerId == strongSelf.peerId {
                                                if messageIds.count == 1 {
                                                    localOptionText = strongSelf.presentationData.strings.Conversation_Moderate_Delete
                                                } else {
                                                    localOptionText = strongSelf.presentationData.strings.Conversation_DeleteManyMessages
                                                }
                                            }
                                            items.append(.action(ContextMenuActionItem(text: localOptionText, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                                c?.dismiss(completion: {
                                                    if let strongSelf = self {
                                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                        let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).startStandalone()
                                                    }
                                                })
                                            })))
                                        }
                                    }
                                    
                                    return ContextController.Items(content: .list(items))
                                }, minHeight: nil, animated: true)
                            })))
                        }
                        
                        items.append(.separator)
                        items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuSelect, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.chatInterfaceInteraction.toggleMessagesSelection([message.id], true)
                            strongSelf.expandTabs(animated: true)
                            f(.default)
                        })))
                        
                        return items
                    }
                    
                    switch previewData {
                    case let .gallery(gallery):
                        gallery.setHintWillBePresentedInPreviewingContext(true)
                        let contextController = ContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: node, sourceRect: rect)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                        strongSelf.controller?.presentInGlobalOverlay(contextController)
                    case .instantPage:
                        break
                    }
                }
            })
        }, navigateToMessage: { _, _, _ in
        }, navigateToMessageStandalone: { _ in
        }, navigateToThreadMessage: { _, _, _ in
        }, tapMessage: nil, clickThroughMessage: { _, _ in
        }, toggleMessagesSelection: { [weak self] ids, value in
            guard let strongSelf = self else {
                return
            }
            if var selectedMessageIds = strongSelf.state.selectedMessageIds {
                for id in ids {
                    if value {
                        selectedMessageIds.insert(id)
                    } else {
                        selectedMessageIds.remove(id)
                    }
                }
                strongSelf.state = strongSelf.state.withSelectedMessageIds(selectedMessageIds)
            } else {
                strongSelf.state = strongSelf.state.withSelectedMessageIds(value ? Set(ids) : Set())
            }
            strongSelf.chatInterfaceInteraction.selectionState = strongSelf.state.selectedMessageIds.flatMap { ChatInterfaceSelectionState(selectedIds: $0) }
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
            }
            strongSelf.paneContainerNode.updateSelectedMessageIds(strongSelf.state.selectedMessageIds, animated: true)
        }, sendCurrentMessage: { _, _ in
        }, sendMessage: { _ in
        }, sendSticker: { _, _, _, _, _, _, _, _, _ in
            return false
        }, sendEmoji: { _, _, _ in
        }, sendGif: { _, _, _, _, _ in
            return false
        }, sendBotContextResultAsGif: { _, _, _, _, _, _ in
            return false
        }, requestMessageActionCallback: { _, _, _, _ in
        }, requestMessageActionUrlAuth: { _, _ in
        }, activateSwitchInline: { _, _, _ in
        }, openUrl: { [weak self] url in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openUrl(url: url.url, concealed: url.concealed, external: url.external ?? false)
        }, shareCurrentLocation: {
        }, shareAccountContact: {
        }, sendBotCommand: { _, _ in
        }, openInstantPage: { [weak self] message, associatedData in
            guard let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController else {
                return
            }
            var foundGalleryMessage: Message?
            if let searchContentNode = strongSelf.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
                if let galleryMessage = searchContentNode.messageForGallery(message.id) {
                    strongSelf.context.engine.messages.ensureMessagesAreLocallyAvailable(messages: [EngineMessage(galleryMessage)])
                    foundGalleryMessage = galleryMessage
                }
            }
            if foundGalleryMessage == nil, let galleryMessage = strongSelf.paneContainerNode.findLoadedMessage(id: message.id) {
                foundGalleryMessage = galleryMessage
            }
            
            if let foundGalleryMessage = foundGalleryMessage {
                if let controller = strongSelf.context.sharedContext.makeInstantPageController(context: strongSelf.context, message: foundGalleryMessage, sourcePeerType: associatedData?.automaticDownloadPeerType) {
                    navigationController.pushViewController(controller)
                }
            }
        }, openWallpaper: { _ in
        }, openTheme: { _ in
        }, openHashtag: { _, _ in
        }, updateInputState: { _ in
        }, updateInputMode: { _ in
        }, openMessageShareMenu: { _ in
        }, presentController: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a)
        }, presentControllerInCurrent: { [weak self] c, a in
            self?.controller?.present(c, in: .current, with: a)
        }, navigationController: { [weak self] in
            return self?.controller?.navigationController as? NavigationController
        }, chatControllerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _, _ in
        }, openConferenceCall: { _ in
        }, longTap: { [weak self] content, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.endEditing(true)
            switch content {
            case let .url(url):
                let canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
                let openText = canOpenIn ? strongSelf.presentationData.strings.Conversation_FileOpenIn : strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: url),
                    ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            if canOpenIn {
                                let actionSheet = OpenInActionSheetController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, item: .url(url: url), openUrl: { [weak self] url in
                                    if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                        strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.presentationData, navigationController: navigationController, dismissInput: {
                                        })
                                    }
                                })
                                strongSelf.view.endEditing(true)
                                strongSelf.controller?.present(actionSheet, in: .window(.root))
                            } else {
                                strongSelf.context.sharedContext.applicationBindings.openUrl(url)
                            }
                        }
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        UIPasteboard.general.string = url
                    }),
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let link = URL(string: url) {
                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                        }
                    })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.view.endEditing(true)
                strongSelf.controller?.present(actionSheet, in: .window(.root))
            default:
                break
            }
        }, openCheckoutOrReceipt: { _, _ in
        }, openSearch: {
        }, setupReply: { _ in
        }, canSetupReply: { _ in
            return .none
        }, canSendMessages: {
            return false
        }, navigateToFirstDateMessage: { _, _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: { _ in
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _, _ in
        }, displayImportedMessageTooltip: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: { _, _ in
        }, displayPremiumStickerTooltip: { _, _ in
        }, displayEmojiPackTooltip: { _, _ in
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
        }, activateAdAction: { _, _, _, _ in
        }, adContextAction: { _, _, _ in
        }, removeAd: { _ in
        }, openRequestedPeerSelection: { _, _, _, _ in
        }, saveMediaToFiles: { _ in
        }, openNoAdsDemo: {
        }, openAdsInfo: {
        }, displayGiveawayParticipationStatus: { _ in
        }, openPremiumStatusInfo: { _, _, _, _ in
        }, openRecommendedChannelContextMenu: { _, _, _ in
        }, openGroupBoostInfo: { _, _ in
        }, openStickerEditor: {
        }, openAgeRestrictedMessageMedia: { _, _ in
        }, playMessageEffect: { _ in
        }, editMessageFactCheck: { _ in
        }, sendGift: { [weak self] _ in
            guard let self else {
                return
            }
            self.openPremiumGift()
        }, openUniqueGift: { _ in
        }, openMessageFeeException: {
        }, requestMessageUpdate: { _, _ in
        }, cancelInteractiveKeyboardGestures: {
        }, dismissTextInput: {
        }, scrollToMessageId: { _ in
        }, navigateToStory: { _, _ in
        }, attemptedNavigationToPrivateQuote: { _ in
        }, forceUpdateWarpContents: {
        }, playShakeAnimation: {
        }, displayQuickShare: { _, _ ,_ in
        }, updateChatLocationThread: { _, _ in
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
        pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(), presentationContext: ChatPresentationContext(context: context, backgroundNode: nil))
        self.hiddenMediaDisposable = context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().startStrict(next: { [weak self] ids in
            guard let strongSelf = self else {
                return
            }
            var hiddenMedia: [MessageId: [Media]] = [:]
            for id in ids {
                if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                    hiddenMedia[messageId] = [media]
                }
            }
            strongSelf.chatInterfaceInteraction.hiddenMedia = hiddenMedia
            strongSelf.paneContainerNode.updateHiddenMedia()
        })
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.alwaysBounceVertical = true
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.paneContainerNode)
        
        self.addSubnode(self.headerNode)
        self.scrollNode.view.isScrollEnabled = !self.isMediaOnly
        
        self.paneContainerNode.chatControllerInteraction = self.chatInterfaceInteraction
        self.paneContainerNode.openPeerContextAction = { [weak self] recommended, peer, node, gesture in
            guard let strongSelf = self, let controller = strongSelf.controller else {
                return
            }
            let presentationData = strongSelf.presentationData
            let chatController = strongSelf.context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(.previewing), params: nil)
            chatController.canReadHistory.set(false)
            let items: [ContextMenuItem]
            if recommended {
                items = [
                    .action(ContextMenuActionItem(text: presentationData.strings.Conversation_LinkDialogOpen, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ImageEnlarge"), color: theme.actionSheet.primaryTextColor) }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        self?.chatInterfaceInteraction.openPeer(EnginePeer(peer), .default, nil, .default)
                    })),
                    .action(ContextMenuActionItem(text: presentationData.strings.Chat_SimilarChannels_Join, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.actionSheet.primaryTextColor) }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        
                        guard let self else {
                            return
                        }
                        self.joinChannel(peer: EnginePeer(peer))
                    }))
                ]
            } else {
                items = [
                    .action(ContextMenuActionItem(text: presentationData.strings.Conversation_LinkDialogOpen, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ImageEnlarge"), color: theme.actionSheet.primaryTextColor) }, action: { _, f in
                        f(.dismissWithoutContent)
                        self?.chatInterfaceInteraction.openPeer(EnginePeer(peer), .default, nil, .default)
                    }))
                ]
            }
            let contextController = ContextController(presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            controller.presentInGlobalOverlay(contextController)
        }
        
        self.paneContainerNode.currentPaneUpdated = { [weak self] expand in
            guard let strongSelf = self else {
                return
            }

            if let (layout, navigationHeight) = strongSelf.validLayout {
                if strongSelf.headerNode.isAvatarExpanded {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                    
                    strongSelf.headerNode.updateIsAvatarExpanded(false, transition: transition)
                    strongSelf.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
                    
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                    }
                }
                
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                if expand {
                    strongSelf.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: strongSelf.paneContainerNode.frame.minY - navigationHeight), animated: true)
                }
            }
        }

        self.customStatusPromise.set(self.paneContainerNode.currentPaneStatus)
        
        self.paneContainerNode.requestExpandTabs = { [weak self] in
            guard let strongSelf = self, let (_, navigationHeight) = strongSelf.validLayout else {
                return false
            }
            
            if strongSelf.headerNode.isAvatarExpanded {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                
                strongSelf.headerNode.updateIsAvatarExpanded(false, transition: transition)
                strongSelf.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
                
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                }
            }
            
            let contentOffset = strongSelf.scrollNode.view.contentOffset
            let paneAreaExpansionFinalPoint: CGFloat = strongSelf.paneContainerNode.frame.minY - navigationHeight
            if contentOffset.y < paneAreaExpansionFinalPoint - CGFloat.ulpOfOne {
                strongSelf.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: paneAreaExpansionFinalPoint), animated: true)
                return true
            } else {
                return false
            }
        }
        
        self.paneContainerNode.requestUpdate = { [weak self] transition in
            guard let self else {
                return
            }
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: false)
            }
        }
        
        self.paneContainerNode.ensurePaneRectVisible = { [weak self] sourceView, rect in
            guard let self else {
                return
            }
            let localRect = sourceView.convert(rect, to: self.view)
            if !self.view.bounds.insetBy(dx: -1000.0, dy: 0.0).contains(localRect) {
                guard let (_, navigationHeight) = self.validLayout else {
                    return
                }
                
                if self.headerNode.isAvatarExpanded {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                    
                    self.headerNode.updateIsAvatarExpanded(false, transition: transition)
                    self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                    }
                }
                
                let contentOffset = self.scrollNode.view.contentOffset
                let paneAreaExpansionFinalPoint: CGFloat = self.paneContainerNode.frame.minY - navigationHeight
                if contentOffset.y < paneAreaExpansionFinalPoint - CGFloat.ulpOfOne {
                    self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: paneAreaExpansionFinalPoint), animated: false)
                }
            }
        }

        self.paneContainerNode.openMediaCalendar = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openMediaCalendar()
        }
        
        self.paneContainerNode.openAddStory = { [weak self] in
            guard let self else {
                return
            }
            
            self.headerNode.navigationButtonContainer.performAction?(.postStory, nil, nil)
        }

        self.paneContainerNode.paneDidScroll = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let mediaGalleryContextMenu = strongSelf.mediaGalleryContextMenu {
                strongSelf.mediaGalleryContextMenu = nil
                mediaGalleryContextMenu.dismiss()
            }
        }
        
        self.paneContainerNode.openAddMemberAction = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openAddMember()
        }
        
        self.paneContainerNode.requestPerformPeerMemberAction = { [weak self] member, action in
            guard let strongSelf = self else {
                return
            }
            switch action {
            case .open:
                strongSelf.openPeerInfo(peer: member.peer, isMember: true)
            case .promote:
                strongSelf.performMemberAction(member: member, action: .promote)
            case .restrict:
                strongSelf.performMemberAction(member: member, action: .restrict)
            case .remove:
                strongSelf.performMemberAction(member: member, action: .remove)
            case let .openStories(sourceView):
                strongSelf.performMemberAction(member: member, action: .openStories(sourceView: sourceView))
            }
        }
        
        self.headerNode.performButtonAction = { [weak self] key, gesture in
            self?.performButtonAction(key: key, gesture: gesture)
        }
        
        self.headerNode.cancelUpload = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.state.updatingAvatar != nil {
                strongSelf.updateAvatarDisposable.set(nil)
                strongSelf.state = strongSelf.state.withUpdatingAvatar(nil)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
            }
        }
        
        self.headerNode.requestAvatarExpansion = { [weak self] gallery, entries, centralEntry, _ in
            guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                return
            }

            if strongSelf.state.updatingAvatar != nil {
                strongSelf.updateAvatarDisposable.set(nil)
                strongSelf.state = strongSelf.state.withUpdatingAvatar(nil)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
                return
            }
            
            if !gallery, let expiringStoryListState = strongSelf.expiringStoryListState, !expiringStoryListState.items.isEmpty {
                strongSelf.openStories(fromAvatar: true)
                
                return
            }
            
            guard peer.smallProfileImage != nil else {
                return
            }
            
            if !gallery {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                strongSelf.headerNode.updateIsAvatarExpanded(true, transition: transition)
                strongSelf.updateNavigationExpansionPresentation(isExpanded: true, animated: true)
                
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                }
                return
            }
            
            strongSelf.openAvatarGallery(peer: EnginePeer(peer), entries: entries, centralEntry: centralEntry, animateTransition: true)
            
            Queue.mainQueue().after(0.4) {
                strongSelf.resetHeaderExpansion()
            }
        }
        
        self.headerNode.requestOpenAvatarForEditing = { [weak self] confirm in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.state.updatingAvatar != nil {
                let proceed = {
                    strongSelf.updateAvatarDisposable.set(nil)
                    strongSelf.state = strongSelf.state.withUpdatingAvatar(nil)
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                }
                if confirm {
                    let controller = ActionSheetController(presentationData: strongSelf.presentationData)
                    let dismissAction: () -> Void = { [weak controller] in
                        controller?.dismissAnimated()
                    }
                    
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Settings_CancelUpload, color: .destructive, action: {
                        dismissAction()
                        proceed()
                    }))
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    strongSelf.controller?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                } else {
                    proceed()
                }
            } else {
                strongSelf.controller?.openAvatarForEditing()
            }
        }

        self.headerNode.animateOverlaysFadeIn = { [weak self] in
            guard let strongSelf = self, let navigationBar = strongSelf.controller?.navigationBar else {
                return
            }
            navigationBar.layer.animateAlpha(from: 0.0, to: navigationBar.alpha, duration: 0.25)
        }
        
        self.headerNode.requestUpdateLayout = { [weak self] animated in
            guard let strongSelf = self else {
                return
            }
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: animated ? .animated(duration: 0.35, curve: .slide) : .immediate, additive: false)
            }
        }
        
        self.headerNode.navigationButtonContainer.performAction = { [weak self] key, source, gesture in
            guard let strongSelf = self else {
                return
            }
            switch key {
            case .back:
                strongSelf.controller?.dismiss()
            case .edit:
                if case let .replyThread(message) = strongSelf.chatLocation {
                    let threadId = message.threadId
                    if let threadData = strongSelf.data?.threadData {
                        let controller = ForumCreateTopicScreen(context: strongSelf.context, peerId: strongSelf.peerId, mode: .edit(threadId: threadId, threadInfo: threadData.info, isHidden: threadData.isHidden))
                        controller.navigationPresentation = .modal
                        let context = strongSelf.context
                        controller.completion = { [weak controller] title, fileId, _, isHidden in
                            let _ = (context.engine.peers.editForumChannelTopic(id: peerId, threadId: threadId, title: title, iconFileId: fileId)
                            |> deliverOnMainQueue).startStandalone(completed: {
                                controller?.dismiss()
                            })
                            
                            if let isHidden = isHidden {
                                let _ = (context.engine.peers.setForumChannelTopicHidden(id: peerId, threadId: threadId, isHidden: isHidden)
                                |> deliverOnMainQueue).startStandalone(completed: {
                                    controller?.dismiss()
                                })
                            }
                        }
                        strongSelf.controller?.push(controller)
                    }
                } else {
                    (strongSelf.controller?.parent as? TabBarController)?.updateIsTabBarHidden(true, transition: .animated(duration: 0.3, curve: .linear))
                    strongSelf.state = strongSelf.state.withIsEditing(true)
                    var updateOnCompletion = false
                    if strongSelf.headerNode.isAvatarExpanded {
                        updateOnCompletion = true
                        strongSelf.headerNode.skipCollapseCompletion = true
                        strongSelf.headerNode.avatarListNode.avatarContainerNode.canAttachVideo = false
                        strongSelf.headerNode.editingContentNode.avatarNode.canAttachVideo = false
                        strongSelf.headerNode.avatarListNode.listContainerNode.isCollapsing = true
                        strongSelf.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
                        strongSelf.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
                    }
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.scrollNode.view.setContentOffset(CGPoint(), animated: false)
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                    UIView.transition(with: strongSelf.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: { _ in
                        if updateOnCompletion {
                            strongSelf.headerNode.skipCollapseCompletion = false
                            strongSelf.headerNode.avatarListNode.listContainerNode.isCollapsing = false
                            strongSelf.headerNode.avatarListNode.avatarContainerNode.canAttachVideo = true
                            strongSelf.headerNode.editingContentNode.avatarNode.canAttachVideo = true
                            strongSelf.headerNode.editingContentNode.avatarNode.reset()
                            if let (layout, navigationHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                            }
                        }
                    })
                }
            case .done, .cancel:
                strongSelf.view.endEditing(true)
                if case .done = key {
                    guard let data = strongSelf.data else {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                        return
                    }
                    if let peer = data.peer as? TelegramUser {
                        if strongSelf.isSettings || strongSelf.isMyProfile, let cachedData = data.cachedData as? CachedUserData {
                            let firstName = strongSelf.headerNode.editingContentNode.editingTextForKey(.firstName) ?? ""
                            let lastName = strongSelf.headerNode.editingContentNode.editingTextForKey(.lastName) ?? ""
                            let bio = strongSelf.state.updatingBio
                            let birthday = strongSelf.state.updatingBirthDate
                            
                            if let bio = bio {
                                if Int32(bio.count) > strongSelf.context.userLimits.maxAboutLength {
                                    for (_, section) in strongSelf.editingSections {
                                        section.animateErrorIfNeeded()
                                    }
                                    strongSelf.hapticFeedback.error()
                                    return
                                }
                            }
                            
                            let peerBio = cachedData.about ?? ""
                                                        
                            if (peer.firstName ?? "") != firstName || (peer.lastName ?? "") != lastName || (bio ?? "") != peerBio || (cachedData.birthday != birthday) {
                                var updateNameSignal: Signal<Void, UpdateInfoError> = .complete()
                                var hasProgress = false
                                if (peer.firstName ?? "") != firstName || (peer.lastName ?? "") != lastName {
                                    updateNameSignal = context.engine.accountData.updateAccountPeerName(firstName: firstName, lastName: lastName)
                                    |> castError(UpdateInfoError.self)
                                    hasProgress = true
                                }
                                
                                enum UpdateInfoError {
                                    case generic
                                    case birthdayFlood
                                }
                                
                                var updateBioSignal: Signal<Void, UpdateInfoError> = .complete()
                                if let bio, bio != cachedData.about {
                                    updateBioSignal = context.engine.accountData.updateAbout(about: bio)
                                    |> `catch` { _ -> Signal<Void, UpdateInfoError> in
                                        return .complete()
                                    }
                                    hasProgress = true
                                }
                                var updatedBirthdaySignal: Signal<Never, UpdateInfoError> = .complete()
                                if let birthday, birthday != cachedData.birthday {
                                    updatedBirthdaySignal = context.engine.accountData.updateBirthday(birthday: birthday)
                                    |> `catch` { error -> Signal<Never, UpdateInfoError> in
                                        if case .flood = error {
                                            return .fail(.birthdayFlood)
                                        }
                                        return .complete()
                                    }
                                    hasProgress = true
                                }
                                
                                var dismissStatus: (() -> Void)?
                                let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                    dismissStatus?()
                                }))
                                dismissStatus = { [weak statusController] in
                                    self?.activeActionDisposable.set(nil)
                                    statusController?.dismiss()
                                }
                                if hasProgress {
                                    strongSelf.controller?.present(statusController, in: .window(.root))
                                }
                                strongSelf.activeActionDisposable.set((combineLatest(updateNameSignal, updateBioSignal, updatedBirthdaySignal) |> deliverOnMainQueue
                                |> deliverOnMainQueue).startStrict(error: { [weak self] error in
                                    dismissStatus?()
                                    
                                    guard let self else {
                                        return
                                    }
                                    if case .birthdayFlood = error {
                                        self.controller?.present(textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: self.presentationData.strings.Birthday_FloodError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                }, completed: {
                                    dismissStatus?()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                }))
                            } else {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                            }
                        } else if let botInfo = peer.botInfo, botInfo.flags.contains(.canEdit), let cachedData = data.cachedData as? CachedUserData, let editableBotInfo = cachedData.editableBotInfo {
                            let firstName = strongSelf.headerNode.editingContentNode.editingTextForKey(.firstName) ?? ""
                            let bio = strongSelf.headerNode.editingContentNode.editingTextForKey(.description)
                            if let bio = bio {
                                if Int32(bio.count) > strongSelf.context.userLimits.maxAboutLength {
                                    for (_, section) in strongSelf.editingSections {
                                        section.animateErrorIfNeeded()
                                    }
                                    strongSelf.hapticFeedback.error()
                                    return
                                }
                            }
                            let peerName = editableBotInfo.name
                            let peerBio = editableBotInfo.about
                            
                            if firstName != peerName || (bio ?? "") != peerBio {
                                var updateNameSignal: Signal<Void, NoError> = .complete()
                                var hasProgress = false
                                if firstName != peerName {
                                    updateNameSignal = context.engine.peers.updateBotName(peerId: peer.id, name: firstName)
                                    |> `catch` { _ -> Signal<Void, NoError> in
                                        return .complete()
                                    }
                                    hasProgress = true
                                }
                                var updateBioSignal: Signal<Void, NoError> = .complete()
                                if let bio = bio, bio != peerBio {
                                    updateBioSignal = context.engine.peers.updateBotAbout(peerId: peer.id, about: bio)
                                    |> `catch` { _ -> Signal<Void, NoError> in
                                        return .complete()
                                    }
                                    hasProgress = true
                                }
                                
                                var dismissStatus: (() -> Void)?
                                let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                    dismissStatus?()
                                }))
                                dismissStatus = { [weak statusController] in
                                    self?.activeActionDisposable.set(nil)
                                    statusController?.dismiss()
                                }
                                if hasProgress {
                                    strongSelf.controller?.present(statusController, in: .window(.root))
                                }
                                strongSelf.activeActionDisposable.set((combineLatest(updateNameSignal, updateBioSignal) |> deliverOnMainQueue
                                |> deliverOnMainQueue).startStrict(completed: {
                                    dismissStatus?()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                }))
                            } else {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                            }
                        } else if data.isContact {
                            let firstName = strongSelf.headerNode.editingContentNode.editingTextForKey(.firstName) ?? ""
                            let lastName = strongSelf.headerNode.editingContentNode.editingTextForKey(.lastName) ?? ""
                            
                            if (peer.firstName ?? "") != firstName || (peer.lastName ?? "") != lastName {
                                if firstName.isEmpty && lastName.isEmpty {
                                    strongSelf.hapticFeedback.error()
                                    strongSelf.headerNode.editingContentNode.shakeTextForKey(.firstName)
                                } else {
                                    var dismissStatus: (() -> Void)?
                                    let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                        dismissStatus?()
                                    }))
                                    dismissStatus = { [weak statusController] in
                                        self?.activeActionDisposable.set(nil)
                                        statusController?.dismiss()
                                    }
                                    strongSelf.controller?.present(statusController, in: .window(.root))
                                    
                                    strongSelf.activeActionDisposable.set((context.engine.contacts.updateContactName(peerId: peer.id, firstName: firstName, lastName: lastName)
                                    |> deliverOnMainQueue).startStrict(error: { _ in
                                        dismissStatus?()
                                        
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                    }, completed: {
                                        dismissStatus?()
                                        
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let context = strongSelf.context
                                        
                                        let _ = (getUserPeer(engine: strongSelf.context.engine, peerId: peer.id)
                                        |> mapToSignal { peer -> Signal<Void, NoError> in
                                            guard case let .user(peer) = peer, let phone = peer.phone, !phone.isEmpty else {
                                                return .complete()
                                            }
                                            return (context.sharedContext.contactDataManager?.basicDataForNormalizedPhoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(context: context, number: phone))) ?? .single([]))
                                            |> take(1)
                                            |> mapToSignal { records -> Signal<Void, NoError> in
                                                var signals: [Signal<DeviceContactExtendedData?, NoError>] = []
                                                if let contactDataManager = context.sharedContext.contactDataManager {
                                                    for (id, basicData) in records {
                                                        signals.append(contactDataManager.appendContactData(DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: basicData.phoneNumbers), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: ""), to: id))
                                                    }
                                                }
                                                return combineLatest(signals)
                                                |> mapToSignal { _ -> Signal<Void, NoError> in
                                                    return .complete()
                                                }
                                            }
                                        }).startStandalone()
                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                    }))
                                }
                            } else {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                            }
                        } else {
                            strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                        }
                    } else if let group = data.peer as? TelegramGroup, canEditPeerInfo(context: strongSelf.context, peer: group, chatLocation: chatLocation, threadData: data.threadData) {
                        let title = strongSelf.headerNode.editingContentNode.editingTextForKey(.title) ?? ""
                        let description = strongSelf.headerNode.editingContentNode.editingTextForKey(.description) ?? ""
                        
                        if title.isEmpty {
                            strongSelf.hapticFeedback.error()
                            
                            strongSelf.headerNode.editingContentNode.shakeTextForKey(.title)
                        } else {
                            var updateDataSignals: [Signal<Never, Void>] = []
                            
                            var hasProgress = false
                            if title != group.title {
                                updateDataSignals.append(
                                    strongSelf.context.engine.peers.updatePeerTitle(peerId: group.id, title: title)
                                    |> ignoreValues
                                    |> mapError { _ in return Void() }
                                )
                                hasProgress = true
                            }
                            if description != (data.cachedData as? CachedGroupData)?.about {
                                updateDataSignals.append(
                                    strongSelf.context.engine.peers.updatePeerDescription(peerId: group.id, description: description.isEmpty ? nil : description)
                                    |> ignoreValues
                                    |> mapError { _ in return Void() }
                                )
                                hasProgress = true
                            }
                            var dismissStatus: (() -> Void)?
                            let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                dismissStatus?()
                            }))
                            dismissStatus = { [weak statusController] in
                                self?.activeActionDisposable.set(nil)
                                statusController?.dismiss()
                            }
                            if hasProgress {
                                strongSelf.controller?.present(statusController, in: .window(.root))
                            }
                            strongSelf.activeActionDisposable.set((combineLatest(updateDataSignals)
                            |> deliverOnMainQueue).startStrict(error: { _ in
                                dismissStatus?()
                                
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                            }, completed: {
                                dismissStatus?()
                                
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                            }))
                        }
                    } else if let channel = data.peer as? TelegramChannel, canEditPeerInfo(context: strongSelf.context, peer: channel, chatLocation: strongSelf.chatLocation, threadData: data.threadData) {
                        let title = strongSelf.headerNode.editingContentNode.editingTextForKey(.title) ?? ""
                        let description = strongSelf.headerNode.editingContentNode.editingTextForKey(.description) ?? ""
                        
                        let proceed: () -> Void = {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if title.isEmpty {
                                strongSelf.headerNode.editingContentNode.shakeTextForKey(.title)
                            } else {
                                var updateDataSignals: [Signal<Never, Void>] = []
                                var hasProgress = false
                                if title != channel.title {
                                    updateDataSignals.append(
                                        strongSelf.context.engine.peers.updatePeerTitle(peerId: channel.id, title: title)
                                        |> ignoreValues
                                        |> mapError { _ in return Void() }
                                    )
                                    hasProgress = true
                                }
                                if description != (data.cachedData as? CachedChannelData)?.about {
                                    updateDataSignals.append(
                                        strongSelf.context.engine.peers.updatePeerDescription(peerId: channel.id, description: description.isEmpty ? nil : description)
                                        |> ignoreValues
                                        |> mapError { _ in return Void() }
                                    )
                                    hasProgress = true
                                }
                                
                                var dismissStatus: (() -> Void)?
                                let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                    dismissStatus?()
                                }))
                                dismissStatus = { [weak statusController] in
                                    self?.activeActionDisposable.set(nil)
                                    statusController?.dismiss()
                                }
                                if hasProgress {
                                    strongSelf.controller?.present(statusController, in: .window(.root))
                                }
                                strongSelf.activeActionDisposable.set((combineLatest(updateDataSignals)
                                |> deliverOnMainQueue).startStrict(error: { _ in
                                    dismissStatus?()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                }, completed: {
                                    dismissStatus?()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                }))
                            }
                        }
                        
                        proceed()
                    } else {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                    }
                } else {
                    strongSelf.state = strongSelf.state.withIsEditing(false).withUpdatingBio(nil).withUpdatingBirthDate(nil).withIsEditingBirthDate(false)
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.scrollNode.view.setContentOffset(CGPoint(), animated: false)
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                    UIView.transition(with: strongSelf.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: nil)
                }
                (strongSelf.controller?.parent as? TabBarController)?.updateIsTabBarHidden(false, transition: .animated(duration: 0.3, curve: .linear))
            case .select:
                strongSelf.state = strongSelf.state.withSelectedMessageIds(Set())
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
                }
                strongSelf.chatInterfaceInteraction.selectionState = strongSelf.state.selectedMessageIds.flatMap { ChatInterfaceSelectionState(selectedIds: $0) }
                strongSelf.paneContainerNode.updateSelectedMessageIds(strongSelf.state.selectedMessageIds, animated: true)
            case .selectionDone:
                strongSelf.state = strongSelf.state.withSelectedMessageIds(nil).withSelectedStoryIds(nil).withPaneIsReordering(false)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
                }
                strongSelf.chatInterfaceInteraction.selectionState = strongSelf.state.selectedMessageIds.flatMap { ChatInterfaceSelectionState(selectedIds: $0) }
                strongSelf.paneContainerNode.updateSelectedMessageIds(strongSelf.state.selectedMessageIds, animated: true)
                strongSelf.paneContainerNode.updateSelectedStoryIds(strongSelf.state.selectedStoryIds, animated: true)
                strongSelf.paneContainerNode.updatePaneIsReordering(isReordering: strongSelf.state.paneIsReordering, animated: true)
            case .search, .searchWithTags, .standaloneSearch:
                strongSelf.activateSearch()
            case .more:
                guard let source else {
                    return
                }
                if let currentPaneKey = strongSelf.paneContainerNode.currentPaneKey {
                    switch currentPaneKey {
                    case .savedMessagesChats:
                        if let controller = strongSelf.controller {
                            PeerInfoScreenImpl.openSavedMessagesMoreMenu(context: strongSelf.context, sourceController: controller, isViewingAsTopics: true, sourceView: source.view, gesture: gesture)
                        }
                    default:
                        strongSelf.displayMediaGalleryContextMenu(source: source, gesture: gesture)
                    }
                }
            case .sort:
                guard let source else {
                    return
                }
                if let currentPaneKey = strongSelf.paneContainerNode.currentPaneKey, case .gifts = currentPaneKey {
                    strongSelf.displayGiftsContextMenu(source: source, gesture: gesture)
                }
            case .qrCode:
                strongSelf.openQrCode()
            case .postStory:
                var sourceFrame: CGRect?
                if let source {
                    sourceFrame = source.view.convert(source.bounds, to: strongSelf.view)
                }
                strongSelf.openPostStory(sourceFrame: sourceFrame)
            case .editPhoto, .editVideo, .moreSearchSort:
                break
            }
        }
        
        let screenData: Signal<PeerInfoScreenData, NoError>
        if self.isSettings {
            self.notificationExceptions.set(.single(NotificationExceptionsList(peers: [:], settings: [:]))
            |> then(
                context.engine.peers.notificationExceptionsList()
                |> map(Optional.init)
            ))
            self.privacySettings.set(.single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)))
            self.archivedPacks.set(.single(nil) |> then(context.engine.stickers.archivedStickerPacks() |> map(Optional.init)))
            self.twoStepAccessConfiguration.set(.single(nil) |> then(context.engine.auth.twoStepVerificationConfiguration()
            |> map { value -> TwoStepVerificationAccessConfiguration? in
                return TwoStepVerificationAccessConfiguration(configuration: value, password: nil)
            }))
            
            self.twoStepAuthData.set(.single(nil)
            |> then(
                context.engine.auth.twoStepAuthData()
                |> map(Optional.init)
                |> `catch` { _ -> Signal<TwoStepAuthData?, NoError> in
                    return .single(nil)
                }
            ))
            
            let hasPassport = self.twoStepAuthData.get()
            |> map { data -> Bool in
                return data?.hasSecretValues ?? false
            }
            
            self.cachedFaq.set(.single(nil) |> then(cachedFaqInstantPage(context: self.context) |> map(Optional.init)))
            
            screenData = peerInfoScreenSettingsData(context: context, peerId: peerId, accountsAndPeers: self.accountsAndPeers.get(), activeSessionsContextAndCount: self.activeSessionsContextAndCount.get(), notificationExceptions: self.notificationExceptions.get(), privacySettings: self.privacySettings.get(), archivedStickerPacks: self.archivedPacks.get(), hasPassport: hasPassport, starsContext: starsContext)
            
            
            self.headerNode.displayCopyContextMenu = { [weak self] node, copyPhone, copyUsername in
                guard let strongSelf = self, let data = strongSelf.data, let user = data.peer as? TelegramUser else {
                    return
                }
                var actions: [ContextMenuAction] = []
                if copyPhone, let phone = user.phone, !phone.isEmpty {
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Settings_CopyPhoneNumber, accessibilityLabel: strongSelf.presentationData.strings.Settings_CopyPhoneNumber), action: { [weak self] in
                        if let strongSelf = self {
                            UIPasteboard.general.string = formatPhoneNumber(context: strongSelf.context, number: phone)
                            
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }
                    }))
                }
                
                if copyUsername, let username = user.addressName, !username.isEmpty {
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Settings_CopyUsername, accessibilityLabel: strongSelf.presentationData.strings.Settings_CopyUsername), action: { [weak self] in
                        UIPasteboard.general.string = "@\(username)"
                        
                        if let strongSelf = self {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_UsernameCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }
                    }))
                }
                
                let contextMenuController = makeContextMenuController(actions: actions)
                strongSelf.controller?.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                    if let strongSelf = self {
                        return (node, node.bounds.insetBy(dx: 0.0, dy: -2.0), strongSelf, strongSelf.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
            
            var previousTimestamp: Double?
            self.headerNode.displayPremiumIntro = { [weak self] sourceView, _, _, _ in
                guard let strongSelf = self else {
                    return
                }
                let currentTimestamp = CACurrentMediaTime()
                if let previousTimestamp, currentTimestamp < previousTimestamp + 1.0 {
                    return
                }
                previousTimestamp = currentTimestamp
                
                let animationCache = context.animationCache
                let animationRenderer = context.animationRenderer
                
                strongSelf.emojiStatusSelectionController?.dismiss()
                var selectedItems = Set<MediaId>()
                var currentSelectedFileId: Int64?
                var topStatusTitle = strongSelf.presentationData.strings.PeerStatusSetup_NoTimerTitle
                if let peer = strongSelf.data?.peer {
                    if let emojiStatus = peer.emojiStatus {
                        selectedItems.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: emojiStatus.fileId))
                        currentSelectedFileId = emojiStatus.fileId
                        
                        if let timestamp = emojiStatus.expirationDate {
                            topStatusTitle = peerStatusExpirationString(statusTimestamp: timestamp, relativeTo: Int32(Date().timeIntervalSince1970), strings: strongSelf.presentationData.strings, dateTimeFormat: strongSelf.presentationData.dateTimeFormat)
                        }
                    }
                }
                
                let emojiStatusSelectionController = EmojiStatusSelectionController(
                    context: strongSelf.context,
                    mode: .statusSelection,
                    sourceView: sourceView,
                    emojiContent: EmojiPagerContentComponent.emojiInputData(
                        context: strongSelf.context,
                        animationCache: animationCache,
                        animationRenderer: animationRenderer,
                        isStandalone: false,
                        subject: .status,
                        hasTrending: false,
                        topReactionItems: [],
                        areUnicodeEmojiEnabled: false,
                        areCustomEmojiEnabled: true,
                        chatPeerId: strongSelf.context.account.peerId,
                        selectedItems: selectedItems,
                        topStatusTitle: topStatusTitle
                    ),
                    currentSelection: currentSelectedFileId,
                    destinationItemView: { [weak sourceView] in
                        return sourceView
                    }
                )
                emojiStatusSelectionController.pushController = { [weak self] c in
                    self?.controller?.push(c)
                }
                strongSelf.emojiStatusSelectionController = emojiStatusSelectionController
                strongSelf.controller?.present(emojiStatusSelectionController, in: .window(.root))
            }
        } else {
            if peerId == context.account.peerId {
                self.privacySettings.set(.single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)))
            } else {
                self.privacySettings.set(.single(nil))
            }
            
            screenData = peerInfoScreenData(context: context, peerId: peerId, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, isSettings: self.isSettings, isMyProfile: self.isMyProfile, hintGroupInCommon: hintGroupInCommon, existingRequestsContext: requestsContext, existingProfileGiftsContext: profileGiftsContext, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, privacySettings: self.privacySettings.get(), forceHasGifts: initialPaneKey == .gifts)
                       
            var previousTimestamp: Double?
            self.headerNode.displayPremiumIntro = { [weak self] sourceView, peerStatus, emojiStatusFileAndPack, white in
                guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                    return
                }
                let currentTimestamp = CACurrentMediaTime()
                if let previousTimestamp, currentTimestamp < previousTimestamp + 1.0 {
                    return
                }
                previousTimestamp = currentTimestamp
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                guard !premiumConfiguration.isPremiumDisabled else {
                    return
                }
                
                let source: Signal<PremiumSource, NoError>
                if let peerStatus = peerStatus {
                    source = emojiStatusFileAndPack
                    |> take(1)
                    |> mapToSignal { emojiStatusFileAndPack -> Signal<PremiumSource, NoError> in
                        if let (file, pack) = emojiStatusFileAndPack {
                            return .single(.emojiStatus(peer.id, peerStatus.fileId, file, pack))
                        } else {
                            return .complete()
                        }
                    }
                } else {
                    source = .single(.profile(strongSelf.peerId))
                }
                
                let _ = (source
                |> deliverOnMainQueue).startStandalone(next: { [weak self] source in
                    guard let strongSelf = self else {
                        return
                    }
                    let controller = PremiumIntroScreen(context: strongSelf.context, source: source)
                    controller.sourceView = sourceView
                    controller.containerView = strongSelf.controller?.navigationController?.view
                    controller.animationColor = white ? .white : strongSelf.presentationData.theme.list.itemAccentColor
                    strongSelf.controller?.push(controller)
                })
            }
            
            self.headerNode.displayUniqueGiftInfo = { [weak self] sourceView, text in
                guard let self, let controller = self.controller else {
                    return
                }
                let sourceRect = sourceView.convert(sourceView.bounds, to: controller.view)
                guard sourceRect.minY > 44.0 else {
                    return
                }
                
                let backgroundColor: UIColor
                if !self.headerNode.isAvatarExpanded, let contentButtonBackgroundColor = self.headerNode.contentButtonBackgroundColor {
                    backgroundColor = contentButtonBackgroundColor
                } else {
                    backgroundColor = UIColor(rgb: 0x000000, alpha: 0.65)
                }
                
                let tooltipController = TooltipScreen(
                    context: self.context,
                    account: self.context.account,
                    sharedContext: self.context.sharedContext,
                    text: .attributedString(text: NSAttributedString(string: text, font: Font.semibold(11.0), textColor: .white)),
                    style: .customBlur(backgroundColor, -4.0),
                    arrowStyle: .small,
                    location: .point(sourceRect, .bottom),
                    isShimmering: true,
                    cornerRadius: 10.0,
                    shouldDismissOnTouch: { _, _ in
                        return .dismiss(consume: false)
                    }
                )
                controller.present(tooltipController, in: .current)
            }
            
            self.headerNode.displayStatusPremiumIntro = { [weak self] in
                guard let self else {
                    return
                }
                let controller = self.context.sharedContext.makePremiumPrivacyControllerController(context: self.context, subject: .presence, peerId: self.peerId)
                self.controller?.push(controller)
            }
            
            self.headerNode.displayAvatarContextMenu = { [weak self] node, gesture in
                guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                    return
                }
                
                var isPersonal = false
                var currentIsVideo = false
                let item = strongSelf.headerNode.avatarListNode.listContainerNode.currentItemNode?.item
                if let item = item, case let .image(_, representations, videoRepresentations, _, _, _) = item {
                    if representations.first?.representation.isPersonal == true {
                        isPersonal = true
                    }
                    currentIsVideo = !videoRepresentations.isEmpty
                }
                guard !isPersonal else {
                    return
                }
                
                let items: [ContextMenuItem] = [
                    .action(ContextMenuActionItem(text: currentIsVideo ? strongSelf.presentationData.strings.PeerInfo_ReportProfileVideo : strongSelf.presentationData.strings.PeerInfo_ReportProfilePhoto, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] c, f in                        
                        if let strongSelf = self, let parent = strongSelf.controller {
                            presentPeerReportOptions(context: context, parent: parent, contextController: c, subject: .profilePhoto(peer.id, 0), completion: { _, _ in })
                        }
                    }))
                ]
                
                let galleryController = AvatarGalleryController(context: strongSelf.context, peer: EnginePeer(peer), remoteEntries: nil, replaceRootController: { controller, ready in
                }, synchronousLoad: true)
                galleryController.setHintWillBePresentedInPreviewingContext(true)
                
                let contextController = ContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: galleryController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }
            
            self.headerNode.displayEmojiPackTooltip = { [weak self] in
                guard let strongSelf = self, let threadData = strongSelf.data?.threadData else {
                    return
                }
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                guard !premiumConfiguration.isPremiumDisabled else {
                    return
                }
                
                if let icon = threadData.info.icon, icon != 0 {
                    let _ = (strongSelf.context.engine.stickers.resolveInlineStickers(fileIds: [icon])
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] files in
                        if let file = files.first?.value {
                            var stickerPackReference: StickerPackReference?
                            for attribute in file.attributes {
                                if case let .CustomEmoji(_, _, _, packReference) = attribute {
                                    stickerPackReference = packReference
                                    break
                                }
                            }
                            
                            if let stickerPackReference = stickerPackReference {
                                let _ = (strongSelf.context.engine.stickers.loadedStickerPack(reference: stickerPackReference, forceActualized: false)
                                |> deliverOnMainQueue).startStandalone(next: { [weak self] stickerPack in
                                    if let strongSelf = self, case let .result(info, _, _) = stickerPack {
                                        strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: file, loop: true, title: nil, text: strongSelf.presentationData.strings.PeerInfo_TopicIconInfoText(info.title).string, undoText: strongSelf.presentationData.strings.Stickers_PremiumPackView, customAction: nil), elevatedLayout: false, action: { [weak self] action in
                                            if let strongSelf = self, action == .undo {
                                                strongSelf.presentEmojiList(packReference: stickerPackReference)
                                            }
                                            return false
                                        }), in: .current)
                                    }
                                })
                            }
                        }
                    })
                }
            }
            
            self.headerNode.navigateToForum = { [weak self] in
                guard let self, let navigationController = self.controller?.navigationController as? NavigationController, let peer = self.data?.peer else {
                    return
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer))))
            }
            
            if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(peerId.namespace) {
                self.displayAsPeersPromise.set(context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId))
            }
        }
        
        self.headerNode.openUniqueGift = { [weak self] _, slug in
            guard let self, let profileGifts = self.data?.profileGiftsContext else {
                return
            }
            var found = false
            if let state = profileGifts.currentState {
                for gift in state.gifts {
                    if case let .unique(uniqueGift) = gift.gift, uniqueGift.slug == slug {
                        found = true
                        
                        let controller = GiftViewScreen(
                            context: self.context,
                            subject: .profileGift(self.peerId, gift),
                            updateSavedToProfile: { [weak profileGifts] reference, added in
                                guard let profileGifts else {
                                    return
                                }
                                profileGifts.updateStarGiftAddedToProfile(reference: reference, added: added)
                            },
                            convertToStars: { [weak profileGifts] in
                                guard let profileGifts, let reference = gift.reference else {
                                    return
                                }
                                profileGifts.convertStarGift(reference: reference)
                            },
                            transferGift: { [weak profileGifts] prepaid, peerId in
                                guard let profileGifts, let reference = gift.reference else {
                                    return .complete()
                                }
                                return profileGifts.transferStarGift(prepaid: prepaid, reference: reference, peerId: peerId)
                            },
                            upgradeGift: { [weak profileGifts] formId, keepOriginalInfo in
                                guard let profileGifts, let reference = gift.reference else {
                                    return .never()
                                }
                                return profileGifts.upgradeStarGift(formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
                            },
                            buyGift: { [weak profileGifts] slug, peerId, price in
                                guard let profileGifts else {
                                    return .never()
                                }
                                return profileGifts.buyStarGift(slug: slug, peerId: peerId, price: price)
                            },
                            shareStory: { [weak self] uniqueGift in
                                guard let self, let controller = self.controller else {
                                    return
                                }
                                Queue.mainQueue().after(0.15) {
                                    let shareController = self.context.sharedContext.makeStorySharingScreen(context: self.context, subject: .gift(uniqueGift), parentController: controller)
                                    controller.push(shareController)
                                }
                            }
                        )
                        self.controller?.push(controller)
                        
                        break
                    }
                }
            }
            if !found {
                self.openUrl(url: "https://t.me/nft/\(slug)", concealed: false, external: false)
            }
        }
        
        self.headerNode.avatarListNode.listContainerNode.currentIndexUpdated = { [weak self] in
            self?.updateNavigation(transition: .immediate, additive: true, animateHeader: true)
        }
        
        self.dataDisposable = combineLatest(
            queue: Queue.mainQueue(),
            screenData,
            self.forceIsContactPromise.get()
        ).startStrict(next: { [weak self] data, forceIsContact in
            guard let strongSelf = self else {
                return
            }
            if data.isContact && forceIsContact {
                strongSelf.forceIsContactPromise.set(false)
            } else {
                data.forceIsContact = forceIsContact
            }
            strongSelf.updateData(data)
            strongSelf.cachedDataPromise.set(.single(data.cachedData))
        })
        
        if let _ = nearbyPeerDistance {
            self.preloadHistoryDisposable.set(self.context.account.addAdditionalPreloadHistoryPeerId(peerId: peerId))
            
            self.context.prefetchManager?.prepareNextGreetingSticker()
        }

        self.customStatusDisposable = (self.customStatusPromise.get()
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.customStatusData = value
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
        })

        self.refreshMessageTagStatsDisposable = context.engine.messages.refreshMessageTagStats(peerId: peerId, threadId: chatLocation.threadId, tags: [.video, .photo, .gif, .music, .voiceOrInstantVideo, .webPage, .file]).startStrict()
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            self.translationStateDisposable = (chatTranslationState(context: context, peerId: peerId, threadId: nil)
            |> deliverOnMainQueue).startStrict(next: { [weak self] translationState in
                self?.translationState = translationState
            })
            
            let _ = context.engine.peers.requestRecommendedChannels(peerId: peerId, forceUpdate: true).startStandalone()
            
            self.boostStatusDisposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> mapToSignal { peer -> Signal<ChannelBoostStatus?, NoError> in
                if case let .channel(channel) = peer {
                    if case .broadcast = channel.info, (channel.flags.contains(.isCreator) || channel.adminRights != nil) {
                        return context.engine.peers.getChannelBoostStatus(peerId: peerId)
                    } else if case .group = channel.info {
                        return context.engine.peers.getChannelBoostStatus(peerId: peerId)
                    }
                }
                return .single(nil)
            }
            |> deliverOnMainQueue).start(next: { [weak self] boostStatus in
                guard let self else {
                    return
                }
                self.boostStatus = boostStatus
            })
        }
        
        if peerId.namespace == Namespaces.Peer.CloudUser {
            let _ = context.engine.peers.requestRecommendedBots(peerId: peerId, forceUpdate: true).startStandalone()
        }
        
        if peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudUser {
            self.storiesReady.set(false)
            let expiringStoryList = PeerExpiringStoryListContext(account: context.account, peerId: peerId)
            self.expiringStoryList = expiringStoryList
            self.storyUploadProgressDisposable = (
                combineLatest(
                    queue: Queue.mainQueue(),
                    context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> distinctUntilChanged,
                    context.engine.messages.allStoriesUploadProgress()
                    |> map { value -> Float? in
                        return value[peerId]
                    }
                    |> distinctUntilChanged
            )).startStrict(next: { [weak self] peer, value in
                guard let self else {
                    return
                }
                var mappedValue = value
                if let value {
                    mappedValue = max(0.027, value)
                }
                
                if self.headerNode.avatarListNode.avatarContainerNode.storyProgress != mappedValue {
                    self.headerNode.avatarListNode.avatarContainerNode.storyProgress = mappedValue
                    self.headerNode.avatarListNode.avatarContainerNode.updateStoryView(transition: .immediate, theme: self.presentationData.theme, peer: peer?._asPeer())
                }
            })
            self.expiringStoryListDisposable = (combineLatest(queue: .mainQueue(),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
                expiringStoryList.state
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer, state in
                guard let self, let peer else {
                    return
                }
                self.expiringStoryListState = state
                if state.items.isEmpty {
                    self.headerNode.avatarListNode.avatarContainerNode.storyData = nil
                    self.headerNode.avatarListNode.listContainerNode.storyParams = nil
                } else {
                    let totalCount = state.items.count
                    var unseenCount = 0
                    for item in state.items {
                        if item.id > state.maxReadId {
                            unseenCount += 1
                        }
                    }
                    
                    self.headerNode.avatarListNode.avatarContainerNode.storyData = (totalCount, unseenCount, state.hasUnseenCloseFriends && peer.id != self.context.account.peerId)
                    self.headerNode.avatarListNode.listContainerNode.storyParams = (peer, state.items.prefix(3).compactMap { item -> EngineStoryItem? in
                        switch item {
                        case let .item(item):
                            return item
                        case .placeholder:
                            return nil
                        }
                    }, state.items.count, state.hasUnseen, state.hasUnseenCloseFriends)
                }
                
                self.storiesReady.set(true)
                
                self.requestLayout(animated: false)
                
                if self.headerNode.avatarListNode.openStories == nil {
                    self.headerNode.avatarListNode.openStories = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openStories(fromAvatar: false)
                    }
                }
            })
        }
    }
    
    deinit {
        self.dataDisposable?.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.activeActionDisposable.dispose()
        self.resolveUrlDisposable.dispose()
        self.hiddenAvatarRepresentationDisposable.dispose()
        self.toggleShouldChannelMessagesSignaturesDisposable.dispose()
        self.toggleMessageCopyProtectionDisposable.dispose()
        self.selectAddMemberDisposable.dispose()
        self.addMemberDisposable.dispose()
        self.preloadHistoryDisposable.dispose()
        self.resolvePeerByNameDisposable?.dispose()
        self.navigationActionDisposable.dispose()
        self.enqueueMediaMessageDisposable.dispose()
        self.supportPeerDisposable.dispose()
        self.tipsPeerDisposable.dispose()
        self.shareStatusDisposable?.dispose()
        self.customStatusDisposable?.dispose()
        self.refreshMessageTagStatsDisposable?.dispose()
        self.forumTopicNotificationExceptionsDisposable?.dispose()
        self.translationStateDisposable?.dispose()
        self.copyProtectionTooltipController?.dismiss()
        self.expiringStoryListDisposable?.dispose()
        self.postingAvailabilityDisposable?.dispose()
        self.storyUploadProgressDisposable?.dispose()
        self.updateAvatarDisposable.dispose()
        self.joinChannelDisposable.dispose()
        self.boostStatusDisposable?.dispose()
        self.personalChannelsDisposable?.dispose()
        self.autoTranslateDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
                
        self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            if let strongSelf = self {
                return strongSelf.state.isEditing
            } else {
                return false
            }
        }
    }
        
    var canAttachVideo: Bool?
    
    private func updateData(_ data: PeerInfoScreenData) {
        let previousData = self.data
        var previousMemberCount: Int?
        if let data = self.data {
            if let members = data.members, case let .shortList(_, memberList) = members {
                previousMemberCount = memberList.count
            }
        }
        self.data = data
        if previousData?.members?.membersContext !== data.members?.membersContext {
            if let peer = data.peer, let _ = data.members {
                self.groupMembersSearchContext = GroupMembersSearchContext(context: self.context, peerId: peer.id)
            } else {
                self.groupMembersSearchContext = nil
            }
        }
        
        if let channel = data.peer as? TelegramChannel, channel.isForumOrMonoForum, self.chatLocation.threadId == nil {
            if self.forumTopicNotificationExceptionsDisposable == nil {
                self.forumTopicNotificationExceptionsDisposable = (self.context.engine.peers.forumChannelTopicNotificationExceptions(id: channel.id)
                |> deliverOnMainQueue).startStrict(next: { [weak self] list in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.forumTopicNotificationExceptions = list
                })
            }
        }
        
        if let (layout, navigationHeight) = self.validLayout {
            var updatedMemberCount: Int?
            if let data = self.data {
                if let members = data.members, case let .shortList(_, memberList) = members {
                    updatedMemberCount = memberList.count
                }
            }
            
            var membersUpdated = false
            if let previousMemberCount = previousMemberCount, let updatedMemberCount = updatedMemberCount, previousMemberCount > updatedMemberCount {
                membersUpdated = true
            }
            
            var infoUpdated = false
            
            var previousCall: CachedChannelData.ActiveCall?
            var currentCall: CachedChannelData.ActiveCall?
            
            var previousCallsPrivate: Bool?
            var currentCallsPrivate: Bool?
            var previousVideoCallsAvailable: Bool? = true
            var currentVideoCallsAvailable: Bool?
            
            var previousAbout: String?
            var currentAbout: String?
            
            var previousIsBlocked: Bool?
            var currentIsBlocked: Bool?
            
            var previousBusinessHours: TelegramBusinessHours?
            var currentBusinessHours: TelegramBusinessHours?
            
            var previousBusinessLocation: TelegramBusinessLocation?
            var currentBusinessLocation: TelegramBusinessLocation?
            
            var previousPhotoIsPersonal: Bool?
            var currentPhotoIsPersonal: Bool?
            if let previousUser = previousData?.peer as? TelegramUser {
                previousPhotoIsPersonal = previousUser.profileImageRepresentations.first?.isPersonal == true
            }
            if let user = data.peer as? TelegramUser {
                currentPhotoIsPersonal = user.profileImageRepresentations.first?.isPersonal == true
            }
            
            if let previousCachedData = previousData?.cachedData as? CachedChannelData, let cachedData = data.cachedData as? CachedChannelData {
                previousCall = previousCachedData.activeCall
                currentCall = cachedData.activeCall
                previousAbout = previousCachedData.about
                currentAbout = cachedData.about
            } else if let previousCachedData = previousData?.cachedData as? CachedGroupData, let cachedData = data.cachedData as? CachedGroupData {
                previousCall = previousCachedData.activeCall
                currentCall = cachedData.activeCall
                previousAbout = previousCachedData.about
                currentAbout = cachedData.about
            } else if let previousCachedData = previousData?.cachedData as? CachedUserData, let cachedData = data.cachedData as? CachedUserData {
                previousCallsPrivate = previousCachedData.callsPrivate
                currentCallsPrivate = cachedData.callsPrivate
                previousVideoCallsAvailable = previousCachedData.videoCallsAvailable
                currentVideoCallsAvailable = cachedData.videoCallsAvailable
                previousAbout = previousCachedData.about
                currentAbout = cachedData.about
                previousIsBlocked = previousCachedData.isBlocked
                currentIsBlocked = cachedData.isBlocked
                previousBusinessHours = previousCachedData.businessHours
                currentBusinessHours = cachedData.businessHours
                previousBusinessLocation = previousCachedData.businessLocation
                currentBusinessLocation = cachedData.businessLocation
            }
            
            if self.isSettings {
                if let previousSuggestPhoneNumberConfirmation = previousData?.globalSettings?.suggestPhoneNumberConfirmation, previousSuggestPhoneNumberConfirmation != data.globalSettings?.suggestPhoneNumberConfirmation {
                    infoUpdated = true
                }
                if let previousSuggestPasswordConfirmation = previousData?.globalSettings?.suggestPasswordConfirmation, previousSuggestPasswordConfirmation != data.globalSettings?.suggestPasswordConfirmation {
                    infoUpdated = true
                }
                if let previousBots = previousData?.globalSettings?.bots, previousBots.count != (data.globalSettings?.bots ?? []).count {
                    infoUpdated = true
                }
            }
            if previousCallsPrivate != currentCallsPrivate || (previousVideoCallsAvailable != currentVideoCallsAvailable && currentVideoCallsAvailable != nil) {
                infoUpdated = true
            }
            if (previousCall == nil) != (currentCall == nil) {
                infoUpdated = true
            }
            if (previousAbout?.isEmpty ?? true) != (currentAbout?.isEmpty ?? true) {
                infoUpdated = true
            }
            if let previousPhotoIsPersonal, let currentPhotoIsPersonal, previousPhotoIsPersonal != currentPhotoIsPersonal {
                infoUpdated = true
            }
            if let previousIsBlocked, let currentIsBlocked, previousIsBlocked != currentIsBlocked {
                infoUpdated = true
            }
            
            if previousData != nil {
                if (previousBusinessHours == nil) != (currentBusinessHours != nil) {
                    infoUpdated = true
                }
                if (previousBusinessLocation == nil) != (currentBusinessLocation != nil) {
                    infoUpdated = true
                }
            }
            
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: self.didSetReady && (membersUpdated || infoUpdated) ? .animated(duration: 0.3, curve: .spring) : .immediate)
            
            if let cachedData = data.cachedData as? CachedUserData, let _ = cachedData.birthday {
                self.maybePlayBirthdayAnimation()
            }
        }
        
        if let peer = data.peer, peer.isCopyProtectionEnabled {
            setLayerDisableScreenshots(self.layer, true)
        } else {
            setLayerDisableScreenshots(self.layer, false)
        }
    }
    
    func scrollToTop() {
        if !self.paneContainerNode.scrollToTop() {
            self.scrollNode.view.setContentOffset(CGPoint(), animated: true)
        }
    }
    
    func expandTabs(animated: Bool) {
        if self.headerNode.isAvatarExpanded {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
            
            self.headerNode.updateIsAvatarExpanded(false, transition: transition)
            self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
            
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
            }
        }
        
        if let (_, navigationHeight) = self.validLayout {
            let contentOffset = self.scrollNode.view.contentOffset
            let paneAreaExpansionFinalPoint: CGFloat = self.paneContainerNode.frame.minY - navigationHeight
            if contentOffset.y < paneAreaExpansionFinalPoint - CGFloat.ulpOfOne {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
                
                self.ignoreScrolling = true
                transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: paneAreaExpansionFinalPoint), size: self.scrollNode.bounds.size))
                self.ignoreScrolling = false
                self.updateNavigation(transition: transition, additive: false, animateHeader: true)
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                }
            }
        }
    }
    
    private func openStories(fromAvatar: Bool) {
        guard let controller = self.controller else {
            return
        }
        if let expiringStoryList = self.expiringStoryList, let expiringStoryListState = self.expiringStoryListState, !expiringStoryListState.items.isEmpty {
            if fromAvatar {
                StoryContainerScreen.openPeerStories(context: self.context, peerId: self.peerId, parentController: controller, avatarNode: self.headerNode.avatarListNode.avatarContainerNode.avatarNode)
                return
            }
            
            let _ = expiringStoryList
            let storyContent = StoryContentContextImpl(context: self.context, isHidden: false, focusedPeerId: self.peerId, singlePeer: true)
            let _ = (storyContent.state
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] storyContentState in
                guard let self else {
                    return
                }
                var transitionIn: StoryContainerScreen.TransitionIn?
                
                if fromAvatar {
                    let transitionView = self.headerNode.avatarListNode.avatarContainerNode.avatarNode.view
                    transitionIn = StoryContainerScreen.TransitionIn(
                        sourceView: transitionView,
                        sourceRect: transitionView.bounds,
                        sourceCornerRadius: transitionView.bounds.height * 0.5,
                        sourceIsAvatar: true
                    )
                    self.headerNode.avatarListNode.avatarContainerNode.avatarNode.isHidden = true
                } else if let (expandedStorySetIndicatorTransitionView, subRect) = self.headerNode.avatarListNode.listContainerNode.expandedStorySetIndicatorTransitionView {
                    transitionIn = StoryContainerScreen.TransitionIn(
                        sourceView: expandedStorySetIndicatorTransitionView,
                        sourceRect: subRect,
                        sourceCornerRadius: expandedStorySetIndicatorTransitionView.bounds.height * 0.5,
                        sourceIsAvatar: false
                    )
                    expandedStorySetIndicatorTransitionView.isHidden = true
                }
                
                let storyContainerScreen = StoryContainerScreen(
                    context: self.context,
                    content: storyContent,
                    transitionIn: transitionIn,
                    transitionOut: { [weak self] peerId, _ in
                        guard let self else {
                            return nil
                        }
                        if !fromAvatar {
                            self.headerNode.avatarListNode.avatarContainerNode.avatarNode.isHidden = false
                            
                            if let (expandedStorySetIndicatorTransitionView, subRect) = self.headerNode.avatarListNode.listContainerNode.expandedStorySetIndicatorTransitionView {
                                return StoryContainerScreen.TransitionOut(
                                    destinationView: expandedStorySetIndicatorTransitionView,
                                    transitionView: StoryContainerScreen.TransitionView(
                                        makeView: { [weak expandedStorySetIndicatorTransitionView] in
                                            let parentView = UIView()
                                            if let copyView = expandedStorySetIndicatorTransitionView?.snapshotContentTree(unhide: true) {
                                                copyView.layer.anchorPoint = CGPoint()
                                                parentView.addSubview(copyView)
                                            }
                                            return parentView
                                        },
                                        updateView: { copyView, state, transition in
                                            guard let view = copyView.subviews.first else {
                                                return
                                            }
                                            let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                            transition.setPosition(view: view, position: CGPoint(x: 0.0, y: 0.0))
                                            transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                        },
                                        insertCloneTransitionView: nil
                                    ),
                                    destinationRect: subRect,
                                    destinationCornerRadius: expandedStorySetIndicatorTransitionView.bounds.height * 0.5,
                                    destinationIsAvatar: false,
                                    completed: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        
                                        if let (expandedStorySetIndicatorTransitionView, _) = self.headerNode.avatarListNode.listContainerNode.expandedStorySetIndicatorTransitionView {
                                            expandedStorySetIndicatorTransitionView.isHidden = false
                                        }
                                    }
                                )
                            }
                            
                            return nil
                        }
                        
                        let transitionView = self.headerNode.avatarListNode.avatarContainerNode.avatarNode.view
                        return StoryContainerScreen.TransitionOut(
                            destinationView: transitionView,
                            transitionView: StoryContainerScreen.TransitionView(
                                makeView: { [weak transitionView] in
                                    let parentView = UIView()
                                    if let copyView = transitionView?.snapshotContentTree(unhide: true) {
                                        parentView.addSubview(copyView)
                                    }
                                    return parentView
                                },
                                updateView: { copyView, state, transition in
                                    guard let view = copyView.subviews.first else {
                                        return
                                    }
                                    let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                    transition.setPosition(view: view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                                    transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                },
                                insertCloneTransitionView: nil
                            ),
                            destinationRect: transitionView.bounds,
                            destinationCornerRadius: transitionView.bounds.height * 0.5,
                            destinationIsAvatar: true,
                            completed: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.headerNode.avatarListNode.avatarContainerNode.avatarNode.isHidden = false
                            }
                        )
                    }
                )
                self.controller?.push(storyContainerScreen)
            })
            
            return
        }
    }
    
    private func openMessage(id: MessageId) -> Bool {
        guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return false
        }
        var foundGalleryMessage: Message?
        if let searchContentNode = self.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
            if let galleryMessage = searchContentNode.messageForGallery(id) {
                self.context.engine.messages.ensureMessagesAreLocallyAvailable(messages: [EngineMessage(galleryMessage)])
                foundGalleryMessage = galleryMessage
            }
        }
        if foundGalleryMessage == nil, let galleryMessage = self.paneContainerNode.findLoadedMessage(id: id) {
            foundGalleryMessage = galleryMessage
        }
        
        guard let galleryMessage = foundGalleryMessage else {
            return false
        }
        self.view.endEditing(true)
        
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, chatLocation: self.chatLocation, chatFilterTag: nil, chatLocationContextHolder: self.chatLocationContextHolder, message: galleryMessage, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, present: { [weak self] c, a, _ in
            self?.controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, transitionNode: { [weak self] messageId, media, _ in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.paneContainerNode.transitionNodeForGallery(messageId: messageId, media: media)
        }, addToTransitionSurface: { [weak self] view in
            guard let strongSelf = self else {
                return
            }
            strongSelf.paneContainerNode.currentPane?.node.addToTransitionSurface(view: view)
        }, openUrl: { [weak self] url in
            self?.openUrl(url: url, concealed: false, external: false)
        }, openPeer: { [weak self] peer, navigation in
            self?.openPeer(peerId: peer.id, navigation: navigation)
        }, callPeer: { peerId, isVideo in
        }, openConferenceCall: { _ in
        }, enqueueMessage: { _ in
        }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, actionInteraction: GalleryControllerActionInteraction(openUrl: { [weak self] url, concealed in
            if let strongSelf = self {
                strongSelf.openUrl(url: url, concealed: false, external: false)
            }
        }, openUrlIn: { [weak self] url in
            if let strongSelf = self {
                strongSelf.openUrlIn(url)
            }
        }, openPeerMention: { [weak self] mention in
            if let strongSelf = self {
                strongSelf.openPeerMention(mention)
            }
        }, openPeer: { [weak self] peer in
            if let strongSelf = self {
                strongSelf.openPeer(peerId: peer.id, navigation: .default)
            }
        }, openHashtag: { [weak self] peerName, hashtag in
            if let strongSelf = self {
                strongSelf.openHashtag(hashtag, peerName: peerName)
            }
        }, openBotCommand: { _ in
        }, openAd: { _ in
        }, addContact: { [weak self] phoneNumber in
            if let strongSelf = self {
                strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
                    self?.controller?.present(controller, in: .window(.root), with: arguments)
                }, pushController: { [weak self] controller in
                    if let strongSelf = self {
                        strongSelf.controller?.push(controller)
                    }
                }, completed: {})
            }
        }, storeMediaPlaybackState: { [weak self] messageId, timestamp, playbackRate in
            guard let strongSelf = self else {
                return
            }
            var storedState: MediaPlaybackStoredState?
            if let timestamp = timestamp {
                storedState = MediaPlaybackStoredState(timestamp: timestamp, playbackRate: AudioPlaybackRate(playbackRate))
            }
            let _ = updateMediaPlaybackStoredStateInteractively(engine: strongSelf.context.engine, messageId: messageId, state: storedState).startStandalone()
        }, editMedia: { [weak self] messageId, snapshots, transitionCompletion in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] message in
                guard let strongSelf = self, let message = message else {
                    return
                }
                
                var mediaReference: AnyMediaReference?
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        mediaReference = AnyMediaReference.standalone(media: image)
                    } else if let file = media as? TelegramMediaFile {
                        mediaReference = AnyMediaReference.standalone(media: file)
                    }
                }
                
                if let mediaReference = mediaReference, let peer = message.peers[message.id.peerId] {
                    legacyMediaEditor(context: strongSelf.context, peer: peer, threadTitle: message.associatedThreadInfo?.title, media: mediaReference, mode: .draw, initialCaption: NSAttributedString(), snapshots: snapshots, transitionCompletion: {
                        transitionCompletion()
                    }, getCaptionPanelView: {
                        return nil
                    }, sendMessagesWithSignals: { [weak self] signals, _, _, _ in
                        if let strongSelf = self {
                            strongSelf.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(context: strongSelf.context, account: strongSelf.context.account, signals: signals!)
                            |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
                                if let strongSelf = self {
                                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: strongSelf.peerId, messages: messages.map { $0.message }).startStandalone()
                                }
                            }))
                        }
                    }, present: { [weak self] c, a in
                        self?.controller?.present(c, in: .window(.root), with: a)
                    })
                }
            })
        }, updateCanReadHistory: { _ in
        }), centralItemUpdated: { [weak self] messageId in
            let _ = self?.paneContainerNode.requestExpandTabs?()
            self?.paneContainerNode.currentPane?.node.ensureMessageIsVisible(id: messageId)
        }))
    }
    
    private func openResolved(_ result: ResolvedUrl) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.openResolvedUrl(result, context: self.context, urlContext: .chat(peerId: self.peerId, message: nil, updatedPresentationData: self.controller?.updatedPresentationData), navigationController: navigationController, forceExternal: false, forceUpdate: false, openPeer: { [weak self] peer, navigation in
            guard let strongSelf = self else {
                return
            }
            switch navigation {
            case let .chat(inputState, subject, peekData):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), subject: subject, updateTextInputState: inputState, activateInput: inputState != nil ? .text : nil, keepStack: .always, peekData: peekData))
            case .info:
                if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                    if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        strongSelf.controller?.push(infoController)
                    }
                }
            case let .withBotStartPayload(startPayload):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), botStart: startPayload, keepStack: .always))
            case let .withAttachBot(attachBotStart):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
            case let .withBotApp(botAppStart):
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), botAppStart: botAppStart))
            default:
                break
            }
        },
        sendFile: nil,
        sendSticker: nil,
        sendEmoji: nil,
        requestMessageActionUrlAuth: nil,
        joinVoiceChat: { peerId, invite, call in
            
        }, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, contentContext: nil, progress: nil, completion: nil)
    }
    
    private func openUrl(url: String, concealed: Bool, external: Bool, forceExternal: Bool = false, commit: @escaping () -> Void = {}) {
        let _ = openUserGeneratedUrl(context: self.context, peerId: self.peerId, url: url, concealed: concealed, present: { [weak self] c in
            self?.controller?.present(c, in: .window(.root))
        }, openResolved: { [weak self] tempResolved in
            guard let strongSelf = self else {
                return
            }
            
            let result: ResolvedUrl = external ? .externalUrl(url) : tempResolved
            
            strongSelf.context.sharedContext.openResolvedUrl(result, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.controller?.navigationController as? NavigationController, forceExternal: forceExternal, forceUpdate: false, openPeer: { peer, navigation in
                self?.openPeer(peerId: peer.id, navigation: navigation)
                commit()
            }, sendFile: nil,
            sendSticker: nil,
            sendEmoji: nil,
            requestMessageActionUrlAuth: nil,
            joinVoiceChat: { peerId, invite, call in
                
            },
            present: { c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, dismissInput: {
                self?.view.endEditing(true)
            }, contentContext: nil, progress: nil, completion: nil)
        })
    }
    
    private func openUrlIn(_ url: String) {
        let actionSheet = OpenInActionSheetController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, item: .url(url: url), openUrl: { [weak self] url in
            if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.presentationData, navigationController: navigationController, dismissInput: {
                })
            }
        })
        self.controller?.present(actionSheet, in: .window(.root))
    }
    
    private func openPeer(peerId: PeerId, navigation: ChatControllerInteractionNavigateToPeer) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        PeerInfoScreenImpl.openPeer(context: self.context, peerId: peerId, navigation: navigation, navigationController: navigationController)
    }
        
    private func openPeerMention(_ name: String, navigation: ChatControllerInteractionNavigateToPeer = .default) {
        let disposable: MetaDisposable
        if let resolvePeerByNameDisposable = self.resolvePeerByNameDisposable {
            disposable = resolvePeerByNameDisposable
        } else {
            disposable = MetaDisposable()
            self.resolvePeerByNameDisposable = disposable
        }
        var resolveSignal = self.context.engine.peers.resolvePeerByName(name: name, referrer: nil, ageLimit: 10)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))
            self?.controller?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        resolveSignal = resolveSignal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = { [weak self] in
            self?.resolvePeerByNameDisposable?.set(nil)
        }
        disposable.set((resolveSignal
        |> take(1)
        |> mapToSignal { peer -> Signal<Peer?, NoError> in
            return .single(peer?._asPeer())
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                if let peer = peer {
                    var navigation = navigation
                    if case .default = navigation {
                        if let peer = peer as? TelegramUser, peer.botInfo != nil {
                            navigation = .chat(textInputState: nil, subject: nil, peekData: nil)
                        }
                    }
                    strongSelf.openResolved(.peer(peer, navigation))
                } else {
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }))
    }
    
    private func openHashtag(_ hashtag: String, peerName: String?) {
        if self.resolvePeerByNameDisposable == nil {
            self.resolvePeerByNameDisposable = MetaDisposable()
        }
        var resolveSignal: Signal<Peer?, NoError>
        if let peerName = peerName {
            resolveSignal = self.context.engine.peers.resolvePeerByName(name: peerName, referrer: nil)
            |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                guard case let .result(result) = result else {
                    return .complete()
                }
                return .single(result)
            }
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                return .single(peer?._asPeer())
            }
        } else {
            resolveSignal = self.context.account.postbox.loadedPeerWithId(self.peerId)
            |> map(Optional.init)
        }
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                cancelImpl?()
            }))
            self?.controller?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        resolveSignal = resolveSignal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = { [weak self] in
            self?.resolvePeerByNameDisposable?.set(nil)
        }
        self.resolvePeerByNameDisposable?.set((resolveSignal
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self, !hashtag.isEmpty {
                let searchController = HashtagSearchController(context: strongSelf.context, peer: peer.flatMap(EnginePeer.init), query: hashtag)
                strongSelf.controller?.push(searchController)
            }
        }))
    }
    
    private func openBotApp(_ bot: AttachMenuBot) {
        guard let controller = self.controller else {
            return
        }
        
        if let navigationController = controller.navigationController as? NavigationController, let minimizedContainer = navigationController.minimizedContainer {
            for controller in minimizedContainer.controllers {
                if let controller = controller as? AttachmentController, let mainController = controller.mainController as? WebAppController, mainController.botId == bot.peer.id && mainController.source == .settings {
                    navigationController.maximizeViewController(controller, animated: true)
                    return
                }
            }
        }
        
        var appSettings: BotAppSettings?
        if let settings = self.data?.cachedData as? CachedUserData {
            appSettings = settings.botInfo?.appSettings
        }
        
        let presentationData = self.presentationData
        let proceed: (Bool) -> Void = { [weak self] installed in
            guard let self else {
                return
            }
            let context = self.context
            let peerId = self.peerId
            let params = WebAppParameters(source: .settings, peerId: self.context.account.peerId, botId: bot.peer.id, botName: bot.peer.compactDisplayTitle, botVerified: bot.peer.isVerified, botAddress: bot.peer.addressName ?? "", appName: "", url: nil, queryId: nil, payload: nil, buttonText: nil, keepAliveSignal: nil, forceHasSettings: bot.flags.contains(.hasSettings), fullSize: true, appSettings: appSettings)
            
            var openUrlImpl: ((String, Bool, Bool, @escaping () -> Void) -> Void)?
            var presentImpl: ((ViewController, Any?) -> Void)?
            
            let controller = standaloneWebAppController(context: context, updatedPresentationData: self.controller?.updatedPresentationData, params: params, threadId: nil, openUrl: { url, concealed, forceUpdate, commit in
               openUrlImpl?(url, concealed, forceUpdate, commit)
            }, requestSwitchInline: { _, _, _ in
            }, getNavigationController: { [weak self] in
                return (self?.controller?.navigationController as? NavigationController) ?? context.sharedContext.mainWindow?.viewController as? NavigationController
            })
            controller.navigationPresentation = .flatModal
            self.controller?.push(controller)
            
            openUrlImpl = { [weak self, weak controller] url, concealed, forceUpdate, commit in
                let _ = openUserGeneratedUrl(context: context, peerId: peerId, url: url, concealed: concealed, present: { [weak self] c in
                    self?.controller?.present(c, in: .window(.root))
                }, openResolved: { result in
                    var navigationController: NavigationController?
                    if let current = self?.controller?.navigationController as? NavigationController {
                        navigationController = current
                    } else if let current = controller?.navigationController as? NavigationController {
                        navigationController = current
                    }
                    context.sharedContext.openResolvedUrl(result, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, forceUpdate: forceUpdate, openPeer: { peer, navigation in
                        if let navigationController {
                            PeerInfoScreenImpl.openPeer(context: context, peerId: peer.id, navigation: navigation, navigationController: navigationController)
                        }
                        commit()
                    }, sendFile: nil,
                    sendSticker: nil,
                    sendEmoji: nil,
                    requestMessageActionUrlAuth: nil,
                    joinVoiceChat: { peerId, invite, call in
                        
                    },
                    present: { c, a in
                        presentImpl?(c, a)
                    }, dismissInput: {
                        context.sharedContext.mainWindow?.viewController?.view.endEditing(false)
                    }, contentContext: nil, progress: nil, completion: nil)
                })
            }
            presentImpl = { [weak controller] c, a in
                controller?.present(c, in: .window(.root), with: a)
            }
            
            if installed {
                Queue.mainQueue().after(0.3, {
                    let text: String
                    if bot.flags.contains(.showInSettings) {
                        text = presentationData.strings.WebApp_ShortcutsSettingsAdded(bot.peer.compactDisplayTitle).string
                    } else {
                        text = presentationData.strings.WebApp_ShortcutsAdded(bot.peer.compactDisplayTitle).string
                    }
                    controller.present(
                        UndoOverlayController(presentationData: presentationData, content: .succeed(text: text, timeout: 5.0, customUndoText: nil), elevatedLayout: false, position: .top, action: { _ in return false }),
                        in: .current
                    )
                })
            }
        }
        
        if bot.flags.contains(.notActivated) || bot.flags.contains(.showInSettingsDisclaimer) {
            let alertController = webAppTermsAlertController(context: self.context, updatedPresentationData: controller.updatedPresentationData, bot: bot, completion: { [weak self] allowWrite in
                guard let self else {
                    return
                }
                let showInstalledTooltip = !bot.flags.contains(.showInSettingsDisclaimer)
                if bot.flags.contains(.showInSettingsDisclaimer) {
                    let _ = self.context.engine.messages.acceptAttachMenuBotDisclaimer(botId: bot.peer.id).startStandalone()
                }
                if bot.flags.contains(.notActivated) {
                    let _ = (self.context.engine.messages.addBotToAttachMenu(botId: bot.peer.id, allowWrite: allowWrite)
                    |> deliverOnMainQueue).startStandalone(error: { _ in
                    }, completed: {
                        proceed(showInstalledTooltip)
                    })
                } else {
                    proceed(false)
                }
            })
            controller.present(alertController, in: .window(.root))
        } else {
            proceed(false)
        }
    }
    
    private func performButtonAction(key: PeerInfoHeaderButtonKey, gesture: ContextGesture?) {
        guard let controller = self.controller else {
            return
        }
        switch key {
        case .message:
            if let navigationController = controller.navigationController as? NavigationController, let peer = self.data?.peer {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
                    if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                        var viewControllers = navigationController.viewControllers
                        viewControllers = viewControllers.filter { controller in
                            if controller is PeerInfoScreen {
                                return false
                            }
                            return true
                        }
                        navigationController.setViewControllers(viewControllers, animated: false)
                    }
                }))
            }
        case .discussion:
            if let cachedData = self.data?.cachedData as? CachedChannelData, case let .known(maybeLinkedDiscussionPeerId) = cachedData.linkedDiscussionPeerId, let linkedDiscussionPeerId = maybeLinkedDiscussionPeerId {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: linkedDiscussionPeerId))
                |> deliverOnMainQueue).startStandalone(next: { [weak self] linkedDiscussionPeer in
                    guard let self, let linkedDiscussionPeer else {
                        return
                    }
                    if let navigationController = controller.navigationController as? NavigationController {
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(linkedDiscussionPeer)))
                    }
                })
            }
        case .call:
            self.requestCall(isVideo: false)
        case .videoCall:
            self.requestCall(isVideo: true)
        case .voiceChat:
            self.requestCall(isVideo: false, gesture: gesture)
        case .mute:
            var displayCustomNotificationSettings = false
                        
            let chatIsMuted = peerInfoIsChatMuted(peer: self.data?.peer, peerNotificationSettings: self.data?.peerNotificationSettings, threadNotificationSettings: self.data?.threadNotificationSettings, globalNotificationSettings: self.data?.globalNotificationSettings)
            if chatIsMuted {
            } else {
                displayCustomNotificationSettings = true
            }
            if self.data?.threadData == nil, let channel = self.data?.peer as? TelegramChannel, channel.isForumOrMonoForum {
                displayCustomNotificationSettings = true
            }
            
            let peerId = self.data?.peer?.id ?? self.peerId
            
            if !displayCustomNotificationSettings {
                let _ = self.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: self.chatLocation.threadId, muteInterval: 0).startStandalone()
                
                let iconColor: UIColor = .white
                self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                        "Middle.Group 1.Fill 1": iconColor,
                        "Top.Group 1.Fill 1": iconColor,
                        "Bottom.Group 1.Fill 1": iconColor,
                        "EXAMPLE.Group 1.Fill 1": iconColor,
                        "Line.Group 1.Stroke 1": iconColor
                ], title: nil, text: self.presentationData.strings.PeerInfo_TooltipUnmuted, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            } else {
                self.state = self.state.withHighlightedButton(.mute)
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
                
                var items: [ContextMenuItem] = []
                
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_MuteFor, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Mute2d"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    guard let strongSelf = self else {
                        return
                    }
                    var subItems: [ContextMenuItem] = []
                    
                    subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                    }, iconPosition: .left, action: { c, _ in
                        c?.popItems()
                    })))
                    subItems.append(.separator)
                    
                    let presetValues: [Int32] = [
                        1 * 60 * 60,
                        8 * 60 * 60,
                        1 * 24 * 60 * 60,
                        7 * 24 * 60 * 60
                    ]
                    
                    for value in presetValues {
                        subItems.append(.action(ContextMenuActionItem(text: muteForIntervalString(strings: strongSelf.presentationData.strings, value: value), icon: { _ in
                            return nil
                        }, action: { _, f in
                            f(.default)
                            
                            let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: strongSelf.chatLocation.threadId, muteInterval: value).startStandalone()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_mute_for", scale: 0.066, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedFor(mutedForTimeIntervalString(strings: strongSelf.presentationData.strings, value: value)).string, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    }
                    
                    subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_MuteForCustom, icon: { _ in
                        return nil
                    }, action: { _, f in
                        f(.default)
                        
                        self?.openCustomMute()
                    })))
                    
                    c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                })))
                
                items.append(.separator)
                
                var isSoundEnabled = true
                let notificationSettings = self.data?.threadNotificationSettings ?? self.data?.peerNotificationSettings
                if let notificationSettings {
                    switch notificationSettings.messageSound {
                    case .none:
                        isSoundEnabled = false
                    default:
                        break
                    }
                }
                
                if !chatIsMuted {
                    if !isSoundEnabled {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_EnableSound, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOn"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: strongSelf.chatLocation.threadId, sound: .default).startStandalone()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_sound_on", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipSoundEnabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    } else {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_DisableSound, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOff"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                            
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: strongSelf.chatLocation.threadId, sound: .none).startStandalone()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_sound_off", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipSoundDisabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    }
                }
                
                let context = self.context
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_NotificationsCustomize, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Customize"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    let _ = (context.engine.data.get(
                        TelegramEngine.EngineData.Item.NotificationSettings.Global()
                    )
                    |> deliverOnMainQueue).startStandalone(next: { globalSettings in
                        guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                            return
                        }
                        let threadId = strongSelf.chatLocation.threadId
                        
                        let context = strongSelf.context
                        let updatePeerSound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
                            return context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: sound) |> deliverOnMainQueue
                        }
                        
                        let updatePeerNotificationInterval: (PeerId, Int32?) -> Signal<Void, NoError> = { peerId, muteInterval in
                            return context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: muteInterval) |> deliverOnMainQueue
                        }
                        
                        let updatePeerDisplayPreviews: (PeerId, PeerNotificationDisplayPreviews) -> Signal<Void, NoError> = {
                            peerId, displayPreviews in
                            return context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, threadId: threadId, displayPreviews: displayPreviews) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStoriesMuted: (PeerId, PeerStoryNotificationSettings.Mute) -> Signal<Void, NoError> = {
                            peerId, mute in
                            return context.engine.peers.updatePeerStoriesMutedSetting(peerId: peerId, mute: mute) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStoriesHideSender: (PeerId, PeerStoryNotificationSettings.HideSender) -> Signal<Void, NoError> = {
                            peerId, hideSender in
                            return context.engine.peers.updatePeerStoriesHideSenderSetting(peerId: peerId, hideSender: hideSender) |> deliverOnMainQueue
                        }
                        
                        let updatePeerStorySound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
                            return context.engine.peers.updatePeerStorySoundInteractive(peerId: peerId, sound: sound) |> deliverOnMainQueue
                        }
                        
                        let mode: NotificationExceptionMode
                        let defaultSound: PeerMessageSound
                        if let _ = peer as? TelegramUser {
                            mode = .users([:])
                            defaultSound = globalSettings.privateChats.sound._asMessageSound()
                        } else if let _ = peer as? TelegramSecretChat {
                            mode = .users([:])
                            defaultSound = globalSettings.privateChats.sound._asMessageSound()
                        } else if let channel = peer as? TelegramChannel {
                            if case .broadcast = channel.info {
                                mode = .channels([:])
                                defaultSound = globalSettings.channels.sound._asMessageSound()
                            } else {
                                mode = .groups([:])
                                defaultSound = globalSettings.groupChats.sound._asMessageSound()
                            }
                        } else {
                            mode = .groups([:])
                            defaultSound = globalSettings.groupChats.sound._asMessageSound()
                        }
                        let _ = mode
                        
                        let canRemove = false
                        
                        let exceptionController = notificationPeerExceptionController(context: context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, peer: EnginePeer(peer), threadId: threadId, isStories: nil, canRemove: canRemove, defaultSound: defaultSound, defaultStoriesSound: globalSettings.privateChats.storySettings.sound, edit: true, updatePeerSound: { peerId, sound in
                            let _ = (updatePeerSound(peer.id, sound)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                            })
                        }, updatePeerNotificationInterval: { peerId, muteInterval in
                            let _ = (updatePeerNotificationInterval(peerId, muteInterval)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let muteInterval = muteInterval, muteInterval == Int32.max {
                                    let iconColor: UIColor = .white
                                    strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                                        "Middle.Group 1.Fill 1": iconColor,
                                        "Top.Group 1.Fill 1": iconColor,
                                        "Bottom.Group 1.Fill 1": iconColor,
                                        "EXAMPLE.Group 1.Fill 1": iconColor,
                                        "Line.Group 1.Stroke 1": iconColor
                                    ], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                }
                            })
                        }, updatePeerDisplayPreviews: { peerId, displayPreviews in
                            let _ = (updatePeerDisplayPreviews(peerId, displayPreviews)
                            |> deliverOnMainQueue).startStandalone(next: { _ in
                                
                            })
                        }, updatePeerStoriesMuted: { peerId, mute in
                            let _ = (updatePeerStoriesMuted(peerId, mute)
                            |> deliverOnMainQueue).startStandalone()
                        }, updatePeerStoriesHideSender: { peerId, hideSender in
                            let _ = (updatePeerStoriesHideSender(peerId, hideSender)
                            |> deliverOnMainQueue).startStandalone()
                        }, updatePeerStorySound: { peerId, sound in
                            let _ = (updatePeerStorySound(peer.id, sound)
                            |> deliverOnMainQueue).startStandalone()
                        }, removePeerFromExceptions: {
                        }, modifiedPeer: {
                        })
                        exceptionController.navigationPresentation = .modal
                        controller.push(exceptionController)
                    })
                })))
                
                if chatIsMuted {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_ButtonUnmute, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unmute"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        
                        let _ = self.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: self.chatLocation.threadId, muteInterval: 0).startStandalone()
                        
                        let iconColor: UIColor = .white
                        self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                                "Middle.Group 1.Fill 1": iconColor,
                                "Top.Group 1.Fill 1": iconColor,
                                "Bottom.Group 1.Fill 1": iconColor,
                                "EXAMPLE.Group 1.Fill 1": iconColor,
                                "Line.Group 1.Stroke 1": iconColor
                        ], title: nil, text: self.presentationData.strings.PeerInfo_TooltipUnmuted, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                } else {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_MuteForever, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Muted"), color: theme.contextMenu.destructiveColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: strongSelf.chatLocation.threadId, muteInterval: Int32.max).startStandalone()
                        
                        let iconColor: UIColor = .white
                        strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                            "Middle.Group 1.Fill 1": iconColor,
                            "Top.Group 1.Fill 1": iconColor,
                            "Bottom.Group 1.Fill 1": iconColor,
                            "EXAMPLE.Group 1.Fill 1": iconColor,
                            "Line.Group 1.Stroke 1": iconColor
                        ], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                }
                
                var tip: ContextController.Tip?
                tip = nil
                if !self.forumTopicNotificationExceptions.isEmpty {
                    items.append(.separator)
                    
                    let text: String = self.presentationData.strings.PeerInfo_TopicNotificationExceptions(Int32(self.forumTopicNotificationExceptions.count))
                    
                    items.append(.action(ContextMenuActionItem(
                        text: text,
                        textLayout: .multiline,
                        textFont: .small,
                        parseMarkdown: true,
                        badge: nil,
                        icon: { _ in
                            return nil
                        },
                        action: { [weak self] _, f in
                            guard let self else {
                                return
                            }
                            f(.default)
                            self.controller?.push(threadNotificationExceptionsScreen(context: self.context, peerId: self.peerId, notificationExceptions: self.forumTopicNotificationExceptions, updated: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                self.forumTopicNotificationExceptions = value
                            }))
                        }
                    )))
                }
                
                self.view.endEditing(true)
                
                if let sourceNode = self.headerNode.buttonNodes[.mute]?.referenceNode {
                    let contextController = ContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items), tip: tip)), gesture: gesture)
                    contextController.dismissed = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.state = strongSelf.state.withHighlightedButton(nil)
                            if let (layout, navigationHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                            }
                        }
                    }
                    controller.presentInGlobalOverlay(contextController)
                }
            }
        case .more:
            guard let data = self.data, let peer = data.peer, let chatPeer = data.chatPeer else {
                return
            }
            let presentationData = self.presentationData
            self.state = self.state.withHighlightedButton(.more)
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
            
            var mainItemsImpl: (() -> Signal<[ContextMenuItem], NoError>)?
            mainItemsImpl = { [weak self] in
                var items: [ContextMenuItem] = []
                guard let strongSelf = self else {
                    return .single(items)
                }
                
                let allHeaderButtons = Set(peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: strongSelf.isOpenedFromChat, isExpanded: false, videoCallsEnabled: strongSelf.videoCallsEnabled, isSecretChat: strongSelf.peerId.namespace == Namespaces.Peer.SecretChat, isContact: strongSelf.data?.isContact ?? false, threadInfo: data.threadData?.info))
                let headerButtons = Set(peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: strongSelf.isOpenedFromChat, isExpanded: true, videoCallsEnabled: strongSelf.videoCallsEnabled, isSecretChat: strongSelf.peerId.namespace == Namespaces.Peer.SecretChat, isContact: strongSelf.data?.isContact ?? false, threadInfo: strongSelf.data?.threadData?.info))
                
                let filteredButtons = allHeaderButtons.subtracting(headerButtons)
                
                var currentAutoremoveTimeout: Int32?
                if let cachedData = data.cachedData as? CachedUserData {
                    switch cachedData.autoremoveTimeout {
                    case let .known(value):
                        currentAutoremoveTimeout = value?.peerValue
                    case .unknown:
                        break
                    }
                } else if let cachedData = data.cachedData as? CachedGroupData {
                    switch cachedData.autoremoveTimeout {
                    case let .known(value):
                        currentAutoremoveTimeout = value?.peerValue
                    case .unknown:
                        break
                    }
                } else if let cachedData = data.cachedData as? CachedChannelData {
                    switch cachedData.autoremoveTimeout {
                    case let .known(value):
                        currentAutoremoveTimeout = value?.peerValue
                    case .unknown:
                        break
                    }
                }
                
                var canSetupAutoremoveTimeout = false
                
                if let secretChat = chatPeer as? TelegramSecretChat {
                    currentAutoremoveTimeout = secretChat.messageAutoremoveTimeout
                    canSetupAutoremoveTimeout = false
                } else if let group = chatPeer as? TelegramGroup {
                    if !group.hasBannedPermission(.banChangeInfo) {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let user = chatPeer as? TelegramUser {
                    if user.id != strongSelf.context.account.peerId {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let channel = chatPeer as? TelegramChannel {
                    if channel.hasPermission(.changeInfo) {
                        canSetupAutoremoveTimeout = true
                    }
                }
                            
                if filteredButtons.contains(.call) {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_ButtonCall, icon: { theme in
                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        self?.requestCall(isVideo: false)
                    })))
                }
                if filteredButtons.contains(.search) {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChatSearch_SearchPlaceholder, icon: { theme in
                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Search"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        self?.openChatWithMessageSearch()
                    })))
                }
                
                if let user = peer as? TelegramUser {
                    if user.botInfo == nil && strongSelf.data?.encryptionKeyFingerprint == nil && !user.isDeleted {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_ChangeWallpaper, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openChatForThemeChange()
                        })))
                    }
                                        
                    if let _ = user.botInfo {
                        if user.addressName != nil {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_ShareBot, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                self?.openShareBot()
                            })))
                        }
                        
                        var addedPrivacy = false
                        var privacyPolicyUrl: String?
                        if let cachedData = (data.cachedData as? CachedUserData), let botInfo = cachedData.botInfo {
                            if let url = botInfo.privacyPolicyUrl {
                                privacyPolicyUrl = url
                            } else if botInfo.commands.contains(where: { $0.text == "privacy" }) {
                                
                            } else {
                                privacyPolicyUrl = presentationData.strings.WebApp_PrivacyPolicy_URL
                            }
                        }
                        if let privacyPolicyUrl {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotPrivacy, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: privacyPolicyUrl, forceExternal: false, presentationData: self.presentationData, navigationController: self.controller?.navigationController as? NavigationController, dismissInput: {})
                            })))
                            addedPrivacy = true
                        }
                        if let cachedData = data.cachedData as? CachedUserData, let botInfo = cachedData.botInfo {
                            for command in botInfo.commands {
                                if command.text == "settings" {
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotSettings, icon: { theme in
                                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
                                    }, action: { [weak self] _, f in
                                        f(.dismissWithoutContent)
                                        self?.performBotCommand(command: .settings)
                                    })))
                                } else if command.text == "help" {
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotHelp, icon: { theme in
                                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Help"), color: theme.contextMenu.primaryColor)
                                    }, action: { [weak self] _, f in
                                        f(.dismissWithoutContent)
                                        self?.performBotCommand(command: .help)
                                    })))
                                } else if command.text == "privacy" && !addedPrivacy {
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_BotPrivacy, icon: { theme in
                                        generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor)
                                    }, action: { [weak self] _, f in
                                        f(.dismissWithoutContent)
                                        self?.performBotCommand(command: .privacy)
                                    })))
                                }
                            }
                        }
                    }
                    
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser && user.botInfo == nil && !user.flags.contains(.isSupport) {
                        if let cachedUserData = strongSelf.data?.cachedData as? CachedUserData, let _ = cachedUserData.sendPaidMessageStars {
                            
                        } else {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_StartSecretChat, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Lock"), color: theme.contextMenu.primaryColor)
                            }, action: { _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openStartSecretChat()
                            })))
                        }
                    }
                    
                    if user.botInfo == nil && data.isContact, let peer = strongSelf.data?.peer as? TelegramUser, let phone = peer.phone {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Profile_ShareContactButton, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self {
                                let contact = TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)
                                let shareController = ShareController(context: strongSelf.context, subject: .media(.standalone(media: contact), nil), updatedPresentationData: strongSelf.controller?.updatedPresentationData)
                                shareController.completed = { [weak self] peerIds in
                                    if let strongSelf = self {
                                        let _ = (strongSelf.context.engine.data.get(
                                            EngineDataList(
                                                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                            )
                                        )
                                        |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            
                                            let peers = peerList.compactMap { $0 }
                                            
                                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                            
                                            let text: String
                                            var savedMessages = false
                                            if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                                text = presentationData.strings.UserInfo_ContactForwardTooltip_SavedMessages_One
                                                savedMessages = true
                                            } else {
                                                if peers.count == 1, let peer = peers.first {
                                                    let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    text = presentationData.strings.UserInfo_ContactForwardTooltip_Chat_One(peerName).string
                                                } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                                    let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    text = presentationData.strings.UserInfo_ContactForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                                } else if let peer = peers.first {
                                                    let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                    text = presentationData.strings.UserInfo_ContactForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                                } else {
                                                    text = ""
                                                }
                                            }
                                            
                                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                                                if savedMessages, let self, action == .info {
                                                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                                                        guard let self, let peer else {
                                                            return
                                                        }
                                                        guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                                            return
                                                        }
                                                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                                                    })
                                                }
                                                return false
                                            }), in: .current)
                                        })
                                    }
                                }
                                strongSelf.controller?.present(shareController, in: .window(.root))
                            }
                        })))
                    }
                    
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser, !user.isDeleted && user.botInfo == nil && !user.flags.contains(.isSupport) {
                        if let cachedData = data.cachedData as? CachedUserData, cachedData.disallowedGifts == .All {
                        } else {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Profile_SendGift, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Gift"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                if let self {
                                    self.openPremiumGift()
                                }
                            })))
                        }
                    }
                    
                    if let cachedData = data.cachedData as? CachedUserData, cachedData.flags.contains(.translationHidden) {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self {
                                let _ = updateChatTranslationStateInteractively(engine: strongSelf.context.engine, peerId: strongSelf.peerId, threadId: nil, { current in
                                    return current?.withIsEnabled(true)
                                }).startStandalone()
                                
                                Queue.mainQueue().after(0.2, {
                                    let _ = (strongSelf.context.engine.messages.togglePeerMessagesTranslationHidden(peerId: strongSelf.peerId, hidden: false)
                                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                        self?.openChatForTranslation()
                                    })
                                })
                            }
                        })))
                    }
                    
                    let itemsCount = items.count
                                        
                    if canSetupAutoremoveTimeout {
                        let strings = strongSelf.presentationData.strings
                        items.append(.action(ContextMenuActionItem(text: currentAutoremoveTimeout == nil ? strongSelf.presentationData.strings.PeerInfo_EnableAutoDelete : strongSelf.presentationData.strings.PeerInfo_AdjustAutoDelete, icon: { theme in
                            if let currentAutoremoveTimeout = currentAutoremoveTimeout {
                                let text = NSAttributedString(string: shortTimeIntervalString(strings: strings, value: currentAutoremoveTimeout), font: Font.regular(14.0), textColor: theme.contextMenu.primaryColor)
                                let bounds = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                                return generateImage(bounds.size.integralFloor, rotatedContext: { size, context in
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    UIGraphicsPushContext(context)
                                    text.draw(in: bounds)
                                    UIGraphicsPopContext()
                                })
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Timer"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] c, _ in
                            var subItems: [ContextMenuItem] = []
                            
                            subItems.append(.action(ContextMenuActionItem(text: strings.Common_Back, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                            }, iconPosition: .left, action: { c, _ in
                                c?.popItems()
                            })))
                            subItems.append(.separator)
                            
                            let presetValues: [Int32] = [
                                1 * 24 * 60 * 60,
                                7 * 24 * 60 * 60,
                                31 * 24 * 60 * 60
                            ]
                            
                            for value in presetValues {
                                subItems.append(.action(ContextMenuActionItem(text: timeIntervalString(strings: strings, value: value), icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: value)
                                })))
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteSettingOther, icon: { _ in
                                return nil
                            }, action: { _, f in
                                f(.default)
                                
                                self?.openAutoremove(currentValue: currentAutoremoveTimeout)
                            })))
                            
                            if let _ = currentAutoremoveTimeout {
                                subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteDisable, textColor: .destructive, icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: nil)
                                })))
                            }
                            
                            subItems.append(.separator)
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteInfo + "\n\n" + strongSelf.presentationData.strings.AutoremoveSetup_AdditionalGlobalSettingsInfo, textLayout: .multiline, textFont: .small, parseMarkdown: true, icon: { _ in
                                return nil
                            }, textLinkAction: { [weak c] in
                                c?.dismiss(completion: nil)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openResolvedUrl(.settings(.autoremoveMessages), context: self.context, urlContext: .generic, navigationController: self.controller?.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { _, _ in }, dismissInput: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.controller?.view.endEditing(true)
                                }, contentContext: nil, progress: nil, completion: nil)
                            }, action: nil as ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
                            
                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: user, chatPeer: chatPeer, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            if let c {
                                self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: user, chatPeer: user)
                            }
                        })))
                    }
                    
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser && user.botInfo == nil && !user.flags.contains(.isSupport) {
                        if data.isContact {
                            if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                            } else {
                                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_BlockUser, textColor: .destructive, icon: { theme in
                                    generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.destructiveColor)
                                }, action: { _, f in
                                    f(.dismissWithoutContent)
                                    
                                    self?.updateBlocked(block: true)
                                })))
                            }
                        }
                    } else if strongSelf.peerId.namespace == Namespaces.Peer.SecretChat && data.isContact {
                        if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                        } else {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_BlockUser, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.updateBlocked(block: true)
                            })))
                        }
                    }
                    
                    let finalItemsCount = items.count
                    
                    if finalItemsCount > itemsCount {
                        items.insert(.separator, at: itemsCount)
                    }
                } else if let channel = peer as? TelegramChannel {
                    if let cachedData = strongSelf.data?.cachedData as? CachedChannelData {
                        if case .broadcast = channel.info, cachedData.flags.contains(.starGiftsAvailable) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Profile_SendGift, badge: nil, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Gift"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openPremiumGift()
                            })))
                        }
                        
                        let boostTitle: String
                        switch channel.info {
                        case .group:
                            boostTitle = presentationData.strings.PeerInfo_Group_Boost
                        case .broadcast:
                            boostTitle = presentationData.strings.PeerInfo_Channel_Boost
                        }
                        items.append(.action(ContextMenuActionItem(text: boostTitle, badge: nil, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Boost"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openBoost()
                        })))
                                                
                        if channel.hasPermission(.editStories) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_Channel_ArchivedStories, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Archive"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openStoryArchive()
                            })))
                        }
                        if cachedData.flags.contains(.canViewStats) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChannelInfo_Stats, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openStats(section: .stats)
                            })))
                        }
                        if cachedData.flags.contains(.translationHidden) {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                if let strongSelf = self {
                                    let _ = updateChatTranslationStateInteractively(engine: strongSelf.context.engine, peerId: strongSelf.peerId, threadId: nil, { current in
                                        return current?.withIsEnabled(true)
                                    }).startStandalone()
                                    
                                    Queue.mainQueue().after(0.2, {
                                        let _ = (strongSelf.context.engine.messages.togglePeerMessagesTranslationHidden(peerId: strongSelf.peerId, hidden: false)
                                        |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                            self?.openChatForTranslation()
                                        })
                                    })
                                }
                            })))
                        }
                    }
                    
                    var canReport = true
                    if channel.adminRights != nil {
                        canReport = false
                    }
                    if channel.flags.contains(.isCreator) {
                        canReport = false
                    }
                    if canReport {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.ReportPeer_Report, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] c, f in
                            self?.openReport(type: .default, contextController: c, backAction: { c in
                                if let mainItemsImpl = mainItemsImpl {
                                    c.setItems(mainItemsImpl() |> map { ContextController.Items(content: .list($0)) }, minHeight: nil, animated: true)
                                }
                            })
                        })))
                    }
                    
                    if canSetupAutoremoveTimeout {
                        let strings = strongSelf.presentationData.strings
                        items.append(.action(ContextMenuActionItem(text: currentAutoremoveTimeout == nil ? strongSelf.presentationData.strings.PeerInfo_EnableAutoDelete : strongSelf.presentationData.strings.PeerInfo_AdjustAutoDelete, icon: { theme in
                            if let currentAutoremoveTimeout = currentAutoremoveTimeout {
                                let text = NSAttributedString(string: shortTimeIntervalString(strings: strings, value: currentAutoremoveTimeout), font: Font.regular(14.0), textColor: theme.contextMenu.primaryColor)
                                let bounds = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                                return generateImage(bounds.size.integralFloor, rotatedContext: { size, context in
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    UIGraphicsPushContext(context)
                                    text.draw(in: bounds)
                                    UIGraphicsPopContext()
                                })
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Timer"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] c, _ in
                            var subItems: [ContextMenuItem] = []
                            
                            subItems.append(.action(ContextMenuActionItem(text: strings.Common_Back, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                            }, iconPosition: .left, action: { c, _ in
                                c?.popItems()
                            })))
                            subItems.append(.separator)
                            
                            let presetValues: [Int32] = [
                                1 * 24 * 60 * 60,
                                7 * 24 * 60 * 60,
                                31 * 24 * 60 * 60
                            ]
                            
                            for value in presetValues {
                                subItems.append(.action(ContextMenuActionItem(text: timeIntervalString(strings: strings, value: value), icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: value)
                                })))
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteSettingOther, icon: { _ in
                                return nil
                            }, action: { _, f in
                                f(.default)
                                
                                self?.openAutoremove(currentValue: currentAutoremoveTimeout)
                            })))
                            
                            if let _ = currentAutoremoveTimeout {
                                subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteDisable, textColor: .destructive, icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: nil)
                                })))
                            }
                            
                            subItems.append(.separator)
                            
                            let baseText: String
                            if case .broadcast = channel.info {
                                baseText = strongSelf.presentationData.strings.PeerInfo_ChannelAutoDeleteInfo
                            } else {
                                baseText = strongSelf.presentationData.strings.PeerInfo_AutoDeleteInfo
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: baseText + "\n\n" + strongSelf.presentationData.strings.AutoremoveSetup_AdditionalGlobalSettingsInfo, textLayout: .multiline, textFont: .small, parseMarkdown: true, icon: { _ in
                                return nil
                            }, textLinkAction: { [weak c] in
                                c?.dismiss(completion: nil)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openResolvedUrl(.settings(.autoremoveMessages), context: self.context, urlContext: .generic, navigationController: self.controller?.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { _, _ in }, dismissInput: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.controller?.view.endEditing(true)
                                }, contentContext: nil, progress: nil, completion: nil)
                            }, action: nil as ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
                            
                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: channel, chatPeer: channel, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            if let c {
                                self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: channel, chatPeer: channel)
                            }
                        })))
                    }
                    
                    switch channel.info {
                    case .broadcast:
                        if case .member = channel.participationStatus, !headerButtons.contains(.leave) {
                            if !items.isEmpty {
                                items.append(.separator)
                            }
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Channel_LeaveChannel, textColor: .destructive, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.destructiveColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openLeavePeer(delete: false)
                            })))
                        }
                    case .group:
                        if case .member = channel.participationStatus, !headerButtons.contains(.leave) {
                            if !items.isEmpty {
                                items.append(.separator)
                            }
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_LeaveGroup, textColor: .primary, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openLeavePeer(delete: false)
                            })))
                            if let cachedData = data.cachedData as? CachedChannelData, cachedData.flags.contains(.canDeleteHistory) {
                                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_DeleteGroup, textColor: .destructive, icon: { theme in
                                    generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor)
                                }, action: { [weak self] _, f in
                                    f(.dismissWithoutContent)
                                    
                                    self?.openLeavePeer(delete: true)
                                })))
                            }
                        }
                    }
                } else if let group = peer as? TelegramGroup {
                    if canSetupAutoremoveTimeout {
                        let strings = strongSelf.presentationData.strings
                        items.append(.action(ContextMenuActionItem(text: currentAutoremoveTimeout == nil ? strongSelf.presentationData.strings.PeerInfo_EnableAutoDelete : strongSelf.presentationData.strings.PeerInfo_AdjustAutoDelete, icon: { theme in
                            if let currentAutoremoveTimeout = currentAutoremoveTimeout {
                                let text = NSAttributedString(string: shortTimeIntervalString(strings: strings, value: currentAutoremoveTimeout), font: Font.regular(14.0), textColor: theme.contextMenu.primaryColor)
                                let bounds = text.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                                return generateImage(bounds.size.integralFloor, rotatedContext: { size, context in
                                    context.clear(CGRect(origin: CGPoint(), size: size))
                                    UIGraphicsPushContext(context)
                                    text.draw(in: bounds)
                                    UIGraphicsPopContext()
                                })
                            } else {
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Timer"), color: theme.contextMenu.primaryColor)
                            }
                        }, action: { [weak self] c, _ in
                            var subItems: [ContextMenuItem] = []
                            
                            subItems.append(.action(ContextMenuActionItem(text: strings.Common_Back, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                            }, iconPosition: .left, action: { c, _ in
                                c?.popItems()
                            })))
                            subItems.append(.separator)
                            
                            let presetValues: [Int32] = [
                                1 * 24 * 60 * 60,
                                7 * 24 * 60 * 60,
                                31 * 24 * 60 * 60
                            ]
                            
                            for value in presetValues {
                                subItems.append(.action(ContextMenuActionItem(text: timeIntervalString(strings: strings, value: value), icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: value)
                                })))
                            }
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteSettingOther, icon: { _ in
                                return nil
                            }, action: { _, f in
                                f(.default)
                                
                                self?.openAutoremove(currentValue: currentAutoremoveTimeout)
                            })))
                            
                            if let _ = currentAutoremoveTimeout {
                                subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteDisable, textColor: .destructive, icon: { _ in
                                    return nil
                                }, action: { _, f in
                                    f(.default)
                                    
                                    self?.setAutoremove(timeInterval: nil)
                                })))
                            }
                            
                            subItems.append(.separator)
                            
                            subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteInfo + "\n\n" + strongSelf.presentationData.strings.AutoremoveSetup_AdditionalGlobalSettingsInfo, textLayout: .multiline, textFont: .small, parseMarkdown: true, icon: { _ in
                                return nil
                            }, textLinkAction: { [weak c] in
                                c?.dismiss(completion: nil)
                                
                                guard let self else {
                                    return
                                }
                                self.context.sharedContext.openResolvedUrl(.settings(.autoremoveMessages), context: self.context, urlContext: .generic, navigationController: self.controller?.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { _, _ in }, dismissInput: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.controller?.view.endEditing(true)
                                }, contentContext: nil, progress: nil, completion: nil)
                            }, action: nil as ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
                            
                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                        })))
                    }

                    if let cachedData = data.cachedData as? CachedGroupData, cachedData.flags.contains(.translationHidden) {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self {
                                let _ = updateChatTranslationStateInteractively(engine: strongSelf.context.engine, peerId: strongSelf.peerId, threadId: nil, { current in
                                    return current?.withIsEnabled(true)
                                }).startStandalone()
                                
                                Queue.mainQueue().after(0.2, {
                                    let _ = (strongSelf.context.engine.messages.togglePeerMessagesTranslationHidden(peerId: strongSelf.peerId, hidden: false)
                                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                        self?.openChatForTranslation()
                                    })
                                })
                            }
                        })))
                    }
                    
                    var canReport = true
                    if case .creator = group.role {
                        canReport = false
                    }
                    if canReport {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.ReportPeer_Report, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] c, f in
                            self?.openReport(type: .default, contextController: c, backAction: { c in
                                if let mainItemsImpl = mainItemsImpl {
                                    c.setItems(mainItemsImpl() |> map { ContextController.Items(content: .list($0)) }, minHeight: nil, animated: true)
                                }
                            })
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: group, chatPeer: group, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            if let c {
                                self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: group, chatPeer: group)
                            }
                        })))
                    }
                    
                    if case .Member = group.membership, !headerButtons.contains(.leave) {
                        if !items.isEmpty {
                            items.append(.separator)
                        }
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_LeaveGroup, textColor: .destructive, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.destructiveColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openLeavePeer(delete: false)
                        })))
                        
                        if case .creator = group.role {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Group_DeleteGroup, textColor: .destructive, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.destructiveColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                
                                self?.openLeavePeer(delete: true)
                            })))
                        }
                    }
                }
                
                return .single(items)
            }
            
            self.view.endEditing(true)
            
            if let sourceNode = self.headerNode.buttonNodes[.more]?.referenceNode {
                let items = mainItemsImpl?() ?? .single([])
                let contextController = ContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                contextController.dismissed = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.state = strongSelf.state.withHighlightedButton(nil)
                        if let (layout, navigationHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                        }
                    }
                }
                controller.presentInGlobalOverlay(contextController)
            }
        case .addMember:
            self.openAddMember()
        case .search:
            self.openChatWithMessageSearch()
        case .leave:
            self.openLeavePeer(delete: false)
        case .stop:
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_banned", scale: 0.066, colors: [:], title: self.presentationData.strings.PeerInfo_BotBlockedTitle, text: self.presentationData.strings.PeerInfo_BotBlockedText, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            self.updateBlocked(block: true)
        case .addContact:
            self.openAddContact()
        }
    }
    
    private func openChatWithMessageSearch() {
        if let navigationController = (self.controller?.navigationController as? NavigationController) {
            if case let .replyThread(currentMessage) = self.chatLocation, let current = navigationController.viewControllers.first(where: { controller in
                if let controller = controller as? ChatController, case let .replyThread(message) = controller.chatLocation, message.peerId == currentMessage.peerId, message.threadId == currentMessage.threadId {
                    return true
                }
                return false
            }) as? ChatController {
                var viewControllers = navigationController.viewControllers
                if let index = viewControllers.firstIndex(of: current) {
                    viewControllers.removeSubrange(index + 1 ..< viewControllers.count)
                }
                navigationController.setViewControllers(viewControllers, animated: true)
                current.activateSearch(domain: .everything, query: "")
            } else if let peer = self.data?.chatPeer {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, activateMessageSearch: (.everything, ""), peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
                    if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                        var viewControllers = navigationController.viewControllers
                        viewControllers = viewControllers.filter { controller in
                            if controller is PeerInfoScreen {
                                return false
                            }
                            return true
                        }
                        navigationController.setViewControllers(viewControllers, animated: false)
                    }
                }))
            }
        }
    }
    
    private func openChatForReporting(title: String, option: Data, message: String?) {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            if let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
                //let _ = self.context.engine.peers.reportPeer(peerId: peer.id, reason: reason, message: "").startStandalone()
                //self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .emoji(name: "PoliceCar", text: self.presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
            } else {
                self.context.sharedContext.navigateToChatController(
                    NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: self.context,
                        chatLocation: .peer(EnginePeer(peer)),
                        keepStack: .default,
                        reportReason: NavigateToChatControllerParams.ReportReason(title: title, option: option, message: message),
                        completion: { _ in
                        }
                    )
                )
            }
        }
    }
    
    private func openChatForThemeChange() {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: .default, changeColors: true, completion: { _ in
            }))
        }
    }
    
    private func openChatForTranslation() {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: .default, changeColors: false, completion: { _ in
            }))
        }
    }
    
    private func openAutoremove(currentValue: Int32?) {
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, style: .default, mode: .autoremove, currentTime: currentValue, dismissByTapOutside: true, completion: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: strongSelf.peerId, timeout: value == 0 ? nil : value)
            |> deliverOnMainQueue).startStandalone(completed: {
                guard let strongSelf = self else {
                    return
                }
                
                var isOn: Bool = true
                var text: String?
                if value != 0 {
                    text = strongSelf.presentationData.strings.Conversation_AutoremoveChanged("\(timeIntervalString(strings: strongSelf.presentationData.strings, value: value))").string
                } else {
                    isOn = false
                    text = strongSelf.presentationData.strings.Conversation_AutoremoveOff
                }
                if let text = text {
                    strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
            })
        })
        self.controller?.view.endEditing(true)
        self.controller?.present(controller, in: .window(.root))
    }
    
    private func openCustomMute() {
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, style: .default, mode: .mute, currentTime: nil, dismissByTapOutside: true, completion: { [weak self] value in
            guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                return
            }
            if value <= 0 {
                let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: peer.id, threadId: strongSelf.chatLocation.threadId, muteInterval: nil).startStandalone()
            } else {
                let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: peer.id, threadId: strongSelf.chatLocation.threadId, muteInterval: value).startStandalone()
                
                let timeString = stringForPreciseRelativeTimestamp(strings: strongSelf.presentationData.strings, relativeTimestamp: Int32(Date().timeIntervalSince1970) + value, relativeTo: Int32(Date().timeIntervalSince1970), dateTimeFormat: strongSelf.presentationData.dateTimeFormat)
                
                strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_mute_for", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedUntil(timeString).string, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            }
        })
        self.controller?.view.endEditing(true)
        self.controller?.present(controller, in: .window(.root))
    }
    
    private func setAutoremove(timeInterval: Int32?) {
        let _ = (self.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: self.peerId, timeout: timeInterval)
        |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var isOn: Bool = true
            var text: String?
            if let myValue = timeInterval {
                text = strongSelf.presentationData.strings.Conversation_AutoremoveChanged("\(timeIntervalString(strings: strongSelf.presentationData.strings, value: myValue))").string
            } else {
                isOn = false
                text = strongSelf.presentationData.strings.Conversation_AutoremoveOff
            }
            if let text = text {
                strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
            }
        })
    }
    
    private func openStartSecretChat() {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        let peerId = self.peerId
        
        let _ = (combineLatest(
            self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.peerId)),
            self.context.engine.peers.mostRecentSecretChat(id: self.peerId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, currentPeerId in
            guard let strongSelf = self else {
                return
            }
            guard let controller = strongSelf.controller else {
                return
            }
            let displayTitle = peer?.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder) ?? ""
            controller.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.UserInfo_StartSecretChatConfirmation(displayTitle).string, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.UserInfo_StartSecretChatStart, action: {
                guard let strongSelf = self else {
                    return
                }
                var createSignal = strongSelf.context.engine.peers.createSecretChat(peerId: peerId)
                var cancelImpl: (() -> Void)?
                let progressSignal = Signal<Never, NoError> { subscriber in
                    if let strongSelf = self {
                        let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                            cancelImpl?()
                        }))
                        strongSelf.controller?.present(statusController, in: .window(.root))
                        return ActionDisposable { [weak statusController] in
                            Queue.mainQueue().async() {
                                statusController?.dismiss()
                            }
                        }
                    } else {
                        return EmptyDisposable
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                createSignal = createSignal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                let createSecretChatDisposable = MetaDisposable()
                cancelImpl = {
                    createSecretChatDisposable.set(nil)
                }
                
                createSecretChatDisposable.set((createSignal
                |> deliverOnMainQueue).start(next: { peerId in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let strongSelf = self, let peer = peer else {
                            return
                        }
                        if let navigationController = (strongSelf.controller?.navigationController as? NavigationController) {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer)))
                        }
                    })
                }, error: { error in
                    guard let strongSelf = self else {
                        return
                    }
                    let text: String
                    switch error {
                    case .limitExceeded:
                        text = strongSelf.presentationData.strings.TwoStepAuth_FloodError
                    case .premiumRequired:
                        text = strongSelf.presentationData.strings.Conversation_SendMessageErrorNonPremiumForbidden(displayTitle).string
                    default:
                        text = strongSelf.presentationData.strings.Login_UnknownError
                    }
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }))
            })]), in: .window(.root))
        })
    }
    
    private func openClearHistory(contextController: ContextControllerProtocol, clearPeerHistory: ClearPeerHistory, peer: Peer, chatPeer: Peer) {
        var subItems: [ContextMenuItem] = []
        
        subItems.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Common_Back, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
        }, iconPosition: .left, action: { c, _ in
            c?.popItems()
        })))
        subItems.append(.separator)
        
        guard let anyType = clearPeerHistory.canClearForEveryone ?? clearPeerHistory.canClearForMyself else {
            return
        }
        
        let title: String
        switch anyType {
        case .user, .secretChat, .savedMessages:
            title = self.presentationData.strings.PeerInfo_ClearConfirmationUser(EnginePeer(chatPeer).compactDisplayTitle).string
        case .group, .channel:
            title = self.presentationData.strings.PeerInfo_ClearConfirmationGroup(EnginePeer(chatPeer).compactDisplayTitle).string
        }
        
        subItems.append(.action(ContextMenuActionItem(text: title, textLayout: .multiline, textFont: .small, icon: { _ in
            return nil
        }, action: nil as ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
        
        let beginClear: (InteractiveHistoryClearingType) -> Void = { [weak self] type in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.openChatWithClearedHistory(type: type)
        }
        
        if let canClearForEveryone = clearPeerHistory.canClearForEveryone {
            let text: String
            switch canClearForEveryone {
            case .user, .secretChat, .savedMessages:
                text = self.presentationData.strings.Conversation_DeleteMessagesFor(EnginePeer(chatPeer).compactDisplayTitle).string
            case .channel, .group:
                text = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
            }
            
            subItems.append(.action(ContextMenuActionItem(text: text, textColor: .destructive, icon: { _ in
                return nil
            }, action: { _, f in
                f(.default)
                
                beginClear(.forEveryone)
            })))
        }
        
        if let canClearForMyself = clearPeerHistory.canClearForMyself {
            let text: String
            switch canClearForMyself {
            case .secretChat:
                text = self.presentationData.strings.Conversation_DeleteMessagesFor(EnginePeer(chatPeer).compactDisplayTitle).string
            default:
                text = self.presentationData.strings.Conversation_DeleteMessagesForMe
            }
            
            subItems.append(.action(ContextMenuActionItem(text: text, textColor: .destructive, icon: { _ in
                return nil
            }, action: { _, f in
                f(.default)
                
                beginClear(.forLocalPeer)
            })))
        }
        
        contextController.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
    }
    
    private func openUsername(value: String, isMainUsername: Bool, progress: Promise<Bool>?) {
        let url: String
        if value.hasPrefix("https://") {
            url = value
        } else {
            url = "https://t.me/\(value)"
        }
        
        let openShare: (TelegramCollectibleItemInfo?) -> Void = { [weak self] collectibleItemInfo in
            guard let self else {
                return
            }
            let shareController = ShareController(context: self.context, subject: .url(url), updatedPresentationData: self.controller?.updatedPresentationData, collectibleItemInfo: collectibleItemInfo)
            shareController.completed = { [weak self] peerIds in
                guard let strongSelf = self else {
                    return
                }
                let _ = (strongSelf.context.engine.data.get(
                    EngineDataList(
                        peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                    )
                )
                |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let peers = peerList.compactMap { $0 }
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    
                    let text: String
                    var savedMessages = false
                    if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                        text = presentationData.strings.UserInfo_LinkForwardTooltip_SavedMessages_One
                        savedMessages = true
                    } else {
                        if peers.count == 1, let peer = peers.first {
                            let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.UserInfo_LinkForwardTooltip_Chat_One(peerName).string
                        } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                            let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.UserInfo_LinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                        } else if let peer = peers.first {
                            let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.UserInfo_LinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                        } else {
                            text = ""
                        }
                    }
                    
                    strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                        if savedMessages, let self, action == .info {
                            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                     |> deliverOnMainQueue).start(next: { [weak self] peer in
                                guard let self, let peer else {
                                    return
                                }
                                guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                    return
                                }
                                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                            })
                        }
                        return false
                    }), in: .current)
                })
            }
            shareController.actionCompleted = { [weak self] in
                if let strongSelf = self {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            }
            self.view.endEditing(true)
            self.controller?.present(shareController, in: .window(.root))
        }
        
        if let pathComponents = URL(string: url)?.pathComponents, pathComponents.count >= 2, !pathComponents[1].isEmpty {
            let namePart = pathComponents[1]
            progress?.set(.single(true))
            let _ = (self.context.sharedContext.makeCollectibleItemInfoScreenInitialData(context: self.context, peerId: self.peerId, subject: .username(namePart))
            |> deliverOnMainQueue).start(next: { [weak self] initialData in
                guard let self else {
                    return
                }
                
                progress?.set(.single(false))
                
                if let initialData {
                    if isMainUsername {
                        openShare(initialData.collectibleItemInfo)
                    } else {
                        self.view.endEditing(true)
                        self.controller?.push(self.context.sharedContext.makeCollectibleItemInfoScreen(context: self.context, initialData: initialData))
                    }
                } else {
                    openShare(nil)
                }
            })
        } else {
            openShare(nil)
        }
    }
    
    private func requestCall(isVideo: Bool, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil, result: ((ContextMenuActionResult) -> Void)? = nil, backAction: ((ContextControllerProtocol) -> Void)? = nil) {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        let peerId = self.peerId
        let requestCall: (PeerId?, EngineGroupCallDescription?) -> Void = { [weak self] defaultJoinAsPeerId, activeCall in
            if let activeCall = activeCall {
                self?.context.joinGroupCall(peerId: peerId, invite: nil, requestJoinAsPeerId: { completion in
                    if let defaultJoinAsPeerId = defaultJoinAsPeerId {
                        result?(.dismissWithoutContent)
                        completion(defaultJoinAsPeerId)
                    } else {
                        self?.openVoiceChatDisplayAsPeerSelection(completion: { joinAsPeerId in
                            completion(joinAsPeerId)
                        }, gesture: gesture, contextController: contextController, result: result, backAction: backAction)
                    }
                }, activeCall: activeCall)
            } else {
                self?.openVoiceChatOptions(defaultJoinAsPeerId: defaultJoinAsPeerId, gesture: gesture, contextController: contextController)
            }
        }
        
        if let cachedChannelData = self.data?.cachedData as? CachedChannelData {
            requestCall(cachedChannelData.callJoinPeerId, cachedChannelData.activeCall.flatMap(EngineGroupCallDescription.init))
            return
        } else if let cachedGroupData = self.data?.cachedData as? CachedGroupData {
            requestCall(cachedGroupData.callJoinPeerId, cachedGroupData.activeCall.flatMap(EngineGroupCallDescription.init))
            return
        }
        
        guard let peer = self.data?.peer as? TelegramUser, let cachedUserData = self.data?.cachedData as? CachedUserData else {
            return
        }
        if cachedUserData.callsPrivate {
            self.controller?.present(textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: self.presentationData.strings.Call_ConnectionErrorTitle, text: self.presentationData.strings.Call_PrivacyErrorMessage(EnginePeer(peer).compactDisplayTitle).string, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            return
        }
        
        self.context.requestCall(peerId: peer.id, isVideo: isVideo, completion: {})
    }
    
    private func scheduleGroupCall() {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        self.context.scheduleGroupCall(peerId: self.peerId, parentController: controller)
    }
    
    private func createExternalStream(credentialsPromise: Promise<GroupCallStreamCredentials>?) {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        self.controller?.push(CreateExternalMediaStreamScreen(context: self.context, peerId: self.peerId, credentialsPromise: credentialsPromise, mode: .create))
    }
    
    private func createAndJoinGroupCall(peerId: PeerId, joinAsPeerId: PeerId?) {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        if let _ = self.context.sharedContext.callManager {
            let startCall: (Bool) -> Void = { [weak self] endCurrentIfAny in
                guard let strongSelf = self else {
                    return
                }
                
                var cancelImpl: (() -> Void)?
                let presentationData = strongSelf.presentationData
                let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                    let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    self?.controller?.present(controller, in: .window(.root))
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                let createSignal = strongSelf.context.engine.calls.createGroupCall(peerId: peerId, title: nil, scheduleDate: nil, isExternalStream: false)
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = { [weak self] in
                    self?.activeActionDisposable.set(nil)
                }
                strongSelf.activeActionDisposable.set((createSignal
                |> deliverOnMainQueue).start(next: { [weak self] info in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.context.joinGroupCall(peerId: peerId, invite: nil, requestJoinAsPeerId: { result in
                        result(joinAsPeerId)
                    }, activeCall: EngineGroupCallDescription(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: nil, subscribedToScheduled: false, isStream: info.isStream))
                }, error: { [weak self] error in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                    
                    let text: String
                    switch error {
                    case .generic, .scheduledTooLate:
                        text = strongSelf.presentationData.strings.Login_UnknownError
                    case .anonymousNotAllowed:
                        if let channel = strongSelf.data?.peer as? TelegramChannel, case .broadcast = channel.info {
                            text = strongSelf.presentationData.strings.LiveStream_AnonymousDisabledAlertText
                        } else {
                            text = strongSelf.presentationData.strings.VoiceChat_AnonymousDisabledAlertText
                        }
                    }
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }))
            }
            
            startCall(true)
        }
    }
    
    private func openUsernameContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let peer = self.data?.peer else {
            return
        }
        guard let username = peer.addressName else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            UIPasteboard.general.string = "@\(username)"
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.Conversation_UsernameCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_UsernameActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    self.openSettings(section: .username)
                }
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_UsernameActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
            c?.dismiss {
                copyAction()
            }
        })))
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = ContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
    
    private func openBioContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] sharedData in
            guard let self else {
                return
            }
            
            let translationSettings: TranslationSettings
            if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                translationSettings = current
            } else {
                translationSettings = TranslationSettings.defaultSettings
            }
            
            guard let sourceNode = node as? ContextExtractedContentContainingNode else {
                return
            }
            guard let cachedData = self.data?.cachedData else {
                return
            }
            
            var bioText: String?
            if let cachedData = cachedData as? CachedUserData {
                bioText = cachedData.about
            } else if let cachedData = cachedData as? CachedChannelData {
                bioText = cachedData.about
            } else if let cachedData = cachedData as? CachedGroupData {
                bioText = cachedData.about
            }
            
            guard let bioText, !bioText.isEmpty else {
                return
            }
            
            let copyAction = { [weak self] in
                guard let self else {
                    return
                }
                UIPasteboard.general.string = bioText
                
                let toastText: String
                if let _ = self.data?.peer as? TelegramUser {
                    toastText = self.presentationData.strings.MyProfile_ToastBioCopied
                } else {
                    toastText = self.presentationData.strings.ChannelProfile_ToastAboutCopied
                }
                
                self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: toastText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }
            
            var items: [ContextMenuItem] = []
            
            if self.isMyProfile {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_BioActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        self.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
                        
                        for (_, section) in self.editingSections {
                            for (id, itemNode) in section.itemNodes {
                                if id == AnyHashable("bio_edit") {
                                    if let itemNode = itemNode as? PeerInfoScreenMultilineInputItemNode {
                                        itemNode.focus()
                                    }
                                    break
                                }
                            }
                        }
                    }
                })))
            }
            
            let copyText: String
            if let _ = self.data?.peer as? TelegramUser {
                copyText = self.presentationData.strings.MyProfile_BioActionCopy
            } else {
                copyText = self.presentationData.strings.ChannelProfile_AboutActionCopy
            }
            items.append(.action(ContextMenuActionItem(text: copyText, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c?.dismiss {
                    copyAction()
                }
            })))
            
            let (canTranslate, language) = canTranslateText(context: self.context, text: bioText, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
            if canTranslate {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        
                        let controller = TranslateScreen(context: self.context, text: bioText, canCopy: true, fromLanguage: language, ignoredLanguages: translationSettings.ignoredLanguages)
                        controller.pushController = { [weak self] c in
                            (self?.controller?.navigationController as? NavigationController)?._keepModalDismissProgress = true
                            self?.controller?.push(c)
                        }
                        controller.presentController = { [weak self] c in
                            self?.controller?.present(c, in: .window(.root))
                        }
                        self.controller?.present(controller, in: .window(.root))
                    }
                })))
            }
            
            let actions = ContextController.Items(content: .list(items))
            
            let contextController = ContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
            self.controller?.present(contextController, in: .window(.root))
        })
    }
    
    private func openWorkingHoursContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let cachedData = self.data?.cachedData else {
            return
        }
        
        var businessHours: TelegramBusinessHours?
        if let cachedData = cachedData as? CachedUserData {
            businessHours = cachedData.businessHours
        }
        
        guard let businessHours else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            UIPasteboard.general.string = businessHoursTextToCopy(businessHours: businessHours, presentationData: self.presentationData, displayLocalTimezone: false)
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.MyProfile_ToastHoursCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    let businessHoursSetupScreen = self.context.sharedContext.makeBusinessHoursSetupScreen(context: self.context, initialValue: businessHours, completion: { _ in })
                    self.controller?.push(businessHoursSetupScreen)
                }
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
            c?.dismiss {
                copyAction()
            }
        })))
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursActionRemove, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _
                in
                guard let self else {
                    return
                }
                
                var subItems: [ContextMenuItem] = []
                let noAction: ((ContextMenuActionItem.Action) -> Void)? = nil
                subItems.append(.action(ContextMenuActionItem(
                    text: self.presentationData.strings.MyProfile_HoursRemoveConfirmation_Title,
                    textLayout: .multiline,
                    textFont: .small,
                    icon: { _ in nil },
                    action: noAction
                )))
                subItems.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_HoursRemoveConfirmation_Action, textColor: .destructive, icon: { _ in nil }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        let _ = self.context.engine.accountData.updateAccountBusinessHours(businessHours: nil).startStandalone()
                    }
                })))
                c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
            })))
        }
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = ContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
    
    private func openBusinessLocationContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let cachedData = self.data?.cachedData else {
            return
        }
        
        var businessLocation: TelegramBusinessLocation?
        if let cachedData = cachedData as? CachedUserData {
            businessLocation = cachedData.businessLocation
        }
        
        guard let businessLocation else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            UIPasteboard.general.string = businessLocation.address
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.MyProfile_ToastLocationCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if businessLocation.coordinates != nil {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionOpen, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Media Editor/LocationSmall"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss(completion: {
                    guard let self else {
                        return
                    }
                    self.interaction.openLocation()
                })
            })))
        }
        
        if !businessLocation.address.isEmpty {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c?.dismiss {
                    copyAction()
                }
            })))
        }
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    let businessLocationSetupScreen = self.context.sharedContext.makeBusinessLocationSetupScreen(context: self.context, initialValue: businessLocation, completion: { _ in })
                    self.controller?.push(businessLocationSetupScreen)
                }
            })))
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationActionRemove, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _ in
                guard let self else {
                    return
                }
                
                var subItems: [ContextMenuItem] = []
                let noAction: ((ContextMenuActionItem.Action) -> Void)? = nil
                subItems.append(.action(ContextMenuActionItem(
                    text: self.presentationData.strings.MyProfile_LocationRemoveConfirmation_Title,
                    textLayout: .multiline,
                    textFont: .small,
                    icon: { _ in nil },
                    action: noAction
                )))
                subItems.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_LocationRemoveConfirmation_Action, textColor: .destructive, icon: { _ in nil }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        let _ = self.context.engine.accountData.updateAccountBusinessLocation(businessLocation: nil).startStandalone()
                    }
                })))
                c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
            })))
        }
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = ContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
    
    private func openBirthdayContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let cachedData = self.data?.cachedData else {
            return
        }
        
        var birthday: TelegramBirthday?
        if let cachedData = cachedData as? CachedUserData {
            birthday = cachedData.birthday
        }
        
        guard let birthday else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            let presentationData = self.presentationData
            let text = stringForCompactBirthday(birthday, strings: presentationData.strings)
            
            UIPasteboard.general.string = text
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.MyProfile_ToastBirthdayCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_BirthdayActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    
                    self.state = self.state.withIsEditingBirthDate(true)
                    self.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
                }
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_BirthdayActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
            c?.dismiss {
                copyAction()
            }
        })))
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = ContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
    
    private func openPhone(value: String, node: ASDisplayNode, gesture: ContextGesture?, progress: Promise<Bool>?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        
        let formattedPhoneNumber = formatPhoneNumber(context: self.context, number: value)
        if gesture == nil, formattedPhoneNumber.hasPrefix("+888") {
            let collectibleInfo = Promise<CollectibleItemInfoScreenInitialData?>()
            collectibleInfo.set(self.context.sharedContext.makeCollectibleItemInfoScreenInitialData(context: self.context, peerId: self.peerId, subject: .phoneNumber(value)))
            
            progress?.set(.single(true))
            let _ = (collectibleInfo.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] initialData in
                progress?.set(.single(false))
                
                guard let self else {
                    return
                }
                if let initialData {
                    self.view.endEditing(true)
                    self.controller?.push(self.context.sharedContext.makeCollectibleItemInfoScreen(context: self.context, initialData: initialData))
                } else {
                    self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: "https://fragment.com/numbers", forceExternal: true, presentationData: self.presentationData, navigationController: nil, dismissInput: {})
                }
            })
            
            return
        }
        
        let _ = (combineLatest(
            getUserPeer(engine: self.context.engine, peerId: self.peerId),
            getUserPeer(engine: self.context.engine, peerId: self.context.account.peerId)
        ) |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, accountPeer in
            guard let strongSelf = self else {
                return
            }
            let presentationData = strongSelf.presentationData
                        
            let telegramCallAction: (Bool) -> Void = { [weak self] isVideo in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestCall(isVideo: isVideo)
            }
            
            let phoneCallAction = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(context: strongSelf.context, number: value).replacingOccurrences(of: " ", with: ""))")
            }
            
            let copyAction = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                UIPasteboard.general.string = formatPhoneNumber(context: strongSelf.context, number: value)
                
                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }
            
            var accountIsFromUS = false
            if let accountPeer, case let .user(user) = accountPeer, let phone = user.phone {
                if let (country, _) = lookupCountryIdByNumber(phone, configuration: strongSelf.context.currentCountriesConfiguration.with { $0 }) {
                    if country.id == "US" {
                        accountIsFromUS = true
                    }
                }
            }
            
            var isAnonymousNumber = false
            var items: [ContextMenuItem] = []
            
            if strongSelf.isMyProfile {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.MyProfile_PhoneActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        self.openSettings(section: .phoneNumber)
                    }
                })))
            }
            
            if case let .user(peer) = peer, let peerPhoneNumber = peer.phone, formattedPhoneNumber == formatPhoneNumber(context: strongSelf.context, number: peerPhoneNumber) {
                if !strongSelf.isMyProfile {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_TelegramCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss {
                            telegramCallAction(false)
                        }
                    })))
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_TelegramVideoCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VideoCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss {
                            telegramCallAction(true)
                        }
                    })))
                }
                if !formattedPhoneNumber.hasPrefix("+888") {
                    if !strongSelf.isMyProfile {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_PhoneCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PhoneCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                            c?.dismiss {
                                phoneCallAction()
                            }
                        })))
                    }
                } else {
                    isAnonymousNumber = true
                }
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.MyProfile_PhoneActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c?.dismiss {
                        copyAction()
                    }
                })))
            } else {
                if !formattedPhoneNumber.hasPrefix("+888") {
                    if !strongSelf.isMyProfile {
                        items.append(
                            .action(ContextMenuActionItem(text: presentationData.strings.UserInfo_PhoneCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PhoneCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                                c?.dismiss {
                                    phoneCallAction()
                                }
                            }))
                        )
                    }
                } else {
                    isAnonymousNumber = true
                }
                items.append(
                    .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.MyProfile_PhoneActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c?.dismiss {
                            copyAction()
                        }
                    }))
                )
            }
            var actions = ContextController.Items(content: .list(items))
            if isAnonymousNumber && !accountIsFromUS {
                let collectibleInfo = Promise<CollectibleItemInfoScreenInitialData?>()
                collectibleInfo.set(strongSelf.context.sharedContext.makeCollectibleItemInfoScreenInitialData(context: strongSelf.context, peerId: strongSelf.peerId, subject: .phoneNumber(value)))
                
                actions.tip = .animatedEmoji(text: strongSelf.presentationData.strings.UserInfo_AnonymousNumberInfo, arguments: nil, file: nil, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    
                    let _ = (collectibleInfo.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] initialData in
                        guard let self else {
                            return
                        }
                        if let initialData {
                            self.view.endEditing(true)
                            self.controller?.push(self.context.sharedContext.makeCollectibleItemInfoScreen(context: self.context, initialData: initialData))
                        } else {
                            self.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: "https://fragment.com/numbers", forceExternal: true, presentationData: self.presentationData, navigationController: nil, dismissInput: {})
                        }
                    })
                })
            }
            let contextController = ContextController(presentationData: strongSelf.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
            strongSelf.controller?.present(contextController, in: .window(.root))
        })
    }
    
    private func editingOpenNotificationSettings() {
        let _ = (combineLatest(
            self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: self.peerId),
                TelegramEngine.EngineData.Item.NotificationSettings.Global()
            ),
            self.context.engine.peers.notificationSoundList()
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] settings, notificationSoundList in
            guard let strongSelf = self else {
                return
            }
            
            let (peerSettings, globalSettings) = settings
            
            let muteSettingsController = notificationMuteSettingsController(presentationData: strongSelf.presentationData, notificationSoundList: notificationSoundList, notificationSettings: globalSettings.groupChats._asMessageNotificationSettings(), soundSettings: nil, openSoundSettings: {
                guard let strongSelf = self else {
                    return
                }
                let soundController = notificationSoundSelectionController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, isModal: true, currentSound: peerSettings.messageSound._asMessageSound(), defaultSound: globalSettings.groupChats.sound._asMessageSound(), completion: { sound in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: strongSelf.peerId, threadId: strongSelf.chatLocation.threadId, sound: sound).startStandalone()
                })
                soundController.navigationPresentation = .modal
                strongSelf.controller?.push(soundController)
            }, updateSettings: { value in
                guard let strongSelf = self else {
                    return
                }
                let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: strongSelf.peerId, threadId: strongSelf.chatLocation.threadId, muteInterval: value).startStandalone()
            })
            strongSelf.view.endEditing(true)
            strongSelf.controller?.present(muteSettingsController, in: .window(.root))
        })
    }
    
    private func editingOpenSoundSettings() {
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: self.peerId),
            TelegramEngine.EngineData.Item.NotificationSettings.Global()
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peerSettings, globalSettings in
            guard let strongSelf = self else {
                return
            }
            
            let soundController = notificationSoundSelectionController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, isModal: true, currentSound: peerSettings.messageSound._asMessageSound(), defaultSound: globalSettings.groupChats.sound._asMessageSound(), completion: { sound in
                guard let strongSelf = self else {
                    return
                }
                let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: strongSelf.peerId, threadId: strongSelf.chatLocation.threadId, sound: sound).startStandalone()
            })
            strongSelf.controller?.push(soundController)
        })
    }
    
    private func editingToggleShowMessageText(value: Bool) {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            let _ = strongSelf.context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peer.id, threadId: strongSelf.chatLocation.threadId, displayPreviews: value ? .show : .hide).startStandalone()
        })
    }
    
    private func requestDeleteContact() {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak actionSheet] in
            actionSheet?.dismissAnimated()
        }
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.UserInfo_DeleteContact, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (getUserPeer(engine: strongSelf.context.engine, peerId: strongSelf.peerId)
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        guard let peer = peer, let strongSelf = self else {
                            return
                        }
                        let deleteContactFromDevice: Signal<Never, NoError>
                        if let contactDataManager = strongSelf.context.sharedContext.contactDataManager {
                            deleteContactFromDevice = contactDataManager.deleteContactWithAppSpecificReference(peerId: peer.id)
                        } else {
                            deleteContactFromDevice = .complete()
                        }
                        
                        var deleteSignal = strongSelf.context.engine.contacts.deleteContactPeerInteractively(peerId: peer.id)
                        |> then(deleteContactFromDevice)
                        
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            guard let strongSelf = self else {
                                return EmptyDisposable
                            }
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                            strongSelf.controller?.present(statusController, in: .window(.root))
                            return ActionDisposable { [weak statusController] in
                                Queue.mainQueue().async() {
                                    statusController?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        deleteSignal = deleteSignal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        
                        strongSelf.activeActionDisposable.set((deleteSignal
                        |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                            if let strongSelf = self, let peer = strongSelf.data?.peer {
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                let controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.Conversation_DeletedFromContacts(EnginePeer(peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).string, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false })
                                controller.keepOnParentDismissal = true
                                strongSelf.controller?.present(controller, in: .window(.root))
                                
                                strongSelf.controller?.dismiss()
                            }
                        }))
                        
                        deleteSendMessageIntents(peerId: strongSelf.peerId)
                    })
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        self.view.endEditing(true)
        self.controller?.present(actionSheet, in: .window(.root))
    }
    
    private func openChat(peerId: EnginePeer.Id?) {
        if let peerId {
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                guard let navigationController = self.controller?.navigationController as? NavigationController else {
                    return
                }
                
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .always))
            })
            return
        }
        
        if let peer = self.data?.peer, let navigationController = self.controller?.navigationController as? NavigationController {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
                if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { controller in
                        if controller is PeerInfoScreen {
                            return false
                        }
                        return true
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
            }))
        }
    }
    
    private func openChatWithClearedHistory(type: InteractiveHistoryClearingType) {
        guard let peer = self.data?.chatPeer, let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(peer)), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), setupController: { controller in
            controller.beginClearHistory(type: type)
        }, completion: { [weak self] _ in
            if let strongSelf = self, strongSelf.nearbyPeerDistance != nil {
                var viewControllers = navigationController.viewControllers
                viewControllers = viewControllers.filter { controller in
                    if controller is PeerInfoScreen {
                        return false
                    }
                    return true
                }
                
                navigationController.setViewControllers(viewControllers, animated: false)
            }
        }))
    }
    
    private func openAddContact() {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            openAddPersonContactImpl(context: strongSelf.context, peerId: peer.id, pushController: { c in
                self?.controller?.push(c)
            }, present: { c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, completion: { [weak self] in
                if let self {
                    self.forceIsContactPromise.set(true)
                }
            })
        })
    }
    
    private func updateBlocked(block: Bool) {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            
            let presentationData = strongSelf.presentationData
            if case let .user(peer) = peer, let _ = peer.botInfo {
                strongSelf.activeActionDisposable.set(strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: block).startStrict())
                if !block {
                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: "/start", attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
                    if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(EnginePeer(peer))))
                    }
                }
            } else {
                if block {
                    let presentationData = strongSelf.presentationData
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    let dismissAction: () -> Void = { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    }
                    let reportSpam = false
                    let deleteChat = false
                    actionSheet.setItemGroups([
                        ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(peer.compactDisplayTitle).string),
                            ActionSheetButtonItem(title: presentationData.strings.UserInfo_BlockActionTitle(peer.compactDisplayTitle).string, color: .destructive, action: {
                                dismissAction()
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.activeActionDisposable.set(strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: true).startStrict())
                                if deleteChat {
                                    let _ = strongSelf.context.engine.peers.removePeerChat(peerId: strongSelf.peerId, reportChatSpam: reportSpam).startStandalone()
                                    (strongSelf.controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
                                } else if reportSpam {
                                    let _ = strongSelf.context.engine.peers.reportPeer(peerId: strongSelf.peerId, reason: .spam, message: "").startStandalone()
                                }
                                
                                deleteSendMessageIntents(peerId: strongSelf.peerId)
                            })
                        ]),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    strongSelf.view.endEditing(true)
                    strongSelf.controller?.present(actionSheet, in: .window(.root))
                } else {
                    let text: String
                    if block {
                        text = presentationData.strings.UserInfo_BlockConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                    } else {
                        text = presentationData.strings.UserInfo_UnblockConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                    }
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Yes, action: {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.activeActionDisposable.set(strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: block).startStrict())
                    })]), in: .window(.root))
                }
            }
        })
    }
    
    private func openStoryArchive() {
        self.controller?.push(PeerInfoStoryGridScreen(context: self.context, peerId: self.peerId, scope: .archive))
    }
    
    private func openStats(section: ChannelStatsSection, boostStatus: ChannelBoostStatus? = nil) {
        guard let controller = self.controller, let data = self.data, let peer = data.peer else {
            return
        }
        self.view.endEditing(true)
        
        let statsController: ViewController
        if let channel = peer as? TelegramChannel, case .group = channel.info {
            if case .monetization = section {
                statsController = channelStatsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, section: section, existingStarsRevenueContext: data.starsRevenueStatsContext, boostStatus: boostStatus)
            } else {
                statsController = groupStatsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id)
            }
        } else {
            statsController = channelStatsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, section: section, boostStatus: boostStatus)
        }
        controller.push(statsController)
    }
    
    private func openBoost() {
        guard let peer = self.data?.peer, let channel = peer as? TelegramChannel, let controller = self.controller else {
            return
        }
        
        if channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canInviteUsers) == true) {
            let boostsController = channelStatsController(context: self.context, updatedPresentationData: controller.updatedPresentationData, peerId: self.peerId, section: .boosts, boostStatus: self.boostStatus, boostStatusUpdated: { [weak self] boostStatus in
                if let self {
                    self.boostStatus = boostStatus
                }
            })
            controller.push(boostsController)
        } else {
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                context.engine.peers.getChannelBoostStatus(peerId: self.peerId),
                context.engine.peers.getMyBoostStatus()
            ).startStandalone(next: { [weak self] boostStatus, myBoostStatus in
                guard let self, let controller = self.controller, let boostStatus, let myBoostStatus else {
                    return
                }
                let boostController = PremiumBoostLevelsScreen(
                    context: self.context,
                    peerId: controller.peerId,
                    mode: .user(mode: .current),
                    status: boostStatus,
                    myBoostStatus: myBoostStatus
                )
                controller.push(boostController)
            })
        }
    }
    
    private func openVoiceChatOptions(defaultJoinAsPeerId: PeerId?, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil) {
        guard let chatPeer = self.data?.peer else {
            return
        }
        let context = self.context
        let peerId = self.peerId
        let defaultJoinAsPeerId = defaultJoinAsPeerId ?? self.context.account.peerId
        let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> map { peer in
            return [FoundPeer(peer: peer, subscribers: nil)]
        }
        let _ = (combineLatest(queue: Queue.mainQueue(), currentAccountPeer, self.displayAsPeersPromise.get() |> take(1))
        |> map { currentAccountPeer, availablePeers -> [FoundPeer] in
            var result = currentAccountPeer
            result.append(contentsOf: availablePeers)
            return result
        }).startStandalone(next: { [weak self] peers in
            guard let strongSelf = self else {
                return
            }
            
            var items: [ContextMenuItem] = []
            
            if peers.count > 1 {
                var selectedPeer: FoundPeer?
                for peer in peers {
                    if peer.peer.id == defaultJoinAsPeerId {
                        selectedPeer = peer
                    }
                }
                if let peer = selectedPeer {
                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.VoiceChat_DisplayAs, textLayout: .secondLineWithValue(EnginePeer(peer.peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: strongSelf.context.account, peer: EnginePeer(peer.peer), size: avatarSize)), action: { c, f in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.openVoiceChatDisplayAsPeerSelection(completion: { joinAsPeerId in
                            let _ = context.engine.calls.updateGroupCallJoinAsPeer(peerId: peerId, joinAs: joinAsPeerId).startStandalone()
                            self?.openVoiceChatOptions(defaultJoinAsPeerId: joinAsPeerId, gesture: nil, contextController: c)
                        }, gesture: gesture, contextController: c, result: f, backAction: { [weak self] c in
                            self?.openVoiceChatOptions(defaultJoinAsPeerId: defaultJoinAsPeerId, gesture: nil, contextController: c)
                        })
                        
                    })))
                    items.append(.separator)
                }
            }

            let createVoiceChatTitle: String
            let scheduleVoiceChatTitle: String
            if let channel = strongSelf.data?.peer as? TelegramChannel, case .broadcast = channel.info {
                createVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_CreateLiveStream
                scheduleVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_ScheduleLiveStream
            } else {
                createVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_CreateVoiceChat
                scheduleVoiceChatTitle = strongSelf.presentationData.strings.ChannelInfo_ScheduleVoiceChat
            }
            
            items.append(.action(ContextMenuActionItem(text: createVoiceChatTitle, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VoiceChat"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                f(.dismissWithoutContent)
                
                self?.createAndJoinGroupCall(peerId: peerId, joinAsPeerId: defaultJoinAsPeerId)
            })))
            
            items.append(.action(ContextMenuActionItem(text: scheduleVoiceChatTitle, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Schedule"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                f(.dismissWithoutContent)
                
                self?.scheduleGroupCall()
            })))
            
            var credentialsPromise: Promise<GroupCallStreamCredentials>?
            var canCreateStream = false
            switch chatPeer {
            case let group as TelegramGroup:
                if case .creator = group.role {
                    canCreateStream = true
                }
            case let channel as TelegramChannel:
                if channel.hasPermission(.manageCalls) {
                    canCreateStream = true
                    credentialsPromise = Promise()
                    credentialsPromise?.set(context.engine.calls.getGroupCallStreamCredentials(peerId: peerId, revokePreviousCredentials: false) |> `catch` { _ -> Signal<GroupCallStreamCredentials, NoError> in return .never() })
                }
            default:
                break
            }
            
            if canCreateStream {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChannelInfo_CreateExternalStream, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VoiceChat"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    self?.createExternalStream(credentialsPromise: credentialsPromise)
                })))
            }
            
            if let contextController = contextController {
                contextController.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil, animated: true)
            } else {
                strongSelf.state = strongSelf.state.withHighlightedButton(.voiceChat)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
                
                if let sourceNode = strongSelf.headerNode.buttonNodes[.voiceChat]?.referenceNode, let controller = strongSelf.controller {
                    let contextController = ContextController(presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                    contextController.dismissed = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.state = strongSelf.state.withHighlightedButton(nil)
                            if let (layout, navigationHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                            }
                        }
                    }
                    controller.presentInGlobalOverlay(contextController)
                }
            }
        })
    }
    
    private func openVoiceChatDisplayAsPeerSelection(completion: @escaping (PeerId) -> Void, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil, result: ((ContextMenuActionResult) -> Void)? = nil, backAction: ((ContextControllerProtocol) -> Void)? = nil) {
        let dismissOnSelection = contextController == nil
        let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(context.account.peerId)
        |> map { peer in
            return [FoundPeer(peer: peer, subscribers: nil)]
        }
        let _ = (combineLatest(queue: Queue.mainQueue(), currentAccountPeer, self.displayAsPeersPromise.get() |> take(1))
        |> map { currentAccountPeer, availablePeers -> [FoundPeer] in
            var result = currentAccountPeer
            result.append(contentsOf: availablePeers)
            return result
        }).startStandalone(next: { [weak self] peers in
            guard let strongSelf = self else {
                return
            }
            if peers.count == 1, let peer = peers.first {
                result?(.dismissWithoutContent)
                completion(peer.peer.id)
            } else {
                var items: [ContextMenuItem] = []
                
                var isGroup = false
                for peer in peers {
                    if peer.peer is TelegramGroup {
                        isGroup = true
                        break
                    } else if let peer = peer.peer as? TelegramChannel, case .group = peer.info {
                        isGroup = true
                        break
                    }
                }
                
                items.append(.custom(VoiceChatInfoContextItem(text: isGroup ? strongSelf.presentationData.strings.VoiceChat_DisplayAsInfoGroup : strongSelf.presentationData.strings.VoiceChat_DisplayAsInfo, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Accounts"), color: theme.actionSheet.primaryTextColor)
                }), true))
                
                for peer in peers {
                    var subtitle: String?
                    if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                        subtitle = strongSelf.presentationData.strings.VoiceChat_PersonalAccount
                    } else if let subscribers = peer.subscribers {
                        if let peer = peer.peer as? TelegramChannel, case .broadcast = peer.info {
                            subtitle = strongSelf.presentationData.strings.Conversation_StatusSubscribers(subscribers)
                        } else {
                            subtitle = strongSelf.presentationData.strings.Conversation_StatusMembers(subscribers)
                        }
                    }

                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    let avatarSignal = peerAvatarCompleteImage(account: strongSelf.context.account, peer: EnginePeer(peer.peer), size: avatarSize)
                    items.append(.action(ContextMenuActionItem(text: EnginePeer(peer.peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), textLayout: subtitle.flatMap { .secondLineWithValue($0) } ?? .singleLine, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: avatarSignal), action: { _, f in
                        if dismissOnSelection {
                            f(.dismissWithoutContent)
                        }
                        completion(peer.peer.id)
                    })))
                    
                    if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                        items.append(.separator)
                    }
                }
                if backAction != nil {
                    items.append(.separator)
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Back, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                    }, iconPosition: .left, action: { (c, _) in
                        if let c, let backAction = backAction {
                            backAction(c)
                        }
                    })))
                }
                
                if let contextController = contextController {
                    contextController.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil, animated: true)
                } else {
                    strongSelf.state = strongSelf.state.withHighlightedButton(.voiceChat)
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                    
                    if let sourceNode = strongSelf.headerNode.buttonNodes[.voiceChat]?.referenceNode, let controller = strongSelf.controller {
                        let contextController = ContextController(presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                        contextController.dismissed = { [weak self] in
                            if let strongSelf = self {
                                strongSelf.state = strongSelf.state.withHighlightedButton(nil)
                                if let (layout, navigationHeight) = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                                }
                            }
                        }
                        controller.presentInGlobalOverlay(contextController)
                    }
                }
            }
        })
    }
    
    private func openReport(type: PeerInfoReportType, contextController: ContextControllerProtocol?, backAction: ((ContextControllerProtocol) -> Void)?) {
        self.view.endEditing(true)
        
        switch type {
        case let .reaction(sourceMessageId):
            let presentationData = self.presentationData
            let actionSheet = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: presentationData.strings.ReportPeer_ReportReaction_Text),
                    ActionSheetButtonItem(title: presentationData.strings.ReportPeer_ReportReaction_BanAndReport, color: .destructive, action: { [weak self] in
                        dismissAction()
                        guard let self else {
                            return
                        }
                        self.activeActionDisposable.set(self.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: self.peerId, isBlocked: true).startStrict())
                        self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .emoji(name: "PoliceCar", text: self.presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                    }),
                    ActionSheetButtonItem(title: presentationData.strings.ReportPeer_ReportReaction_Report, action: { [weak self] in
                        dismissAction()
                        guard let self else {
                            return
                        }
                        let _ = (self.context.engine.peers.reportPeerReaction(authorId: self.peerId, messageId: sourceMessageId)
                        |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .emoji(name: "PoliceCar", text: strongSelf.presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                        })
                    })
                ]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            self.controller?.present(actionSheet, in: .window(.root))
        default:
            contextController?.dismiss()
            
            self.context.sharedContext.makeContentReportScreen(context: self.context, subject: .peer(self.peerId), forceDark: false, present: { [weak self] controller in
                self?.controller?.push(controller)
            }, completion: {
            }, requestSelectMessages: { [weak self] title, option, message in
                self?.openChatForReporting(title: title, option: option, message: message)
            })
        }
    }
    
    private func openEncryptionKey() {
        guard let data = self.data, let peer = data.peer, let encryptionKeyFingerprint = data.encryptionKeyFingerprint else {
            return
        }
        self.controller?.push(SecretChatKeyController(context: self.context, fingerprint: encryptionKeyFingerprint, peer: EnginePeer(peer)))
    }
    
    private func openShareBot() {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            if case let .user(peer) = peer, let username = peer.addressName {
                let shareController = ShareController(context: strongSelf.context, subject: .url("https://t.me/\(username)"), updatedPresentationData: strongSelf.controller?.updatedPresentationData)
                shareController.completed = { [weak self] peerIds in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let peers = peerList.compactMap { $0 }
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        
                        let text: String
                        var savedMessages = false
                        if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                            text = presentationData.strings.UserInfo_LinkForwardTooltip_SavedMessages_One
                            savedMessages = true
                        } else {
                            if peers.count == 1, let peer = peers.first {
                                let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                text = presentationData.strings.UserInfo_LinkForwardTooltip_Chat_One(peerName).string
                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                text = presentationData.strings.UserInfo_LinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                            } else if let peer = peers.first {
                                let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                text = presentationData.strings.UserInfo_LinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                            } else {
                                text = ""
                            }
                        }
                        
                        strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                            if savedMessages, let self, action == .info {
                                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    guard let self, let peer else {
                                        return
                                    }
                                    guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                        return
                                    }
                                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                                })
                            }
                            return false
                        }), in: .current)
                    })
                }
                shareController.actionCompleted = { [weak self] in
                    if let strongSelf = self {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    }
                }
                strongSelf.view.endEditing(true)
                strongSelf.controller?.present(shareController, in: .window(.root))
            }
        })
    }
    
    private func openAddBotToGroup() {
        guard let controller = self.controller else {
            return
        }
        self.context.sharedContext.openResolvedUrl(.groupBotStart(peerId: peerId, payload: "", adminRights: nil), context: self.context, urlContext: .generic, navigationController: controller.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { id, navigation in
        },
        sendFile: nil,
        sendSticker: nil,
        sendEmoji: nil,
        requestMessageActionUrlAuth: nil,
        joinVoiceChat: nil,
        present: { [weak controller] c, a in
            controller?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak controller] in
            controller?.view.endEditing(true)
        }, contentContext: nil, progress: nil, completion: nil)
    }
    
    private func performBotCommand(command: PeerInfoBotCommand) {
        let _ = (self.context.account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            let text: String
            switch command {
            case .settings:
                text = "/settings"
            case .privacy:
                text = "/privacy"
            case .help:
                text = "/help"
            }
            let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
            
            if let peer = strongSelf.data?.peer, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(EnginePeer(peer))))
            }
        })
    }
    
    private func openBioPrivacy() {
        guard let _ = self.data?.globalSettings?.privacySettings else {
            return
        }
        self.context.sharedContext.makeBioPrivacyController(context: self.context, settings: self.privacySettings, present: { [weak self] c in
            self?.controller?.push(c)
        })
    }
    
    private func openBirthdatePrivacy() {
        guard let _ = self.data?.globalSettings?.privacySettings else {
            return
        }
        self.context.sharedContext.makeBirthdayPrivacyController(context: self.context, settings: self.privacySettings, openedFromBirthdayScreen: true, present: { [weak self] c in
            self?.controller?.push(c)
        })
    }
    
    private func editingOpenPublicLinkSetup() {
        if let peer = self.data?.peer as? TelegramUser, peer.botInfo != nil {
            let controller = usernameSetupController(context: self.context, mode: .bot(self.peerId))
            self.controller?.push(controller)
        } else {
            var upgradedToSupergroupImpl: (() -> Void)?
            let controller = channelVisibilityController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, mode: .generic, upgradedToSupergroup: { _, f in
                upgradedToSupergroupImpl?()
                f()
            })
            self.controller?.push(controller)
            
            upgradedToSupergroupImpl = { [weak controller] in
                if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                    rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController)
                }
            }
        }
    }
    
    private func editingOpenAffiliateProgram() {
        if let peer = self.data?.peer as? TelegramUser, let botInfo = peer.botInfo {
            if botInfo.flags.contains(.canEdit) {
                let _ = (self.context.sharedContext.makeAffiliateProgramSetupScreenInitialData(context: self.context, peerId: peer.id, mode: .editProgram)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] initialData in
                    guard let self else {
                        return
                    }
                    let controller = self.context.sharedContext.makeAffiliateProgramSetupScreen(context: self.context, initialData: initialData)
                    self.controller?.push(controller)
                })
            } else if let starRefProgram = (self.data?.cachedData as? CachedUserData)?.starRefProgram, starRefProgram.endDate == nil {
                self.activeActionDisposable.set((self.context.engine.peers.getStarRefBotConnection(id: peer.id, targetId: self.context.account.peerId)
                |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    let _ = (self.context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId)
                    )
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] accountPeer in
                        guard let self, let accountPeer else {
                            return
                        }
                        let mode: JoinAffiliateProgramScreenMode
                        if let result {
                            mode = .active(JoinAffiliateProgramScreenMode.Active(
                                targetPeer: accountPeer,
                                bot: result,
                                copyLink: { [weak self] result in
                                    guard let self else {
                                        return
                                    }
                                    UIPasteboard.general.string = result.url
                                    let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
                                    self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: presentationData.strings.AffiliateProgram_ToastLinkCopied_Title, text: presentationData.strings.AffiliateProgram_ToastLinkCopied_Text(formatPermille(result.commissionPermille), result.peer.compactDisplayTitle).string), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                }
                            ))
                        } else {
                            mode = .join(JoinAffiliateProgramScreenMode.Join(
                                initialTargetPeer: accountPeer,
                                canSelectTargetPeer: true,
                                completion: { [weak self] targetPeer in
                                    guard let self else {
                                        return
                                    }
                                    let _ = (self.context.engine.peers.connectStarRefBot(id: targetPeer.id, botId: self.peerId)
                                    |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
                                        guard let self else {
                                            return
                                        }
                                        let bot = result
                                        
                                        self.controller?.push(self.context.sharedContext.makeAffiliateProgramJoinScreen(
                                            context: self.context,
                                            sourcePeer: bot.peer,
                                            commissionPermille: bot.commissionPermille,
                                            programDuration: bot.durationMonths,
                                            revenuePerUser: bot.participants == 0 ? 0.0 : Double(bot.revenue) / Double(bot.participants),
                                            mode: .active(JoinAffiliateProgramScreenMode.Active(
                                                targetPeer: targetPeer,
                                                bot: bot,
                                                copyLink: { [weak self] result in
                                                    guard let self else {
                                                        return
                                                    }
                                                    UIPasteboard.general.string = result.url
                                                    let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
                                                    self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: "Link copied to clipboard", text: "Share this link and earn **\(formatPermille(result.commissionPermille))%** of what people who use it spend in **\(result.peer.compactDisplayTitle)**!"), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                                }
                                            ))
                                        ))
                                    })
                                }
                            ))
                        }
                        self.controller?.push(self.context.sharedContext.makeAffiliateProgramJoinScreen(
                            context: self.context,
                            sourcePeer: .user(peer),
                            commissionPermille: starRefProgram.commissionPermille,
                            programDuration: starRefProgram.durationMonths,
                            revenuePerUser: starRefProgram.dailyRevenuePerUser?.totalValue ?? 0.0,
                            mode: mode
                        ))
                    })
                }))
            }
        } else if let peer = self.data?.peer {
            let _ = (self.context.sharedContext.makeAffiliateProgramSetupScreenInitialData(context: self.context, peerId: peer.id, mode: .connectedPrograms)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] initialData in
                guard let self else {
                    return
                }
                let controller = self.context.sharedContext.makeAffiliateProgramSetupScreen(context: self.context, initialData: initialData)
                self.controller?.push(controller)
            })
        }
    }
    
    private func editingOpenVerifyAccounts() {
        guard let cachedUserData = self.data?.cachedData as? CachedUserData, let verifierSettings = cachedUserData.botInfo?.verifierSettings else {
            return
        }
        let iconPromise = Promise<TelegramMediaFile?>()
        iconPromise.set(self.context.engine.stickers.resolveInlineStickers(fileIds: [verifierSettings.iconFileId])
        |> map { $0.first?.value })
        
        let controller = self.context.sharedContext.makePeerSelectionController(
            PeerSelectionControllerParams(
                context: self.context,
                filter: [.excludeSecretChats, .excludeRecent, .excludeSavedMessages, .includeSelf, .doNotSearchMessages],
                hasContactSelector: false,
                title: self.presentationData.strings.BotVerification_ChooseChat
            )
        )
        controller.peerSelected = { [weak self, weak controller] peer, _ in
            guard let self else {
                return
            }
            let _ = (iconPromise.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { verifierIcon in
                if let _ = peer.verificationIconFileId {
                    let removeController = removeVerificationAlertController(
                        context: self.context,
                        peer: peer,
                        verifierSettings: verifierSettings,
                        verifierIcon: verifierIcon,
                        completion: {  [weak self, weak controller] in
                            guard let self else {
                                return
                            }
                            controller?.dismiss(animated: true)
                            
                            let _ = (self.context.engine.peers.updateCustomVerification(botId: self.peerId, peerId: peer.id, value: .disabled)
                            |> deliverOnMainQueue).start(completed: { [weak self] in
                                guard let self else {
                                    return
                                }
                                let undoController = UndoOverlayController(
                                    presentationData: self.presentationData,
                                    content: .invitedToVoiceChat(context: self.context, peer: peer, title: nil, text: self.presentationData.strings.BotVerification_Removed(peer.compactDisplayTitle).string, action: nil, duration: 5.0),
                                    elevatedLayout: false,
                                    action: { _ in return true }
                                )
                                self.controller?.present(undoController, in: .window(.root))
                            })
                        }
                    )
                    controller?.present(removeController, in: .window(.root))
                } else {
                    let verifyController = verifyAlertController(
                        context: self.context,
                        updatedPresentationData: nil,
                        peer: peer,
                        verifierSettings: verifierSettings,
                        verifierIcon: verifierIcon,
                        apply: { [weak self, weak controller] value in
                            guard let self else {
                                return
                            }
                            controller?.dismiss(animated: true)
                            
                            let _ = (self.context.engine.peers.updateCustomVerification(botId: self.peerId, peerId: peer.id, value: .enabled(description: value))
                            |> deliverOnMainQueue).start(completed: { [weak self] in
                                guard let self else {
                                    return
                                }
                                let undoController = UndoOverlayController(
                                    presentationData: self.presentationData,
                                    content: .invitedToVoiceChat(context: self.context, peer: peer, title: nil, text: self.presentationData.strings.BotVerification_Added(peer.compactDisplayTitle).string, action: nil, duration: 5.0),
                                    elevatedLayout: false,
                                    action: { _ in return true }
                                )
                                self.controller?.present(undoController, in: .window(.root))
                            })
                        }
                    )
                    controller?.present(verifyController, in: .window(.root))
                }
            })
        }
        self.controller?.push(controller)
    }
    
    private func editingOpenNameColorSetup() {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        if self.peerId == self.context.account.peerId {
            controller.push(UserAppearanceScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData))
        } else if let peer = self.data?.peer, peer is TelegramChannel {
            controller.push(ChannelAppearanceScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, boostStatus: self.boostStatus))
        }
    }
    
    private func editingOpenPersonalChannel() {
        let _ = (PeerSelectionScreen.initialData(context: self.context, channels: self.state.personalChannels)
        |> deliverOnMainQueue).start(next: { [weak self] initialData in
            guard let self else {
                return
            }
            
            self.controller?.push(PeerSelectionScreen(context: self.context, initialData: initialData, updatedPresentationData: self.controller?.updatedPresentationData, completion: { [weak self] channel in
                guard let self else {
                    return
                }
                if initialData.channelId == channel?.peer.id {
                    return
                }
                
                let toastText: String
                var mappedChannel: TelegramPersonalChannel?
                if let channel {
                    mappedChannel = TelegramPersonalChannel(peerId: channel.peer.id, subscriberCount: channel.subscriberCount.flatMap(Int32.init(clamping:)), topMessageId: nil)
                    if initialData.channelId != nil {
                        toastText = self.presentationData.strings.Settings_PersonalChannelUpdatedToast
                    } else {
                        toastText = self.presentationData.strings.Settings_PersonalChannelAddedToast
                    }
                } else {
                    toastText = self.presentationData.strings.Settings_PersonalChannelRemovedToast
                }
                let _ = self.context.engine.accountData.updatePersonalChannel(personalChannel: mappedChannel).startStandalone()
                
                self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .actionSucceeded(title: nil, text: toastText, cancel: nil, destructive: false), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }))
        })
    }
        
    private func editingOpenInviteLinksSetup() {
        self.controller?.push(inviteLinkListController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, admin: nil))
    }
    
    private func editingOpenDiscussionGroupSetup() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        self.controller?.push(channelDiscussionGroupSetupController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id))
    }
    
    private func editingOpenPostSuggestionsSetup() {
        if #available(iOS 13.0, *) {
            guard let data = self.data, let peer = data.peer else {
                return
            }
            let context = self.context
            Task { @MainActor [weak self] in
                let postSettingsScreen = await context.sharedContext.makePostSuggestionsSettingsScreen(context: context, peerId: peer.id)
                
                guard let self else {
                    return
                }
                self.controller?.push(postSettingsScreen)
            }
        }
    }
    
    private func editingOpenRevenue() {
        guard let revenueContext = self.data?.revenueStatsContext else {
            return
        }
        let controller = channelStatsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, section: .monetization, existingRevenueContext: revenueContext, boostStatus: nil)
        
        self.controller?.push(controller)
    }
    
    private func editingOpenStars() {
        guard let revenueContext = self.data?.starsRevenueStatsContext else {
            return
        }
        self.controller?.push(self.context.sharedContext.makeStarsStatisticsScreen(context: self.context, peerId: self.peerId, revenueContext: revenueContext))
    }
    
    private func editingOpenReactionsSetup() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
            let subscription = Promise<PeerAllowedReactionsScreen.Content>()
            subscription.set(PeerAllowedReactionsScreen.content(context: self.context, peerId: peer.id))
            let _ = (subscription.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] content in
                guard let self else {
                    return
                }
                self.controller?.push(PeerAllowedReactionsScreen(context: self.context, peerId: peer.id, initialContent: content))
            })
        } else {
            self.controller?.push(peerAllowedReactionListController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id))
        }
    }
    
    private func toggleAutoTranslate(isEnabled: Bool) {
        self.activeActionDisposable.set(self.context.engine.peers.toggleAutoTranslation(peerId: self.peerId, enabled: isEnabled).start())
    }
    
    private func displayAutoTranslateLocked() {
        guard self.autoTranslateDisposable == nil else {
            return
        }
        self.autoTranslateDisposable = combineLatest(
            queue: Queue.mainQueue(),
            context.engine.peers.getChannelBoostStatus(peerId: self.peerId),
            context.engine.peers.getMyBoostStatus()
        ).startStandalone(next: { [weak self] boostStatus, myBoostStatus in
            guard let self, let controller = self.controller, let boostStatus, let myBoostStatus else {
                return
            }
            let boostController = self.context.sharedContext.makePremiumBoostLevelsController(context: self.context, peerId: self.peerId, subject: .autoTranslate, boostStatus: boostStatus, myBoostStatus: myBoostStatus, forceDark: false, openStats: { [weak self] in
                if let self {
                    self.openStats(section: .boosts, boostStatus: boostStatus)
                }
            })
            controller.push(boostController)
            
            self.autoTranslateDisposable?.dispose()
            self.autoTranslateDisposable = nil
        })
    }
    
    private func openForumSettings() {
        guard let controller = self.controller else {
            return
        }
        let settingsController = self.context.sharedContext.makeForumSettingsScreen(context: self.context, peerId: self.peerId)
        controller.push(settingsController)
    }
    
    private func toggleForumTopics(isEnabled: Bool) {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        if peer is TelegramGroup {
            if isEnabled {
                let context = self.context
                let signal: Signal<EnginePeer.Id?, NoError> = self.context.engine.peers.convertGroupToSupergroup(peerId: self.peerId, additionalProcessing: { upgradedPeerId -> Signal<Never, NoError> in
                    return context.engine.peers.setChannelForumMode(id: upgradedPeerId, isForum: isEnabled, displayForumAsTabs: false)
                })
                |> map(Optional.init)
                |> `catch` { [weak self] error -> Signal<PeerId?, NoError> in
                    switch error {
                    case .tooManyChannels:
                        Queue.mainQueue().async {
                            self?.controller?.push(oldChannelsController(context: context, intent: .upgrade))
                        }
                    default:
                        break
                    }
                    return .single(nil)
                }
                |> mapToSignal { upgradedPeerId -> Signal<PeerId?, NoError> in
                    guard let upgradedPeerId = upgradedPeerId else {
                        return .single(nil)
                    }
                    return .single(upgradedPeerId)
                }
                |> deliverOnMainQueue
                
                let _ = signal.startStandalone(next: { [weak self] resultPeerId in
                    guard let self else {
                        return
                    }
                    guard let resultPeerId else {
                        return
                    }
                    
                    let _ = (self.context.engine.peers.setChannelForumMode(id: resultPeerId, isForum: isEnabled, displayForumAsTabs: false)
                    |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        /*if let navigationController = controller.navigationController as? NavigationController {
                            rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController)
                        }*/
                        controller.dismiss()
                    })
                })
            }
        } else {
            let _ = self.context.engine.peers.setChannelForumMode(id: self.peerId, isForum: isEnabled, displayForumAsTabs: false).startStandalone()
        }
    }
        
    private func openParticipantsSection(section: PeerInfoParticipantsSection) {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        switch section {
        case .members:
            self.controller?.push(channelMembersController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId))
        case .admins:
            if peer is TelegramGroup {
                self.controller?.push(channelAdminsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId))
            } else if peer is TelegramChannel {
                self.controller?.push(channelAdminsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId))
            }
        case .banned:
            self.controller?.push(channelBlacklistController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId))
        case .memberRequests:
            self.controller?.push(inviteRequestsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, existingContext: self.data?.requestsContext))
        }
    }
    
    private func openRecentActions() {
        guard let peer = self.data?.peer else {
            return
        }
        let controller = self.context.sharedContext.makeChatRecentActionsController(context: self.context, peer: peer, adminPeerId: nil, starsState: self.data?.starsRevenueStatsState)
        self.controller?.push(controller)
    }
    
    private func openChannelMessages() {
        guard let channel = self.data?.peer as? TelegramChannel, let linkedMonoforumId = channel.linkedMonoforumId else {
            return
        }
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: linkedMonoforumId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
            }
        })
    }
    
    private func editingOpenPreHistorySetup() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        var upgradedToSupergroupImpl: (() -> Void)?
        let controller = groupPreHistorySetupController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, upgradedToSupergroup: { _, f in
            upgradedToSupergroupImpl?()
            f()
        })
        self.controller?.push(controller)
        
        upgradedToSupergroupImpl = { [weak controller] in
            if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController)
            }
        }
    }
    
    private func editingOpenAutoremoveMesages() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        
        let controller = peerAutoremoveSetupScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id)
        self.controller?.push(controller)
    }
    
    private func openPermissions() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        self.controller?.push(channelPermissionsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id))
    }
    
    private func editingOpenStickerPackSetup() {
        guard let data = self.data, let peer = data.peer, let cachedData = data.cachedData as? CachedChannelData else {
            return
        }
        self.controller?.push(groupStickerPackSetupController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, currentPackInfo: cachedData.stickerPack))
    }
    
    private func openLocation() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        
        var location: PeerGeoLocation?
        if let cachedData = data.cachedData as? CachedChannelData, let locationValue = cachedData.peerGeoLocation {
            location = locationValue
        } else if let cachedData = data.cachedData as? CachedUserData, let businessLocation = cachedData.businessLocation, let coordinates = businessLocation.coordinates {
            location = PeerGeoLocation(latitude: coordinates.latitude, longitude: coordinates.longitude, address: businessLocation.address)
        }
        
        guard let location else {
            return
        }
        
        let context = self.context
        let presentationData = self.presentationData
        let map = TelegramMediaMap(latitude: location.latitude, longitude: location.longitude, heading: nil, accuracyRadius: nil, venue: MapVenue(title: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), address: location.address, provider: nil, id: nil, type: nil), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
        
        let controllerParams = LocationViewParams(sendLiveLocation: { _ in
        }, stopLiveLocation: { _ in
        }, openUrl: { url in
            context.sharedContext.applicationBindings.openUrl(url)
        }, openPeer: { _ in
        }, showAll: false)
        
        let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: peer, text: "", attributes: [], media: [map], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        
        let controller = LocationViewController(context: context, updatedPresentationData: self.controller?.updatedPresentationData, subject: EngineMessage(message), params: controllerParams)
        self.controller?.push(controller)
    }
    
    private func editingOpenSetupLocation() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        
        let controller = LocationPickerController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, mode: .pick, completion: { [weak self] location, _, _, address, _ in
            guard let strongSelf = self else {
                return
            }
            let addressSignal: Signal<String, NoError>
            if let address = address {
                addressSignal = .single(address)
            } else {
                addressSignal = reverseGeocodeLocation(latitude: location.latitude, longitude: location.longitude)
                |> map { placemark in
                    if let placemark = placemark {
                        return placemark.fullAddress
                    } else {
                        return "\(location.latitude), \(location.longitude)"
                    }
                }
            }
            
            let context = strongSelf.context
            let _ = (addressSignal
            |> mapToSignal { address -> Signal<Bool, NoError> in
                return updateChannelGeoLocation(postbox: context.account.postbox, network: context.account.network, channelId: peer.id, coordinate: (location.latitude, location.longitude), address: address)
            }
            |> deliverOnMainQueue).startStandalone()
        })
        self.controller?.push(controller)
    }
    
    private func openPeerInfo(peer: Peer, isMember: Bool) {
        var mode: PeerInfoControllerMode = .generic
        if isMember {
            mode = .group(self.peerId)
        }
        if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: peer, mode: mode, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
            (self.controller?.navigationController as? NavigationController)?.pushViewController(infoController)
        }
    }
    
    private func performMemberAction(member: PeerInfoMember, action: PeerInfoMemberAction) {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        switch action {
        case .promote:
            if case let .channelMember(channelMember, _) = member {
                var upgradedToSupergroupImpl: (() -> Void)?
                let controller = channelAdminController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, adminId: member.id, initialParticipant: channelMember.participant, updated: { _ in
                }, upgradedToSupergroup: { _, f in
                    upgradedToSupergroupImpl?()
                    f()
                }, transferedOwnership: { _ in })
                
                self.controller?.push(controller)
                
                upgradedToSupergroupImpl = { [weak controller] in
                    if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                        rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController)
                    }
                }
            }
        case .restrict:
            if case let .channelMember(channelMember, _) = member {
                var upgradedToSupergroupImpl: (() -> Void)?
                
                let controller = channelBannedMemberController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, memberId: member.id, initialParticipant: channelMember.participant, updated: { _ in
                }, upgradedToSupergroup: { _, f in
                    upgradedToSupergroupImpl?()
                    f()
                })
                
                self.controller?.push(controller)
                
                upgradedToSupergroupImpl = { [weak controller] in
                    if let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                        rebuildControllerStackAfterSupergroupUpgrade(controller: controller, navigationController: navigationController)
                    }
                }
            }
        case .remove:
            data.members?.membersContext.removeMember(memberId: member.id)
        case let .openStories(sourceView):
            guard let controller = self.controller else {
                return
            }
            if let avatarNode = sourceView.asyncdisplaykit_node as? AvatarNode {
                StoryContainerScreen.openPeerStories(context: self.context, peerId: member.id, parentController: controller, avatarNode: avatarNode)
                return
            }
            let storyContent = StoryContentContextImpl(context: self.context, isHidden: false, focusedPeerId: member.id, singlePeer: true)
            let _ = (storyContent.state
            |> filter { $0.slice != nil }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self, weak sourceView] _ in
                guard let self else {
                    return
                }
                
                var transitionIn: StoryContainerScreen.TransitionIn?
                if let sourceView {
                    transitionIn = StoryContainerScreen.TransitionIn(
                        sourceView: sourceView,
                        sourceRect: sourceView.bounds,
                        sourceCornerRadius: sourceView.bounds.width * 0.5,
                        sourceIsAvatar: false
                    )
                    sourceView.isHidden = true
                }
                
                let storyContainerScreen = StoryContainerScreen(
                    context: self.context,
                    content: storyContent,
                    transitionIn: transitionIn,
                    transitionOut: { peerId, _ in
                        if let sourceView {
                            let destinationView = sourceView
                            return StoryContainerScreen.TransitionOut(
                                destinationView: destinationView,
                                transitionView: StoryContainerScreen.TransitionView(
                                    makeView: { [weak destinationView] in
                                        let parentView = UIView()
                                        if let copyView = destinationView?.snapshotContentTree(unhide: true) {
                                            parentView.addSubview(copyView)
                                        }
                                        return parentView
                                    },
                                    updateView: { copyView, state, transition in
                                        guard let view = copyView.subviews.first else {
                                            return
                                        }
                                        let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                        transition.setPosition(view: view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                                        transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                    },
                                    insertCloneTransitionView: nil
                                ),
                                destinationRect: destinationView.bounds,
                                destinationCornerRadius: destinationView.bounds.width * 0.5,
                                destinationIsAvatar: false,
                                completed: { [weak sourceView] in
                                    guard let sourceView else {
                                        return
                                    }
                                    sourceView.isHidden = false
                                }
                            )
                        } else {
                            return nil
                        }
                    }
                )
                self.controller?.push(storyContainerScreen)
            })
        }
    }
    
    private func openPeerInfoContextMenu(subject: PeerInfoContextSubject, sourceNode: ASDisplayNode, sourceRect: CGRect?) {
        guard let data = self.data, let peer = data.peer, let controller = self.controller else {
            return
        }
        let context = self.context
        switch subject {
        case .birthday:
            if let cachedData = data.cachedData as? CachedUserData, let birthday = cachedData.birthday {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text = stringForCompactBirthday(birthday, strings: presentationData.strings)
                
                let actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                    UIPasteboard.general.string = text
                    
                    self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                })]
                let contextMenuController = makeContextMenuController(actions: actions)
                controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                    if let controller = self?.controller, let sourceNode = sourceNode {
                        var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                        if let sourceRect = sourceRect {
                            rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                        }
                        return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
        case .bio:
            var text: String?
            if let cachedData = data.cachedData as? CachedUserData {
                text = cachedData.about
            } else if let cachedData = data.cachedData as? CachedGroupData {
                text = cachedData.about
            } else if let cachedData = data.cachedData as? CachedChannelData {
                text = cachedData.about
            }
            if let text = text, !text.isEmpty {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] sharedData in
                    let translationSettings: TranslationSettings
                    if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                        translationSettings = current
                    } else {
                        translationSettings = TranslationSettings.defaultSettings
                    }
                    
                    var actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                        UIPasteboard.general.string = text
                        
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    })]
                    
                    let (canTranslate, language) = canTranslateText(context: context, text: text, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
                    if canTranslate {
                        actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuTranslate, accessibilityLabel: presentationData.strings.Conversation_ContextMenuTranslate), action: { [weak self] in
                            
                            let controller = TranslateScreen(context: context, text: text, canCopy: true, fromLanguage: language, ignoredLanguages: translationSettings.ignoredLanguages)
                            controller.pushController = { [weak self] c in
                                (self?.controller?.navigationController as? NavigationController)?._keepModalDismissProgress = true
                                self?.controller?.push(c)
                            }
                            controller.presentController = { [weak self] c in
                                self?.controller?.present(c, in: .window(.root))
                            }
                            self?.controller?.present(controller, in: .window(.root))
                        }))
                    }
                    
                    let contextMenuController = makeContextMenuController(actions: actions)
                    controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                        if let controller = self?.controller, let sourceNode = sourceNode {
                            var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                            if let sourceRect = sourceRect {
                                rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                            }
                            return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                        } else {
                            return nil
                        }
                    }))
                })
            }
        case let .phone(phone):
            let contextMenuController = makeContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = phone
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })])
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                    if let sourceRect = sourceRect {
                        rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                    }
                    return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        case let .link(customLink):
            let text: String
            let content: UndoOverlayContent
            if let customLink = customLink {
                text = customLink
                content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
            } else if let addressName = peer.addressName {
                if peer is TelegramChannel {
                    text = "https://t.me/\(addressName)"
                    content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
                } else {
                    text = "@" + addressName
                    content = .copy(text: self.presentationData.strings.Conversation_UsernameCopied)
                }
            } else {
                text = "https://t.me/@id\(peer.id.id._internalGetInt64Value())"
                content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
            }
        
            let contextMenuController = makeContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = text
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })])
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                    if let sourceRect = sourceRect {
                        rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                    }
                    return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        case .businessHours(let text), .businessLocation(let text):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
            let actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = text
                
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })]
            
            let contextMenuController = makeContextMenuController(actions: actions)
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                    if let sourceRect = sourceRect {
                        rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                    }
                    return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        }
    }
    
    private func performBioLinkAction(action: TextLinkItemActionType, item: TextLinkItem) {
        guard let data = self.data, let peer = data.peer, let controller = self.controller else {
            return
        }
        self.context.sharedContext.handleTextLinkAction(context: self.context, peerId: peer.id, navigateDisposable: self.resolveUrlDisposable, controller: controller, action: action, itemLink: item)
    }
    
    private func requestLayout(animated: Bool = false) {
        self.headerNode.requestUpdateLayout?(animated)
    }
    
    private func openDeletePeer() {
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.peerId))
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            var isGroup = false
            if case let .channel(channel) = peer {
                if case .group = channel.info {
                    isGroup = true
                }
            } else if case .legacyGroup = peer {
                isGroup = true
            }
            let presentationData = strongSelf.presentationData
            let actionSheet = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            }
            
            let title: String
            let text: String
            if isGroup {
                title = strongSelf.presentationData.strings.PeerInfo_DeleteGroupTitle
                text = strongSelf.presentationData.strings.PeerInfo_DeleteGroupText(peer.debugDisplayTitle).string
            } else {
                title = strongSelf.presentationData.strings.PeerInfo_DeleteChannelTitle
                text = strongSelf.presentationData.strings.PeerInfo_DeleteChannelText(peer.debugDisplayTitle).string
            }
            
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: text),
                    ActionSheetButtonItem(title: title, color: .destructive, action: {
                        dismissAction()
                        self?.deletePeerChat(peer: peer._asPeer(), globally: true)
                    }),
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            strongSelf.view.endEditing(true)
            strongSelf.controller?.present(actionSheet, in: .window(.root))
        })
    }
    
    private func openLeavePeer(delete: Bool) {
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.peerId))
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            
            var isGroup = false
            if case let .channel(channel) = peer {
                if case .group = channel.info {
                    isGroup = true
                }
            } else if case .legacyGroup = peer {
                isGroup = true
            }
            
            let title: String
            let text: String
            let actionText: String
            
            if delete {
                if isGroup {
                    title = strongSelf.presentationData.strings.PeerInfo_DeleteGroupTitle
                    text = strongSelf.presentationData.strings.PeerInfo_DeleteGroupText(peer.debugDisplayTitle).string
                } else {
                    title = strongSelf.presentationData.strings.PeerInfo_DeleteChannelTitle
                    text = strongSelf.presentationData.strings.PeerInfo_DeleteChannelText(peer.debugDisplayTitle).string
                }
                actionText = strongSelf.presentationData.strings.Common_Delete
            } else {
                if isGroup {
                    title = strongSelf.presentationData.strings.PeerInfo_LeaveGroupTitle
                    text = strongSelf.presentationData.strings.PeerInfo_LeaveGroupText(peer.debugDisplayTitle).string
                } else {
                    title = strongSelf.presentationData.strings.PeerInfo_LeaveChannelTitle
                    text = strongSelf.presentationData.strings.PeerInfo_LeaveChannelText(peer.debugDisplayTitle).string
                }
                actionText = strongSelf.presentationData.strings.PeerInfo_AlertLeaveAction
            }
            
            strongSelf.view.endEditing(true)
            
            strongSelf.controller?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: title, text: text, actions: [
                TextAlertAction(type: .destructiveAction, title: actionText, action: {
                    self?.deletePeerChat(peer: peer._asPeer(), globally: delete)
                }),
                TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                })
            ], parseMarkdown: true), in: .window(.root))
        })
    }
    
    private func deletePeerChat(peer: Peer, globally: Bool) {
        guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }
        guard let tabController = navigationController.viewControllers.first as? TabBarController else {
            return
        }
        for childController in tabController.controllers {
            if let chatListController = childController as? ChatListController {
                chatListController.maybeAskForPeerChatRemoval(peer: EngineRenderedPeer(peer: EnginePeer(peer)), joined: false, deleteGloballyIfPossible: globally, completion: { [weak navigationController] deleted in
                    if deleted {
                        navigationController?.popToRoot(animated: true)
                    }
                }, removed: {
                })
                break
            }
        }
    }
    
    func deleteProfilePhoto(_ item: PeerInfoAvatarListItem) {
        let dismiss = self.headerNode.avatarListNode.listContainerNode.deleteItem(item)
        if dismiss {
            if self.headerNode.isAvatarExpanded {
                self.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
                self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
            }
            if let (layout, navigationHeight) = self.validLayout {
                self.scrollNode.view.setContentOffset(CGPoint(), animated: false)
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
        }
    }
    
    func oldOpenAvatarForEditing(mode: PeerInfoAvatarEditingMode = .generic, fromGallery: Bool = false, completion: @escaping (UIImage?) -> Void = { _ in }) {
        guard let peer = self.data?.peer, mode != .generic || canEditPeerInfo(context: self.context, peer: peer, chatLocation: self.chatLocation, threadData: self.data?.threadData) else {
            return
        }
        
        self.view.endEditing(true)
        
        var currentIsVideo = false
        var emojiMarkup: TelegramMediaImage.EmojiMarkup?
        let item = self.headerNode.avatarListNode.listContainerNode.currentItemNode?.item
        if let item = item, case let .image(_, _, videoRepresentations, _, _, emojiMarkupValue) = item {
            currentIsVideo = !videoRepresentations.isEmpty
            emojiMarkup = emojiMarkupValue
        }
        let _ = emojiMarkup
        
        let peerId = self.peerId
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.Configuration.SearchBots()
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, searchBotsConfiguration in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            
            let presentationData = strongSelf.presentationData
        
            var hasPhotos = false
            if !peer.profileImageRepresentations.isEmpty {
                hasPhotos = true
            }
            
            var isForum = false
            if let peer = strongSelf.data?.peer as? TelegramChannel, peer.isForumOrMonoForum {
                isForum = true
            }
            
            var hasDeleteButton = false
            if case .generic = mode {
                hasDeleteButton = hasPhotos && !fromGallery
            } else if case .custom = mode {
                hasDeleteButton = peer.profileImageRepresentations.first?.isPersonal == true
            } else if case .fallback = mode {
                if let cachedData = strongSelf.data?.cachedData as? CachedUserData, case let .known(photo) = cachedData.fallbackPhoto {
                    hasDeleteButton = photo != nil
                }
            }
            
            let title: String?
            let confirmationTextPhoto: String?
            let confirmationTextVideo: String?
            let confirmationAction: String?
            switch mode {
            case .suggest:
                title = strongSelf.presentationData.strings.UserInfo_SuggestPhotoTitle(peer.compactDisplayTitle).string
                confirmationTextPhoto = strongSelf.presentationData.strings.UserInfo_SuggestPhoto_AlertPhotoText(peer.compactDisplayTitle).string
                confirmationTextVideo = strongSelf.presentationData.strings.UserInfo_SuggestPhoto_AlertVideoText(peer.compactDisplayTitle).string
                confirmationAction = strongSelf.presentationData.strings.UserInfo_SuggestPhoto_AlertSuggest
            case .custom:
                title = strongSelf.presentationData.strings.UserInfo_SetCustomPhotoTitle(peer.compactDisplayTitle).string
                confirmationTextPhoto = strongSelf.presentationData.strings.UserInfo_SetCustomPhoto_AlertPhotoText(peer.compactDisplayTitle, peer.compactDisplayTitle).string
                confirmationTextVideo = strongSelf.presentationData.strings.UserInfo_SetCustomPhoto_AlertVideoText(peer.compactDisplayTitle, peer.compactDisplayTitle).string
                confirmationAction = strongSelf.presentationData.strings.UserInfo_SetCustomPhoto_AlertSet
            default:
                title = nil
                confirmationTextPhoto = nil
                confirmationTextVideo = nil
                confirmationAction = nil
            }
            
            let keyboardInputData = Promise<AvatarKeyboardInputData>()
            keyboardInputData.set(AvatarEditorScreen.inputData(context: strongSelf.context, isGroup: peer.id.namespace != Namespaces.Peer.CloudUser))
            
            let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
            legacyController.statusBar.statusBarStyle = .Ignore
            
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
            
            legacyController.bind(controller: navigationController)
            
            let parentController = (strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController)?.topViewController as? ViewController
            parentController?.present(legacyController, in: .window(.root))
            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasDeleteButton, hasViewButton: false, personalPhoto: strongSelf.isSettings || strongSelf.isMyProfile, isVideo: currentIsVideo, saveEditedPhotos: false, saveCapturedMedia: false, signup: false, forum: isForum, title: title, isSuggesting: [.custom, .suggest].contains(mode))!
            mixin.stickersContext = LegacyPaintStickersContext(context: strongSelf.context)
            let _ = strongSelf.currentAvatarMixin.swap(mixin)
            let isFromEditor = !"".isEmpty
//            mixin.requestAvatarEditor = { [weak self, weak parentController] imageCompletion, videoCompletion in
//                guard let strongSelf = self, let imageCompletion, let videoCompletion else {
//                    return
//                }
//                let peerType: AvatarEditorScreen.PeerType
//                if mode == .suggest {
//                    peerType = .suggest
//                } else if case .legacyGroup = peer {
//                    peerType = .group
//                } else if case let .channel(channel) = peer {
//                    if case .group = channel.info {
//                        peerType = channel.flags.contains(.isForum) ? .forum : .group
//                    } else {
//                        peerType = .channel
//                    }
//                } else {
//                    peerType = .user
//                }
//                let controller = AvatarEditorScreen(context: strongSelf.context, inputData: keyboardInputData.get(), peerType: peerType, markup: emojiMarkup)
//                controller.imageCompletion = imageCompletion
//                controller.videoCompletion = videoCompletion
//                parentController?.push(controller)
//                isFromEditor = true
//            }

            if let confirmationTextPhoto, let confirmationAction {
                mixin.willFinishWithImage = { [weak self, weak parentController] image, commit in
                    if let strongSelf = self, let image {
                        let controller = photoUpdateConfirmationController(context: strongSelf.context, peer: peer, image: image, text: confirmationTextPhoto, doneTitle: confirmationAction, commit: {
                            commit?()
                        })
                        parentController?.presentInGlobalOverlay(controller)
                    }
                }
            }
            if let confirmationTextVideo, let confirmationAction {
                mixin.willFinishWithVideo = { [weak self, weak parentController] image, commit in
                    if let strongSelf = self, let image {
                        let controller = photoUpdateConfirmationController(context: strongSelf.context, peer: peer, image: image, text: confirmationTextVideo, doneTitle: confirmationAction, isDark: !isFromEditor, commit: {
                            commit?()
                        })
                        parentController?.presentInGlobalOverlay(controller)
                    }
                }
            }
            mixin.didFinishWithImage = { [weak self] image in
                if let image = image {
                    completion(image)
                    self?.controller?.updateProfilePhoto(image, mode: mode, uploadStatus: nil)
                }
            }
//            mixin.didFinishWithVideo = { [weak self] image, asset, adjustments, _ in
//                if let image = image, let asset = asset {
//                    completion(image)
//                    self?.controller?.updateProfileVideo(image, asset: asset, adjustments: adjustments, mode: mode)
//                }
//            }
            mixin.didFinishWithDelete = {
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.controller?.openAvatarRemoval(mode: mode, peer: peer, item: item)
            }
            mixin.didDismiss = { [weak legacyController] in
                guard let strongSelf = self else {
                    return
                }
                let _ = strongSelf.currentAvatarMixin.swap(nil)
                legacyController?.dismiss()
            }
            let menuController = mixin.present()
            if let menuController = menuController {
                menuController.customRemoveFromParentViewController = { [weak legacyController] in
                    legacyController?.dismiss()
                }
            }
        })
    }
    
    private func openAddMember() {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        guard let data = self.data, let groupPeer = data.peer else {
            return
        }
        
        presentAddMembersImpl(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, parentController: controller, groupPeer: groupPeer, selectAddMemberDisposable: self.selectAddMemberDisposable, addMemberDisposable: self.addMemberDisposable)
    }
    
    private func openQrCode() {
        guard let data = self.data, let peer = data.peer, let controller = self.controller else {
            return
        }
        
        var threadId: Int64?
        if case let .replyThread(message) = self.chatLocation {
            threadId = message.threadId
        }
        
        var temporary = false
        if (self.isSettings || self.isMyProfile) && self.data?.globalSettings?.privacySettings?.phoneDiscoveryEnabled == false && (self.data?.peer?.addressName ?? "").isEmpty {
            temporary = true
        }
        let qrController = self.context.sharedContext.makeChatQrCodeScreen(context: self.context, peer: peer, threadId: threadId, temporary: temporary)
        controller.push(qrController)
    }
    
    private func openPremiumGift() {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        let premiumGiftOptions = self.data?.premiumGiftOptions ?? []
        let premiumOptions = premiumGiftOptions.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
    
        var hasBirthday = false
        if let cachedUserData = self.data?.cachedData as? CachedUserData {
            hasBirthday = hasBirthdayToday(cachedData: cachedUserData)
        }
        
        let giftsController = self.context.sharedContext.makeGiftOptionsController(
            context: self.context,
            peerId: self.peerId,
            premiumOptions: premiumOptions,
            hasBirthday: hasBirthday,
            completion: { [weak self] in
                guard let self, let profileGiftsContext = self.data?.profileGiftsContext else {
                    return
                }
                Queue.mainQueue().after(0.5) {
                    profileGiftsContext.reload()
                }
            }
        )
        controller.push(giftsController)
    }
    
    private func openBotPreviewEditor(target: Stories.PendingTarget, source: Any, transitionIn: (UIView, CGRect, UIImage?)?) {
        let context = self.context

        let externalState = MediaEditorTransitionOutExternalState(
            storyTarget: target,
            isForcedTarget: false,
            isPeerArchived: false,
            transitionOut: nil
        )
        
        let controller = context.sharedContext.makeBotPreviewEditorScreen(
            context: context,
            source: source,
            target: target,
            transitionArguments: transitionIn,
            transitionOut: { [weak self] in
                guard let self else {
                    return nil
                }
                
                if let pane = self.paneContainerNode.currentPane?.node as? PeerInfoStoryPaneNode, let transitionView = pane.extractPendingStoryTransitionView() {
                    return BotPreviewEditorTransitionOut(
                        destinationView: transitionView,
                        destinationRect: transitionView.bounds,
                        destinationCornerRadius: 0.0,
                        completion: { [weak transitionView] in
                            transitionView?.removeFromSuperview()
                        }
                    )
                }
                
                return nil
            },
            externalState: externalState,
            completion: { result, commit in
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    var viewControllers = rootController.viewControllers
                    viewControllers = viewControllers.filter { !($0 is AttachmentController)}
                    rootController.setViewControllers(viewControllers, animated: false)
                    
                    rootController.proceedWithStoryUpload(target: target, results: [result], existingMedia: nil, forwardInfo: nil, externalState: externalState, commit: commit)
                }
            },
            cancelled: {}
        )
        self.controller?.push(controller)
    }
    
    private func openPostStory(sourceFrame: CGRect?) {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        self.postingAvailabilityDisposable?.dispose()
        
        if let data = self.data, let user = data.peer as? TelegramUser, let botInfo = user.botInfo {
            if !botInfo.flags.contains(.canEdit) {
                return
            }
            let storyController = self.context.sharedContext.makeStoryMediaPickerScreen(
                context: self.context,
                isDark: false,
                forCollage: false,
                selectionLimit: nil,
                getSourceRect: { return .zero },
                completion: { [weak self] result, transitionView, transitionRect, transitionImage, transitionOut, dismissed in
                    guard let self else {
                        return
                    }
                    
                    guard let pane = self.paneContainerNode.currentPane?.node as? PeerInfoStoryPaneNode else {
                        return
                    }
                    
                    self.openBotPreviewEditor(target: .botPreview(id: self.peerId, language: pane.currentBotPreviewLanguage?.id), source: result, transitionIn: (transitionView, transitionRect, transitionImage))
                },
                multipleCompletion: { _, _ in },
                dismissed: {},
                groupsPresented: {}
            )
            controller.push(storyController)
        } else {
            let canPostStatus: Signal<StoriesUploadAvailability, NoError>
            canPostStatus = self.context.engine.messages.checkStoriesUploadAvailability(target: .peer(self.peerId))
            
            self.postingAvailabilityDisposable = (canPostStatus
            |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                guard let self else {
                    return
                }
                switch status {
                case .available:
                    var cameraTransitionIn: StoryCameraTransitionIn?
                    if let rightButton = self.headerNode.navigationButtonContainer.rightButtonNodes[.postStory] {
                        cameraTransitionIn = StoryCameraTransitionIn(
                            sourceView: rightButton.view,
                            sourceRect: rightButton.view.bounds,
                            sourceCornerRadius: rightButton.view.bounds.height * 0.5,
                            useFillAnimation: false
                        )
                    }
                    
                    if let rootController = self.context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                        let coordinator = rootController.openStoryCamera(customTarget: self.peerId == self.context.account.peerId ? nil : .peer(self.peerId), transitionIn: cameraTransitionIn, transitionedIn: {}, transitionOut: self.storyCameraTransitionOut())
                        coordinator?.animateIn()
                    }
                case .channelBoostRequired:
                    self.postingAvailabilityDisposable?.dispose()
                    
                    self.postingAvailabilityDisposable = combineLatest(
                        queue: Queue.mainQueue(),
                        self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.peerId)),
                        self.context.engine.peers.getChannelBoostStatus(peerId: self.peerId),
                        self.context.engine.peers.getMyBoostStatus()
                    ).startStrict(next: { [weak self] peer, boostStatus, myBoostStatus in
                        guard let self, let peer, let boostStatus, let myBoostStatus else {
                            return
                        }
                        
                        if let navigationController = self.controller?.navigationController as? NavigationController {
                            if let previousController = navigationController.viewControllers.last as? ShareWithPeersScreen {
                                previousController.dismiss()
                            }
                            let controller = self.context.sharedContext.makePremiumBoostLevelsController(context: self.context, peerId: peer.id, subject: .stories, boostStatus: boostStatus, myBoostStatus: myBoostStatus, forceDark: false, openStats: { [weak self] in
                                if let self {
                                    self.openStats(section: .boosts, boostStatus: boostStatus)
                                }
                            })
                            navigationController.pushViewController(controller)
                        }
                        
                        self.hapticFeedback.impact(.light)
                    }).strict()
                case .premiumRequired, .monthlyLimit, .weeklyLimit, .expiringLimit:
                    if let sourceFrame {
                        let context = self.context
                        let location = CGRect(origin: CGPoint(x: sourceFrame.midX, y: sourceFrame.maxY), size: CGSize())
                        
                        let text: String
                        text = self.presentationData.strings.StoryFeed_TooltipPremiumPostingLimited
                        
                        let tooltipController = TooltipScreen(
                            context: context,
                            account: context.account,
                            sharedContext: context.sharedContext,
                            text: .markdown(text: text),
                            style: .customBlur(UIColor(rgb: 0x2a2a2a), 2.0),
                            icon: .none,
                            location: .point(location, .top),
                            shouldDismissOnTouch: { [weak self] point, containerFrame in
                                if containerFrame.contains(point) {
                                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .stories, forceDark: false, dismissed: nil)
                                    self?.controller?.push(controller)
                                    return .dismiss(consume: true)
                                } else {
                                    return .dismiss(consume: false)
                                }
                            }
                        )
                        self.controller?.present(tooltipController, in: .current)
                    }
                default:
                    break
                }
            }).strict()
        }
    }
    
    private func storyCameraTransitionOut() -> (Stories.PendingTarget?, Bool) -> StoryCameraTransitionOut? {
        return { [weak self] target, _ in
            guard let self else {
                return nil
            }
            
            if let data = self.data, let user = data.peer as? TelegramUser, let _ = user.botInfo {
                if let pane = self.paneContainerNode.currentPane?.node as? PeerInfoStoryPaneNode, let transitionView = pane.extractPendingStoryTransitionView() {
                    return StoryCameraTransitionOut(
                        destinationView: transitionView,
                        destinationRect: transitionView.bounds,
                        destinationCornerRadius: 0.0,
                        completion: { [weak transitionView] in
                            transitionView?.removeFromSuperview()
                        }
                    )
                }
                
                return nil
            } else {
                if !self.headerNode.isAvatarExpanded {
                    let transitionView = self.headerNode.avatarListNode.avatarContainerNode.avatarNode.contentNode.view
                    return StoryCameraTransitionOut(
                        destinationView: transitionView,
                        destinationRect: transitionView.bounds,
                        destinationCornerRadius: transitionView.bounds.height * 0.5
                    )
                }
                
                return nil
            }
        }
    }
    
    fileprivate func openSettings(section: PeerInfoSettingsSection) {
        let push: (ViewController) -> Void = { [weak self] c in
            guard let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController else {
                return
            }
            
            if strongSelf.isMyProfile {
                navigationController.pushViewController(c)
            } else {
                var updatedControllers = navigationController.viewControllers
                for controller in navigationController.viewControllers.reversed() {
                    if controller !== strongSelf && !(controller is TabBarController) {
                        updatedControllers.removeLast()
                    } else {
                        break
                    }
                }
                updatedControllers.append(c)
                
                var animated = true
                if let validLayout = strongSelf.validLayout?.0, case .regular = validLayout.metrics.widthClass {
                    animated = false
                }
                navigationController.setViewControllers(updatedControllers, animated: animated)
            }
        }
        switch section {
        case .avatar:
            self.controller?.openAvatarForEditing()
        case .edit:
            self.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
        case .proxy:
            self.controller?.push(proxySettingsController(context: self.context))
        case .profile:
            self.controller?.push(PeerInfoScreenImpl(
                context: self.context,
                updatedPresentationData: self.controller?.updatedPresentationData,
                peerId: self.context.account.peerId,
                avatarInitiallyExpanded: false,
                isOpenedFromChat: false,
                nearbyPeerDistance: nil,
                reactionSourceMessageId: nil,
                callMessages: [],
                isMyProfile: true,
                profileGiftsContext: self.data?.profileGiftsContext
            ))
        case .stories:
            push(PeerInfoStoryGridScreen(context: self.context, peerId: self.context.account.peerId, scope: .saved))
        case .savedMessages:
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                guard let self, let peer = peer else {
                    return
                }
                if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
                }
            })
        case .recentCalls:
            push(CallListController(context: context, mode: .navigation))
        case .devices:
            let _ = (self.activeSessionsContextAndCount.get()
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] activeSessionsContextAndCount in
                if let strongSelf = self, let activeSessionsContextAndCount = activeSessionsContextAndCount {
                    let (activeSessionsContext, _, webSessionsContext) = activeSessionsContextAndCount
                    push(recentSessionsController(context: strongSelf.context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext, websitesOnly: false))
                }
            })
        case .chatFolders:
            let controller = self.context.sharedContext.makeFilterSettingsController(context: self.context, modal: false, scrollToTags: false, dismissed: nil)
            push(controller)
        case .notificationsAndSounds:
            if let settings = self.data?.globalSettings {
                push(notificationsAndSoundsController(context: self.context, exceptionsList: settings.notificationExceptions))
            }
        case .privacyAndSecurity:
            if let settings = self.data?.globalSettings {
                let _ = (combineLatest(self.blockedPeers.get(), self.hasTwoStepAuth.get())
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] blockedPeersContext, hasTwoStepAuth in
                    if let strongSelf = self {
                        let loginEmailPattern = strongSelf.twoStepAuthData.get() |> map { data -> String? in
                            return data?.loginEmailPattern
                        }
                        push(privacyAndSecurityController(context: strongSelf.context, initialSettings: settings.privacySettings, updatedSettings: { [weak self] settings in
                            self?.privacySettings.set(.single(settings))
                        }, updatedBlockedPeers: { [weak self] blockedPeersContext in
                            self?.blockedPeers.set(.single(blockedPeersContext))
                        }, updatedHasTwoStepAuth: { [weak self] hasTwoStepAuthValue in
                            self?.hasTwoStepAuth.set(.single(hasTwoStepAuthValue))
                        }, focusOnItemTag: nil, activeSessionsContext: settings.activeSessionsContext, webSessionsContext: settings.webSessionsContext, blockedPeersContext: blockedPeersContext, hasTwoStepAuth: hasTwoStepAuth, loginEmailPattern: loginEmailPattern, updatedTwoStepAuthData: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.twoStepAuthData.set(
                                    strongSelf.context.engine.auth.twoStepAuthData()
                                    |> map(Optional.init)
                                    |> `catch` { _ -> Signal<TwoStepAuthData?, NoError> in
                                        return .single(nil)
                                    }
                                )
                            }
                        }, requestPublicPhotoSetup: { [weak self] completion in
                            if let self {
                                self.controller?.openAvatarForEditing(mode: .fallback, completion: completion)
                            }
                        }, requestPublicPhotoRemove: { [weak self] completion in
                            if let self {
                                self.controller?.openAvatarRemoval(mode: .fallback, completion: completion)
                            }
                        }))
                    }
                })
            }
        case .passwordSetup:
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.6, execute: { [weak self] in
                guard let self else {
                    return
                }
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.setupPassword.id).startStandalone()
            })
            
            let controller = self.context.sharedContext.makeSetupTwoFactorAuthController(context: self.context)
            push(controller)
        case .dataAndStorage:
            push(dataAndStorageController(context: self.context))
        case .appearance:
            push(themeSettingsController(context: self.context))
        case .language:
            push(LocalizationListController(context: self.context))
        case .premium:
            let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .settings, forceDark: false, dismissed: nil)
            self.controller?.push(controller)
        case .premiumGift:
            guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
                return
            }
            let _ = (self.context.account.stateManager.contactBirthdays
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] birthdays in
                guard let self else {
                    return
                }
                let giftsController = self.context.sharedContext.makePremiumGiftController(context: self.context, source: .settings(birthdays), completion: nil)
                self.controller?.push(giftsController)
            })
        case .stickers:
            if let settings = self.data?.globalSettings {
                push(installedStickerPacksController(context: self.context, mode: .general, archivedPacks: settings.archivedStickerPacks, updatedPacks: { [weak self] packs in
                    self?.archivedPacks.set(.single(packs))
                }))
            }
        case .passport:
            self.controller?.push(SecureIdAuthController(context: self.context, mode: .list))
        case .watch:
            push(watchSettingsController(context: self.context))
        case .support:
            let supportPeer = Promise<PeerId?>()
            supportPeer.set(context.engine.peers.supportPeerId())
            
            self.controller?.present(textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: self.presentationData.strings.Settings_FAQ_Intro, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Settings_FAQ_Button, action: { [weak self] in
                    self?.openFaq()
                }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { [weak self] peerId in
                        if let strongSelf = self, let peerId = peerId {
                            push(strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil))
                        }
                    }))
                })]), in: .window(.root))
        case .faq:
            self.openFaq()
        case .tips:
            self.openTips()
        case .phoneNumber:
            guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
                return
            }
            if let user = self.data?.peer as? TelegramUser, let phoneNumber = user.phone {
                let introController = PrivacyIntroController(context: self.context, mode: .changePhoneNumber(phoneNumber), proceedAction: { [weak self] in
                    if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                        navigationController.replaceTopController(ChangePhoneNumberController(context: strongSelf.context), animated: true)
                    }
                })
                push(introController)
            }
        case .username:
            guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
                return
            }
            push(usernameSetupController(context: self.context))
        case .addAccount:
            let _ = (activeAccountsAndPeers(context: context)
            |> take(1)
            |> deliverOnMainQueue
            ).startStandalone(next: { [weak self] accountAndPeer, accountsAndPeers in
                guard let strongSelf = self else {
                    return
                }
                var maximumAvailableAccounts: Int = 3
                if accountAndPeer?.1.isPremium == true && !strongSelf.context.account.testingEnvironment {
                    maximumAvailableAccounts = 4
                }
                var count: Int = 1
                for (accountContext, peer, _) in accountsAndPeers {
                    if !accountContext.account.testingEnvironment {
                        if peer.isPremium {
                            maximumAvailableAccounts = 4
                        }
                        count += 1
                    }
                }
                
                if count >= maximumAvailableAccounts {
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = PremiumLimitScreen(context: strongSelf.context, subject: .accounts, count: Int32(count), action: {
                        let controller = PremiumIntroScreen(context: strongSelf.context, source: .accounts)
                        replaceImpl?(controller)
                        return true
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                        navigationController.pushViewController(controller)
                    }
                } else {
                    strongSelf.context.sharedContext.beginNewAuth(testingEnvironment: strongSelf.context.account.testingEnvironment)
                }
            })
        case .logout:
            if let user = self.data?.peer as? TelegramUser, let phoneNumber = user.phone {
                if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                    self.controller?.push(logoutOptionsController(context: self.context, navigationController: navigationController, canAddAccounts: true, phoneNumber: phoneNumber))
                }
            }
        case .rememberPassword:
            let context = self.context
            let controller = TwoFactorDataInputScreen(sharedContext: self.context.sharedContext, engine: .authorized(self.context.engine), mode: .rememberPassword(doneText: self.presentationData.strings.TwoFactorSetup_Done_Action), stateUpdated: { _ in
            }, presentation: .modalInLargeLayout)
            controller.twoStepAuthSettingsController = { configuration in
                return twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: false, data: .single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationAccessConfiguration(configuration: configuration, password: nil)))))
            }
            controller.passwordRemembered = {
                let _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.validatePassword.id).startStandalone()
            }
            push(controller)
        case .emojiStatus:
            self.headerNode.invokeDisplayPremiumIntro()
        case .powerSaving:
            push(energySavingSettingsScreen(context: self.context))
        case .businessSetup:
            guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
                return
            }
            push(self.context.sharedContext.makeBusinessSetupScreen(context: self.context))
        case .premiumManagement:
            guard let controller = self.controller else {
                return
            }
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
            let url = premiumConfiguration.subscriptionManagementUrl
            guard !url.isEmpty else {
                return
            }
            self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: !url.hasPrefix("tg://") && !url.contains("?start="), presentationData: self.context.sharedContext.currentPresentationData.with({$0}), navigationController: controller.navigationController as? NavigationController, dismissInput: {})
        case .stars:
            if let starsContext = self.controller?.starsContext {
                push(self.context.sharedContext.makeStarsTransactionsScreen(context: self.context, starsContext: starsContext))
            }
        }
    }
    
    fileprivate func openPaymentMethod() {
        self.controller?.push(AddPaymentMethodSheetScreen(context: self.context, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controller?.push(PaymentCardEntryScreen(context: strongSelf.context, completion: { result in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controller?.push(paymentMethodListScreen(context: strongSelf.context, items: [result]))
            }))
        }))
    }
    
    private func openFaq(anchor: String? = nil) {
        let presentationData = self.presentationData
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            self?.controller?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        let _ = (self.cachedFaq.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] resolvedUrl in
            progressDisposable.dispose()

            if let strongSelf = self, let resolvedUrl = resolvedUrl {
                var resolvedUrl = resolvedUrl
                if case let .instantView(webPage, _) = resolvedUrl, let customAnchor = anchor {
                    resolvedUrl = .instantView(webPage, customAnchor)
                }
                strongSelf.context.sharedContext.openResolvedUrl(resolvedUrl, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.controller?.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { peer, navigation in
                }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { [weak self] controller, arguments in
                    self?.controller?.push(controller)
                }, dismissInput: {}, contentContext: nil, progress: nil, completion: nil)
            }
        })
    }
    
    private func openTips() {
        let controller = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: nil))
        self.controller?.present(controller, in: .window(.root))
        
        let context = self.context
        let navigationController = self.controller?.navigationController as? NavigationController
        self.tipsPeerDisposable.set((self.context.engine.peers.resolvePeerByName(name: self.presentationData.strings.Settings_TipsUsername, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        |> deliverOnMainQueue).startStrict(next: { [weak controller] peer in
            controller?.dismiss()
            if let peer = peer, let navigationController = navigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
            }
        }))
    }
            
    fileprivate func switchToAccount(id: AccountRecordId) {
        self.accountsAndPeers.set(.never())
        self.context.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
    }
    
    private func logoutAccount(id: AccountRecordId) {
        let controller = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        
        var items: [ActionSheetItem] = []
        items.append(ActionSheetTextItem(title: self.presentationData.strings.Settings_LogoutConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)))
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.Settings_Logout, color: .destructive, action: { [weak self] in
            dismissAction()
            if let strongSelf = self {
                let _ = logoutFromAccount(id: id, accountManager: strongSelf.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).startStandalone()
            }
        }))
        controller.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        self.controller?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    private func accountContextMenuItems(context: AccountContext, logout: @escaping () -> Void) -> Signal<[ContextMenuItem], NoError> {
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        return context.engine.messages.unreadChatListPeerIds(groupId: .root, filterPredicate: nil)
        |> map { unreadChatListPeerIds -> [ContextMenuItem] in
            var items: [ContextMenuItem] = []
            
            if !unreadChatListPeerIds.isEmpty {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAllAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = (context.engine.messages.markAllChatsAsReadInteractively(items: [(groupId: .root, filterPredicate: nil)])
                    |> deliverOnMainQueue).startStandalone(completed: {
                        f(.default)
                    })
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: strings.Settings_Context_Logout, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                logout()
                f(.default)
            })))
            
            return items
        }
    }
    
    private func accountContextMenu(id: AccountRecordId, node: ASDisplayNode, gesture: ContextGesture?) {
        var selectedAccount: Account?
        let _ = (self.accountsAndPeers.get()
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { accountsAndPeers in
            for (account, _, _) in accountsAndPeers {
                if account.account.id == id {
                    selectedAccount = account.account
                    break
                }
            }
        })
        if let selectedAccount = selectedAccount {
            let accountContext = self.context.sharedContext.makeTempAccountContext(account: selectedAccount)
            let chatListController = accountContext.sharedContext.makeChatListController(context: accountContext, location: .chatList(groupId: EngineChatList.Group(.root)), controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                    
            let contextController = ContextController(presentationData: self.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node)), items: accountContextMenuItems(context: accountContext, logout: { [weak self] in
                self?.logoutAccount(id: id)
            }) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
            self.controller?.presentInGlobalOverlay(contextController)
        } else {
            gesture?.cancel()
        }
    }
    
    private func updateBio(_ bio: String) {
        self.state = self.state.withUpdatingBio(bio)
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut), additive: false)
        }
    }
    
    private func deleteMessages(messageIds: Set<MessageId>?) {
        if let messageIds = messageIds ?? self.state.selectedMessageIds, !messageIds.isEmpty {
            self.activeActionDisposable.set((self.context.sharedContext.chatAvailableMessageActions(engine: self.context.engine, accountPeerId: self.context.account.peerId, messageIds: messageIds, keepUpdated: false)
            |> deliverOnMainQueue).startStrict(next: { [weak self] actions in
                if let strongSelf = self, let peer = strongSelf.data?.peer, !actions.options.isEmpty {
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    var personalPeerName: String?
                    var isChannel = false
                    if let user = peer as? TelegramUser {
                        personalPeerName = EnginePeer(user).compactDisplayTitle
                    } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        isChannel = true
                    }
                    
                    if actions.options.contains(.deleteGlobally) {
                        let globalTitle: String
                        if isChannel {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                        } else if let personalPeerName = personalPeerName {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                        } else {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                        }
                        items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).startStandalone()
                            }
                        }))
                    }
                    if actions.options.contains(.deleteLocally) {
                        var localOptionText = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                        if strongSelf.context.account.peerId == strongSelf.peerId {
                            if messageIds.count == 1 {
                                localOptionText = strongSelf.presentationData.strings.Conversation_Moderate_Delete
                            } else {
                                localOptionText = strongSelf.presentationData.strings.Conversation_DeleteManyMessages
                            }
                        }
                        items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).startStandalone()
                            }
                        }))
                    }
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    strongSelf.view.endEditing(true)
                    strongSelf.controller?.present(actionSheet, in: .window(.root))
                }
            }))
        }
    }
    
    func forwardMessages(messageIds: Set<MessageId>?) {
        if let messageIds = messageIds ?? self.state.selectedMessageIds, !messageIds.isEmpty {
            let peerSelectionController = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, filter: [.onlyWriteable, .excludeDisabled], hasFilters: true, multipleSelection: true, selectForumThreads: true))
            peerSelectionController.multiplePeersSelected = { [weak self, weak peerSelectionController] peers, peerMap, messageText, mode, forwardOptions, _ in
                guard let strongSelf = self, let strongController = peerSelectionController else {
                    return
                }
                strongController.dismiss()

                var result: [EnqueueMessage] = []
                if messageText.string.count > 0 {
                    let inputText = convertMarkdownToAttributes(messageText)
                    for text in breakChatInputText(trimChatInputText(inputText)) {
                        if text.length != 0 {
                            var attributes: [MessageAttribute] = []
                            let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                            if !entities.isEmpty {
                                attributes.append(TextEntitiesMessageAttribute(entities: entities))
                            }
                            result.append(.message(text: text.string, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                        }
                    }
                }
                
                var attributes: [MessageAttribute] = []
                attributes.append(ForwardOptionsMessageAttribute(hideNames: forwardOptions?.hideNames == true, hideCaptions: forwardOptions?.hideCaptions == true))
                
                result.append(contentsOf: messageIds.map { messageId -> EnqueueMessage in
                    return .forward(source: messageId, threadId: nil, grouping: .auto, attributes: attributes, correlationId: nil)
                })
                
                var displayPeers: [EnginePeer] = []
                for peer in peers {
                    let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: result)
                    |> deliverOnMainQueue).startStandalone(next: { messageIds in
                        if let strongSelf = self {
                            let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                                guard let id = id else {
                                    return nil
                                }
                                return strongSelf.context.account.pendingMessageManager.pendingMessageStatus(id)
                                |> mapToSignal { status, _ -> Signal<Bool, NoError> in
                                    if status != nil {
                                        return .never()
                                    } else {
                                        return .single(true)
                                    }
                                }
                                |> take(1)
                            })
                            if strongSelf.shareStatusDisposable == nil {
                                strongSelf.shareStatusDisposable = MetaDisposable()
                            }
                            strongSelf.shareStatusDisposable?.set((combineLatest(signals)
                            |> deliverOnMainQueue).startStrict())
                        }
                    })
                    
                    if case let .secretChat(secretPeer) = peer {
                        if let peer = peerMap[secretPeer.regularPeerId] {
                            displayPeers.append(peer)
                        }
                    } else {
                        displayPeers.append(peer)
                    }
                }
                    
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                var savedMessages = false
                if displayPeers.count == 1, let peerId = displayPeers.first?.id, peerId == strongSelf.context.account.peerId {
                    text = messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
                    savedMessages = true
                } else {
                    if displayPeers.count == 1, let peer = displayPeers.first {
                        var peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                        text = messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                    } else if displayPeers.count == 2, let firstPeer = displayPeers.first, let secondPeer = displayPeers.last {
                        var firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                        var secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                        text = messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                    } else if let peer = displayPeers.first {
                        var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                        text = messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(displayPeers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(displayPeers.count - 1)").string
                    } else {
                        text = ""
                    }
                }

                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                    if savedMessages, let self, action == .info {
                        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                            guard let self, let peer else {
                                return
                            }
                            guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                return
                            }
                            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                        })
                    }
                    return false
                }), in: .current)
            }
            peerSelectionController.peerSelected = { [weak self, weak peerSelectionController] peer, threadId in
                let peerId = peer.id
                
                if let strongSelf = self, let _ = peerSelectionController {
                    if peerId == strongSelf.context.account.peerId {
                        Queue.mainQueue().after(0.88) {
                            strongSelf.hapticFeedback.success()
                        }
                        
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: true, text: messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                            if let self, action == .info {
                                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    guard let self, let peer else {
                                        return
                                    }
                                    guard let navigationController = self.controller?.navigationController as? NavigationController else {
                                        return
                                    }
                                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
                                })
                            }
                            return false
                        }), in: .current)
                        
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                        
                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                            return .forward(source: id, threadId: nil, grouping: .auto, attributes: [], correlationId: nil)
                        })
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] messageIds in
                            if let strongSelf = self {
                                let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                                    guard let id = id else {
                                        return nil
                                    }
                                    return strongSelf.context.account.pendingMessageManager.pendingMessageStatus(id)
                                        |> mapToSignal { status, _ -> Signal<Bool, NoError> in
                                            if status != nil {
                                                return .never()
                                            } else {
                                                return .single(true)
                                            }
                                        }
                                        |> take(1)
                                })
                                strongSelf.activeActionDisposable.set((combineLatest(signals)
                                |> deliverOnMainQueue).startStrict())
                            }
                        })
                        if let peerSelectionController = peerSelectionController {
                            peerSelectionController.dismiss()
                        }
                    } else {
                        let _ = (ChatInterfaceState.update(engine: strongSelf.context.engine, peerId: peerId, threadId: threadId, { currentState in
                            return currentState.withUpdatedForwardMessageIds(Array(messageIds))
                        })
                        |> deliverOnMainQueue).startStandalone(completed: {
                            if let strongSelf = self {
                                let proceed: (ChatController) -> Void = { chatController in
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                    
                                    if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                        var viewControllers = navigationController.viewControllers
                                        if threadId != nil {
                                            viewControllers.insert(chatController, at: viewControllers.count - 2)
                                        } else {
                                            viewControllers.insert(chatController, at: viewControllers.count - 1)
                                        }
                                        navigationController.setViewControllers(viewControllers, animated: false)
                                        
                                        strongSelf.activeActionDisposable.set((chatController.ready.get()
                                        |> filter { $0 }
                                        |> take(1)
                                        |> deliverOnMainQueue).startStrict(next: { [weak navigationController] _ in
                                            viewControllers.removeAll(where: { $0 is PeerSelectionController })
                                            navigationController?.setViewControllers(viewControllers, animated: true)
                                        }))
                                    }
                                }
                                
                                if let threadId = threadId {
                                    let _ = (strongSelf.context.sharedContext.chatControllerForForumThread(context: strongSelf.context, peerId: peerId, threadId: threadId)
                                    |> deliverOnMainQueue).startStandalone(next: { chatController in
                                        proceed(chatController)
                                    })
                                } else {
                                    let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: .none, botStart: nil, mode: .standard(.default), params: nil)
                                    proceed(chatController)
                                }
                            }
                        })
                    }
                }
            }
            self.controller?.push(peerSelectionController)
        }
    }
    
    private func activateSearch() {
        guard let (layout, navigationBarHeight) = self.validLayout, self.searchDisplayController == nil else {
            return
        }
        
        if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .savedMessages = currentPaneKey, let paneNode = self.paneContainerNode.currentPane?.node as? PeerInfoChatPaneNode {
            paneNode.activateSearch()
            return
        } else if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .savedMessagesChats = currentPaneKey, let paneNode = self.paneContainerNode.currentPane?.node as? PeerInfoChatListPaneNode {
            paneNode.activateSearch()
            return
        }
        
        self.headerNode.navigationButtonContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        
        if self.isSettings {
            (self.controller?.parent as? TabBarController)?.updateIsTabBarHidden(true, transition: .animated(duration: 0.3, curve: .linear))
            
            if let settings = self.data?.globalSettings {
                self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Settings_Search, hasBackground: true, hasSeparator: true, contentNode: SettingsSearchContainerNode(context: self.context, openResult: { [weak self] result in
                    if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                        result.present(strongSelf.context, navigationController, { [weak self] mode, controller in
                            if let strongSelf = self {
                                switch mode {
                                    case .push:
                                        if let controller = controller {
                                            strongSelf.controller?.push(controller)
                                        }
                                    case .modal:
                                        if let controller = controller {
                                            strongSelf.controller?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet, completion: { [weak self] in
                                                self?.deactivateSearch()
                                            }))
                                        }
                                    case .immediate:
                                        if let controller = controller {
                                            strongSelf.controller?.present(controller, in: .window(.root), with: nil)
                                        }
                                    case .dismiss:
                                        strongSelf.deactivateSearch()
                                }
                            }
                        })
                    }
                }, resolvedFaqUrl: self.cachedFaq.get(), exceptionsList: .single(settings.notificationExceptions), archivedStickerPacks: .single(settings.archivedStickerPacks), privacySettings: .single(settings.privacySettings), hasTwoStepAuth: self.hasTwoStepAuth.get(), twoStepAuthData: self.twoStepAccessConfiguration.get(), activeSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.0 }, webSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.2 }), cancel: { [weak self] in
                    self?.deactivateSearch()
                })
            }
        } else if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .members = currentPaneKey {
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, hasBackground: true, hasSeparator: true, contentNode: ChannelMembersSearchContainerNode(context: self.context, forceTheme: nil, peerId: self.peerId, mode: .searchMembers, filters: [], searchContext: self.groupMembersSearchContext, openPeer: { [weak self] peer, participant in
                self?.openPeer(peerId: peer.id, navigation: .info(nil))
            }, updateActivity: { _ in
            }, pushController: { [weak self] c in
                self?.controller?.push(c)
            }), cancel: { [weak self] in
                self?.deactivateSearch()
            })
        } else if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .savedMessagesChats = currentPaneKey {
            let contentNode = ChatListSearchContainerNode(context: self.context, animationCache: self.context.animationCache, animationRenderer: self.context.animationRenderer, filter: [.removeSearchHeader], requestPeerType: nil, location: .savedMessagesChats(peerId: self.context.account.peerId), displaySearchFilters: false, hasDownloads: false, initialFilter: .chats, openPeer: { [weak self] peer, _, _, _ in
                guard let self else {
                    return
                }
                guard let navigationController = self.controller?.navigationController as? NavigationController else {
                    return
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                    navigationController: navigationController,
                    context: self.context,
                    chatLocation: .replyThread(ChatReplyThreadMessage(
                        peerId: self.context.account.peerId,
                        threadId: peer.id.toInt64(),
                        channelMessageId: nil,
                        isChannelPost: false,
                        isForumPost: false,
                        isMonoforumPost: false,
                        maxMessage: nil,
                        maxReadIncomingMessageId: nil,
                        maxReadOutgoingMessageId: nil,
                        unreadCount: 0,
                        initialFilledHoles: IndexSet(),
                        initialAnchor: .automatic,
                        isNotAvailable: false
                    )),
                    subject: nil,
                    keepStack: .always
                ))
            }, openDisabledPeer: { _, _, _ in
            }, openRecentPeerOptions: { _ in
            }, openMessage: { [weak self] peer, threadId, messageId, deactivateOnAction in
                guard let self else {
                    return
                }
                guard let navigationController = self.controller?.navigationController as? NavigationController else {
                    return
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                    navigationController: navigationController,
                    context: self.context,
                    chatLocation: .replyThread(ChatReplyThreadMessage(
                        peerId: self.context.account.peerId,
                        threadId: peer.id.toInt64(),
                        channelMessageId: nil,
                        isChannelPost: false,
                        isForumPost: false,
                        isMonoforumPost: false,
                        maxMessage: nil,
                        maxReadIncomingMessageId: nil,
                        maxReadOutgoingMessageId: nil,
                        unreadCount: 0,
                        initialFilledHoles: IndexSet(),
                        initialAnchor: .automatic,
                        isNotAvailable: false
                    )),
                    subject: nil,
                    keepStack: .always
                ))
            }, addContact: { _ in
            }, peerContextAction: nil, present: { [weak self] c, a in
                guard let self else {
                    return
                }
                self.controller?.present(c, in: .window(.root), with: a)
            }, presentInGlobalOverlay: { [weak self] c, a in
                guard let self else {
                    return
                }
                self.controller?.presentInGlobalOverlay(c, with: a)
            }, navigationController: self.controller?.navigationController as? NavigationController, parentController: { [weak self] in
                guard let self else {
                    return nil
                }
                return self.controller
            })
            
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, hasBackground: true, hasSeparator: true, contentNode: contentNode, cancel: { [weak self] in
                self?.deactivateSearch()
            })
        } else {
            var tagMask: MessageTags = .file
            if let currentPaneKey = self.paneContainerNode.currentPaneKey {
                switch currentPaneKey {
                case .links:
                    tagMask = .webPage
                case .music:
                    tagMask = .music
                default:
                    break
                }
            }
            
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, hasBackground: true, contentNode: ChatHistorySearchContainerNode(context: self.context, peerId: self.peerId, threadId: self.chatLocation.threadId, tagMask: tagMask, interfaceInteraction: self.chatInterfaceInteraction), cancel: { [weak self] in
                self?.deactivateSearch()
            })
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 0.0)
        }
        
        self.searchDisplayController?.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight + 10.0, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
            if let strongSelf = self, let navigationBar = strongSelf.controller?.navigationBar {
                strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
            }
        }, placeholder: nil)
        
        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationBarHeight, transition: .immediate)
    }
    
    private func deactivateSearch() {
        guard let searchDisplayController = self.searchDisplayController else {
            return
        }
        self.searchDisplayController = nil
        searchDisplayController.deactivate(placeholder: nil)
        
        if self.isSettings {
            (self.controller?.parent as? TabBarController)?.updateIsTabBarHidden(false, transition: .animated(duration: 0.3, curve: .linear))
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 1.0)
        }
    }

    private weak var mediaGalleryContextMenu: ContextController?

    func displaySharedMediaFastScrollingTooltip() {
        guard let buttonNode = self.headerNode.navigationButtonContainer.rightButtonNodes[.more] else {
            return
        }
        guard let controller = self.controller else {
            return
        }
        let buttonFrame = buttonNode.view.convert(buttonNode.bounds, to: self.view)
        controller.present(TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: self.presentationData.strings.SharedMedia_CalendarTooltip), style: .default, icon: .none, location: .point(buttonFrame.insetBy(dx: 0.0, dy: 5.0), .top), shouldDismissOnTouch: { point, _ in
            return .dismiss(consume: false)
        }), in: .current)
    }
    
    private func displayGiftsContextMenu(source: ContextReferenceContentNode, gesture: ContextGesture?) {
        guard let currentPaneKey = self.paneContainerNode.currentPaneKey, case .gifts = currentPaneKey else {
            return
        }
        guard let pane = self.paneContainerNode.currentPane?.node as? PeerInfoGiftsPaneNode else {
            return
        }
        guard let controller = self.controller else {
            return
        }
        guard let data = self.data, let giftsContext = data.profileGiftsContext else {
            return
        }
        
        var hasVisibility = false
        if let channel = data.peer as? TelegramChannel, channel.hasPermission(.sendSomething) {
            hasVisibility = true
        } else if data.peer?.id == self.context.account.peerId {
            hasVisibility = true
        }
            
        let strings = self.presentationData.strings
        let items: Signal<ContextController.Items, NoError> = giftsContext.state
        |> map { state in
            var hasPinnedGifts = false
            for gift in state.gifts {
                if gift.pinnedToTop {
                    hasPinnedGifts = true
                    break
                }
            }
            return (state.filter, state.sorting, hasPinnedGifts)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
            let filterEquals = lhs.0 == rhs.0
            let sortingEquals = lhs.1 == rhs.1
            let hasPinnedGiftsEquals = lhs.2 == rhs.2
            return filterEquals && sortingEquals && hasPinnedGiftsEquals
        })
        |> map { [weak giftsContext] filter, sorting, hasPinnedGifts -> ContextController.Items in
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: sorting == .date ? strings.PeerInfo_Gifts_SortByValue : strings.PeerInfo_Gifts_SortByDate, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: sorting == .date ? "Peer Info/SortValue" : "Peer Info/SortDate"), color: theme.contextMenu.primaryColor)
            }, action: { [weak giftsContext] _, f in
                f(.default)
                
                giftsContext?.updateSorting(sorting == .date ? .value : .date)
            })))
            
            if hasPinnedGifts && hasVisibility {
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Reorder, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.default)
                    
                    pane.beginReordering()
                })))
            }
            
            items.append(.separator)
            
            let toggleFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                if updatedFilter.contains(value) {
                    updatedFilter.remove(value)
                } else {
                    updatedFilter.insert(value)
                }
                if !updatedFilter.contains(.unlimited) && !updatedFilter.contains(.limited) && !updatedFilter.contains(.unique) {
                    updatedFilter.insert(.unlimited)
                }
                if !updatedFilter.contains(.displayed) && !updatedFilter.contains(.hidden) {
                    if value == .displayed {
                        updatedFilter.insert(.hidden)
                    } else {
                        updatedFilter.insert(.displayed)
                    }
                }
                giftsContext?.updateFilter(updatedFilter)
            }
            
            let switchToFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                updatedFilter.remove(.unlimited)
                updatedFilter.remove(.limited)
                updatedFilter.remove(.unique)
                updatedFilter.insert(value)
                giftsContext?.updateFilter(updatedFilter)
            }
            
            let switchToVisiblityFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = filter
                updatedFilter.remove(.hidden)
                updatedFilter.remove(.displayed)
                updatedFilter.insert(value)
                giftsContext?.updateFilter(updatedFilter)
            }
            
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Unlimited, icon: { theme in
                return filter.contains(.unlimited) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, f in
                toggleFilter(.unlimited)
            }, longPressAction: { _, f in
                switchToFilter(.unlimited)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Limited, icon: { theme in
                return filter.contains(.limited) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, f in
                toggleFilter(.limited)
            }, longPressAction: { _, f in
                switchToFilter(.limited)
            })))
            items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Unique, icon: { theme in
                return filter.contains(.unique) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
            }, action: { _, f in
                toggleFilter(.unique)
            }, longPressAction: { _, f in
                switchToFilter(.unique)
            })))
            
            if hasVisibility {
                items.append(.separator)
                
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Displayed, icon: { theme in
                    return filter.contains(.displayed) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
                }, action: { _, f in
                    toggleFilter(.displayed)
                }, longPressAction: { _, f in
                    switchToVisiblityFilter(.displayed)
                })))
                items.append(.action(ContextMenuActionItem(text: strings.PeerInfo_Gifts_Hidden, icon: { theme in
                    return filter.contains(.hidden) ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil
                }, action: { _, f in
                    toggleFilter(.hidden)
                }, longPressAction: { _, f in
                    switchToVisiblityFilter(.hidden)
                })))
            }
            
            return ContextController.Items(content: .list(items))
        }
        
        let contextController = ContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: source)), items: items, gesture: gesture)
        contextController.passthroughTouchEvent = { [weak self] sourceView, point in
            guard let strongSelf = self else {
                return .ignore
            }
            
            let localPoint = strongSelf.view.convert(sourceView.convert(point, to: nil), from: nil)
            guard let localResult = strongSelf.hitTest(localPoint, with: nil) else {
                return .dismiss(consume: true, result: nil)
            }
            
            var testView: UIView? = localResult
            while true {
                if let testViewValue = testView {
                    if let node = testViewValue.asyncdisplaykit_node as? PeerInfoHeaderNavigationButton {
                        node.isUserInteractionEnabled = false
                        DispatchQueue.main.async {
                            node.isUserInteractionEnabled = true
                        }
                        return .dismiss(consume: false, result: nil)
                    } else {
                        testView = testViewValue.superview
                    }
                } else {
                    break
                }
            }
            
            return .dismiss(consume: true, result: nil)
        }
        self.mediaGalleryContextMenu = contextController
        controller.presentInGlobalOverlay(contextController)
    }

    private func displayMediaGalleryContextMenu(source: ContextReferenceContentNode, gesture: ContextGesture?) {
        let peerId = self.peerId
        
        if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .botPreview = currentPaneKey {
            guard let controller = self.controller else {
                return
            }
            guard let pane = self.paneContainerNode.currentPane?.node as? PeerInfoStoryPaneNode else {
                return
            }
            guard let data = self.data, let user = data.peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) else {
                return
            }
            
            var items: [ContextMenuItem] = []
            
            let strings = self.presentationData.strings
            
            var ignoreNextActions = false
            
            if pane.canAddMoreBotPreviews() {
                items.append(.action(ContextMenuActionItem(text: strings.BotPreviews_MenuAddPreview, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, a in
                    if ignoreNextActions {
                        return
                    }
                    ignoreNextActions = true
                    a(.default)
                    
                    if let self {
                        self.headerNode.navigationButtonContainer.performAction?(.postStory, nil, nil)
                    }
                })))
            }
            
            if pane.canReorder() {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.BotPreviews_MenuReorder, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReorderItems"), color: theme.contextMenu.primaryColor)
                }, action: { [weak pane] _, a in
                    if ignoreNextActions {
                        return
                    }
                    ignoreNextActions = true
                    a(.default)
                    
                    if let pane {
                        pane.beginReordering()
                    }
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuSelect, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, a in
                if ignoreNextActions {
                    return
                }
                ignoreNextActions = true
                a(.default)
                
                if let self {
                    self.toggleStorySelection(ids: [], isSelected: true)
                }
            })))
            
            if let language = pane.currentBotPreviewLanguage {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.BotPreviews_MenuDeleteLanguage(language.name).string, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak pane] _, a in
                    if ignoreNextActions {
                        return
                    }
                    ignoreNextActions = true
                    a(.default)
                    
                    if let pane {
                        pane.presentDeleteBotPreviewLanguage()
                    }
                })))
            }
            
            let contextController = ContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: source)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            contextController.passthroughTouchEvent = { [weak self] sourceView, point in
                guard let strongSelf = self else {
                    return .ignore
                }
                
                let localPoint = strongSelf.view.convert(sourceView.convert(point, to: nil), from: nil)
                guard let localResult = strongSelf.hitTest(localPoint, with: nil) else {
                    return .dismiss(consume: true, result: nil)
                }
                
                var testView: UIView? = localResult
                while true {
                    if let testViewValue = testView {
                        if let node = testViewValue.asyncdisplaykit_node as? PeerInfoHeaderNavigationButton {
                            node.isUserInteractionEnabled = false
                            DispatchQueue.main.async {
                                node.isUserInteractionEnabled = true
                            }
                            return .dismiss(consume: false, result: nil)
                        } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoVisualMediaPaneNode {
                            node.brieflyDisableTouchActions()
                            return .dismiss(consume: false, result: nil)
                        } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoStoryPaneNode {
                            node.brieflyDisableTouchActions()
                            return .dismiss(consume: false, result: nil)
                        } else {
                            testView = testViewValue.superview
                        }
                    } else {
                        break
                    }
                }
                
                return .dismiss(consume: true, result: nil)
            }
            self.mediaGalleryContextMenu = contextController
            controller.presentInGlobalOverlay(contextController)
        } else {
            let _ = (self.context.engine.data.get(EngineDataMap([
                TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, threadId: self.chatLocation.threadId, tag: .photo),
                TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, threadId: self.chatLocation.threadId, tag: .video)
            ]))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] messageCounts in
                guard let strongSelf = self else {
                    return
                }
                
                var mediaCount: [MessageTags: Int32] = [:]
                for (key, count) in messageCounts {
                    mediaCount[key.tag] = count.flatMap(Int32.init) ?? 0
                }
                
                let photoCount: Int32 = mediaCount[.photo] ?? 0
                let videoCount: Int32 = mediaCount[.video] ?? 0
                
                guard let controller = strongSelf.controller else {
                    return
                }
                guard let pane = strongSelf.paneContainerNode.currentPane?.node as? PeerInfoVisualMediaPaneNode else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                
                let strings = strongSelf.presentationData.strings
                
                var recurseGenerateAction: ((Bool) -> ContextMenuActionItem)?
                let generateAction: (Bool) -> ContextMenuActionItem = { [weak pane] isZoomIn in
                    let nextZoomLevel = isZoomIn ? pane?.availableZoomLevels().increment : pane?.availableZoomLevels().decrement
                    let canZoom: Bool = nextZoomLevel != nil
                    
                    return ContextMenuActionItem(id: isZoomIn ? 0 : 1, text: isZoomIn ? strings.SharedMedia_ZoomIn : strings.SharedMedia_ZoomOut, textColor: canZoom ? .primary : .disabled, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: isZoomIn ? "Chat/Context Menu/ZoomIn" : "Chat/Context Menu/ZoomOut"), color: canZoom ? theme.contextMenu.primaryColor : theme.contextMenu.primaryColor.withMultipliedAlpha(0.4))
                    }, action: canZoom ? { action in
                        guard let pane = pane, let zoomLevel = isZoomIn ? pane.availableZoomLevels().increment : pane.availableZoomLevels().decrement else {
                            return
                        }
                        pane.updateZoomLevel(level: zoomLevel)
                        if let recurseGenerateAction = recurseGenerateAction {
                            action.updateAction(0, recurseGenerateAction(true))
                            action.updateAction(1, recurseGenerateAction(false))
                        }
                    } : nil)
                }
                recurseGenerateAction = { isZoomIn in
                    return generateAction(isZoomIn)
                }
                
                items.append(.action(generateAction(true)))
                items.append(.action(generateAction(false)))
                
                var ignoreNextActions = false
                if strongSelf.chatLocation.threadId == nil {
                    items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowCalendar, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Calendar"), color: theme.contextMenu.primaryColor)
                    }, action: { _, a in
                        if ignoreNextActions {
                            return
                        }
                        ignoreNextActions = true
                        a(.default)
                        
                        self?.openMediaCalendar()
                    })))
                }
                
                if photoCount != 0 && videoCount != 0 {
                    items.append(.separator)
                    
                    let showPhotos: Bool
                    switch pane.contentType {
                    case .photo, .photoOrVideo:
                        showPhotos = true
                    default:
                        showPhotos = false
                    }
                    let showVideos: Bool
                    switch pane.contentType {
                    case .video, .photoOrVideo:
                        showVideos = true
                    default:
                        showVideos = false
                    }
                    
                    items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowPhotos, icon: { theme in
                        if !showPhotos {
                            return nil
                        }
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, a in
                        a(.default)
                        
                        guard let pane = pane else {
                            return
                        }
                        let updatedContentType: PeerInfoVisualMediaPaneNode.ContentType
                        switch pane.contentType {
                        case .photoOrVideo:
                            updatedContentType = .video
                        case .photo:
                            updatedContentType = .photo
                        case .video:
                            updatedContentType = .photoOrVideo
                        default:
                            updatedContentType = pane.contentType
                        }
                        pane.updateContentType(contentType: updatedContentType)
                    })))
                    items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ShowVideos, icon: { theme in
                        if !showVideos {
                            return nil
                        }
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak pane] _, a in
                        a(.default)
                        
                        guard let pane = pane else {
                            return
                        }
                        let updatedContentType: PeerInfoVisualMediaPaneNode.ContentType
                        switch pane.contentType {
                        case .photoOrVideo:
                            updatedContentType = .photo
                        case .photo:
                            updatedContentType = .photoOrVideo
                        case .video:
                            updatedContentType = .video
                        default:
                            updatedContentType = pane.contentType
                        }
                        pane.updateContentType(contentType: updatedContentType)
                    })))
                }
                
                let contextController = ContextController(presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: source)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                contextController.passthroughTouchEvent = { sourceView, point in
                    guard let strongSelf = self else {
                        return .ignore
                    }
                    
                    let localPoint = strongSelf.view.convert(sourceView.convert(point, to: nil), from: nil)
                    guard let localResult = strongSelf.hitTest(localPoint, with: nil) else {
                        return .dismiss(consume: true, result: nil)
                    }
                    
                    var testView: UIView? = localResult
                    while true {
                        if let testViewValue = testView {
                            if let node = testViewValue.asyncdisplaykit_node as? PeerInfoHeaderNavigationButton {
                                node.isUserInteractionEnabled = false
                                DispatchQueue.main.async {
                                    node.isUserInteractionEnabled = true
                                }
                                return .dismiss(consume: false, result: nil)
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoVisualMediaPaneNode {
                                node.brieflyDisableTouchActions()
                                return .dismiss(consume: false, result: nil)
                            } else if let node = testViewValue.asyncdisplaykit_node as? PeerInfoStoryPaneNode {
                                node.brieflyDisableTouchActions()
                                return .dismiss(consume: false, result: nil)
                            } else {
                                testView = testViewValue.superview
                            }
                        } else {
                            break
                        }
                    }
                    
                    return .dismiss(consume: true, result: nil)
                }
                strongSelf.mediaGalleryContextMenu = contextController
                controller.presentInGlobalOverlay(contextController)
            })
        }
    }

    private func openMediaCalendar() {
        var initialTimestamp = Int32(Date().timeIntervalSince1970)

        guard let pane = self.paneContainerNode.currentPane?.node as? PeerInfoVisualMediaPaneNode, let timestamp = pane.currentTopTimestamp(), let calendarSource = pane.calendarSource else {
            return
        }
        initialTimestamp = timestamp

        var dismissCalendarScreen: (() -> Void)?

        let calendarScreen = CalendarMessageScreen(
            context: self.context,
            peerId: self.peerId,
            calendarSource: calendarSource,
            initialTimestamp: initialTimestamp,
            enableMessageRangeDeletion: false,
            canNavigateToEmptyDays: false,
            navigateToDay: { [weak self] c, index, _ in
                guard let strongSelf = self else {
                    c.dismiss()
                    return
                }
                guard let pane = strongSelf.paneContainerNode.currentPane?.node as? PeerInfoVisualMediaPaneNode else {
                    c.dismiss()
                    return
                }

                pane.scrollToItem(index: index)

                c.dismiss()
            },
            previewDay: { [weak self] _, index, sourceNode, sourceRect, gesture in
                guard let strongSelf = self, let index = index else {
                    return
                }

                var items: [ContextMenuItem] = []

                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    dismissCalendarScreen?()

                    guard let strongSelf = self, let peer = strongSelf.data?.peer, let controller = strongSelf.controller, let navigationController = controller.navigationController as? NavigationController else {
                        return
                    }

                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        chatController: nil,
                        context: strongSelf.context,
                        chatLocation: .peer(EnginePeer(peer)),
                        subject: .message(id: .id(index.id), highlight: nil, timecode: nil, setupReply: false),
                        botStart: nil,
                        updateTextInputState: nil,
                        keepStack: .never,
                        useExisting: true,
                        purposefulAction: nil,
                        scrollToEndIfExists: false,
                        activateMessageSearch: nil,
                        peekData: nil,
                        peerNearbyData: nil,
                        reportReason: nil,
                        animated: true,
                        options: [],
                        parentGroupId: nil,
                        chatListFilter: nil,
                        changeColors: false,
                        completion: { _ in
                        }
                    ))
                })))

                let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: strongSelf.peerId), subject: .message(id: .id(index.id), highlight: nil, timecode: nil, setupReply: false), botStart: nil, mode: .standard(.previewing), params: nil)
                chatController.canReadHistory.set(false)
                let contextController = ContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, sourceRect: sourceRect, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }
        )

        self.controller?.push(calendarScreen)
        dismissCalendarScreen = { [weak calendarScreen] in
            calendarScreen?.dismiss(completion: nil)
        }
    }
    
    func presentEmojiList(packReference: StickerPackReference) {
        guard let peerController = self.controller else {
            return
        }
        let presentationData = self.presentationData
        let navigationController = peerController.navigationController as? NavigationController
        let controller = StickerPackScreen(context: self.context, updatedPresentationData: peerController.updatedPresentationData, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: navigationController, sendEmoji: nil, actionPerformed: { [weak self] actions in
            guard let strongSelf = self else {
                return
            }
            let context = strongSelf.context
            if let (info, items, action) = actions.first {
                let isEmoji = info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks
                
                switch action {
                case .add:
                    strongSelf.controller?.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedTitle : presentationData.strings.StickerPackActionInfo_AddedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedText(info.title).string : presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                        return true
                    }))
                case let .remove(positionInList):
                    strongSelf.controller?.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedText(info.title).string : presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                        if case .undo = action {
                            let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).startStandalone()
                        }
                        return true
                    }))
                }
            }
        })
        peerController.present(controller, in: .window(.root))
    }
    
    private func suggestPhoto() {
        self.controller?.openAvatarForEditing(mode: .suggest)
    }
    
    private func setCustomPhoto() {
        self.controller?.openAvatarForEditing(mode: .custom)
    }
    
    private func resetCustomPhoto() {
        guard let peer = self.data?.peer else {
            return
        }
        let alertController = textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: self.presentationData.strings.UserInfo_ResetToOriginalAlertText(EnginePeer(peer).compactDisplayTitle).string, actions: [
            TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {
                
            }),
            TextAlertAction(type: .defaultAction, title: self.presentationData.strings.UserInfo_ResetToOriginalAlertReset, action: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateAvatarDisposable.set((strongSelf.context.engine.contacts.updateContactPhoto(peerId: strongSelf.peerId, resource: nil, videoResource: nil, videoStartTimestamp: nil, markup: nil, mode: .custom, mapResourceToAvatarSizes: { resource, representations in
                    mapResourceToAvatarSizes(postbox: strongSelf.context.account.postbox, resource: resource, representations: representations)
                })
                |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.state = strongSelf.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)

                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut), additive: false)
                    }
                }))
            })
        ])
        self.controller?.present(alertController, in: .window(.root))
    }
 
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
    
        self.updateNavigationExpansionPresentation(isExpanded: self.headerNode.isAvatarExpanded, animated: false)
        
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
        }
    }
    
    private func updateNavigationHeight(width: CGFloat, defaultHeight: CGFloat, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) -> CGFloat {
        var navigationHeight = defaultHeight
        if let customNavigationContentNode = self.headerNode.customNavigationContentNode {
            var mappedTransition = transition
            if customNavigationContentNode.supernode == nil {
                mappedTransition = .immediate
            }
            let contentHeight = customNavigationContentNode.update(width: width, defaultHeight: defaultHeight, insets: insets, transition: mappedTransition)
            navigationHeight = contentHeight
        }
        return navigationHeight
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition, additive: Bool = false) {
        self.validLayout = (layout, navigationHeight)
        
        self.headerNode.customNavigationContentNode = self.paneContainerNode.currentPane?.node.navigationContentNode
        
        var isScrollEnabled = !self.isMediaOnly && self.headerNode.customNavigationContentNode == nil
        if self.state.selectedStoryIds != nil || self.state.paneIsReordering {
            isScrollEnabled = false
        }
        if self.scrollNode.view.isScrollEnabled != isScrollEnabled {
            self.scrollNode.view.isScrollEnabled = isScrollEnabled
        }
        
        let navigationHeight = self.updateNavigationHeight(width: layout.size.width, defaultHeight: navigationHeight, insets: UIEdgeInsets(top: 0.0, left: layout.safeInsets.left, bottom: 0.0, right: layout.safeInsets.right), transition: transition)
        
        if self.headerNode.isAvatarExpanded && layout.size.width > layout.size.height {
            self.headerNode.updateIsAvatarExpanded(false, transition: transition)
            self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight + 10.0, transition: transition)
            if !searchDisplayController.isDeactivating {
                //vanillaInsets.top += (layout.statusBarHeight ?? 0.0) - navigationBarHeightDelta
            }
        }
        
        self.ignoreScrolling = true
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sectionSpacing: CGFloat = 24.0
        
        var contentHeight: CGFloat = 0.0
        
        let sectionInset: CGFloat
        if layout.size.width >= 375.0 {
            sectionInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
        } else {
            sectionInset = 0.0
        }
        let headerInset = sectionInset
        
        let headerHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : self.scrollNode.view.contentOffset.y, paneContainerY: self.paneContainerNode.frame.minY, presentationData: self.presentationData, peer: self.data?.savedMessagesPeer ?? self.data?.peer, cachedData: self.data?.cachedData, threadData: self.data?.threadData, peerNotificationSettings: self.data?.peerNotificationSettings, threadNotificationSettings: self.data?.threadNotificationSettings, globalNotificationSettings: self.data?.globalNotificationSettings, statusData: self.data?.status, panelStatusData: self.customStatusData, isSecretChat: self.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, profileGiftsContext: self.data?.profileGiftsContext, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, transition: self.headerNode.navigationTransition == nil ? transition : .immediate, additive: additive, animateHeader: transition.isAnimated && self.headerNode.navigationTransition == nil)
        let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: headerHeight))
        if additive {
            transition.updateFrameAdditive(node: self.headerNode, frame: headerFrame)
        } else {
            transition.updateFrame(node: self.headerNode, frame: headerFrame)
        }
        if self.isMediaOnly {
            contentHeight += navigationHeight
        }
        
        var validRegularSections: [AnyHashable] = []
        if !self.isMediaOnly {
            var insets = UIEdgeInsets()
            insets.left += sectionInset
            insets.right += sectionInset
            
            let items = self.isSettings ? settingsItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction, isExpanded: self.headerNode.isAvatarExpanded) : infoItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction, nearbyPeerDistance: self.nearbyPeerDistance, reactionSourceMessageId: self.reactionSourceMessageId, callMessages: self.callMessages, chatLocation: self.chatLocation, isOpenedFromChat: self.isOpenedFromChat, isMyProfile: self.isMyProfile)
            
            contentHeight += headerHeight
            if !((self.isSettings || self.isMyProfile) && self.state.isEditing) {
                contentHeight += sectionSpacing + 12.0
            }
              
            var isFirst = true
            for (sectionId, sectionItems) in items {
                let isFirstSection = isFirst
                isFirst = false
                validRegularSections.append(sectionId)
                
                var wasAdded = false
                let sectionNode: PeerInfoScreenItemSectionContainerNode
                if let current = self.regularSections[sectionId] {
                    sectionNode = current
                } else {
                    sectionNode = PeerInfoScreenItemSectionContainerNode()
                    self.regularSections[sectionId] = sectionNode
                    self.scrollNode.addSubnode(sectionNode)
                    wasAdded = true
                }
                
                if wasAdded && transition.isAnimated && (self.isSettings || self.isMyProfile) && !self.state.isEditing {
                    sectionNode.alpha = 0.0
                    transition.updateAlpha(node: sectionNode, alpha: 1.0, delay: 0.1)
                }
                             
                let sectionWidth = layout.size.width - insets.left - insets.right
                if isFirstSection && sectionItems.first is PeerInfoScreenHeaderItem && !self.state.isEditing {
                    if self.data?.peer?.profileColor == nil {
                        contentHeight -= 16.0
                    }
                }
                let sectionHeight = sectionNode.update(context: self.context, width: sectionWidth, safeInsets: UIEdgeInsets(), hasCorners: !insets.left.isZero, presentationData: self.presentationData, items: sectionItems, transition: transition)
                let sectionFrame = CGRect(origin: CGPoint(x: insets.left, y: contentHeight), size: CGSize(width: sectionWidth, height: sectionHeight))
                if additive {
                    transition.updateFrameAdditive(node: sectionNode, frame: sectionFrame)
                } else {
                    transition.updateFrame(node: sectionNode, frame: sectionFrame)
                }
                
                if wasAdded && transition.isAnimated && (self.isSettings || self.isMyProfile) && !self.state.isEditing {
                } else {
                    transition.updateAlpha(node: sectionNode, alpha: self.state.isEditing ? 0.0 : 1.0)
                }
                if !sectionHeight.isZero && !self.state.isEditing {
                    contentHeight += sectionHeight
                    contentHeight += sectionSpacing
                }
            }
            var removeRegularSections: [AnyHashable] = []
            for (sectionId, _) in self.regularSections {
                if !validRegularSections.contains(sectionId) {
                    removeRegularSections.append(sectionId)
                }
            }
            for sectionId in removeRegularSections {
                if let sectionNode = self.regularSections.removeValue(forKey: sectionId) {
                    var alphaTransition = transition
                    if let sectionId = sectionId as? SettingsSection, case .edit = sectionId {
                        sectionNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -layout.size.width * 0.7), duration: 0.4, delay: 0.0, timingFunction: kCAMediaTimingFunctionSpring, mediaTimingFunction: nil, removeOnCompletion: false, additive: true, completion: nil)
                        
                        if alphaTransition.isAnimated {
                            alphaTransition = .animated(duration: 0.12, curve: .easeInOut)
                        }
                    }
                    transition.updateAlpha(node: sectionNode, alpha: 0.0, completion: { [weak sectionNode] _ in
                        sectionNode?.removeFromSupernode()
                    })
                }
            }
            
            var validEditingSections: [AnyHashable] = []
            let editItems = (self.isSettings || self.isMyProfile) ? settingsEditingItems(data: self.data, state: self.state, context: self.context, presentationData: self.presentationData, interaction: self.interaction, isMyProfile: self.isMyProfile) : editingItems(data: self.data, boostStatus: self.boostStatus, state: self.state, chatLocation: self.chatLocation, context: self.context, presentationData: self.presentationData, interaction: self.interaction)

            for (sectionId, sectionItems) in editItems {
                var insets = UIEdgeInsets()
                insets.left += sectionInset
                insets.right += sectionInset

                validEditingSections.append(sectionId)
                
                var wasAdded = false
                let sectionNode: PeerInfoScreenItemSectionContainerNode
                if let current = self.editingSections[sectionId] {
                    sectionNode = current
                } else {
                    wasAdded = true
                    sectionNode = PeerInfoScreenItemSectionContainerNode()
                    self.editingSections[sectionId] = sectionNode
                    self.scrollNode.addSubnode(sectionNode)
                }
                
                let sectionWidth = layout.size.width - insets.left - insets.right
                let sectionHeight = sectionNode.update(context: self.context, width: sectionWidth, safeInsets: UIEdgeInsets(), hasCorners: !insets.left.isZero, presentationData: self.presentationData, items: sectionItems, transition: transition)
                let sectionFrame = CGRect(origin: CGPoint(x: insets.left, y: contentHeight), size: CGSize(width: sectionWidth, height: sectionHeight))
                
                if wasAdded {
                    sectionNode.frame = sectionFrame
                    sectionNode.alpha = self.state.isEditing ? 1.0 : 0.0
                } else {
                    if additive {
                        transition.updateFrameAdditive(node: sectionNode, frame: sectionFrame)
                    } else {
                        transition.updateFrame(node: sectionNode, frame: sectionFrame)
                    }
                    transition.updateAlpha(node: sectionNode, alpha: self.state.isEditing ? 1.0 : 0.0)
                }
                if !sectionHeight.isZero && self.state.isEditing {
                    contentHeight += sectionHeight
                    contentHeight += sectionSpacing
                }
            }
            var removeEditingSections: [AnyHashable] = []
            for (sectionId, _) in self.editingSections {
                if !validEditingSections.contains(sectionId) {
                    removeEditingSections.append(sectionId)
                }
            }
            for sectionId in removeEditingSections {
                if let sectionNode = self.editingSections.removeValue(forKey: sectionId) {
                    sectionNode.removeFromSupernode()
                }
            }
        }
        
        let paneContainerSize = CGSize(width: layout.size.width, height: layout.size.height - navigationHeight)
        var restoreContentOffset: CGPoint?
        if additive {
            restoreContentOffset = self.scrollNode.view.contentOffset
        }
        
        let paneContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: paneContainerSize)
        if self.state.isEditing || (self.data?.availablePanes ?? []).isEmpty {
            transition.updateAlpha(node: self.paneContainerNode, alpha: 0.0)
        } else {
            contentHeight += layout.size.height - navigationHeight
            transition.updateAlpha(node: self.paneContainerNode, alpha: 1.0)
        }
        
        if let selectedMessageIds = self.state.selectedMessageIds {
            var wasAdded = false
            let selectionPanelNode: PeerInfoSelectionPanelNode
            if let current = self.paneContainerNode.selectionPanelNode {
                selectionPanelNode = current
            } else {
                wasAdded = true
                selectionPanelNode = PeerInfoSelectionPanelNode(context: self.context, presentationData: self.presentationData, peerId: self.peerId, deleteMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.deleteMessages(messageIds: nil)
                }, shareMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty, strongSelf.peerId.namespace != Namespaces.Peer.SecretChat else {
                        return
                    }
                    let _ = (strongSelf.context.engine.data.get(EngineDataMap(
                        messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
                    ))
                    |> deliverOnMainQueue).startStandalone(next: { messageMap in
                        let messages = messageMap.values.compactMap { $0 }
                        
                        if let strongSelf = self, !messages.isEmpty {
                            strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                            
                            let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                                return lhs.index < rhs.index
                            }).map({ $0._asMessage() })), externalShare: true, immediateExternalShare: true, updatedPresentationData: strongSelf.controller?.updatedPresentationData)
                            strongSelf.view.endEditing(true)
                            strongSelf.controller?.present(shareController, in: .window(.root))
                        }
                    })
                }, forwardMessages: { [weak self] in
                    guard let strongSelf = self, strongSelf.peerId.namespace != Namespaces.Peer.SecretChat else {
                        return
                    }
                    strongSelf.forwardMessages(messageIds: nil)
                }, reportMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    strongSelf.view.endEditing(true)
                    
                    strongSelf.context.sharedContext.makeContentReportScreen(context: strongSelf.context, subject: .messages(Array(messageIds).sorted()), forceDark: false, present: { [weak self] controller in
                        self?.controller?.push(controller)
                    }, completion: {}, requestSelectMessages: nil)
                }, displayCopyProtectionTip: { [weak self] node, save in
                    if let strongSelf = self, let peer = strongSelf.data?.peer, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty {
                        let _ = (strongSelf.context.engine.data.get(EngineDataMap(
                            messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
                        ))
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] messageMap in
                            guard let strongSelf = self else {
                                return
                            }
                            let messages = messageMap.values.compactMap { $0 }
                            enum PeerType {
                                case group
                                case channel
                                case bot
                                case user
                            }
                            var isBot = false
                            for message in messages {
                                if let author = message.author, case let .user(user) = author {
                                    if user.botInfo != nil && !user.id.isVerificationCodes {
                                        isBot = true
                                    }
                                    break
                                }
                            }
                            let type: PeerType
                            if isBot {
                                type = .bot
                            } else if let user = peer as? TelegramUser {
                                if user.botInfo != nil && !user.id.isVerificationCodes {
                                    type = .bot
                                } else {
                                    type = .user
                                }
                            } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                type = .channel
                            }  else {
                                type = .group
                            }
                            
                            let text: String
                            switch type {
                            case .group:
                                text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledGroup : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledGroup
                            case .channel:
                                text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledChannel : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledChannel
                            case .bot:
                                text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledBot : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledBot
                            case .user:
                                text = save ? strongSelf.presentationData.strings.Conversation_CopyProtectionSavingDisabledSecret : strongSelf.presentationData.strings.Conversation_CopyProtectionForwardingDisabledSecret
                            }
                            
                            strongSelf.copyProtectionTooltipController?.dismiss()
                            let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                            strongSelf.copyProtectionTooltipController = tooltipController
                            tooltipController.dismissed = { [weak tooltipController] _ in
                                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.copyProtectionTooltipController === tooltipController {
                                    strongSelf.copyProtectionTooltipController = nil
                                }
                            }
                            strongSelf.controller?.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                                if let strongSelf = self {
                                    let rect = node.view.convert(node.view.bounds, to: strongSelf.view).offsetBy(dx: 0.0, dy: 3.0)
                                    return (strongSelf, rect)
                                }
                                return nil
                            }))
                        })
                   }
                })
                self.paneContainerNode.selectionPanelNode = selectionPanelNode
                self.paneContainerNode.addSubnode(selectionPanelNode)
                if let viewForOverlayContent = selectionPanelNode.viewForOverlayContent {
                    self.paneContainerNode.view.addSubview(viewForOverlayContent)
                }
            }
            selectionPanelNode.selectionPanel.selectedMessages = selectedMessageIds
            let panelHeight = selectionPanelNode.update(layout: layout, presentationData: self.presentationData, transition: wasAdded ? .immediate : transition)
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: paneContainerSize.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            if wasAdded {
                selectionPanelNode.frame = panelFrame
                transition.animatePositionAdditive(node: selectionPanelNode, offset: CGPoint(x: 0.0, y: panelHeight))
                
                if let viewForOverlayContent = selectionPanelNode.viewForOverlayContent {
                    viewForOverlayContent.frame = panelFrame
                    transition.animatePositionAdditive(layer: viewForOverlayContent.layer, offset: CGPoint(x: 0.0, y: panelHeight))
                }
            } else {
                transition.updateFrame(node: selectionPanelNode, frame: panelFrame)
                
                if let viewForOverlayContent = selectionPanelNode.viewForOverlayContent {
                    transition.updateFrame(view: viewForOverlayContent, frame: panelFrame)
                }
            }
        } else if let selectionPanelNode = self.paneContainerNode.selectionPanelNode {
            self.paneContainerNode.selectionPanelNode = nil
            transition.updateFrame(node: selectionPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: selectionPanelNode.bounds.size), completion: { [weak selectionPanelNode] _ in
                selectionPanelNode?.removeFromSupernode()
                selectionPanelNode?.viewForOverlayContent?.removeFromSuperview()
            })
        }
        
        if self.isSettings {
            contentHeight = max(contentHeight, layout.size.height + 140.0 - layout.intrinsicInsets.bottom)
        }
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
        if self.isSettings {
            self.scrollNode.view.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
        }
        if let restoreContentOffset = restoreContentOffset {
            self.scrollNode.view.contentOffset = restoreContentOffset
        }
                
        if additive {
            transition.updateFrameAdditive(node: self.paneContainerNode, frame: paneContainerFrame)
        } else {
            transition.updateFrame(node: self.paneContainerNode, frame: paneContainerFrame)
        }
                
        self.ignoreScrolling = false
        self.updateNavigation(transition: transition, additive: additive, animateHeader: self.controller?.didAppear ?? false)
        
        if !self.didSetReady && self.data != nil {
            self.didSetReady = true
            let avatarReady = self.headerNode.avatarListNode.isReady.get()
            let combinedSignal = combineLatest(queue: .mainQueue(),
                avatarReady,
                self.storiesReady.get(),
                self.paneContainerNode.isReady.get()
            )
            |> map { a, b, c in
                return a && b && c
            }
            self._ready.set(combinedSignal
            |> filter { $0 }
            |> take(1))
        }
    }
        
    private var hasQrButton = false
    fileprivate func updateNavigation(transition: ContainedViewLayoutTransition, additive: Bool, animateHeader: Bool) {
        let offsetY = self.scrollNode.view.contentOffset.y
        
        if self.isSettings, !(self.controller?.movingInHierarchy == true) {
            var bottomInset = self.scrollNode.view.contentInset.bottom
            if let layout = self.validLayout?.0, case .compact = layout.metrics.widthClass {
                bottomInset = min(83.0, bottomInset)
            }
            let bottomOffsetY = max(0.0, self.scrollNode.view.contentSize.height + bottomInset - offsetY - self.scrollNode.frame.height)
            let backgroundAlpha: CGFloat = min(30.0, bottomOffsetY) / 30.0
            
            if let tabBarController = self.controller?.parent as? TabBarController {
                tabBarController.updateBackgroundAlpha(backgroundAlpha, transition: transition)
            }
        }
                
        if self.state.isEditing || offsetY <= 50.0 || self.paneContainerNode.alpha.isZero {
            if !self.scrollNode.view.bounces {
                self.scrollNode.view.bounces = true
                self.scrollNode.view.alwaysBounceVertical = true
            }
        } else {
            if self.scrollNode.view.bounces {
                self.scrollNode.view.bounces = false
                self.scrollNode.view.alwaysBounceVertical = false
            }
        }
                
        if let (layout, navigationHeight) = self.validLayout {
            let navigationHeight = self.updateNavigationHeight(width: layout.size.width, defaultHeight: navigationHeight, insets: UIEdgeInsets(top: 0.0, left: layout.safeInsets.left, bottom: 0.0, right: layout.safeInsets.right), transition: transition)
            
            if !additive {
                let sectionInset: CGFloat
                if layout.size.width >= 375.0 {
                    sectionInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
                } else {
                    sectionInset = 0.0
                }
                let headerInset = sectionInset

                let _ = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : offsetY, paneContainerY: self.paneContainerNode.frame.minY, presentationData: self.presentationData, peer: self.data?.savedMessagesPeer ?? self.data?.peer, cachedData: self.data?.cachedData, threadData: self.data?.threadData, peerNotificationSettings: self.data?.peerNotificationSettings, threadNotificationSettings: self.data?.threadNotificationSettings, globalNotificationSettings: self.data?.globalNotificationSettings, statusData: self.data?.status, panelStatusData: self.customStatusData, isSecretChat: self.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, profileGiftsContext: self.data?.profileGiftsContext, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, transition: self.headerNode.navigationTransition == nil ? transition : .immediate, additive: additive, animateHeader: animateHeader && self.headerNode.navigationTransition == nil)
            }
            
            let paneAreaExpansionDistance: CGFloat = 32.0
            let effectiveAreaExpansionFraction: CGFloat
            if self.state.isEditing {
                effectiveAreaExpansionFraction = 0.0
            } else if self.isSettings {
                var paneAreaExpansionDelta = (self.headerNode.frame.maxY - navigationHeight) - self.scrollNode.view.contentOffset.y
                paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
                effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            } else {
                var paneAreaExpansionDelta = (self.paneContainerNode.frame.minY - navigationHeight) - self.scrollNode.view.contentOffset.y
                paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
                effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            }
            
            let visibleHeight = self.scrollNode.view.contentOffset.y + self.scrollNode.view.bounds.height - self.paneContainerNode.frame.minY
            
            var bottomInset = layout.intrinsicInsets.bottom
            if let selectionPanelNode = self.paneContainerNode.selectionPanelNode {
                bottomInset = max(bottomInset, selectionPanelNode.bounds.height)
            }
            
            var disableTabSwitching = false
            if self.state.selectedStoryIds != nil || self.state.paneIsReordering {
                disableTabSwitching = true
            }
                        
            let navigationBarHeight: CGFloat = !self.isSettings && layout.isModalOverlay ? 56.0 : 44.0
            self.paneContainerNode.update(size: self.paneContainerNode.bounds.size, sideInset: layout.safeInsets.left, bottomInset: bottomInset, deviceMetrics: layout.deviceMetrics, visibleHeight: visibleHeight, expansionFraction: effectiveAreaExpansionFraction, presentationData: self.presentationData, data: self.data, areTabsHidden: self.headerNode.customNavigationContentNode != nil, disableTabSwitching: disableTabSwitching, navigationHeight: navigationHeight, transition: transition)
          
            transition.updateFrame(node: self.headerNode.navigationButtonContainer, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left, y: layout.statusBarHeight ?? 0.0), size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight)))
            
                        
            var leftNavigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            var rightNavigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            if self.state.isEditing {
                leftNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .cancel, isForExpandedView: false))
                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .done, isForExpandedView: false))
            } else {
                if self.isSettings {
                    leftNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .qrCode, isForExpandedView: false))
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
                } else if self.isMyProfile {
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                } else if peerInfoCanEdit(peer: self.data?.peer, chatLocation: self.chatLocation, threadData: self.data?.threadData, cachedData: self.data?.cachedData, isContact: self.data?.isContact) {
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                }
                if let data = self.data, !data.isPremiumRequiredForStoryPosting || data.accountIsPremium, let channel = data.peer as? TelegramChannel, channel.hasPermission(.postStories) {
                    rightNavigationButtons.insert(PeerInfoHeaderNavigationButtonSpec(key: .postStory, isForExpandedView: false), at: 0)
                } else if self.isMyProfile {
                    rightNavigationButtons.insert(PeerInfoHeaderNavigationButtonSpec(key: .postStory, isForExpandedView: false), at: 0)
                }
                
                if self.state.selectedMessageIds == nil && self.state.selectedStoryIds == nil && !self.state.paneIsReordering {
                    if let currentPaneKey = self.paneContainerNode.currentPaneKey {
                        switch currentPaneKey {
                        case .files, .music, .links, .members:
                            rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
                        case .savedMessagesChats:
                            if let data = self.data, data.hasSavedMessageTags {
                                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .searchWithTags, isForExpandedView: true))
                            } else {
                                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .standaloneSearch, isForExpandedView: true))
                            }
                            rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .more, isForExpandedView: true))
                        case .savedMessages:
                            if let data = self.data, data.hasSavedMessageTags {
                                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .searchWithTags, isForExpandedView: true))
                            } else {
                                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
                            }
                        case .media:
                            rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .more, isForExpandedView: true))
                        case .botPreview:
                            if let data = self.data, data.hasBotPreviewItems, let user = data.peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
                                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .more, isForExpandedView: true))
                            }
                        case .gifts:
                            //if let data = self.data, let channel = data.peer as? TelegramChannel, case .broadcast = channel.info {
                                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .sort, isForExpandedView: true))
                            //}
                        default:
                            break
                        }
                        switch currentPaneKey {
                        case .media, .files, .music, .links, .voice:
                            //navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .select, isForExpandedView: true))
                            break
                        default:
                            break
                        }
                    }
                } else {
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .selectionDone, isForExpandedView: true))
                }
            }
            if leftNavigationButtons.isEmpty, let controller = self.controller, let previousItem = controller.previousItem {
                switch previousItem {
                case .close, .item:
                    leftNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .back, isForExpandedView: false))
                }
            }
            self.headerNode.navigationButtonContainer.update(size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight), presentationData: self.presentationData, leftButtons: leftNavigationButtons, rightButtons: rightNavigationButtons, expandFraction: effectiveAreaExpansionFraction, shouldAnimateIn: animateHeader, transition: transition)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        cancelContextGestures(view: scrollView)
        self.canAddVelocity = true
        self.canOpenAvatarByDragging = self.headerNode.isAvatarExpanded
        self.paneContainerNode.currentPane?.node.cancelPreviewGestures()
    }
    
    private var previousVelocityM1: CGFloat = 0.0
    private var previousVelocity: CGFloat = 0.0
    private var canAddVelocity: Bool = false
    
    private var canOpenAvatarByDragging = false
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.ignoreScrolling else {
            return
        }
                        
        if !self.state.isEditing {
            if self.canAddVelocity {
                self.previousVelocityM1 = self.previousVelocity
                if let value = (scrollView.value(forKey: (["_", "verticalVelocity"] as [String]).joined()) as? NSNumber)?.doubleValue {
                    self.previousVelocity = CGFloat(value)
                }
            }
            
            let offsetY = self.scrollNode.view.contentOffset.y
            var shouldBeExpanded: Bool?
            
            var isLandscape = false
            if let (layout, _) = self.validLayout, layout.size.width > layout.size.height {
                isLandscape = true
            }
            if offsetY <= -32.0 && scrollView.isDragging && scrollView.isTracking {
                if let peer = self.data?.peer, self.chatLocation.threadId == nil, peer.smallProfileImage != nil && self.state.updatingAvatar == nil && !isLandscape {
                    shouldBeExpanded = true
                    
                    if self.canOpenAvatarByDragging && self.headerNode.isAvatarExpanded && offsetY <= -32.0 {
                        self.hapticFeedback.impact()
                        
                        self.canOpenAvatarByDragging = false
                        let contentOffset = scrollView.contentOffset.y
                        scrollView.panGestureRecognizer.isEnabled = false
                        self.headerNode.initiateAvatarExpansion(gallery: true, first: false)
                        scrollView.panGestureRecognizer.isEnabled = true
                        scrollView.contentOffset = CGPoint(x: 0.0, y: contentOffset)
                        UIView.animate(withDuration: 0.1) {
                            scrollView.contentOffset = CGPoint()
                        }
                    }
                }
            } else if offsetY >= 1.0 {
                shouldBeExpanded = false
                self.canOpenAvatarByDragging = false
            }
            if let shouldBeExpanded = shouldBeExpanded, shouldBeExpanded != self.headerNode.isAvatarExpanded {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)
                
                if shouldBeExpanded {
                    self.hapticFeedback.impact()
                } else {
                    self.hapticFeedback.tap()
                }
                
                self.headerNode.updateIsAvatarExpanded(shouldBeExpanded, transition: transition)
                self.updateNavigationExpansionPresentation(isExpanded: shouldBeExpanded, animated: true)
                
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                }
            }
        }
        
        self.updateNavigation(transition: .immediate, additive: false, animateHeader: true)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        
        let paneAreaExpansionFinalPoint: CGFloat = self.paneContainerNode.frame.minY - navigationHeight
        if abs(scrollView.contentOffset.y - paneAreaExpansionFinalPoint) < .ulpOfOne {
            self.paneContainerNode.currentPane?.node.transferVelocity(self.previousVelocityM1)
        }
    }
    
    fileprivate func resetHeaderExpansion() {
        if self.headerNode.isAvatarExpanded {
            self.headerNode.ignoreCollapse = true
            self.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
            self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
            self.headerNode.ignoreCollapse = false
        }
    }
    
    func updateNavigationExpansionPresentation(isExpanded: Bool, animated: Bool) {
        /*if let controller = self.controller {
            if animated {
                UIView.transition(with: controller.controllerNode.headerNode.navigationButtonContainer.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                }, completion: nil)
            }
            
            let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
            let navigationBarPresentationData = NavigationBarPresentationData(
                theme: NavigationBarTheme(
                    buttonColor: .white,
                    disabledButtonColor: baseNavigationBarPresentationData.theme.disabledButtonColor,
                    primaryTextColor: baseNavigationBarPresentationData.theme.primaryTextColor,
                    backgroundColor: .clear,
                    enableBackgroundBlur: false,
                    separatorColor: .clear,
                    badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                    badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                    badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
            ), strings: baseNavigationBarPresentationData.strings)
            
            controller.setNavigationBarPresentationData(navigationBarPresentationData, animated: animated)
        }*/
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        if self.state.isEditing {
            if self.isSettings || self.isMyProfile {
                if targetContentOffset.pointee.y < navigationHeight {
                    if targetContentOffset.pointee.y < navigationHeight / 2.0 {
                        targetContentOffset.pointee.y = 0.0
                    } else {
                        targetContentOffset.pointee.y = navigationHeight
                    }
                }
            }
        } else {
            let height: CGFloat = (self.isSettings || self.isMyProfile) ? 140.0 : 140.0
            if targetContentOffset.pointee.y < height {
                if targetContentOffset.pointee.y < height / 2.0 {
                    targetContentOffset.pointee.y = 0.0
                    self.canAddVelocity = false
                    self.previousVelocity = 0.0
                    self.previousVelocityM1 = 0.0
                } else {
                    targetContentOffset.pointee.y = height
                    self.canAddVelocity = false
                    self.previousVelocity = 0.0
                    self.previousVelocityM1 = 0.0
                }
            }
            if !self.isSettings && !self.isMyProfile {
                let paneAreaExpansionDistance: CGFloat = 32.0
                let paneAreaExpansionFinalPoint: CGFloat = self.paneContainerNode.frame.minY - navigationHeight
                if targetContentOffset.pointee.y > paneAreaExpansionFinalPoint - paneAreaExpansionDistance && targetContentOffset.pointee.y < paneAreaExpansionFinalPoint {
                    targetContentOffset.pointee.y = paneAreaExpansionFinalPoint
                    self.canAddVelocity = false
                    self.previousVelocity = 0.0
                    self.previousVelocityM1 = 0.0
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        var currentParent: UIView? = result
        while true {
            if currentParent == nil || currentParent === self.view {
                break
            }
            if let scrollView = currentParent as? UIScrollView {
                if scrollView === self.scrollNode.view {
                    break
                }
                if scrollView.isDecelerating && scrollView.contentOffset.y < -scrollView.contentInset.top {
                    return self.scrollNode.view
                }
            } else if let listView = currentParent as? ListViewBackingView, let listNode = listView.target {
                if listNode.scroller.isDecelerating && listNode.scroller.contentOffset.y < listNode.scroller.contentInset.top {
                    return self.scrollNode.view
                }
            }
            currentParent = currentParent?.superview
        }
        return result
    }
    
    fileprivate func presentSelectionDiscardAlert(action: @escaping () -> Void = {}) -> Bool {
        if let selectedIds = self.chatInterfaceInteraction.selectionState?.selectedIds, !selectedIds.isEmpty {
            self.controller?.present(textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: self.presentationData.strings.PeerInfo_CancelSelectionAlertText, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.PeerInfo_CancelSelectionAlertNo, action: {}), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.PeerInfo_CancelSelectionAlertYes, action: {
                action()
            })]), in: .window(.root))
            return true
        }
        return false
    }
    
    fileprivate func joinChannel(peer: EnginePeer) {
        let presentationData = self.presentationData
        self.joinChannelDisposable.set((
            self.context.peerChannelMemberCategoriesContextsManager.join(engine: self.context.engine, peerId: peer.id, hash: nil)
            |> deliverOnMainQueue
            |> afterCompleted { [weak self] in
                Queue.mainQueue().async {
                    if let self {
                        self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.Chat_SimilarChannels_JoinedChannel(peer.compactDisplayTitle).string, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                }
            }
        ).startStrict(error: { [weak self] error in
            guard let self else {
                return
            }
            let text: String
            switch error {
            case .inviteRequestSent:
                self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationData.strings.Group_RequestToJoinSent, text: presentationData.strings.Group_RequestToJoinSentDescriptionGroup), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                return
            case .tooMuchJoined:
                self.controller?.push(oldChannelsController(context: context, intent: .join, completed: { [weak self] value in
                    if value {
                        self?.joinChannel(peer: peer)
                    }
                }))
                return
            case .tooMuchUsers:
                text = self.presentationData.strings.Conversation_UsersTooMuchError
            case .generic:
                text = self.presentationData.strings.Channel_ErrorAccessDenied
            }
            self.controller?.present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }))
    }
    
    private var didPlayBirthdayAnimation = false
    private weak var birthdayOverlayNode: PeerInfoBirthdayOverlay?
    func maybePlayBirthdayAnimation() {
        guard !self.didPlayBirthdayAnimation, !self.isSettings && !self.isMyProfile && !self.isMediaOnly, let cachedData = self.data?.cachedData as? CachedUserData, let birthday = cachedData.birthday, let (layout, _) = self.validLayout else {
            return
        }
        
        self.didPlayBirthdayAnimation = true
        
        if hasBirthdayToday(cachedData: cachedData) {
            Queue.mainQueue().after(0.3) {
                var birthdayItemFrame: CGRect?
                if let section = self.regularSections[InfoSection.peerInfo] {
                    if let birthdayItem = section.itemNodes[AnyHashable(400)] {
                        birthdayItemFrame = birthdayItem.view.convert(birthdayItem.view.bounds, to: self.view)
                    }
                }
                
                let overlayNode = PeerInfoBirthdayOverlay(context: self.context)
                overlayNode.frame = CGRect(origin: .zero, size: layout.size)
                overlayNode.setup(size: layout.size, birthday: birthday, sourceRect: birthdayItemFrame)
                self.addSubnode(overlayNode)
            }
        }
    }
    
    func refreshHasPersonalChannelsIfNeeded() {
        if !self.isSettings && !self.isMyProfile {
            return
        }
        if self.personalChannelsDisposable != nil {
            return
        }
        self.personalChannelsDisposable = (self.context.engine.peers.adminedPublicChannels(scope: .forPersonalProfile)
        |> deliverOnMainQueue).startStrict(next: { [weak self] personalChannels in
            guard let self else {
                return
            }
            self.personalChannelsDisposable?.dispose()
            self.personalChannelsDisposable = nil
            
            if self.state.personalChannels != personalChannels {
                self.state = self.state.withPersonalChannels(personalChannels)
                
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
                }
            }
        })
    }
    
    func toggleStorySelection(ids: [Int32], isSelected: Bool) {
        self.expandTabs(animated: true)
        
        if var selectedStoryIds = self.state.selectedStoryIds {
            for id in ids {
                if isSelected {
                    selectedStoryIds.insert(id)
                } else {
                    selectedStoryIds.remove(id)
                }
            }
            self.state = self.state.withSelectedStoryIds(selectedStoryIds)
        } else {
            self.state = self.state.withSelectedStoryIds(isSelected ? Set(ids) : Set())
        }
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
        }
        self.paneContainerNode.updateSelectedStoryIds(self.state.selectedStoryIds, animated: true)
    }
    
    func togglePaneIsReordering(isReordering: Bool) {
        self.expandTabs(animated: true)
        
        self.state = self.state.withPaneIsReordering(true)
        
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
        }
        self.paneContainerNode.updatePaneIsReordering(isReordering: self.state.paneIsReordering, animated: true)
    }
    
    func cancelItemSelection() {
        self.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
    }
    
    func openAvatarGallery(peer: EnginePeer, entries: [AvatarGalleryEntry], centralEntry: AvatarGalleryEntry?, animateTransition: Bool) {
        let entriesPromise = Promise<[AvatarGalleryEntry]>(entries)
        let galleryController = AvatarGalleryController(context: self.context, peer: peer, sourceCorners: .round, remoteEntries: entriesPromise, skipInitial: true, centralEntryIndex: centralEntry.flatMap { entries.firstIndex(of: $0) }, replaceRootController: { controller, ready in
        })
        galleryController.openAvatarSetup = { [weak self] completion in
            self?.controller?.openAvatarForEditing(fromGallery: true, completion: { _ in
                completion()
            })
        }
        galleryController.removedEntry = { [weak self] entry in
            if let item = PeerInfoAvatarListItem(entry: entry) {
                let _ = self?.headerNode.avatarListNode.listContainerNode.deleteItem(item)
            }
        }
        self.hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).startStrict(next: { [weak self] entry in
            self?.headerNode.updateAvatarIsHidden(entry: entry)
        }))
        self.view.endEditing(true)
        let arguments = AvatarGalleryControllerPresentationArguments(transitionArguments: { [weak self] _ in
            if animateTransition, let entry = centralEntry, let transitionNode = self?.headerNode.avatarTransitionArguments(entry: entry) {
                return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: { view in
                    self?.headerNode.addToAvatarTransitionSurface(view: view)
                })
            } else {
                return nil
            }
        })
        if self.controller?.navigationController != nil {
            self.controller?.present(galleryController, in: .window(.root), with: arguments)
        } else {
            galleryController.presentationArguments = arguments
            self.context.sharedContext.mainWindow?.present(galleryController, on: .root)
        }
    }
}

public final class PeerInfoScreenImpl: ViewController, PeerInfoScreen, KeyShortcutResponder {
    let context: AccountContext
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let peerId: PeerId
    private let avatarInitiallyExpanded: Bool
    private let isOpenedFromChat: Bool
    private let nearbyPeerDistance: Int32?
    private let reactionSourceMessageId: MessageId?
    private let callMessages: [Message]
    let isSettings: Bool
    let isMyProfile: Bool
    private let hintGroupInCommon: PeerId?
    private weak var requestsContext: PeerInvitationImportersContext?
    private weak var profileGiftsContext: ProfileGiftsContext?
    fileprivate let starsContext: StarsContext?
    private let switchToRecommendedChannels: Bool
    private let switchToGifts: Bool
    private let switchToGroupsInCommon: Bool
    let chatLocation: ChatLocation
    private let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
    
    public weak var parentController: TelegramRootControllerInterface?
    
    private(set) var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let cachedDataPromise = Promise<CachedPeerData?>()
    
    private let accountsAndPeers = Promise<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)])>()
    private var accountsAndPeersValue: ((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)])?
    private var accountsAndPeersDisposable: Disposable?
    
    private let activeSessionsContextAndCount = Promise<(ActiveSessionsContext, Int, WebSessionsContext)?>(nil)

    private var tabBarItemDisposable: Disposable?

    var controllerNode: PeerInfoScreenNode {
        return self.displayNode as! PeerInfoScreenNode
    }
    
    private let _readyProxy = Promise<Bool>()
    private let _readyInternal = Promise<Bool>()
    private var readyInternalDisposable: Disposable?
    override public var ready: Promise<Bool> {
        return self._readyProxy
    }
    
    public var privacySettings: Promise<AccountPrivacySettings?> {
        return self.controllerNode.privacySettings
    }
    
    override public var customNavigationData: CustomViewControllerNavigationData? {
        get {
            if !self.isSettings {
                return ChatControllerNavigationData(peerId: self.peerId, threadId: self.chatLocation.threadId)
            } else {
                return nil
            }
        }
    }
    
    override public var previousItem: NavigationPreviousAction? {
        didSet {
            if self.isNodeLoaded {
                if let (layout, navigationHeight) = self.validLayout {
                    self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
                }
            }
        }
    }
    
    var didAppear: Bool = false
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
        peerId: PeerId,
        avatarInitiallyExpanded: Bool,
        isOpenedFromChat: Bool,
        nearbyPeerDistance: Int32?,
        reactionSourceMessageId: MessageId?,
        callMessages: [Message],
        isSettings: Bool = false,
        isMyProfile: Bool = false,
        hintGroupInCommon: PeerId? = nil,
        requestsContext: PeerInvitationImportersContext? = nil,
        profileGiftsContext: ProfileGiftsContext? = nil,
        forumTopicThread: ChatReplyThreadMessage? = nil,
        switchToRecommendedChannels: Bool = false,
        switchToGifts: Bool = false,
        switchToGroupsInCommon: Bool = false
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.peerId = peerId
        self.avatarInitiallyExpanded = avatarInitiallyExpanded
        self.isOpenedFromChat = isOpenedFromChat
        self.nearbyPeerDistance = nearbyPeerDistance
        self.reactionSourceMessageId = reactionSourceMessageId
        self.callMessages = callMessages
        self.isSettings = isSettings
        self.isMyProfile = isMyProfile
        self.hintGroupInCommon = hintGroupInCommon
        self.requestsContext = requestsContext
        self.profileGiftsContext = profileGiftsContext
        self.switchToRecommendedChannels = switchToRecommendedChannels
        self.switchToGifts = switchToGifts
        self.switchToGroupsInCommon = switchToGroupsInCommon
        
        if let forumTopicThread = forumTopicThread {
            self.chatLocation = .replyThread(message: forumTopicThread)
        } else {
            self.chatLocation = .peer(id: peerId)
        }
        
        if isSettings, let starsContext = context.starsContext {
            self.starsContext = starsContext
            starsContext.load(force: true)
        } else {
            self.starsContext = nil
        }
        
        if isMyProfile, let profileGiftsContext {
            profileGiftsContext.updateFilter(.All)
            profileGiftsContext.updateSorting(.date)
            profileGiftsContext.reload()
        }
        
        self.presentationData = updatedPresentationData?.0 ?? context.sharedContext.currentPresentationData.with { $0 }
        
        let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        super.init(navigationBarPresentationData: NavigationBarPresentationData(
            theme: NavigationBarTheme(
                buttonColor: .white,
                disabledButtonColor: .white,
                primaryTextColor: .white,
                backgroundColor: .clear,
                enableBackgroundBlur: false,
                separatorColor: .clear,
                badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
        ), strings: baseNavigationBarPresentationData.strings))
        
        self.navigationBar?.enableAutomaticBackButton = false
                
        if isSettings || isMyProfile {
            let activeSessionsContextAndCountSignal = deferred { () -> Signal<(ActiveSessionsContext, Int, WebSessionsContext)?, NoError> in
                let activeSessionsContext = context.engine.privacy.activeSessions()
                let webSessionsContext = context.engine.privacy.webSessions()
                let otherSessionCount = activeSessionsContext.state
                |> map { state -> Int in
                    return state.sessions.filter({ !$0.isCurrent }).count
                }
                |> distinctUntilChanged
                return otherSessionCount
                |> map { value in
                    return (activeSessionsContext, value, webSessionsContext)
                }
            }
            self.activeSessionsContextAndCount.set(activeSessionsContextAndCountSignal)
            
            self.accountsAndPeers.set(activeAccountsAndPeers(context: context))
            self.accountsAndPeersDisposable = (self.accountsAndPeers.get()
            |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                self?.accountsAndPeersValue = value
            })
            
            self.tabBarItemContextActionType = .always
            
            let notificationsFromAllAccounts = self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
            |> map { sharedData -> Bool in
                let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
                return settings.displayNotificationsFromAllAccounts
            }
            |> distinctUntilChanged
            
            let accountTabBarAvatarBadge: Signal<Int32, NoError> = combineLatest(notificationsFromAllAccounts, self.accountsAndPeers.get())
            |> map { notificationsFromAllAccounts, primaryAndOther -> Int32 in
                if !notificationsFromAllAccounts {
                    return 0
                }
                let (primary, other) = primaryAndOther
                if let _ = primary, !other.isEmpty {
                    return other.reduce(into: 0, { (result, next) in
                        result += next.2
                    })
                } else {
                    return 0
                }
            }
            |> distinctUntilChanged
            
            let accountTabBarAvatar: Signal<(UIImage, UIImage)?, NoError> = combineLatest(self.accountsAndPeers.get(), context.sharedContext.presentationData)
            |> map { primaryAndOther, presentationData -> (Account, EnginePeer, PresentationTheme)? in
                if let primary = primaryAndOther.0, !primaryAndOther.1.isEmpty {
                    return (primary.0.account, primary.1, presentationData.theme)
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged(isEqual: { $0?.0 === $1?.0 && $0?.1 == $1?.1 && $0?.2 === $1?.2 })
            |> mapToSignal { primary -> Signal<(UIImage, UIImage)?, NoError> in
                if let primary = primary {
                    let size = CGSize(width: 31.0, height: 31.0)
                    let inset: CGFloat = 3.0
                    if let signal = peerAvatarImage(account: primary.0, peerReference: PeerReference(primary.1._asPeer()), authorOfMessage: nil, representation: primary.1.profileImageRepresentations.first, displayDimensions: size, inset: 3.0, emptyColor: nil, synchronousLoad: false) {
                        return signal
                        |> map { imageVersions -> (UIImage, UIImage)? in
                            if let image = imageVersions?.0 {
                                return (image.withRenderingMode(.alwaysOriginal), image.withRenderingMode(.alwaysOriginal))
                            } else {
                                return nil
                            }
                        }
                    } else {
                        return Signal { subscriber in
                            let avatarFont = avatarPlaceholderFont(size: 13.0)
                            var displayLetters = primary.1.displayLetters
                            if displayLetters.count == 2 && displayLetters[0].isSingleEmoji && displayLetters[1].isSingleEmoji {
                                displayLetters = [displayLetters[0]]
                            }
                            let image = generateImage(size, rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                context.translateBy(x: inset, y: inset)
                                
                                drawPeerAvatarLetters(context: context, size: CGSize(width: size.width - inset * 2.0, height: size.height - inset * 2.0), font: avatarFont, letters: displayLetters, peerId: primary.1.id, nameColor: primary.1.nameColor)
                            })?.withRenderingMode(.alwaysOriginal)
                            if let image = image {
                                subscriber.putNext((image, image))
                            } else {
                                subscriber.putNext(nil)
                            }
                            subscriber.putCompletion()
                            return EmptyDisposable
                        }
                        |> runOn(.concurrentDefaultQueue())
                    }
                } else {
                    return .single(nil)
                }
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if let lhs = lhs, let rhs = rhs {
                    if lhs.0 !== rhs.0 || lhs.1 !== rhs.1 {
                        return false
                    } else {
                        return true
                    }
                } else if (lhs == nil) != (rhs == nil) {
                    return false
                }
                return true
            })
            
            let notificationsAuthorizationStatus = Promise<AccessType>(.allowed)
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                notificationsAuthorizationStatus.set(
                    .single(.allowed)
                    |> then(DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications)
                    )
                )
            }
            
            let notificationsWarningSuppressed = Promise<Bool>(true)
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                notificationsWarningSuppressed.set(
                    .single(true)
                    |> then(context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .notifications)!)
                        |> map { noticeView -> Bool in
                            let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                            if let timestamp = timestamp, timestamp > 0 {
                                return true
                            } else {
                                return false
                            }
                        }
                    )
                )
            }
            
            let icon: UIImage?
            if useSpecialTabBarIcons() {
                icon = UIImage(bundleImageName: "Chat List/Tabs/Holiday/IconSettings")
            } else {
                icon = UIImage(bundleImageName: "Chat List/Tabs/IconSettings")
            }
            
            let tabBarItem: Signal<(String, UIImage?, UIImage?, String?, Bool, Bool), NoError> = combineLatest(queue: .mainQueue(), self.context.sharedContext.presentationData, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get(), context.engine.notices.getServerProvidedSuggestions(), accountTabBarAvatar, accountTabBarAvatarBadge)
            |> map { presentationData, notificationsAuthorizationStatus, notificationsWarningSuppressed, suggestions, accountTabBarAvatar, accountTabBarAvatarBadge -> (String, UIImage?, UIImage?, String?, Bool, Bool) in
                let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
                let phoneNumberWarning = suggestions.contains(.validatePhoneNumber)
                let passwordWarning = suggestions.contains(.validatePassword)
                var otherAccountsBadge: String?
                if accountTabBarAvatarBadge > 0 {
                    otherAccountsBadge = compactNumericCountString(Int(accountTabBarAvatarBadge), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                }
                return (presentationData.strings.Settings_Title, accountTabBarAvatar?.0 ?? icon, accountTabBarAvatar?.1 ?? icon, notificationsWarning || phoneNumberWarning || passwordWarning ? "!" : otherAccountsBadge, accountTabBarAvatar != nil, presentationData.reduceMotion)
            }
            
            self.tabBarItemDisposable = (tabBarItem |> deliverOnMainQueue).startStrict(next: { [weak self] title, image, selectedImage, badgeValue, isAvatar, reduceMotion in
                if let strongSelf = self {
                    strongSelf.tabBarItem.title = title
                    strongSelf.tabBarItem.image = image
                    strongSelf.tabBarItem.selectedImage = selectedImage
                    strongSelf.tabBarItem.animationName = isAvatar || reduceMotion ? nil : "TabSettings"
                    strongSelf.tabBarItem.ringSelection = isAvatar
                    strongSelf.tabBarItem.badgeValue = badgeValue
                }
            })
            
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        }
           
        if self.chatLocation.peerId != nil {
            /*self.navigationBar?.shouldTransitionInline = { [weak self] in
                guard let strongSelf = self else {
                    return false
                }
                if strongSelf.navigationItem.leftBarButtonItem != nil {
                    return false
                }
                if strongSelf.controllerNode.scrollNode.view.contentOffset.y > .ulpOfOne {
                    return false
                }
                if strongSelf.controllerNode.headerNode.isAvatarExpanded {
                    return false
                }
                return false
            }*/
            self.navigationBar?.makeCustomTransitionNode = { [weak self] other, isInteractive in
                guard let strongSelf = self else {
                    return nil
                }
                if strongSelf.navigationItem.leftBarButtonItem != nil {
                    return nil
                }
                if other.item?.leftBarButtonItem != nil {
                    return nil
                }
                if strongSelf.controllerNode.scrollNode.view.contentOffset.y > .ulpOfOne {
                    return nil
                }
                if strongSelf.controllerNode.initialExpandPanes {
                    return nil
                }
                if isInteractive && strongSelf.controllerNode.headerNode.isAvatarExpanded {
                    return nil
                }
                if let allowsCustomTransition = other.allowsCustomTransition, !allowsCustomTransition() {
                    return nil
                }
                if let tag = other.userInfo as? PeerInfoNavigationSourceTag, (tag.peerId == peerId || tag.threadId == peerId.toInt64()) {
                    return PeerInfoNavigationTransitionNode(screenNode: strongSelf.controllerNode, presentationData: strongSelf.presentationData, headerNode: strongSelf.controllerNode.headerNode)
                }
                return nil
            }
        }
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
        
        let presentationDataSignal: Signal<PresentationData, NoError>
        if let updatedPresentationData = updatedPresentationData {
            presentationDataSignal = updatedPresentationData.signal
        } else if self.peerId != self.context.account.peerId {
            let themeEmoticon: Signal<String?, NoError> = self.cachedDataPromise.get()
            |> map { cachedData -> String? in
                if let cachedData = cachedData as? CachedUserData {
                    return cachedData.themeEmoticon
                } else if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.themeEmoticon
                } else if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.themeEmoticon
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged
            
            presentationDataSignal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager, onlyCached: false), themeEmoticon)
            |> map { presentationData, chatThemes, themeEmoticon -> PresentationData in
                var presentationData = presentationData
                if let themeEmoticon = themeEmoticon, let theme = chatThemes.first(where: { $0.emoticon == themeEmoticon }) {
                    if let theme = makePresentationTheme(cloudTheme: theme, dark: presentationData.theme.overallDarkAppearance) {
                        presentationData = presentationData.withUpdated(theme: theme)
                        presentationData = presentationData.withUpdated(chatWallpaper: theme.chat.defaultWallpaper)
                    }
                }
                return presentationData
            }
        } else {
            presentationDataSignal = context.sharedContext.presentationData
        }
        
        self.presentationDataDisposable = (presentationDataSignal
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.controllerNode.updatePresentationData(strongSelf.presentationData)
                    
                    if strongSelf.navigationItem.backBarButtonItem != nil {
                        strongSelf.navigationItem.backBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
                    }
                }
            }
        })
        
        if !isSettings {
            self.attemptNavigation = { [weak self] action in
                guard let strongSelf = self else {
                    return true
                }

                if strongSelf.controllerNode.presentSelectionDiscardAlert(action: action) {
                    return false
                }
                
                return true
            }
        }
        
        self.readyInternalDisposable = (self._readyInternal.get()
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else {
                return
            }
            if self.controllerNode.initialExpandPanes {
                self.controllerNode.expandTabs(animated: false)
            }
            self._readyProxy.set(.single(true))
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.readyInternalDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.accountsAndPeersDisposable?.dispose()
        self.tabBarItemDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        var initialPaneKey: PeerInfoPaneKey?
        if self.switchToRecommendedChannels {
            initialPaneKey = .similarChannels
        } else if self.switchToGifts {
            initialPaneKey = .gifts
        } else if self.switchToGroupsInCommon {
            initialPaneKey = .groupsInCommon
        }
        self.displayNode = PeerInfoScreenNode(controller: self, context: self.context, peerId: self.peerId, avatarInitiallyExpanded: self.avatarInitiallyExpanded, isOpenedFromChat: self.isOpenedFromChat, nearbyPeerDistance: self.nearbyPeerDistance, reactionSourceMessageId: self.reactionSourceMessageId, callMessages: self.callMessages, isSettings: self.isSettings, isMyProfile: self.isMyProfile, hintGroupInCommon: self.hintGroupInCommon, requestsContext: self.requestsContext, profileGiftsContext: self.profileGiftsContext, starsContext: self.starsContext, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, initialPaneKey: initialPaneKey)
        self.controllerNode.accountsAndPeers.set(self.accountsAndPeers.get() |> map { $0.1 })
        self.controllerNode.activeSessionsContextAndCount.set(self.activeSessionsContextAndCount.get())
        self.cachedDataPromise.set(self.controllerNode.cachedDataPromise.get())
        self._readyInternal.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    fileprivate var movingInHierarchy = false
    public override func willMove(toParent viewController: UIViewController?) {
        super.willMove(toParent: parent)
        
        if self.isSettings, viewController == nil, let tabBarController = self.parent as? TabBarController {
            self.movingInHierarchy = true
            tabBarController.updateBackgroundAlpha(1.0, transition: .immediate)
        }
    }
    
    public override func didMove(toParent viewController: UIViewController?) {
        super.didMove(toParent: viewController)
        
        if self.isSettings {
            if viewController == nil {
                self.movingInHierarchy = false
                Queue.mainQueue().after(0.1) {
                    self.controllerNode.resetHeaderExpansion()
                }
            } else {
                self.controllerNode.updateNavigation(transition: .animated(duration: 0.15, curve: .easeInOut), additive: false, animateHeader: false)
            }
        }
    }
    
    private func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController, !controller.keepOnParentDismissal {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController, !controller.keepOnParentDismissal {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    override public func present(_ controller: ViewController, in context: PresentationContextType, with arguments: Any? = nil, blockInteraction: Bool = false, completion: @escaping () -> Void = {}) {
        self.dismissAllTooltips()
        
        super.present(controller, in: context, with: arguments, blockInteraction: blockInteraction, completion: completion)
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.dismissAllTooltips()
        
        if let emojiStatusSelectionController = self.controllerNode.emojiStatusSelectionController {
            self.controllerNode.emojiStatusSelectionController = nil
            emojiStatusSelectionController.dismiss()
        }
    }
    
    public func openAvatarSetup(completedWithUploadingImage: @escaping (UIImage, Signal<PeerInfoAvatarUploadStatus, NoError>) -> UIView?) {
        let proceed = { [weak self] in
            self?.openAvatarForEditing(completedWithUploadingImage: completedWithUploadingImage)
        }
        if !self.isNodeLoaded {
            self.loadDisplayNode()
            Queue.mainQueue().after(0.1) {
                proceed()
            }
        } else {
            proceed()
        }
    }
    
    public func openAvatars() {
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: self.peerId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            self.controllerNode.openAvatarGallery(peer: peer, entries: self.controllerNode.headerNode.avatarListNode.listContainerNode.galleryEntries, centralEntry: nil, animateTransition: false)
        })
    }
    
    static func openPeer(context: AccountContext, peerId: PeerId, navigation: ChatControllerInteractionNavigateToPeer, navigationController: NavigationController) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer else {
                return
            }
            switch navigation {
            case .default:
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always))
            case let .chat(_, subject, peekData):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: subject, keepStack: .always, peekData: peekData))
            case .info:
                if peer.restrictionText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) == nil {
                    if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        navigationController.pushViewController(infoController)
                    }
                }
            case let .withBotStartPayload(startPayload):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), botStart: startPayload))
            case let .withAttachBot(attachBotStart):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), attachBotStart: attachBotStart))
            case let .withBotApp(botAppStart):
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), botAppStart: botAppStart))
            }
        })
    }
    
    public static func displayChatNavigationMenu(context: AccountContext, chatNavigationStack: [ChatNavigationStackItem], nextFolderId: Int32?, parentController: ViewController, backButtonView: UIView, navigationController: NavigationController, gesture: ContextGesture) {
        let peerMap = EngineDataMap(
            Set(chatNavigationStack.map(\.peerId)).map(TelegramEngine.EngineData.Item.Peer.Peer.init)
        )
        let threadDataMap = EngineDataMap(
            Set(chatNavigationStack.filter { $0.threadId != nil }).map { TelegramEngine.EngineData.Item.Peer.ThreadData(id: $0.peerId, threadId: $0.threadId!) }
        )
        let _ = (context.engine.data.get(
            peerMap,
            threadDataMap
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak parentController, weak backButtonView, weak navigationController] peerMap, threadDataMap in
            guard let parentController, let backButtonView else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let avatarSize = CGSize(width: 28.0, height: 28.0)
            
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Navigation_AllChats, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Chats"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                
                if let controller = navigationController?.viewControllers.first as? TabBarController, let chatListController = controller.currentController as? ChatListControllerImpl {
                    chatListController.setInlineChatList(location: nil)
                }
                navigationController?.popToRoot(animated: true)
            })))
            
            for item in chatNavigationStack {
                guard let maybeItemPeer = peerMap[item.peerId], let itemPeer = maybeItemPeer else {
                    continue
                }
                
                let title: String
                let iconSource: ContextMenuActionItemIconSource?
                if let threadId = item.threadId {
                    guard let maybeThreadData = threadDataMap[TelegramEngine.EngineData.Item.Peer.ThreadData.Key(id: item.peerId, threadId: threadId)], let threadData = maybeThreadData else {
                        continue
                    }
                    title = threadData.info.title
                    iconSource = nil
                } else {
                    if itemPeer.id == context.account.peerId {
                        title = presentationData.strings.DialogList_SavedMessages
                        iconSource = nil
                    } else {
                        title = itemPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        iconSource = ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: context.account, peer: itemPeer, size: avatarSize))
                    }
                }
                
                let isSavedMessages = itemPeer.id == context.account.peerId
                
                items.append(.action(ContextMenuActionItem(text: title, icon: { _ in
                    if isSavedMessages {
                        return generateAvatarImage(size: avatarSize, icon: savedMessagesIcon, iconScale: 0.5, color: .blue)
                    }
                    return nil
                }, iconSource: iconSource, action: { _, f in
                    f(.default)
                    
                    guard let navigationController = navigationController else {
                        return
                    }
                    
                    var updatedChatNavigationStack = chatNavigationStack
                    if let index = updatedChatNavigationStack.firstIndex(of: item) {
                        updatedChatNavigationStack.removeSubrange(0 ..< (index + 1))
                    }
                    
                    let navigateChatLocation: NavigateToChatControllerParams.Location
                    if let threadId = item.threadId {
                        navigateChatLocation = .replyThread(ChatReplyThreadMessage(
                            peerId: item.peerId, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, isMonoforumPost: false,maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false
                        ))
                    } else {
                        navigateChatLocation = .peer(itemPeer)
                    }

                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: navigateChatLocation, useBackAnimation: true, animated: true, chatListFilter: nextFolderId, chatNavigationStack: updatedChatNavigationStack, completion: { _ in
                    }))
                })))
            }
            let contextController = ContextController(presentationData: presentationData, source: .reference(PeerInfoControllerContextReferenceContentSource(controller: parentController, sourceView: backButtonView, insets: UIEdgeInsets(), contentInsets: UIEdgeInsets(top: 0.0, left: -15.0, bottom: 0.0, right: -15.0))), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            parentController.presentInGlobalOverlay(contextController)
        })
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async { [weak self] in
            self?.didAppear = true
        }
        
        var chatNavigationStack: [ChatNavigationStackItem] = []
        if !self.isSettings, let summary = self.customNavigationDataSummary as? ChatControllerNavigationDataSummary {
            chatNavigationStack.removeAll()
            chatNavigationStack = summary.peerNavigationItems.filter({ $0 != ChatNavigationStackItem(peerId: self.peerId, threadId: self.chatLocation.threadId) })
        }
        
        if !chatNavigationStack.isEmpty {
            self.navigationBar?.backButtonNode.isGestureEnabled = true
            self.navigationBar?.backButtonNode.activated = { [weak self] gesture, _ in
                guard let strongSelf = self, let backButtonNode = strongSelf.navigationBar?.backButtonNode, let navigationController = strongSelf.navigationController as? NavigationController else {
                    gesture.cancel()
                    return
                }
                
                PeerInfoScreenImpl.displayChatNavigationMenu(
                    context: strongSelf.context,
                    chatNavigationStack: chatNavigationStack,
                    nextFolderId: nil,
                    parentController: strongSelf,
                    backButtonView: backButtonNode.view,
                    navigationController: navigationController,
                    gesture: gesture
                )
            }
        }
        
        self.controllerNode.refreshHasPersonalChannelsIfNeeded()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = self.isSettings ? (self.navigationBar?.frame.height ?? 0.0) : self.navigationLayout(layout: layout).navigationFrame.maxY
        self.validLayout = (layout, navigationHeight)
        
        self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
    }
    
    override public func tabBarItemContextAction(sourceNode: ContextExtractedContentContainingNode, gesture: ContextGesture) {
        guard let (maybePrimary, other) = self.accountsAndPeersValue, let primary = maybePrimary else {
            return
        }
        
        let strings = self.presentationData.strings
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: strings.Settings_AddAccount, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, f in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.openSettings(section: .addAccount)
            f(.dismissWithoutContent)
        })))
        
        
        //let avatarSize = CGSize(width: 28.0, height: 28.0)
        
        items.append(.custom(AccountPeerContextItem(context: self.context, account: self.context.account, peer: primary.1, action: { _, f in
            f(.default)
        }), true))
        
        /*items.append(.action(ContextMenuActionItem(text: primary.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: primary.0.account, peer: primary.1, size: avatarSize)), action: { _, f in
            f(.default)
        })))*/
        
        if !other.isEmpty {
            items.append(.separator)
        }
        
        for account in other {
            let id = account.0.account.id
            items.append(.custom(AccountPeerContextItem(context: self.context, account: account.0.account, peer: account.1, action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerNode.switchToAccount(id: id)
                f(.dismissWithoutContent)
            }), true))
            /*items.append(.action(ContextMenuActionItem(text: account.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), badge: account.2 != 0 ? ContextMenuActionBadge(value: "\(account.2)", color: .accent) : nil, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: account.0.account, peer: account.1, size: avatarSize)), action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerNode.switchToAccount(id: id)
                f(.dismissWithoutContent)
            })))*/
        }
        
        let controller = ContextController(presentationData: self.presentationData, source: .extracted(SettingsTabBarContextExtractedContentSource(controller: self, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
    }
    
    public var keyShortcuts: [KeyShortcut] {
        if self.isSettings {
            return [
                KeyShortcut(
                    input: "0",
                    modifiers: [.command],
                    action: { [weak self] in
                        self?.controllerNode.openSettings(section: .savedMessages)
                    }
                )
            ]
        } else {
            return [
                KeyShortcut(
                    input: "W",
                    modifiers: [.command],
                    action: { [weak self] in
                        self?.dismiss(animated: true, completion: nil)
                    }
                ),
                KeyShortcut(
                    input: UIKeyCommand.inputEscape,
                    modifiers: [],
                    action: { [weak self] in
                        self?.dismiss(animated: true, completion: nil)
                    }
                )
            ]
        }
    }
    
    public func openBirthdaySetup() {
        self.controllerNode.interaction.updateIsEditingBirthdate(true)
        self.controllerNode.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
    }
    
    public static func openSavedMessagesMoreMenu(context: AccountContext, sourceController: ViewController, isViewingAsTopics: Bool, sourceView: UIView, gesture: ContextGesture?) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer else {
                return
            }
            
            let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
            
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: strings.Chat_SavedMessagesModeMenu_ViewAsChats, icon: { theme in
                if !isViewingAsTopics {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .clear)
                }
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { [weak sourceController] _, a in
                a(.default)
                
                guard let sourceController = sourceController, let navigationController = sourceController.navigationController as? NavigationController else {
                    return
                }
                
                context.engine.peers.updateSavedMessagesViewAsTopics(value: true)
                
                if let infoController = navigationController.viewControllers.first(where: { c in
                    if let c = c as? PeerInfoScreenImpl, case .peer(context.account.peerId) = c.chatLocation {
                        return true
                    }
                    return false
                }) {
                    let _ = navigationController.popToViewController(infoController, animated: false)
                } else {
                    if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        navigationController.replaceController(sourceController, with: infoController, animated: false)
                    }
                }
            })))
            items.append(.action(ContextMenuActionItem(text: strings.Chat_SavedMessagesModeMenu_ViewAsMessages, icon: { theme in
                if isViewingAsTopics {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .clear)
                }
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
            }, iconPosition: .left, action: { [weak sourceController] _, a in
                a(.default)
                
                guard let sourceController = sourceController, let navigationController = sourceController.navigationController as? NavigationController else {
                    return
                }
                
                if let chatController = navigationController.viewControllers.first(where: { c in
                    if let c = c as? ChatController, case .peer(context.account.peerId) = c.chatLocation {
                        return true
                    }
                    return false
                }) {
                    let _ = navigationController.popToViewController(chatController, animated: false)
                } else {
                    let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: context.account.peerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                    
                    navigationController.replaceController(sourceController, with: chatController, animated: false)
                }
                
                context.engine.peers.updateSavedMessagesViewAsTopics(value: false)
            })))
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: sourceController, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            sourceController.presentInGlobalOverlay(contextController)
        })
    }
    
    public static func preloadBirthdayAnimations(context: AccountContext, birthday: TelegramBirthday) {
        PeerInfoBirthdayOverlay.preloadBirthdayAnimations(context: context, birthday: birthday)
    }
    
    public func toggleStorySelection(ids: [Int32], isSelected: Bool) {
        self.controllerNode.toggleStorySelection(ids: ids, isSelected: isSelected)
    }
    
    public func togglePaneIsReordering(isReordering: Bool) {
        self.controllerNode.togglePaneIsReordering(isReordering: isReordering)
    }
    
    public func cancelItemSelection() {
        self.controllerNode.cancelItemSelection()
    }
}

private final class SettingsTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private func getUserPeer(engine: TelegramEngine, peerId: EnginePeer.Id) -> Signal<EnginePeer?, NoError> {
    return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
        guard let peer = peer else {
            return .single(nil)
        }
        if case let .secretChat(secretChat) = peer {
            return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: secretChat.regularPeerId))
        } else {
            return .single(peer)
        }
    }
}

private final class PeerInfoNavigationTransitionNode: ASDisplayNode, CustomNavigationTransitionNode {
    private let screenNode: PeerInfoScreenNode
    private let presentationData: PresentationData

    private var topNavigationBar: NavigationBar?
    private var bottomNavigationBar: NavigationBar?
    private var reverseFraction: Bool = false
    
    private let headerNode: PeerInfoHeaderNode
    
    private var previousBackButtonArrow: UIView?
    private var previousBackButton: UIView?
    private var currentBackButtonArrow: ASDisplayNode?
    private var previousBackButtonBadge: ASDisplayNode?
    private var currentBackButton: ASDisplayNode?
    
    private var previousRightButton: CALayer?
    
    private var previousContentNode: ASDisplayNode?
    private var previousContentNodeFrame: CGRect?
    private var previousContentNodeAlpha: CGFloat = 1.0
    
    private var previousSecondaryContentNode: ASDisplayNode?
    private var previousSecondaryContentNodeFrame: CGRect?
    private var previousSecondaryContentNodeAlpha: CGFloat = 1.0
    
    private var previousTitleNode: (ASDisplayNode, PortalView)?
    private var previousStatusNode: (ASDisplayNode, ASDisplayNode)?
    
    private var previousAvatarView: UIView?
    
    private var didSetup: Bool = false
    
    init(screenNode: PeerInfoScreenNode, presentationData: PresentationData, headerNode: PeerInfoHeaderNode) {
        self.screenNode = screenNode
        self.presentationData = presentationData
        self.headerNode = headerNode
        
        super.init()
        
        self.addSubnode(headerNode)
    }
    
    func setup(topNavigationBar: NavigationBar, bottomNavigationBar: NavigationBar) {
        if let _ = bottomNavigationBar.userInfo as? PeerInfoNavigationSourceTag {
            self.topNavigationBar = topNavigationBar
            self.bottomNavigationBar = bottomNavigationBar
        } else {
            self.topNavigationBar = bottomNavigationBar
            self.bottomNavigationBar = topNavigationBar
            self.reverseFraction = true
        }
        
        topNavigationBar.isHidden = true
        bottomNavigationBar.isHidden = true
        
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar {
            self.addSubnode(bottomNavigationBar.additionalContentNode)

            if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
                if let previousBackButtonArrow = headerView.makeTransitionBackArrowView(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                    self.previousBackButtonArrow = previousBackButtonArrow
                    self.view.addSubview(previousBackButtonArrow)
                }
                if let previousBackButton = headerView.makeTransitionBackButtonView(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                    self.previousBackButton = previousBackButton
                    self.view.addSubview(previousBackButton)
                }
            } else {
                if let previousBackButtonArrow = bottomNavigationBar.makeTransitionBackArrowView(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                    self.previousBackButtonArrow = previousBackButtonArrow
                    self.view.addSubview(previousBackButtonArrow)
                }
                if let previousBackButton = bottomNavigationBar.makeTransitionBackButtonView(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                    self.previousBackButton = previousBackButton
                    self.view.addSubview(previousBackButton)
                }
            }
                
            if let currentBackButtonArrow = topNavigationBar.makeTransitionBackArrowNode(accentColor: .white) {
                self.currentBackButtonArrow = currentBackButtonArrow
                //self.addSubnode(currentBackButtonArrow)
            }
            
            if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
                let _ = headerView
            } else {
                if let previousBackButtonBadge = bottomNavigationBar.makeTransitionBadgeNode() {
                    self.previousBackButtonBadge = previousBackButtonBadge
                    self.addSubnode(previousBackButtonBadge)
                }
            }
            
            if let currentBackButton = topNavigationBar.makeTransitionBackButtonNode(accentColor: .white) {
                self.currentBackButton = currentBackButton
                //self.addSubnode(currentBackButton)
            }
            
            if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
                if let previousRightButton = headerView.rightButtonView?.layer.snapshotContentTree() {
                    self.previousRightButton = previousRightButton
                    self.view.layer.addSublayer(previousRightButton)
                }
            } else {
                if let avatarNavigationNode = bottomNavigationBar.rightButtonNode.singleCustomNode as? ChatAvatarNavigationNode, let previousAvatarView = avatarNavigationNode.view.snapshotContentTree() {
                    self.previousAvatarView = previousAvatarView
                    self.view.addSubview(previousAvatarView)
                } else if let previousRightButton = bottomNavigationBar.rightButtonNode.view.layer.snapshotContentTree() {
                    self.previousRightButton = previousRightButton
                    self.view.layer.addSublayer(previousRightButton)
                }
            }
            
            if let contentNode = bottomNavigationBar.contentNode {
                self.previousContentNode = contentNode
                self.previousContentNodeFrame = contentNode.view.convert(contentNode.view.bounds, to: bottomNavigationBar.view)
                self.previousContentNodeAlpha = contentNode.alpha
                self.addSubnode(contentNode)
            }
            
            if let secondaryContentNode = bottomNavigationBar.secondaryContentNode {
                self.previousSecondaryContentNode = secondaryContentNode
                self.previousSecondaryContentNodeFrame = secondaryContentNode.view.convert(secondaryContentNode.view.bounds, to: bottomNavigationBar.view)
                self.previousSecondaryContentNodeAlpha = secondaryContentNode.alpha
                self.addSubnode(secondaryContentNode)
            }
            
            var previousTitleView: UIView?
            if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
                if let componentView = headerView.titleContentView as? ChatTitleComponent.View {
                    previousTitleView = componentView.contentView
                }
            } else {
                previousTitleView = bottomNavigationBar.titleView
            }
            
            if let previousTitleView = previousTitleView as? ChatTitleView, let previousTitleNode = PortalView(matchPosition: false) {
                previousTitleNode.view.frame = previousTitleView.titleContainerView.frame
                previousTitleView.titleContainerView.addPortal(view: previousTitleNode)
                let previousTitleContainerNode = ASDisplayNode()
                previousTitleContainerNode.view.addSubview(previousTitleNode.view)
                previousTitleNode.view.frame = previousTitleNode.view.frame.offsetBy(dx: -previousTitleNode.view.frame.width / 2.0, dy: -previousTitleNode.view.frame.height / 2.0)
                self.previousTitleNode = (previousTitleContainerNode, previousTitleNode)
                self.addSubnode(previousTitleContainerNode)
                
                let previousStatusNode = previousTitleView.activityNode.makeCopy()
                let previousStatusContainerNode = ASDisplayNode()
                previousStatusContainerNode.addSubnode(previousStatusNode)
                previousStatusNode.frame = previousStatusNode.frame.offsetBy(dx: -previousStatusNode.frame.width / 2.0, dy: -previousStatusNode.frame.height / 2.0)
                self.previousStatusNode = (previousStatusContainerNode, previousStatusNode)
                self.addSubnode(previousStatusContainerNode)
            }
        }
    }
    
    func update(containerSize: CGSize, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }
        
        let fraction = self.reverseFraction ? (1.0 - fraction) : fraction
        
        if let previousBackButtonArrow = self.previousBackButtonArrow {
            if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
                if let backArrowView = headerView.backArrowView {
                    let previousBackButtonArrowFrame = backArrowView.convert(backArrowView.bounds, to: bottomNavigationBar.view)
                    previousBackButtonArrow.frame = previousBackButtonArrowFrame
                    transition.updateAlpha(layer: previousBackButtonArrow.layer, alpha: fraction)
                }
            } else {
                let previousBackButtonArrowFrame = bottomNavigationBar.backButtonArrow.view.convert(bottomNavigationBar.backButtonArrow.view.bounds, to: bottomNavigationBar.view)
                previousBackButtonArrow.frame = previousBackButtonArrowFrame
                transition.updateAlpha(layer: previousBackButtonArrow.layer, alpha: fraction)
            }
        }
        
        if let previousBackButton = self.previousBackButton {
            if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
                if let backButtonTitleView = headerView.backButtonTitleView {
                    let previousBackButtonFrame = backButtonTitleView.convert(backButtonTitleView.bounds, to: bottomNavigationBar.view)
                    previousBackButton.frame = previousBackButtonFrame
                    transition.updateAlpha(layer: previousBackButton.layer, alpha: fraction)
                }
            } else {
                let previousBackButtonFrame = bottomNavigationBar.backButtonNode.view.convert(bottomNavigationBar.backButtonNode.view.bounds, to: bottomNavigationBar.view)
                previousBackButton.frame = previousBackButtonFrame
                transition.updateAlpha(layer: previousBackButton.layer, alpha: fraction)
            }
        }
        
        if let previousRightButton = self.previousRightButton {
            if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
                if let rightButtonView = headerView.rightButtonView {
                    let previousRightButtonFrame = rightButtonView.convert(rightButtonView.bounds, to: bottomNavigationBar.view)
                    previousRightButton.frame = previousRightButtonFrame
                    transition.updateAlpha(layer: previousRightButton, alpha: fraction)
                }
            } else {
                let previousRightButtonFrame = bottomNavigationBar.rightButtonNode.view.convert(bottomNavigationBar.rightButtonNode.view.bounds, to: bottomNavigationBar.view)
                previousRightButton.frame = previousRightButtonFrame
                transition.updateAlpha(layer: previousRightButton, alpha: fraction)
            }
        }
        
        if let currentBackButtonArrow = self.currentBackButtonArrow {
            let currentBackButtonArrowFrame = topNavigationBar.backButtonArrow.view.convert(topNavigationBar.backButtonArrow.view.bounds, to: topNavigationBar.view)
            currentBackButtonArrow.frame = currentBackButtonArrowFrame
            
            transition.updateAlpha(node: currentBackButtonArrow, alpha: 1.0 - fraction)
            if let previousBackButtonArrow = self.previousBackButtonArrow {
                transition.updateAlpha(layer: previousBackButtonArrow.layer, alpha: fraction)
            }
        }
        
        if let previousBackButtonBadge = self.previousBackButtonBadge {
            let previousBackButtonBadgeFrame = bottomNavigationBar.badgeNode.view.convert(bottomNavigationBar.badgeNode.view.bounds, to: bottomNavigationBar.view)
            previousBackButtonBadge.frame = previousBackButtonBadgeFrame
            
            transition.updateAlpha(node: previousBackButtonBadge, alpha: fraction)
        }
        
        if let currentBackButton = self.currentBackButton {
            transition.updateAlpha(node: currentBackButton, alpha: (1.0 - fraction))
        }
        
        var previousTitleView: UIView?
        if let headerView = bottomNavigationBar.customHeaderContentView as? ChatListHeaderComponent.View {
            if let componentView = headerView.titleContentView as? ChatTitleComponent.View {
                previousTitleView = componentView.contentView
            }
        } else {
            previousTitleView = bottomNavigationBar.titleView
        }
        
        if let previousTitleView = previousTitleView as? ChatTitleView, let (previousTitleContainerNode, previousTitleNode) = self.previousTitleNode, let (previousStatusContainerNode, previousStatusNode) = self.previousStatusNode {
            let previousTitleFrame = previousTitleView.titleContainerView.convert(previousTitleView.titleContainerView.bounds, to: bottomNavigationBar.view)
            let previousStatusFrame = previousTitleView.activityNode.view.convert(previousTitleView.activityNode.bounds, to: bottomNavigationBar.view)
            
            self.headerNode.navigationTransition = PeerInfoHeaderNavigationTransition(sourceNavigationBar: bottomNavigationBar, sourceTitleView: previousTitleView, sourceTitleFrame: previousTitleFrame, sourceSubtitleFrame: previousStatusFrame, previousAvatarView: self.previousAvatarView, fraction: fraction)
            var topHeight = topNavigationBar.backgroundNode.bounds.height
            
            if let iconView = previousTitleView.titleCredibilityIconView.componentView {
                transition.updateFrame(view: iconView, frame: iconView.bounds.offsetBy(dx: (1.0 - fraction) * 8.0, dy: 0.0))
            }
            
            if let (layout, _) = self.screenNode.validLayout {
                let sectionInset: CGFloat
                if layout.size.width >= 375.0 {
                    sectionInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
                } else {
                    sectionInset = 0.0
                }
                let headerInset = sectionInset
                
                topHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: topNavigationBar.bounds.height, isModalOverlay: layout.isModalOverlay, isMediaOnly: false, contentOffset: 0.0, paneContainerY: 0.0, presentationData: self.presentationData, peer: self.screenNode.data?.savedMessagesPeer ?? self.screenNode.data?.peer, cachedData: self.screenNode.data?.cachedData, threadData: self.screenNode.data?.threadData, peerNotificationSettings: self.screenNode.data?.peerNotificationSettings, threadNotificationSettings: self.screenNode.data?.threadNotificationSettings, globalNotificationSettings: self.screenNode.data?.globalNotificationSettings, statusData: self.screenNode.data?.status, panelStatusData: (nil, nil, nil), isSecretChat: self.screenNode.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.screenNode.data?.isContact ?? false, isSettings: self.screenNode.isSettings, state: self.screenNode.state, profileGiftsContext: self.screenNode.data?.profileGiftsContext, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, transition: transition, additive: false, animateHeader: false)
            }
            
            let titleScale = (fraction * previousTitleNode.view.bounds.height + (1.0 - fraction) * self.headerNode.titleNodeRawContainer.bounds.height) / previousTitleNode.view.bounds.height
            let subtitleScale = max(0.01, min(10.0, (fraction * previousStatusNode.bounds.height + (1.0 - fraction) * self.headerNode.subtitleNodeRawContainer.bounds.height) / previousStatusNode.bounds.height))
            
            transition.updateFrame(node: previousTitleContainerNode, frame: CGRect(origin: self.headerNode.titleNodeRawContainer.frame.center, size: CGSize()))
            transition.updateFrame(view: previousTitleNode.view, frame: CGRect(origin: CGPoint(x: -previousTitleFrame.width / 2.0, y: -previousTitleFrame.height / 2.0), size: previousTitleFrame.size))
            transition.updateFrame(node: previousStatusContainerNode, frame: CGRect(origin: self.headerNode.subtitleNodeRawContainer.frame.center, size: CGSize()))
            transition.updateFrame(node: previousStatusNode, frame: CGRect(origin: CGPoint(x: -previousStatusFrame.size.width / 2.0, y: -previousStatusFrame.size.height / 2.0), size: previousStatusFrame.size))
            
            transition.updateSublayerTransformScale(node: previousTitleContainerNode, scale: titleScale)
            transition.updateSublayerTransformScale(node: previousStatusContainerNode, scale: subtitleScale)
            
            transition.updateAlpha(node: self.headerNode.titleNode, alpha: (1.0 - fraction))
            transition.updateAlpha(layer: previousTitleNode.view.layer, alpha: fraction)
            transition.updateAlpha(node: self.headerNode.subtitleNode, alpha: (1.0 - fraction))
            transition.updateAlpha(node: previousStatusNode, alpha: fraction)
            
            transition.updateAlpha(node: self.headerNode.navigationButtonContainer, alpha: (1.0 - fraction))

            if case .animated = transition, (bottomNavigationBar.additionalContentNode.alpha.isZero || bottomNavigationBar.additionalContentNode.alpha == 1.0) {
                bottomNavigationBar.additionalContentNode.alpha = fraction
                if fraction.isZero {
                    bottomNavigationBar.additionalContentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                } else {
                    transition.updateAlpha(node: bottomNavigationBar.additionalContentNode, alpha: fraction)
                }
            } else {
                transition.updateAlpha(node: bottomNavigationBar.additionalContentNode, alpha: fraction)
            }

            let bottomHeight = bottomNavigationBar.backgroundNode.bounds.height

            transition.updateSublayerTransformOffset(layer: bottomNavigationBar.additionalContentNode.layer, offset: CGPoint(x: 0.0, y: (1.0 - fraction) * (topHeight - bottomHeight)))
            
            if let previousContentNode = self.previousContentNode, let previousContentNodeFrame = self.previousContentNodeFrame {
                var updatedPreviousContentNodeFrame = bottomNavigationBar.view.convert(previousContentNodeFrame, to: bottomNavigationBar.view)
                updatedPreviousContentNodeFrame.origin.y += (1.0 - fraction) * (topHeight - bottomHeight)
                transition.updateFrame(node: previousContentNode, frame: updatedPreviousContentNodeFrame)
                transition.updateAlpha(node: previousContentNode, alpha: fraction)
            }
            
            if let previousSecondaryContentNode = self.previousSecondaryContentNode, let previousSecondaryContentNodeFrame = self.previousSecondaryContentNodeFrame {
                var updatedPreviousSecondaryContentNodeFrame = bottomNavigationBar.view.convert(previousSecondaryContentNodeFrame, to: bottomNavigationBar.view)
                updatedPreviousSecondaryContentNodeFrame.origin.y += (1.0 - fraction) * (topHeight - bottomHeight)
                transition.updateFrame(node: previousSecondaryContentNode, frame: updatedPreviousSecondaryContentNodeFrame)
                transition.updateAlpha(node: previousSecondaryContentNode, alpha: fraction)
            }
        }
    }
    
    func restore() {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }

        topNavigationBar.additionalContentNode.alpha = 1.0
        ContainedViewLayoutTransition.immediate.updateSublayerTransformOffset(layer: topNavigationBar.additionalContentNode.layer, offset: CGPoint())
        topNavigationBar.reattachAdditionalContentNode()

        bottomNavigationBar.additionalContentNode.alpha = 1.0
        ContainedViewLayoutTransition.immediate.updateSublayerTransformOffset(layer: bottomNavigationBar.additionalContentNode.layer, offset: CGPoint())
        bottomNavigationBar.reattachAdditionalContentNode()
        
        topNavigationBar.isHidden = false
        bottomNavigationBar.isHidden = false
        self.headerNode.navigationTransition = nil
        self.screenNode.insertSubnode(self.headerNode, aboveSubnode: self.screenNode.scrollNode)
        
        if let previousContentNode = self.previousContentNode, let previousContentNodeFrame = self.previousContentNodeFrame {
            previousContentNode.frame = previousContentNodeFrame
            previousContentNode.alpha = self.previousContentNodeAlpha
            bottomNavigationBar.insertSubnode(previousContentNode, belowSubnode: bottomNavigationBar.stripeNode)
        }
        
        if let previousSecondaryContentNode = self.previousSecondaryContentNode, let previousSecondaryContentNodeFrame = self.previousSecondaryContentNodeFrame {
            previousSecondaryContentNode.frame = previousSecondaryContentNodeFrame
            previousSecondaryContentNode.alpha = self.previousSecondaryContentNodeAlpha
            bottomNavigationBar.clippingNode.addSubnode(previousSecondaryContentNode)
        }
        
        if let previousTitleView = bottomNavigationBar.titleView as? ChatTitleView, let iconView = previousTitleView.titleCredibilityIconView.componentView {
            iconView.frame = iconView.bounds
        }
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    let sourceRect: CGRect
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, sourceRect: CGRect = CGRect(origin: CGPoint(), size: CGSize()), passthroughTouches: Bool = false) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.sourceRect = sourceRect
        self.passthroughTouches = passthroughTouches
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                let rect = sourceRect.isEmpty ? sourceNode.bounds : sourceRect
                return (sourceNode.view, rect)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        self.controller.didAppearInContextPreview()
    }
}

private final class MessageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(sourceNode: ContextExtractedContentContainingNode) {
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class PeerInfoContextExtractedContentSource: ContextExtractedContentSource {
    var keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .right
      
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(sourceNode: ContextExtractedContentContainingNode) {
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class PeerInfoContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

public func presentAddMembersImpl(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, parentController: ViewController, groupPeer: Peer, selectAddMemberDisposable: MetaDisposable, addMemberDisposable: MetaDisposable) {
    let members: Promise<[PeerId]> = Promise()
    if groupPeer.id.namespace == Namespaces.Peer.CloudChannel {
        /*var membersDisposable: Disposable?
        let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { listState in
            members.set(.single(listState.list.map {$0.peer.id}))
            membersDisposable?.dispose()
        })
        membersDisposable = disposable*/
        members.set(.single([]))
    } else {
        members.set(.single([]))
    }
    
    let _ = (members.get()
    |> take(1)
    |> deliverOnMainQueue).startStandalone(next: { [weak parentController] recentIds in
        var createInviteLinkImpl: (() -> Void)?
        var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
        let _ = confirmationImpl
        var options: [ContactListAdditionalOption] = []
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        var canCreateInviteLink = false
        if let group = groupPeer as? TelegramGroup {
            switch group.role {
            case .creator:
                canCreateInviteLink = true
            case let .admin(rights, _):
                canCreateInviteLink = rights.rights.contains(.canInviteUsers)
            default:
                break
            }
        } else if let channel = groupPeer as? TelegramChannel, (channel.addressName?.isEmpty ?? true) {
            if channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                canCreateInviteLink = true
            }
        }
        
        if canCreateInviteLink {
            options.append(ContactListAdditionalOption(title: presentationData.strings.GroupInfo_InviteByLink, icon: .generic(UIImage(bundleImageName: "Contact List/LinkActionIcon")!), action: {
                createInviteLinkImpl?()
            }, clearHighlightAutomatically: true))
        }
        
        let contactsController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, updatedPresentationData: updatedPresentationData, mode: .peerSelection(searchChatList: false, searchGroups: false, searchChannels: false), options: .single(options), filters: [.excludeSelf, .disable(recentIds)], onlyWriteable: true, isGroupInvitation: true))
            contactsController.navigationPresentation = .modal
        
        confirmationImpl = { [weak contactsController] peerId in
            return context.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue
            |> mapToSignal { peer in
                let result = ValuePromise<Bool>()
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                if let contactsController = contactsController {
                    let alertController = textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.GroupInfo_AddParticipantConfirmation(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string, actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {
                            result.set(false)
                        }),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                            result.set(true)
                        })
                    ])
                    contactsController.present(alertController, in: .window(.root))
                }
                
                return result.get()
            }
        }
        
        let addMembers: ([ContactListPeerId]) -> Signal<[(PeerId, AddChannelMemberError)], NoError> = { members -> Signal<[(PeerId, AddChannelMemberError)], NoError> in
            let memberIds = members.compactMap { contact -> PeerId? in
                switch contact {
                case let .peer(peerId):
                    return peerId
                default:
                    return nil
                }
            }
            return context.account.postbox.multiplePeersView(memberIds)
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { view -> Signal<[(PeerId, AddChannelMemberError)], NoError> in
                if groupPeer.id.namespace == Namespaces.Peer.CloudChannel {
                    if memberIds.count == 1 {
                        return context.peerChannelMemberCategoriesContextsManager.addMember(engine: context.engine, peerId: groupPeer.id, memberId: memberIds[0])
                        |> map { _ -> [(PeerId, AddChannelMemberError)] in
                        }
                        |> then(Signal<[(PeerId, AddChannelMemberError)], AddChannelMemberError>.single([]))
                        |> `catch` { error -> Signal<[(PeerId, AddChannelMemberError)], NoError> in
                            return .single([(memberIds[0], error)])
                        }
                    } else {
                        return context.peerChannelMemberCategoriesContextsManager.addMembersAllowPartial(engine: context.engine, peerId: groupPeer.id, memberIds: memberIds)
                    }
                } else {
                    var signals: [Signal<(PeerId, AddChannelMemberError)?, NoError>] = []
                    for memberId in memberIds {
                        let signal: Signal<(PeerId, AddChannelMemberError)?, NoError> = context.engine.peers.addGroupMember(peerId: groupPeer.id, memberId: memberId)
                        |> mapError { error -> AddChannelMemberError in
                            switch error {
                            case .generic:
                                return .generic
                            case .groupFull:
                                return .limitExceeded
                            case let .privacy(privacy):
                                return .restricted(privacy?.forbiddenPeers.first)
                            case .notMutualContact:
                                return .notMutualContact
                            case .tooManyChannels:
                                return .generic
                            }
                        }
                        |> ignoreValues
                        |> map { _ -> (PeerId, AddChannelMemberError)? in
                        }
                        |> then(Signal<(PeerId, AddChannelMemberError)?, AddChannelMemberError>.single(nil))
                        |> `catch` { error -> Signal<(PeerId, AddChannelMemberError)?, NoError> in
                            return .single((memberId, error))
                        }
                        signals.append(signal)
                    }
                    return combineLatest(signals)
                    |> map { values -> [(PeerId, AddChannelMemberError)] in
                        return values.compactMap { $0 }
                    }
                }
            }
        }
        
        createInviteLinkImpl = { [weak contactsController] in
            contactsController?.view.window?.endEditing(true)
            contactsController?.present(InviteLinkInviteController(context: context, updatedPresentationData: updatedPresentationData, mode: .groupOrChannel(peerId: groupPeer.id), initialInvite: nil, parentNavigationController: contactsController?.navigationController as? NavigationController), in: .window(.root))
        }

        parentController?.push(contactsController)
        do {
            selectAddMemberDisposable.set((
                combineLatest(queue: .mainQueue(),
                    context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: groupPeer.id)),
                    contactsController.result
                )
            |> deliverOnMainQueue).start(next: { [weak contactsController] exportedInvitation, result in
                var peers: [ContactListPeerId] = []
                if case let .result(peerIdsValue, _) = result {
                    peers = peerIdsValue
                }
                
                contactsController?.displayProgress = true
                addMemberDisposable.set((addMembers(peers)
                |> deliverOnMainQueue).start(next: { failedPeerIds in
                    if failedPeerIds.isEmpty {
                        contactsController?.dismiss()
                        
                        let mappedPeerIds: [EnginePeer.Id] = peers.compactMap { peer -> EnginePeer.Id? in
                            switch peer {
                            case let .peer(id):
                                return id
                            default:
                                return nil
                            }
                        }
                        if !mappedPeerIds.isEmpty {
                            let _ = (context.engine.data.get(EngineDataMap(mappedPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
                            |> deliverOnMainQueue).startStandalone(next: { maybePeers in
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                let peers = maybePeers.compactMap { $0.value }
                                
                                let text: String
                                if peers.count == 1 {
                                    text = presentationData.strings.PeerInfo_NotificationMemberAdded(peers[0].displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                } else {
                                    text = presentationData.strings.PeerInfo_NotificationMultipleMembersAdded(Int32(peers.count))
                                }
                                parentController?.present(UndoOverlayController(presentationData: presentationData, content: .peers(context: context, peers: peers, title: nil, text: text, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                            })
                        }
                    } else {
                        let failedPeers = failedPeerIds.compactMap { _, error -> TelegramForbiddenInvitePeer? in
                            if case let .restricted(peer) = error {
                                return peer
                            } else {
                                return nil
                            }
                        }
                        
                        if !failedPeers.isEmpty, let contactsController, let navigationController = contactsController.navigationController as? NavigationController {
                            var viewControllers = navigationController.viewControllers
                            if let index = viewControllers.firstIndex(where: { $0 === contactsController }) {
                                let inviteScreen = SendInviteLinkScreen(context: context, subject: .chat(peer: EnginePeer(groupPeer), link: exportedInvitation?.link), peers: failedPeers)
                                viewControllers.remove(at: index)
                                viewControllers.append(inviteScreen)
                                navigationController.setViewControllers(viewControllers, animated: true)
                            }
                        } else {
                            contactsController?.dismiss()
                        }
                    }
                }))
            }))
            contactsController.dismissed = {
                selectAddMemberDisposable.set(nil)
                addMemberDisposable.set(nil)
            }
        }
    })
}

struct ClearPeerHistory {
    enum ClearType {
        case savedMessages
        case secretChat
        case group
        case channel
        case user
    }
    
    var canClearCache: Bool = false
    var canClearForMyself: ClearType? = nil
    var canClearForEveryone: ClearType? = nil
    
    init(context: AccountContext, peer: Peer, chatPeer: Peer, cachedData: CachedPeerData?) {
        if peer.id == context.account.peerId {
            canClearCache = false
            canClearForMyself = .savedMessages
            canClearForEveryone = nil
        } else if chatPeer is TelegramSecretChat {
            canClearCache = false
            canClearForMyself = .secretChat
            canClearForEveryone = nil
        } else if let group = chatPeer as? TelegramGroup {
            canClearCache = false
            
            switch group.role {
            case .creator:
                canClearForMyself = .group
                canClearForEveryone = .group
            case .admin, .member:
                canClearForMyself = .group
                canClearForEveryone = nil
            }
        } else if let channel = chatPeer as? TelegramChannel {
            var canDeleteHistory = false
            if let cachedData = cachedData as? CachedChannelData {
                canDeleteHistory = cachedData.flags.contains(.canDeleteHistory)
            }
            
            var canDeleteLocally = true
            if case .broadcast = channel.info {
                canDeleteLocally = false
            } else if channel.addressName != nil {
                canDeleteLocally = false
            }
            
            if !canDeleteHistory {
                canClearCache = true
                
                canClearForMyself = canDeleteLocally ? .channel : nil
                canClearForEveryone = nil
            } else {
                canClearCache = true
                canClearForMyself = canDeleteLocally ? .channel : nil
                
                canClearForEveryone = .channel
            }
        } else {
            canClearCache = false
            canClearForMyself = .user
            
            if let user = chatPeer as? TelegramUser, user.botInfo != nil {
                canClearForEveryone = nil
            } else {
                canClearForEveryone = .user
            }
        }
    }
}

private final class AccountPeerContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let account: Account
    let peer: EnginePeer
    let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void
    
    init(context: AccountContext, account: Account, peer: EnginePeer, action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.context = context
        self.account = account
        self.peer = peer
        self.action = action
    }
    
    public func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return AccountPeerContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class AccountPeerContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let item: AccountPeerContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let textNode: ImmediateTextNode
    private let avatarNode: AvatarNode
    private let emojiStatusView: ComponentView<Empty>
    
    init(presentationData: PresentationData, item: AccountPeerContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 17.0 / 17.0)
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        let peerTitle = item.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        self.textNode.attributedText = NSAttributedString(string: peerTitle, font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.textNode.maximumNumberOfLines = 1
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
        
        self.emojiStatusView = ComponentView<Empty>()
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = peerTitle
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.highlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
                strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize = CGSize(width: 28.0, height: 28.0)
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset - 12.0
        }
        
        self.avatarNode.setPeer(context: self.item.context, account: self.item.account, theme: self.presentationData.theme, peer: self.item.peer)
        
        if self.item.peer.emojiStatus != nil {
            rightTextInset += 32.0
        }
    
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        
        return (CGSize(width: textSize.width + sideInset + rightTextInset, height: verticalInset * 2.0 + textSize.height), { size, transition in
            let verticalOrigin = floor((size.height - textSize.height) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            
            var iconContent: EmojiStatusComponent.Content?
            if case let .user(user) = self.item.peer {
                if let emojiStatus = user.emojiStatus {
                    iconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 28.0, height: 28.0), placeholderColor: self.presentationData.theme.list.mediaPlaceholderColor, themeColor: self.presentationData.theme.list.itemAccentColor, loopMode: .forever)
                } else if user.isPremium {
                    iconContent = .premium(color: self.presentationData.theme.list.itemAccentColor)
                }
            } else if case let .channel(channel) = self.item.peer {
                if let emojiStatus = channel.emojiStatus {
                    iconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 28.0, height: 28.0), placeholderColor: self.presentationData.theme.list.mediaPlaceholderColor, themeColor: self.presentationData.theme.list.itemAccentColor, loopMode: .forever)
                }
            }
            if let iconContent {
                let emojiStatusSize = self.emojiStatusView.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: self.item.context,
                        animationCache: self.item.context.animationCache,
                        animationRenderer: self.item.context.animationRenderer,
                        content: iconContent,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 24.0, height: 24.0)
                )
                if let view = self.emojiStatusView.view {
                    if view.superview == nil {
                        self.view.addSubview(view)
                    }
                    transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: textFrame.maxX + 2.0, y: textFrame.minY + floor((textFrame.height - emojiStatusSize.height) / 2.0)), size: emojiStatusSize))
                }
            }
            
            transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
            
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        if let attributedText = self.textNode.attributedText {
            let updatedAttributedText = NSMutableAttributedString(attributedString: attributedText)
            updatedAttributedText.addAttribute(.foregroundColor, value: presentationData.theme.contextMenu.primaryColor.cgColor, range: NSRange(location: 0, length: updatedAttributedText.length))
            self.textNode.attributedText = updatedAttributedText
        }
    }
    
    @objc private func buttonPressed() {
        self.performAction()
    }
    
    func canBeHighlighted() -> Bool {
        return true
    }
    
    func setIsHighlighted(_ value: Bool) {
        if value {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }
    
    func performAction() {
        guard let controller = self.getController() else {
            return
        }
        self.item.action(controller, { [weak self] result in
            self?.actionSelected(result)
        })
    }
}

private final class PeerInfoControllerContextReferenceContentSource: ContextReferenceContentSource {
    let controller: ViewController
    let sourceView: UIView
    let insets: UIEdgeInsets
    let contentInsets: UIEdgeInsets
    
    init(controller: ViewController, sourceView: UIView, insets: UIEdgeInsets, contentInsets: UIEdgeInsets = UIEdgeInsets()) {
        self.controller = controller
        self.sourceView = sourceView
        self.insets = insets
        self.contentInsets = contentInsets
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds.inset(by: self.insets), insets: self.contentInsets)
    }
}

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}
