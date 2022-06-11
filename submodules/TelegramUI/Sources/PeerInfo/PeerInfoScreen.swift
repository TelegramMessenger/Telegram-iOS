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
import AuthTransferUI
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

protocol PeerInfoScreenItem: AnyObject {
    var id: AnyHashable { get }
    func node() -> PeerInfoScreenItemNode
}

class PeerInfoScreenItemNode: ASDisplayNode, AccessibilityFocusableNode {
    var bringToFrontForHighlight: (() -> Void)?
    
    func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
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
    private var itemNodes: [AnyHashable: PeerInfoScreenItemNode] = [:]
    
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
    
    func update(width: CGFloat, safeInsets: UIEdgeInsets, hasCorners: Bool, presentationData: PresentationData, items: [PeerInfoScreenItem], transition: ContainedViewLayoutTransition) -> CGFloat {
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
            
            let itemHeight = itemNode.update(width: width, safeInsets: safeInsets, presentationData: presentationData, item: item, topItem: topItem, bottomItem: bottomItem, hasCorners: hasCorners, transition: itemTransition)
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
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: { _ in
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _, _ in
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
        }, reportPeerIrrelevantGeoLocation: {
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
        
        let interfaceState = ChatPresentationInterfaceState(chatWallpaper: .color(0), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, limitsConfiguration: .defaultValue, fontSize: .regular, bubbleCorners: PresentationChatBubbleCorners(mainRadius: 16.0, auxiliaryRadius: 8.0, mergeBubbleCorners: true), accountPeerId: self.context.account.peerId, mode: .standard(previewing: false), chatLocation: .peer(id: self.peerId), subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil)
        let panelHeight = self.selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: layout.intrinsicInsets.bottom, additionalSideInsets: UIEdgeInsets(), maxHeight: 0.0, isSecondary: false, transition: transition, interfaceState: interfaceState, metrics: layout.metrics)
        
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
}

private enum PeerInfoContextSubject {
    case bio
    case phone(String)
    case link
}

private enum PeerInfoSettingsSection {
    case avatar
    case edit
    case proxy
    case savedMessages
    case recentCalls
    case devices
    case chatFolders
    case notificationsAndSounds
    case privacyAndSecurity
    case dataAndStorage
    case appearance
    case language
    case stickers
    case premium
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
}

private final class PeerInfoInteraction {
    let openChat: () -> Void
    let openUsername: (String) -> Void
    let openPhone: (String) -> Void
    let editingOpenNotificationSettings: () -> Void
    let editingOpenSoundSettings: () -> Void
    let editingToggleShowMessageText: (Bool) -> Void
    let requestDeleteContact: () -> Void
    let openAddContact: () -> Void
    let updateBlocked: (Bool) -> Void
    let openReport: (Bool) -> Void
    let openShareBot: () -> Void
    let openAddBotToGroup: () -> Void
    let performBotCommand: (PeerInfoBotCommand) -> Void
    let editingOpenPublicLinkSetup: () -> Void
    let editingOpenInviteLinksSetup: () -> Void
    let editingOpenDiscussionGroupSetup: () -> Void
    let editingToggleMessageSignatures: (Bool) -> Void
    let openParticipantsSection: (PeerInfoParticipantsSection) -> Void
    let editingOpenPreHistorySetup: () -> Void
    let editingOpenAutoremoveMesages: () -> Void
    let openPermissions: () -> Void
    let editingOpenStickerPackSetup: () -> Void
    let openLocation: () -> Void
    let editingOpenSetupLocation: () -> Void
    let openPeerInfo: (Peer, Bool) -> Void
    let performMemberAction: (PeerInfoMember, PeerInfoMemberAction) -> Void
    let openPeerInfoContextMenu: (PeerInfoContextSubject, ASDisplayNode) -> Void
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
    
    init(
        openUsername: @escaping (String) -> Void,
        openPhone: @escaping (String) -> Void,
        editingOpenNotificationSettings: @escaping () -> Void,
        editingOpenSoundSettings: @escaping () -> Void,
        editingToggleShowMessageText: @escaping (Bool) -> Void,
        requestDeleteContact: @escaping () -> Void,
        openChat: @escaping () -> Void,
        openAddContact: @escaping () -> Void,
        updateBlocked: @escaping (Bool) -> Void,
        openReport: @escaping (Bool) -> Void,
        openShareBot: @escaping () -> Void,
        openAddBotToGroup: @escaping () -> Void,
        performBotCommand: @escaping (PeerInfoBotCommand) -> Void,
        editingOpenPublicLinkSetup: @escaping () -> Void,
        editingOpenInviteLinksSetup: @escaping () -> Void,
        editingOpenDiscussionGroupSetup: @escaping () -> Void,
        editingToggleMessageSignatures: @escaping (Bool) -> Void,
        openParticipantsSection: @escaping (PeerInfoParticipantsSection) -> Void,
        editingOpenPreHistorySetup: @escaping () -> Void,
        editingOpenAutoremoveMesages: @escaping () -> Void,
        openPermissions: @escaping () -> Void,
        editingOpenStickerPackSetup: @escaping () -> Void,
        openLocation: @escaping () -> Void,
        editingOpenSetupLocation: @escaping () -> Void,
        openPeerInfo: @escaping (Peer, Bool) -> Void,
        performMemberAction: @escaping (PeerInfoMember, PeerInfoMemberAction) -> Void,
        openPeerInfoContextMenu: @escaping (PeerInfoContextSubject, ASDisplayNode) -> Void,
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
        dismissInput: @escaping () -> Void
    ) {
        self.openUsername = openUsername
        self.openPhone = openPhone
        self.editingOpenNotificationSettings = editingOpenNotificationSettings
        self.editingOpenSoundSettings = editingOpenSoundSettings
        self.editingToggleShowMessageText = editingToggleShowMessageText
        self.requestDeleteContact = requestDeleteContact
        self.openChat = openChat
        self.openAddContact = openAddContact
        self.updateBlocked = updateBlocked
        self.openReport = openReport
        self.openShareBot = openShareBot
        self.openAddBotToGroup = openAddBotToGroup
        self.performBotCommand = performBotCommand
        self.editingOpenPublicLinkSetup = editingOpenPublicLinkSetup
        self.editingOpenInviteLinksSetup = editingOpenInviteLinksSetup
        self.editingOpenDiscussionGroupSetup = editingOpenDiscussionGroupSetup
        self.editingToggleMessageSignatures = editingToggleMessageSignatures
        self.openParticipantsSection = openParticipantsSection
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
    }
}

private let enabledPublicBioEntities: EnabledEntityTypes = [.allUrl, .mention, .hashtag]
private let enabledPrivateBioEntities: EnabledEntityTypes = [.internalUrl, .mention, .hashtag]

private enum SettingsSection: Int, CaseIterable {
    case edit
    case phone
    case accounts
    case proxy
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
        setPhotoTitle = presentationData.strings.Settings_SetNewProfilePhotoOrVideo
        displaySetPhoto = isExpanded
    } else {
        setPhotoTitle = presentationData.strings.Settings_SetProfilePhotoOrVideo
        displaySetPhoto = true
    }
    if displaySetPhoto {
        items[.edit]!.append(PeerInfoScreenActionItem(id: 0, text: setPhotoTitle, icon: UIImage(bundleImageName: "Settings/SetAvatar"), action: {
            interaction.openSettings(.avatar)
        }))
    }
    if let peer = data.peer, (peer.addressName ?? "").isEmpty {
        items[.edit]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.Settings_SetUsername, icon: UIImage(bundleImageName: "Settings/SetUsername"), action: {
            interaction.openSettings(.username)
        }))
    }
    
    if let settings = data.globalSettings {
        if settings.suggestPhoneNumberConfirmation, let peer = data.peer as? TelegramUser {
            let phoneNumber = formatPhoneNumber(peer.phone ?? "")
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_CheckPhoneNumberTitle(phoneNumber).string, text: .markdown(presentationData.strings.Settings_CheckPhoneNumberText), linkAction: { link in
                if case .tap = link {
                    interaction.openFaq(presentationData.strings.Settings_CheckPhoneNumberFAQAnchor)
                }
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.Settings_KeepPhoneNumber(phoneNumber).string, action: {
                let _ = dismissServerProvidedSuggestion(account: context.account, suggestion: .validatePhoneNumber).start()
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_ChangePhoneNumber, action: {
                interaction.openSettings(.phoneNumber)
            }))
        } else if settings.suggestPasswordConfirmation {
            items[.phone]!.append(PeerInfoScreenInfoItem(id: 0, title: presentationData.strings.Settings_CheckPasswordTitle, text: .markdown(presentationData.strings.Settings_CheckPasswordText), linkAction: { _ in
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 1, text: presentationData.strings.Settings_KeepPassword, action: {
                let _ = dismissServerProvidedSuggestion(account: context.account, suggestion: .validatePassword).start()
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_TryEnterPassword, action: {
                interaction.openSettings(.rememberPassword)
            }))
        }
        
        if !settings.accountsAndPeers.isEmpty {
            for (peerAccountContext, peer, badgeCount) in settings.accountsAndPeers {
                let member: PeerInfoMember = .account(peer: RenderedPeer(peer: peer._asPeer()))
                items[.accounts]!.append(PeerInfoScreenMemberItem(id: member.id, context: context.sharedContext.makeTempAccountContext(account: peerAccountContext.account), enclosingPeer: nil, member: member, badge: badgeCount > 0 ? "\(compactNumericCountString(Int(badgeCount), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))" : nil, action: { action in
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
    
    let languageName = presentationData.strings.primaryComponent.localizedName
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 4, label: .text(languageName.isEmpty ? presentationData.strings.Localization_LanguageName : languageName), text: presentationData.strings.Settings_AppLanguage, icon: PresentationResourcesSettings.language, action: {
        interaction.openSettings(.language)
    }))
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    if !premiumConfiguration.isPremiumDisabled {
        items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 100, label: .text(""), text: presentationData.strings.Settings_Premium, icon: PresentationResourcesSettings.premium, action: {
            interaction.openSettings(.premium)
        }))
    }
    
    /*items[.payment]!.append(PeerInfoScreenDisclosureItem(id: 100, label: .text(""), text: "Payment Method", icon: PresentationResourcesSettings.language, action: {
        interaction.openPaymentMethod()
    }))*/
    
    let stickersLabel: String
    if let settings = data.globalSettings {
        stickersLabel = settings.unreadTrendingStickerPacks > 0 ? "\(settings.unreadTrendingStickerPacks)" : ""
    } else {
        stickersLabel = ""
    }
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 5, label: .badge(stickersLabel, presentationData.theme.list.itemAccentColor), text: presentationData.strings.ChatSettings_StickersAndReactions, icon: PresentationResourcesSettings.stickers, action: {
        interaction.openSettings(.stickers)
    }))
    
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

private func settingsEditingItems(data: PeerInfoScreenData?, state: PeerInfoState, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    enum Section: Int, CaseIterable {
        case help
        case bio
        case info
        case account
        case logout
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    let ItemNameHelp = 0
    let ItemBio = 1
    let ItemBioHelp = 2
    let ItemPhoneNumber = 3
    let ItemUsername = 4
    let ItemAddAccount = 5
    let ItemAddAccountHelp = 6
    let ItemLogout = 7
    
    items[.help]!.append(PeerInfoScreenCommentItem(id: ItemNameHelp, text: presentationData.strings.EditProfile_NameAndPhotoOrVideoHelp))
    
    if let cachedData = data.cachedData as? CachedUserData {
        items[.bio]!.append(PeerInfoScreenMultilineInputItem(id: ItemBio, text: state.updatingBio ?? (cachedData.about ?? ""), placeholder: presentationData.strings.UserInfo_About_Placeholder, textUpdated: { updatedText in
            interaction.updateBio(updatedText)
        }, action: {
            interaction.dismissInput()
        }, maxLength: Int(data.globalSettings?.userLimits.maxAboutLength ?? 70)))
        items[.bio]!.append(PeerInfoScreenCommentItem(id: ItemBioHelp, text: presentationData.strings.Settings_About_Help))
    }
    
    if let user = data.peer as? TelegramUser {
        items[.info]!.append(PeerInfoScreenDisclosureItem(id: ItemPhoneNumber, label: .text(user.phone.flatMap({ formatPhoneNumber($0) }) ?? ""), text: presentationData.strings.Settings_PhoneNumber, action: {
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

private func infoItems(data: PeerInfoScreenData?, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction, nearbyPeerDistance: Int32?, callMessages: [Message]) -> [(AnyHashable, [PeerInfoScreenItem])] {
    guard let data = data else {
        return []
    }
    
    enum Section: Int, CaseIterable {
        case groupLocation
        case calls
        case peerInfo
        case peerMembers
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    let bioContextAction: (ASDisplayNode) -> Void = { sourceNode in
        interaction.openPeerInfoContextMenu(.bio, sourceNode)
    }
    let bioLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void = { action, item in
        interaction.performBioLinkAction(action, item)
    }
    
    if let user = data.peer as? TelegramUser {
        if !callMessages.isEmpty {
            items[.calls]!.append(PeerInfoScreenCallListItem(id: 20, messages: callMessages))
        }
        
        if let phone = user.phone {
            let formattedPhone = formatPhoneNumber(phone)
            items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 2, label: presentationData.strings.ContactInfo_PhoneLabelMobile, text: formattedPhone, textColor: .accent, action: {
                interaction.openPhone(phone)
            }, longTapAction: { sourceNode in
                interaction.openPeerInfoContextMenu(.phone(formattedPhone), sourceNode)
            }, requestLayout: {
                interaction.requestLayout(false)
            }))
        }
        if let username = user.username {
            items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 1, label: presentationData.strings.Profile_Username, text: "@\(username)", textColor: .accent, icon: .qrCode, action: {
                interaction.openUsername(username)
            }, longTapAction: { sourceNode in
                interaction.openPeerInfoContextMenu(.link, sourceNode)
            }, iconAction: {
                interaction.openQrCode()
            }, requestLayout: {
                interaction.requestLayout(false)
            }))
        }
        if let cachedData = data.cachedData as? CachedUserData {
            if user.isFake {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: user.botInfo != nil ? presentationData.strings.UserInfo_FakeBotWarning : presentationData.strings.UserInfo_FakeUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: {
                    interaction.requestLayout(false)
                }))
            } else if user.isScam {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: user.botInfo != nil ? presentationData.strings.UserInfo_ScamBotWarning : presentationData.strings.UserInfo_ScamUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledPrivateBioEntities : []), action: nil, requestLayout: {
                    interaction.requestLayout(false)
                }))
            } else if let about = cachedData.about, !about.isEmpty {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: about, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.isPremium ? enabledPublicBioEntities : enabledPrivateBioEntities), action: nil, longTapAction: bioContextAction, linkItemAction: bioLinkAction, requestLayout: {
                    interaction.requestLayout(false)
                }))
            }
        }
        if let _ = nearbyPeerDistance {
            items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 3, text: presentationData.strings.UserInfo_SendMessage, action: {
                interaction.openChat()
            }))
            
            items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 4, text: presentationData.strings.ReportPeer_Report, color: .destructive, action: {
                interaction.openReport(true)
            }))
        } else {
            if !data.isContact {
                if user.botInfo == nil {
                    items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 3, text: presentationData.strings.PeerInfo_AddToContacts, action: {
                        interaction.openAddContact()
                    }))
                }
            }
            
            var isBlocked = false
            if let cachedData = data.cachedData as? CachedUserData, cachedData.isBlocked {
                isBlocked = true
            }
            
            if isBlocked {
                items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 4, text: user.botInfo != nil ? presentationData.strings.Bot_Unblock : presentationData.strings.Conversation_Unblock, action: {
                    interaction.updateBlocked(false)
                }))
            } else {
                if user.flags.contains(.isSupport) || data.isContact {
                } else {
                    if user.botInfo == nil {
                        items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 4, text: presentationData.strings.Conversation_BlockUser, color: .destructive, action: {
                            interaction.updateBlocked(true)
                        }))
                    }
                }
            }
            
            if let encryptionKeyFingerprint = data.encryptionKeyFingerprint {
                items[.peerInfo]!.append(PeerInfoScreenDisclosureEncryptionKeyItem(id: 5, text: presentationData.strings.Profile_EncryptionKey, fingerprint: encryptionKeyFingerprint, action: {
                    interaction.openEncryptionKey()
                }))
            }
            
            if user.botInfo != nil, !user.isVerified {
                items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 6, text: presentationData.strings.ReportPeer_Report, action: {
                    interaction.openReport(false)
                }))
            }
            
            if let botInfo = user.botInfo, botInfo.flags.contains(.worksWithGroups) {
                items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 7, text: presentationData.strings.Bot_AddToChat, color: .accent, action: {
                    interaction.openAddBotToGroup()
                }))
                items[.peerInfo]!.append(PeerInfoScreenCommentItem(id: 8, text: presentationData.strings.Bot_AddToChatInfo))
            }
            
        }
    } else if let channel = data.peer as? TelegramChannel {
        let ItemUsername = 1
        let ItemAbout = 2
        let ItemLocationHeader = 3
        let ItemLocation = 4
        let ItemAdmins = 5
        let ItemMembers = 6
        let ItemMemberRequests = 7
        
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
        
        if let username = channel.username {
            items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: ItemUsername, label: presentationData.strings.Channel_LinkItem, text: "https://t.me/\(username)", textColor: .accent, icon: .qrCode, action: {
                interaction.openUsername(username)
            }, longTapAction: { sourceNode in
                interaction.openPeerInfoContextMenu(.link, sourceNode)
            }, iconAction: {
                interaction.openQrCode()
            }, requestLayout: {
                interaction.requestLayout(false)
            }))
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
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: presentationData.strings.Channel_Info_Description, text: aboutText, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledEntities), action: nil, longTapAction: bioContextAction, linkItemAction: bioLinkAction, requestLayout: {
                    interaction.requestLayout(true)
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
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: presentationData.strings.Channel_Info_Description, text: aboutText, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledPrivateBioEntities), action: nil, longTapAction: bioContextAction, linkItemAction: bioLinkAction, requestLayout: {
                    interaction.requestLayout(true)
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
            items[.peerMembers]!.append(PeerInfoScreenMemberItem(id: member.id, context: context, enclosingPeer: peer, member: member, action: isAccountPeer ? nil : { action in
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
            }))
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

private func editingItems(data: PeerInfoScreenData?, context: AccountContext, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [(AnyHashable, [PeerInfoScreenItem])] {
    enum Section: Int, CaseIterable {
        case notifications
        case groupLocation
        case peerPublicSettings
        case peerSettings
        case peerAdditionalSettings
        case peerActions
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    if let data = data {
        if let _ = data.peer as? TelegramUser {
            let ItemDelete = 0
            if data.isContact {
                items[.peerSettings]!.append(PeerInfoScreenActionItem(id: ItemDelete, text: presentationData.strings.UserInfo_DeleteContact, color: .destructive, action: {
                    interaction.requestDeleteContact()
                }))
            }
        } else if let channel = data.peer as? TelegramChannel {
            switch channel.info {
            case .broadcast:
                let ItemUsername = 1
                let ItemInviteLinks = 2
                let ItemDiscussionGroup = 3
                let ItemSignMessages = 4
                let ItemSignMessagesHelp = 5
                let ItemDeleteChannel = 6
                let ItemReactions = 7
                
                let ItemAdmins = 8
                let ItemMembers = 9
                let ItemMemberRequests = 10
                let ItemBanned = 11
                
                let isCreator = channel.flags.contains(.isCreator)
                
                if isCreator {
                    let linkText: String
                    if let _ = channel.username {
                        linkText = presentationData.strings.Channel_Setup_TypePublic
                    } else {
                        linkText = presentationData.strings.Channel_Setup_TypePrivate
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(linkText), text: presentationData.strings.Channel_TypeSetup_Title, icon: UIImage(bundleImageName: "Chat/Info/GroupChannelIcon"), action: {
                        interaction.editingOpenPublicLinkSetup()
                    }))
                }
                 
                if (isCreator && (channel.username?.isEmpty ?? true)) || (!channel.flags.contains(.isCreator) && channel.adminRights?.rights.contains(.canInviteUsers) == true) {
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
                    if let cachedData = data.cachedData as? CachedChannelData, let allowedReactions = cachedData.allowedReactions {
                        if allowedReactions.isEmpty {
                            label = presentationData.strings.PeerInfo_ReactionsDisabled
                        } else {
                            label = "\(allowedReactions.count)"
                        }
                    } else {
                        label = ""
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                        interaction.editingOpenReactionsSetup()
                    }))
                }
                
                if isCreator || (channel.adminRights != nil && channel.hasPermission(.sendMessages)) {
                    let messagesShouldHaveSignatures: Bool
                    switch channel.info {
                    case let .broadcast(info):
                        messagesShouldHaveSignatures = info.flags.contains(.messagesShouldHaveSignatures)
                    default:
                        messagesShouldHaveSignatures = false
                    }
                    items[.peerSettings]!.append(PeerInfoScreenSwitchItem(id: ItemSignMessages, text: presentationData.strings.Channel_SignMessages, value: messagesShouldHaveSignatures, icon: UIImage(bundleImageName: "Chat/Info/GroupSignIcon"), toggled: { value in
                        interaction.editingToggleMessageSignatures(value)
                    }))
                    items[.peerSettings]!.append(PeerInfoScreenCommentItem(id: ItemSignMessagesHelp, text: presentationData.strings.Channel_SignMessages_Help))
                }
                
                var canEditMembers = false
                if channel.hasPermission(.banMembers) {
                    canEditMembers = true
                }
                if canEditMembers {
                    if channel.adminRights != nil || channel.flags.contains(.isCreator) {
                        let adminCount: Int32
                        let memberCount: Int32
                        let bannedCount: Int32
                        if let cachedData = data.cachedData as? CachedChannelData {
                            adminCount = cachedData.participantsSummary.adminCount ?? 0
                            memberCount = cachedData.participantsSummary.memberCount ?? 0
                            bannedCount = cachedData.participantsSummary.kickedCount ?? 0
                        } else {
                            adminCount = 0
                            memberCount = 0
                            bannedCount = 0
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
                        
                        items[.peerAdditionalSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemBanned, label: .text("\(bannedCount == 0 ? "" : "\(presentationStringsFormattedNumber(bannedCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Permissions_Removed, icon: UIImage(bundleImageName: "Chat/Info/GroupRemovedIcon"), action: {
                            interaction.openParticipantsSection(.banned)
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
                let ItemStickerPack = 105
                let ItemMembers = 106
                let ItemPermissions = 107
                let ItemAdmins = 108
                let ItemMemberRequests = 109
                let ItemRemovedUsers = 110
                let ItemLocationHeader = 111
                let ItemLocation = 112
                let ItemLocationSetup = 113
                let ItemDeleteGroup = 114
                let ItemReactions = 115
                
                let isCreator = channel.flags.contains(.isCreator)
                let isPublic = channel.username != nil
                
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
                                if let username = channel.username {
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
                    
                    if (isCreator && (channel.username?.isEmpty ?? true) && cachedData.peerGeoLocation == nil) || (!isCreator && channel.adminRights?.rights.contains(.canInviteUsers) == true) {
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
                            
                    if (isCreator || (channel.adminRights != nil && channel.hasPermission(.pinMessages))) && cachedData.peerGeoLocation == nil {
                        if let linkedDiscussionPeer = data.linkedDiscussionPeer {
                            let peerTitle: String
                            if let addressName = linkedDiscussionPeer.addressName, !addressName.isEmpty {
                                peerTitle = "@\(addressName)"
                            } else {
                                peerTitle = EnginePeer(linkedDiscussionPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            }
                            items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemLinkedChannel, label: .text(peerTitle), text: presentationData.strings.Group_LinkedChannel, icon: UIImage(bundleImageName: "Chat/Info/GroupLinkedChannelIcon"), action: {
                                interaction.editingOpenDiscussionGroupSetup()
                            }))
                        }
                        
                        if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                            let label: String
                            if let cachedData = data.cachedData as? CachedChannelData, let allowedReactions = cachedData.allowedReactions {
                                if allowedReactions.isEmpty {
                                    label = presentationData.strings.PeerInfo_ReactionsDisabled
                                } else {
                                    label = "\(allowedReactions.count)"
                                }
                            } else {
                                label = ""
                            }
                            items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                                interaction.editingOpenReactionsSetup()
                            }))
                        }
                        
                        if !isPublic, case .known(nil) = cachedData.linkedDiscussionPeerId {
                            items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPreHistory, label: .text(cachedData.flags.contains(.preHistoryEnabled) ? presentationData.strings.GroupInfo_GroupHistoryVisible : presentationData.strings.GroupInfo_GroupHistoryHidden), text: presentationData.strings.GroupInfo_GroupHistoryShort, icon: UIImage(bundleImageName: "Chat/Info/GroupDiscussionIcon"), action: {
                                interaction.editingOpenPreHistorySetup()
                            }))
                        }
                    } else {
                        if isCreator || (channel.adminRights?.rights.contains(.canChangeInfo) == true) {
                            let label: String
                            if let cachedData = data.cachedData as? CachedChannelData, let allowedReactions = cachedData.allowedReactions {
                                if allowedReactions.isEmpty {
                                    label = presentationData.strings.PeerInfo_ReactionsDisabled
                                } else {
                                    label = "\(allowedReactions.count)"
                                }
                            } else {
                                label = ""
                            }
                            items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                                interaction.editingOpenReactionsSetup()
                            }))
                        }
                    }
                    
                    if cachedData.flags.contains(.canSetStickerSet) && canEditPeerInfo(context: context, peer: channel) {
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemStickerPack, label: .text(cachedData.stickerPack?.title ?? presentationData.strings.GroupInfo_SharedMediaNone), text: presentationData.strings.Stickers_GroupStickers, icon: UIImage(bundleImageName: "Settings/Menu/Stickers"), action: {
                            interaction.editingOpenStickerPackSetup()
                        }))
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
                            for (right, _) in allGroupPermissionList {
                                if !defaultBannedRights.flags.contains(right) {
                                    count += 1
                                }
                            }
                            activePermissionCount = count
                        }
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text(cachedData.participantsSummary.memberCount.flatMap { "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" } ?? ""), text: presentationData.strings.Group_Info_Members, icon: UIImage(bundleImageName: "Chat/Info/GroupMembersIcon"), action: {
                            interaction.openParticipantsSection(.members)
                        }))
                        if !channel.flags.contains(.isGigagroup) {
                            items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, icon: UIImage(bundleImageName: "Settings/Menu/SetPasscode"), action: {
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
                
                do {
                    let label: String
                    if let cachedData = data.cachedData as? CachedGroupData, let allowedReactions = cachedData.allowedReactions {
                        if allowedReactions.isEmpty {
                            label = presentationData.strings.PeerInfo_ReactionsDisabled
                        } else {
                            label = "\(allowedReactions.count)"
                        }
                    } else {
                        label = ""
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemReactions, label: .text(label), text: presentationData.strings.PeerInfo_Reactions, icon: UIImage(bundleImageName: "Settings/Menu/Reactions"), action: {
                        interaction.editingOpenReactionsSetup()
                    }))
                }
                
                canViewAdminsAndBanned = true
            } else if case let .admin(rights, _) = group.role {
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
                    for (right, _) in allGroupPermissionList {
                        if !defaultBannedRights.flags.contains(right) {
                            count += 1
                        }
                    }
                    activePermissionCount = count
                }
                
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, icon: UIImage(bundleImageName: "Settings/Menu/SetPasscode"), action: {
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

final class PeerInfoScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private weak var controller: PeerInfoScreenImpl?
    
    private let context: AccountContext
    let peerId: PeerId
    private let isOpenedFromChat: Bool
    private let videoCallsEnabled: Bool
    private let callMessages: [Message]
    
    let isSettings: Bool
    private let isMediaOnly: Bool
    
    private var presentationData: PresentationData
    
    fileprivate let cachedDataPromise = Promise<CachedPeerData?>()
    
    let scrollNode: ASScrollNode
    
    let headerNode: PeerInfoHeaderNode
    private var regularSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    private var editingSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    private let paneContainerNode: PeerInfoPaneContainerNode
    private var ignoreScrolling: Bool = false
    private var hapticFeedback: HapticFeedback?

    private var customStatusData: (PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?)
    private let customStatusPromise = Promise<(PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?)>((nil, nil, nil))
    private var customStatusDisposable: Disposable?

    private var refreshMessageTagStatsDisposable: Disposable?
    
    private var searchDisplayController: SearchDisplayController?
    
    private var _interaction: PeerInfoInteraction?
    private var interaction: PeerInfoInteraction {
        return self._interaction!
    }
    
    private var _chatInterfaceInteraction: ChatControllerInteraction?
    private var chatInterfaceInteraction: ChatControllerInteraction {
        return self._chatInterfaceInteraction!
    }
    private var hiddenMediaDisposable: Disposable?
    private let hiddenAvatarRepresentationDisposable = MetaDisposable()
    
    private var resolvePeerByNameDisposable: MetaDisposable?
    private let navigationActionDisposable = MetaDisposable()
    private let enqueueMediaMessageDisposable = MetaDisposable()
    
    private(set) var validLayout: (ContainerViewLayout, CGFloat)?
    private(set) var data: PeerInfoScreenData?
    private(set) var state = PeerInfoState(
        isEditing: false,
        selectedMessageIds: nil,
        updatingAvatar: nil,
        updatingBio: nil,
        avatarUploadProgress: nil,
        highlightedButton: nil
    )
    private let nearbyPeerDistance: Int32?
    private var dataDisposable: Disposable?
    
    private let activeActionDisposable = MetaDisposable()
    private let resolveUrlDisposable = MetaDisposable()
    private let toggleShouldChannelMessagesSignaturesDisposable = MetaDisposable()
    private let toggleMessageCopyProtectionDisposable = MetaDisposable()
    private let selectAddMemberDisposable = MetaDisposable()
    private let addMemberDisposable = MetaDisposable()
    private let preloadHistoryDisposable = MetaDisposable()
    private var shareStatusDisposable: MetaDisposable?
    
    private let editAvatarDisposable = MetaDisposable()
    private let updateAvatarDisposable = MetaDisposable()
    private let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    private var groupMembersSearchContext: GroupMembersSearchContext?
    
    private let displayAsPeersPromise = Promise<[FoundPeer]>([])
    
    fileprivate let accountsAndPeers = Promise<[(AccountContext, EnginePeer, Int32)]>()
    fileprivate let activeSessionsContextAndCount = Promise<(ActiveSessionsContext, Int, WebSessionsContext)?>()
    private let notificationExceptions = Promise<NotificationExceptionsList?>()
    private let privacySettings = Promise<AccountPrivacySettings?>()
    private let archivedPacks = Promise<[ArchivedStickerPackItem]?>()
    private let blockedPeers = Promise<BlockedPeersContext?>(nil)
    private let hasTwoStepAuth = Promise<Bool?>(nil)
    private let hasPassport = Promise<Bool>(false)
    private let supportPeerDisposable = MetaDisposable()
    private let tipsPeerDisposable = MetaDisposable()
    private let cachedFaq = Promise<ResolvedUrl?>(nil)
    
    private weak var copyProtectionTooltipController: TooltipController?
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    init(controller: PeerInfoScreenImpl, context: AccountContext, peerId: PeerId, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, nearbyPeerDistance: Int32?, callMessages: [Message], isSettings: Bool, hintGroupInCommon: PeerId?, requestsContext: PeerInvitationImportersContext?) {
        self.controller = controller
        self.context = context
        self.peerId = peerId
        self.isOpenedFromChat = isOpenedFromChat
        self.videoCallsEnabled = true
        self.presentationData = controller.presentationData
        self.nearbyPeerDistance = nearbyPeerDistance
        self.callMessages = callMessages
        self.isSettings = isSettings
        self.isMediaOnly = context.account.peerId == peerId && !isSettings
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.canCancelAllTouchesInViews = true
        
        self.headerNode = PeerInfoHeaderNode(context: context, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, isMediaOnly: self.isMediaOnly, isSettings: isSettings)
        self.paneContainerNode = PeerInfoPaneContainerNode(context: context, updatedPresentationData: controller.updatedPresentationData, peerId: peerId, isMediaOnly: self.isMediaOnly)
        
        super.init()
        
        self.paneContainerNode.parentController = controller
        
        self._interaction = PeerInfoInteraction(
            openUsername: { [weak self] value in
                self?.openUsername(value: value)
            },
            openPhone: { [weak self] value in
                self?.openPhone(value: value)
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
            openChat: { [weak self] in
                self?.openChat()
            },
            openAddContact: { [weak self] in
                self?.openAddContact()
            },
            updateBlocked: { [weak self] block in
                self?.updateBlocked(block: block)
            },
            openReport: { [weak self] user in
                self?.openReport(user: user, contextController: nil, backAction: nil)
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
            editingOpenInviteLinksSetup: { [weak self] in
                self?.editingOpenInviteLinksSetup()
            },
            editingOpenDiscussionGroupSetup: { [weak self] in
                self?.editingOpenDiscussionGroupSetup()
            },
            editingToggleMessageSignatures: { [weak self] value in
                self?.editingToggleMessageSignatures(value: value)
            },
            openParticipantsSection: { [weak self] section in
                self?.openParticipantsSection(section: section)
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
            openPeerInfoContextMenu: { [weak self] subject, sourceNode in
                self?.openPeerInfoContextMenu(subject: subject, sourceNode: sourceNode)
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
            }
        )
        
        self._chatInterfaceInteraction = ChatControllerInteraction(openMessage: { [weak self] message, mode in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.openMessage(id: message.id)
        }, openPeer: { [weak self] id, navigation, _, _ in
            if let id = id {
                self?.openPeer(peerId: id, navigation: navigation)
            }
        }, openPeerMention: { _ in
        }, openMessageContextMenu: { [weak self] message, _, node, frame, anyRecognizer in
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
            let _ = (chatAvailableMessageActionsImpl(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id])
            |> deliverOnMainQueue).start(next: { actions in
                guard let strongSelf = self else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c.dismiss(completion: {
                        if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                            let currentPeerId = strongSelf.peerId
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: currentPeerId), subject: .message(id: .id(message.id), highlight: true, timecode: nil), keepStack: .always, useExisting: false, purposefulAction: {
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
                    })
                })))
                
                if let linkForCopying = linkForCopying {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuCopyLink, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c.dismiss(completion: {})
                        UIPasteboard.general.string = linkForCopying
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    })))
                }
                
                if message.isCopyProtected() {
                    
                } else if message.id.peerId.namespace != Namespaces.Peer.SecretChat {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c.dismiss(completion: {
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
                        c.setItems(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: message.id.peerId))
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
                                        c.dismiss(completion: {
                                            if let strongSelf = self {
                                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
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
                                        c.dismiss(completion: {
                                            if let strongSelf = self {
                                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).start()
                                            }
                                        })
                                    })))
                                }
                            }
                            
                            return ContextController.Items(content: .list(items))
                        }, minHeight: nil)
                    })))
                }
                if strongSelf.searchDisplayController == nil {
                    items.append(.separator)
                    
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuSelect, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c.dismiss(completion: {
                            if let strongSelf = self {
                                strongSelf.chatInterfaceInteraction.toggleMessagesSelection([message.id], true)
                                strongSelf.expandTabs()
                            }
                        })
                    })))
                }
                
                let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
                strongSelf.controller?.window?.presentInGlobalOverlay(controller)
            })
        }, openMessageReactionContextMenu: { _, _, _, _ in
        }, updateMessageReaction: { _, _ in
        }, activateMessagePinch: { _ in
        }, openMessageContextActions: { [weak self] message, node, rect, gesture in
            guard let strongSelf = self else {
                gesture?.cancel()
                return
            }
            
            let _ = (chatMediaListPreviewControllerData(context: strongSelf.context, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: strongSelf.controller?.navigationController as? NavigationController)
            |> deliverOnMainQueue).start(next: { previewData in
                guard let strongSelf = self else {
                    gesture?.cancel()
                    return
                }
                if let previewData = previewData {
                    let context = strongSelf.context
                    let strings = strongSelf.presentationData.strings
                    let items = chatAvailableMessageActionsImpl(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id])
                    |> map { actions -> [ContextMenuItem] in
                        var items: [ContextMenuItem] = []
                        
                        items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            c.dismiss(completion: {
                                if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                    let currentPeerId = strongSelf.peerId
                                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: currentPeerId), subject: .message(id: .id(message.id), highlight: true, timecode: nil), keepStack: .always, useExisting: false, purposefulAction: {
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
                            })
                        })))
                        
                        if message.isCopyProtected() {
                            
                        } else if message.id.peerId.namespace != Namespaces.Peer.SecretChat {
                            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                                c.dismiss(completion: {
                                    if let strongSelf = self {
                                        strongSelf.forwardMessages(messageIds: [message.id])
                                    }
                                })
                            })))
                        }
                        
                        if actions.options.contains(.deleteLocally) || actions.options.contains(.deleteGlobally) {
                            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, f in
                                c.setItems(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: message.id.peerId))
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
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                                            } else if let personalPeerName = personalPeerName {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                                            } else {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                                            }
                                            items.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                                c.dismiss(completion: {
                                                    if let strongSelf = self {
                                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                        let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
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
                                                c.dismiss(completion: {
                                                    if let strongSelf = self {
                                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                                        let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).start()
                                                    }
                                                })
                                            })))
                                        }
                                    }
                                    
                                    return ContextController.Items(content: .list(items))
                                }, minHeight: nil)
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
                            strongSelf.expandTabs()
                            f(.default)
                        })))
                        
                        return items
                    }
                    
                    switch previewData {
                    case let .gallery(gallery):
                        gallery.setHintWillBePresentedInPreviewingContext(true)
                        let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: node, sourceRect: rect)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                        strongSelf.controller?.presentInGlobalOverlay(contextController)
                    case .instantPage:
                        break
                    }
                }
            })
        }, navigateToMessage: { fromId, id in
        }, navigateToMessageStandalone: { _ in
        }, tapMessage: nil, clickThroughMessage: {
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
        }, sendCurrentMessage: { _ in
        }, sendMessage: { _ in
        }, sendSticker: { _, _, _, _, _, _, _ in
            return false
        }, sendGif: { _, _, _, _, _ in
            return false
        }, sendBotContextResultAsGif: { _, _, _, _, _ in
            return false
        }, requestMessageActionCallback: { _, _, _, _ in
        }, requestMessageActionUrlAuth: { _, _ in
        }, activateSwitchInline: { _, _ in
        }, openUrl: { [weak self] url, concealed, external, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openUrl(url: url, concealed: concealed, external: external ?? false)
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
                openChatInstantPage(context: strongSelf.context, message: foundGalleryMessage, sourcePeerType: associatedData?.automaticDownloadPeerType, navigationController: navigationController)
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
        }, openCheckoutOrReceipt: { _ in
        }, openSearch: {
        }, setupReply: { _ in
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
        }, displayPremiumStickerTooltip: { _, _ in
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
        pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: false), presentationContext: ChatPresentationContext(context: context, backgroundNode: nil))
        self.hiddenMediaDisposable = context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
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
        self.scrollNode.view.delegate = self
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.paneContainerNode)
        
        if !self.isMediaOnly {
            self.addSubnode(self.headerNode.buttonsContainerNode)
        }
        self.addSubnode(self.headerNode)
        self.scrollNode.view.isScrollEnabled = !self.isMediaOnly
        
        self.paneContainerNode.chatControllerInteraction = self.chatInterfaceInteraction
        self.paneContainerNode.openPeerContextAction = { [weak self] peer, node, gesture in
            guard let strongSelf = self, let controller = strongSelf.controller else {
                return
            }
            let presentationData = strongSelf.presentationData
            let chatController = strongSelf.context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(previewing: true))
            chatController.canReadHistory.set(false)
            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(text: presentationData.strings.Conversation_LinkDialogOpen, icon: { _ in nil }, action: { _, f in
                    f(.dismissWithoutContent)
                    self?.chatInterfaceInteraction.openPeer(peer.id, .default, nil, nil)
                }))
            ]
            let contextController = ContextController(account: strongSelf.context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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

        self.paneContainerNode.openMediaCalendar = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openMediaCalendar()
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
            
            let entriesPromise = Promise<[AvatarGalleryEntry]>(entries)
            let galleryController = AvatarGalleryController(context: strongSelf.context, peer: peer, sourceCorners: .round, remoteEntries: entriesPromise, skipInitial: true, centralEntryIndex: centralEntry.flatMap { entries.firstIndex(of: $0) }, replaceRootController: { controller, ready in
            })
            galleryController.openAvatarSetup = { [weak self] completion in
                self?.openAvatarForEditing(fromGallery: true, completion: completion)
            }
            galleryController.avatarPhotoEditCompletion = { [weak self] image in
                self?.updateProfilePhoto(image)
            }
            galleryController.avatarVideoEditCompletion = { [weak self] image, asset, adjustments in
                self?.updateProfileVideo(image, asset: asset, adjustments: adjustments)
            }
            galleryController.removedEntry = { [weak self] entry in
                if let item = PeerInfoAvatarListItem(entry: entry) {
                    let _ = self?.headerNode.avatarListNode.listContainerNode.deleteItem(item)
                }
            }
            strongSelf.hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                self?.headerNode.updateAvatarIsHidden(entry: entry)
            }))
            strongSelf.view.endEditing(true)
            strongSelf.controller?.present(galleryController, in: .window(.root), with: AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                if let transitionNode = self?.headerNode.avatarTransitionArguments(entry: entry) {
                    return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: { view in
                        self?.headerNode.addToAvatarTransitionSurface(view: view)
                    })
                } else {
                    return nil
                }
            }))
            
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
                strongSelf.openAvatarForEditing()
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
            case .edit:
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
                strongSelf.controller?.navigationItem.setLeftBarButton(UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, style: .plain, target: strongSelf, action: #selector(strongSelf.editingCancelPressed)), animated: true)
            case .done, .cancel:
                strongSelf.view.endEditing(true)
                if case .done = key {
                    guard let data = strongSelf.data else {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                        return
                    }
                    if let peer = data.peer as? TelegramUser {
                        if strongSelf.isSettings, let cachedData = data.cachedData as? CachedUserData {
                            let firstName = strongSelf.headerNode.editingContentNode.editingTextForKey(.firstName) ?? ""
                            let lastName = strongSelf.headerNode.editingContentNode.editingTextForKey(.lastName) ?? ""
                            let bio = strongSelf.state.updatingBio
                            
                            if let bio = bio {
                                if Int32(bio.count) > strongSelf.context.userLimits.maxAboutLength {
                                    for (_, section) in strongSelf.editingSections {
                                        section.animateErrorIfNeeded()
                                    }
                                    strongSelf.hapticFeedback?.error()
                                    return
                                }
                            }
                            
                            if peer.firstName != firstName || peer.lastName != lastName || (bio != nil && bio != cachedData.about) {
                                var updateNameSignal: Signal<Void, NoError> = .complete()
                                var hasProgress = false
                                if peer.firstName != firstName || peer.lastName != lastName {
                                    updateNameSignal = context.engine.accountData.updateAccountPeerName(firstName: firstName, lastName: lastName)
                                    hasProgress = true
                                }
                                var updateBioSignal: Signal<Void, NoError> = .complete()
                                if let bio = bio, bio != cachedData.about {
                                    updateBioSignal = context.engine.accountData.updateAbout(about: bio)
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
                                |> deliverOnMainQueue).start(completed: {
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
                            
                            if peer.firstName != firstName || peer.lastName != lastName {
                                if firstName.isEmpty && lastName.isEmpty {
                                    if strongSelf.hapticFeedback == nil {
                                        strongSelf.hapticFeedback = HapticFeedback()
                                    }
                                    strongSelf.hapticFeedback?.error()
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
                                    |> deliverOnMainQueue).start(error: { _ in
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
                                            return (context.sharedContext.contactDataManager?.basicDataForNormalizedPhoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone))) ?? .single([]))
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
                                        }).start()
                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                                    }))
                                }
                            } else {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                            }
                        } else {
                            strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                        }
                    } else if let group = data.peer as? TelegramGroup, canEditPeerInfo(context: strongSelf.context, peer: group) {
                        let title = strongSelf.headerNode.editingContentNode.editingTextForKey(.title) ?? ""
                        let description = strongSelf.headerNode.editingContentNode.editingTextForKey(.description) ?? ""
                        
                        if title.isEmpty {
                            if strongSelf.hapticFeedback == nil {
                                strongSelf.hapticFeedback = HapticFeedback()
                            }
                            strongSelf.hapticFeedback?.error()
                            
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
                            |> deliverOnMainQueue).start(error: { _ in
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
                    } else if let channel = data.peer as? TelegramChannel, canEditPeerInfo(context: strongSelf.context, peer: channel) {
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
                                |> deliverOnMainQueue).start(error: { _ in
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
                    strongSelf.state = strongSelf.state.withIsEditing(false)
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.scrollNode.view.setContentOffset(CGPoint(), animated: false)
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                    UIView.transition(with: strongSelf.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: nil)
                    strongSelf.controller?.navigationItem.setLeftBarButton(nil, animated: true)
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
                strongSelf.state = strongSelf.state.withSelectedMessageIds(nil)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
                }
                strongSelf.chatInterfaceInteraction.selectionState = strongSelf.state.selectedMessageIds.flatMap { ChatInterfaceSelectionState(selectedIds: $0) }
                strongSelf.paneContainerNode.updateSelectedMessageIds(strongSelf.state.selectedMessageIds, animated: true)
            case .search:
                strongSelf.headerNode.navigationButtonContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                strongSelf.activateSearch()
            case .more:
                if let source = source {
                    strongSelf.displayMediaGalleryContextMenu(source: source, gesture: gesture)
                }
            case .qrCode:
                strongSelf.openQrCode()
            case .editPhoto, .editVideo, .moreToSearch:
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
            self.hasPassport.set(.single(false) |> then(context.engine.auth.twoStepAuthData()
            |> map { value -> Bool in
                return value.hasSecretValues
            }
            |> `catch` { _ -> Signal<Bool, NoError> in
                return .single(false)
            }))
            
            self.cachedFaq.set(.single(nil) |> then(cachedFaqInstantPage(context: self.context) |> map(Optional.init)))
            
            screenData = peerInfoScreenSettingsData(context: context, peerId: peerId, accountsAndPeers: self.accountsAndPeers.get(), activeSessionsContextAndCount: self.activeSessionsContextAndCount.get(), notificationExceptions: self.notificationExceptions.get(), privacySettings: self.privacySettings.get(), archivedStickerPacks: self.archivedPacks.get(), hasPassport: self.hasPassport.get())
            
            
            self.headerNode.displayCopyContextMenu = { [weak self] node, copyPhone, copyUsername in
                guard let strongSelf = self, let data = strongSelf.data, let user = data.peer as? TelegramUser else {
                    return
                }
                var actions: [ContextMenuAction] = []
                if copyPhone, let phone = user.phone, !phone.isEmpty {
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Settings_CopyPhoneNumber, accessibilityLabel: strongSelf.presentationData.strings.Settings_CopyPhoneNumber), action: { [weak self] in
                        UIPasteboard.general.string = formatPhoneNumber(phone)
                        
                        if let strongSelf = self {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }
                    }))
                }
                
                if copyUsername, let username = user.username, !username.isEmpty {
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Settings_CopyUsername, accessibilityLabel: strongSelf.presentationData.strings.Settings_CopyUsername), action: { [weak self] in
                        UIPasteboard.general.string = "@\(username)"
                        
                        if let strongSelf = self {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_UsernameCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }
                    }))
                }
                
                let contextMenuController = ContextMenuController(actions: actions)
                strongSelf.controller?.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                    if let strongSelf = self {
                        return (node, node.bounds.insetBy(dx: 0.0, dy: -2.0), strongSelf, strongSelf.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
        } else {
            screenData = peerInfoScreenData(context: context, peerId: peerId, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, isSettings: self.isSettings, hintGroupInCommon: hintGroupInCommon, existingRequestsContext: requestsContext)
                       
            self.headerNode.displayPremiumIntro = { [weak self] sourceView, white in
                guard let strongSelf = self else {
                    return
                }
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                if !premiumConfiguration.isPremiumDisabled {
                    let controller = PremiumIntroScreen(context: strongSelf.context, source: .profile(strongSelf.peerId))
                    controller.sourceView = sourceView
                    controller.containerView = strongSelf.controller?.navigationController?.view
                    controller.animationColor = white ? .white : strongSelf.presentationData.theme.list.itemAccentColor
                    strongSelf.controller?.push(controller)
                }
            }
            
            self.headerNode.displayAvatarContextMenu = { [weak self] node, gesture in
                guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                    return
                }
                
                var currentIsVideo = false
                let item = strongSelf.headerNode.avatarListNode.listContainerNode.currentItemNode?.item
                if let item = item, case let .image(_, _, videoRepresentations, _) = item {
                    currentIsVideo = !videoRepresentations.isEmpty
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
                
                let galleryController = AvatarGalleryController(context: strongSelf.context, peer: peer, remoteEntries: nil, replaceRootController: { controller, ready in
                }, synchronousLoad: true)
                galleryController.setHintWillBePresentedInPreviewingContext(true)
                
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: galleryController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }
            
            if [Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel].contains(peerId.namespace) {
                self.displayAsPeersPromise.set(context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId))
            }
        }
        
        self.headerNode.avatarListNode.listContainerNode.currentIndexUpdated = { [weak self] in
            self?.updateNavigation(transition: .immediate, additive: true)
        }
        
        self.dataDisposable = (screenData
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateData(data)
            strongSelf.cachedDataPromise.set(.single(data.cachedData))
        })
        
        if let _ = nearbyPeerDistance {
            self.preloadHistoryDisposable.set(self.context.account.addAdditionalPreloadHistoryPeerId(peerId: peerId))
            
            self.context.prefetchManager?.prepareNextGreetingSticker()
        }

        self.customStatusDisposable = (self.customStatusPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.customStatusData = value
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
        })

        self.refreshMessageTagStatsDisposable = context.engine.messages.refreshMessageTagStats(peerId: peerId, tags: [.video, .photo, .gif, .music, .voiceOrInstantVideo, .webPage, .file]).start()
    }
    
    deinit {
        self.dataDisposable?.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.activeActionDisposable.dispose()
        self.resolveUrlDisposable.dispose()
        self.hiddenAvatarRepresentationDisposable.dispose()
        self.toggleShouldChannelMessagesSignaturesDisposable.dispose()
        self.toggleMessageCopyProtectionDisposable.dispose()
        self.editAvatarDisposable.dispose()
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
        
        self.copyProtectionTooltipController?.dismiss()
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
            
            var infoUpdated = false // previousData != nil && (previousData?.cachedData == nil) != (data.cachedData == nil)
           
            var previousCall: CachedChannelData.ActiveCall?
            var currentCall: CachedChannelData.ActiveCall?
            
            var previousCallsPrivate: Bool?
            var currentCallsPrivate: Bool?
            var previousVideoCallsAvailable: Bool? = true
            var currentVideoCallsAvailable: Bool?
            
            var previousAbout: String?
            var currentAbout: String?
            
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
            }
            
            if self.isSettings {
                if let previousSuggestPhoneNumberConfirmation = previousData?.globalSettings?.suggestPhoneNumberConfirmation, previousSuggestPhoneNumberConfirmation != data.globalSettings?.suggestPhoneNumberConfirmation {
                    infoUpdated = true
                }
                if let previousSuggestPasswordConfirmation = previousData?.globalSettings?.suggestPasswordConfirmation, previousSuggestPasswordConfirmation != data.globalSettings?.suggestPasswordConfirmation {
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
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: self.didSetReady && (membersUpdated || infoUpdated) ? .animated(duration: 0.3, curve: .spring) : .immediate)
        }
    }
    
    func scrollToTop() {
        if !self.paneContainerNode.scrollToTop() {
            self.scrollNode.view.setContentOffset(CGPoint(), animated: true)
        }
    }
    
    private func expandTabs() {
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
                self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: paneAreaExpansionFinalPoint), animated: true)
            }
        }
    }
    
    @objc private func editingCancelPressed() {
        self.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
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
        
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, chatLocation: nil, chatLocationContextHolder: nil, message: galleryMessage, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, transitionNode: { [weak self] messageId, media in
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
            //self?.controllerInteraction?.callPeer(peerId)
        }, enqueueMessage: { _ in
        }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, actionInteraction: GalleryControllerActionInteraction(openUrl: { [weak self] url, concealed in
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
        }, openPeer: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.openPeer(peerId: peerId, navigation: .default)
            }
        }, openHashtag: { [weak self] peerName, hashtag in
            if let strongSelf = self {
                strongSelf.openHashtag(hashtag, peerName: peerName)
            }
        }, openBotCommand: { _ in
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
            let _ = updateMediaPlaybackStoredStateInteractively(engine: strongSelf.context.engine, messageId: messageId, state: storedState).start()
        }, editMedia: { [weak self] messageId, snapshots, transitionCompletion in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).start(next: { [weak self] message in
                guard let strongSelf = self, let message = message else {
                    return
                }
                
                var mediaReference: AnyMediaReference?
                for m in message.media {
                    if let image = m as? TelegramMediaImage {
                        mediaReference = AnyMediaReference.standalone(media: image)
                    }
                }
                
                if let mediaReference = mediaReference, let peer = message.peers[message.id.peerId] {
                    legacyMediaEditor(context: strongSelf.context, peer: peer, media: mediaReference, initialCaption: NSAttributedString(), snapshots: snapshots, transitionCompletion: {
                        transitionCompletion()
                    }, presentStickers: { [weak self] completion in
                        if let strongSelf = self {
                            let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                                completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                                return true
                            })
                            strongSelf.controller?.present(controller, in: .window(.root))
                            return controller
                        } else {
                            return nil
                        }
                    }, getCaptionPanelView: {
                        return nil
                    }, sendMessagesWithSignals: { [weak self] signals, _, _ in
                        if let strongSelf = self {
                            strongSelf.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(account: strongSelf.context.account, signals: signals!)
                            |> deliverOnMainQueue).start(next: { [weak self] messages in
                                if let strongSelf = self {
                                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: strongSelf.peerId, messages: messages.map { $0.message }).start()
                                }
                            }))
                        }
                    }, present: { [weak self] c, a in
                        self?.controller?.present(c, in: .window(.root), with: a)
                    })
                }
            })
        }), centralItemUpdated: { [weak self] messageId in
            let _ = self?.paneContainerNode.requestExpandTabs?()
            self?.paneContainerNode.currentPane?.node.ensureMessageIsVisible(id: messageId)
        }))
    }
    
    private func openResolved(_ result: ResolvedUrl) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        self.context.sharedContext.openResolvedUrl(result, context: self.context, urlContext: .chat(peerId: self.peerId, updatedPresentationData: self.controller?.updatedPresentationData), navigationController: navigationController, forceExternal: false, openPeer: { [weak self] peerId, navigation in
            guard let strongSelf = self else {
                return
            }
            switch navigation {
                case let .chat(_, subject, peekData):
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), subject: subject, keepStack: .always, peekData: peekData))
                case .info:
                    strongSelf.navigationActionDisposable.set((strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                            if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                strongSelf.controller?.push(infoController)
                            }
                        }
                    }))
                case let .withBotStartPayload(startPayload):
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), botStart: startPayload))
                case let .withAttachBot(attachBotStart):
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), attachBotStart: attachBotStart))
                default:
                    break
                }
            }, sendFile: nil,
        sendSticker: { _, _, _ in
            return false
        }, requestMessageActionUrlAuth: nil,
        joinVoiceChat: { peerId, invite, call in
            
        }, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, contentContext: nil)
    }
    
    private func openUrl(url: String, concealed: Bool, external: Bool) {
        openUserGeneratedUrl(context: self.context, peerId: self.peerId, url: url, concealed: concealed, present: { [weak self] c in
            self?.controller?.present(c, in: .window(.root))
        }, openResolved: { [weak self] tempResolved in
            guard let strongSelf = self else {
                return
            }
            
            let result: ResolvedUrl = external ? .externalUrl(url) : tempResolved
            
            strongSelf.context.sharedContext.openResolvedUrl(result, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.controller?.navigationController as? NavigationController, forceExternal: false, openPeer: { peerId, navigation in
                self?.openPeer(peerId: peerId, navigation: navigation)
            }, sendFile: nil,
            sendSticker: nil,
            requestMessageActionUrlAuth: nil,
            joinVoiceChat: { peerId, invite, call in
                
            },
            present: { c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, dismissInput: {
                self?.view.endEditing(true)
            }, contentContext: nil)
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
        switch navigation {
        case .default:
            if let navigationController = self.controller?.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: peerId), keepStack: .always))
            }
        case let .chat(_, subject, peekData):
            if let navigationController = self.controller?.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: peerId), subject: subject, keepStack: .always, peekData: peekData))
            }
        case .info:
            self.resolveUrlDisposable.set((self.context.account.postbox.loadedPeerWithId(peerId)
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                        if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                            (strongSelf.controller?.navigationController as? NavigationController)?.pushViewController(infoController)
                        }
                    }
                }))
        case let .withBotStartPayload(startPayload):
            if let navigationController = self.controller?.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: peerId), botStart: startPayload))
            }
        case let .withAttachBot(attachBotStart):
            if let navigationController = self.controller?.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: peerId), attachBotStart: attachBotStart))
            }
        }
    }
    
    private func openPeerMention(_ name: String, navigation: ChatControllerInteractionNavigateToPeer = .default) {
        let disposable: MetaDisposable
        if let resolvePeerByNameDisposable = self.resolvePeerByNameDisposable {
            disposable = resolvePeerByNameDisposable
        } else {
            disposable = MetaDisposable()
            self.resolvePeerByNameDisposable = disposable
        }
        var resolveSignal = self.context.engine.peers.resolvePeerByName(name: name, ageLimit: 10)
        
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
                    strongSelf.openResolved(.peer(peer.id, navigation))
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
            resolveSignal = self.context.engine.peers.resolvePeerByName(name: peerName)
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
    
    private func performButtonAction(key: PeerInfoHeaderButtonKey, gesture: ContextGesture?) {
        guard let controller = self.controller else {
            return
        }
        switch key {
        case .message:
            if let navigationController = controller.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: self.peerId), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
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
                if let navigationController = controller.navigationController as? NavigationController {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: linkedDiscussionPeerId)))
                }
            }
        case .call:
            self.requestCall(isVideo: false)
        case .videoCall:
            self.requestCall(isVideo: true)
        case .voiceChat:
            self.requestCall(isVideo: false, gesture: gesture)
        case .mute:
            if let notificationSettings = self.data?.notificationSettings, case .muted = notificationSettings.muteState {
                let _ = self.context.engine.peers.updatePeerMuteSetting(peerId: self.peerId, muteInterval: nil).start()
                
                let iconColor: UIColor = .white
                self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                        "Middle.Group 1.Fill 1": iconColor,
                        "Top.Group 1.Fill 1": iconColor,
                        "Bottom.Group 1.Fill 1": iconColor,
                        "EXAMPLE.Group 1.Fill 1": iconColor,
                        "Line.Group 1.Stroke 1": iconColor
                ], title: nil, text: self.presentationData.strings.PeerInfo_TooltipUnmuted), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
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
                    }, action: { c, _ in
                        c.popItems()
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
                            
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: strongSelf.peerId, muteInterval: value).start()
                            
                            strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_mute_for", scale: 0.066, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedFor(mutedForTimeIntervalString(strings: strongSelf.presentationData.strings, value: value)).string), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        })))
                    }
                    
                    subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_MuteForCustom, icon: { _ in
                        return nil
                    }, action: { _, f in
                        f(.default)
                        
                        self?.openCustomMute()
                    })))
                    
                    c.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                })))
                
                items.append(.separator)
                
                var isSoundEnabled = true
                if let notificationSettings = self.data?.notificationSettings {
                    switch notificationSettings.messageSound {
                    case .none:
                        isSoundEnabled = false
                    default:
                        break
                    }
                }
                
                if !isSoundEnabled {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_EnableSound, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOn"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: strongSelf.peerId, sound: .default).start()
                        
                        strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_sound_on", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipSoundEnabled), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                } else {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_DisableSound, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOff"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: strongSelf.peerId, sound: .none).start()
                        
                        strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_sound_off", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipSoundDisabled), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })))
                }
                
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_NotificationsCustomize, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Customize"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                        return
                    }
                    
                    let context = strongSelf.context
                    let updatePeerSound: (PeerId, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
                        return context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, sound: sound) |> deliverOnMainQueue
                    }
                    
                    let updatePeerNotificationInterval: (PeerId, Int32?) -> Signal<Void, NoError> = { peerId, muteInterval in
                        return context.engine.peers.updatePeerMuteSetting(peerId: peerId, muteInterval: muteInterval) |> deliverOnMainQueue
                    }
                    
                    let updatePeerDisplayPreviews:(PeerId, PeerNotificationDisplayPreviews) -> Signal<Void, NoError> = {
                        peerId, displayPreviews in
                        return context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, displayPreviews: displayPreviews) |> deliverOnMainQueue
                    }
                    
                    let mode: NotificationExceptionMode
                    if let _ = peer as? TelegramUser {
                        mode = .users([:])
                    } else if let _ = peer as? TelegramSecretChat {
                        mode = .users([:])
                    } else if let channel = peer as? TelegramChannel {
                        if case .broadcast = channel.info {
                            mode = .channels([:])
                        } else {
                            mode = .groups([:])
                        }
                    } else {
                        mode = .groups([:])
                    }
                    
                    let exceptionController = notificationPeerExceptionController(context: context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, peer: peer, mode: mode, edit: true, updatePeerSound: { peerId, sound in
                        let _ = (updatePeerSound(peer.id, sound)
                        |> deliverOnMainQueue).start(next: { _ in
                          
                        })
                    }, updatePeerNotificationInterval: { peerId, muteInterval in
                        let _ = (updatePeerNotificationInterval(peerId, muteInterval)
                        |> deliverOnMainQueue).start(next: { _ in
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
                            ], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedForever), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                            }
                        })
                    }, updatePeerDisplayPreviews: { peerId, displayPreviews in
                        let _ = (updatePeerDisplayPreviews(peerId, displayPreviews)
                        |> deliverOnMainQueue).start(next: { _ in

                        })
                    }, removePeerFromExceptions: {
                      
                    }, modifiedPeer: {
                    })
                    exceptionController.navigationPresentation = .modal
                    controller.push(exceptionController)
                })))
                
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_MuteForever, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Muted"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: strongSelf.peerId, muteInterval: Int32.max).start()
                    
                    let iconColor: UIColor = .white
                    strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                        "Middle.Group 1.Fill 1": iconColor,
                        "Top.Group 1.Fill 1": iconColor,
                        "Bottom.Group 1.Fill 1": iconColor,
                        "EXAMPLE.Group 1.Fill 1": iconColor,
                        "Line.Group 1.Stroke 1": iconColor
                ], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedForever), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                })))
                
                self.view.endEditing(true)
                
                if let sourceNode = self.headerNode.buttonNodes[.mute]?.referenceNode {
                    let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
                
                let allHeaderButtons = Set(peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: strongSelf.isOpenedFromChat, isExpanded: false, videoCallsEnabled: strongSelf.videoCallsEnabled, isSecretChat: strongSelf.peerId.namespace == Namespaces.Peer.SecretChat, isContact: strongSelf.data?.isContact ?? false))
                let headerButtons = Set(peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: strongSelf.isOpenedFromChat, isExpanded: true, videoCallsEnabled: strongSelf.videoCallsEnabled, isSecretChat: strongSelf.peerId.namespace == Namespaces.Peer.SecretChat, isContact: strongSelf.data?.isContact ?? false))
                
                let filteredButtons = allHeaderButtons.subtracting(headerButtons)
                
                var canChangeColors = false
                if let peer = peer as? TelegramUser, peer.botInfo == nil && strongSelf.data?.encryptionKeyFingerprint == nil {
                    canChangeColors = true
                }
                
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
                    if case .creator = group.role {
                        canSetupAutoremoveTimeout = true
                    } else if case let .admin(rights, _) = group.role {
                        if rights.rights.contains(.canDeleteMessages) {
                            canSetupAutoremoveTimeout = true
                        }
                    }
                } else if let user = chatPeer as? TelegramUser {
                    if user.id != strongSelf.context.account.peerId && user.botInfo == nil {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let channel = chatPeer as? TelegramChannel {
                    if channel.hasPermission(.deleteAllMessages) {
                        canSetupAutoremoveTimeout = true
                    }
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
                        }, action: { c, _ in
                            c.popItems()
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
                        
                        subItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_AutoDeleteInfo, textLayout: .multiline, textFont: .small, icon: { _ in
                            return nil
                        }, action: nil as ((ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
                        
                        c.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                    })))
                    items.append(.separator)
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
                    if let _ = user.botInfo {
                        if user.username != nil {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_ShareBot, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak self] _, f in
                                f(.dismissWithoutContent)
                                self?.openShareBot()
                            })))
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
                                } else if command.text == "privacy" {
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
                    
                    if user.botInfo == nil && data.isContact {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Profile_ShareContactButton, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            if let strongSelf = self, let peer = strongSelf.data?.peer as? TelegramUser, let phone = peer.phone {
                                let contact = TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)
                                let shareController = ShareController(context: strongSelf.context, subject: .media(.standalone(media: contact)), updatedPresentationData: strongSelf.controller?.updatedPresentationData)
                                shareController.completed = { [weak self] peerIds in
                                    if let strongSelf = self {
                                        let _ = (strongSelf.context.engine.data.get(
                                            EngineDataList(
                                                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                            )
                                        )
                                        |> deliverOnMainQueue).start(next: { [weak self] peerList in
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
                                            
                                            strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                        })
                                    }
                                }
                                strongSelf.controller?.present(shareController, in: .window(.root))
                            }
                        })))
                    }
                    
                    if canChangeColors {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_ChangeColors, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openChatForThemeChange()
                        })))
                    }
                                       
                    if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser && user.botInfo == nil && !user.flags.contains(.isSupport) {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_StartSecretChat, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Lock"), color: theme.contextMenu.primaryColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openStartSecretChat()
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: user, chatPeer: user, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        if strongSelf.peerId.namespace == Namespaces.Peer.CloudUser {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                            }, action: { c, _ in
                                self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: user, chatPeer: user)
                            })))
                        }
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
                } else if let channel = peer as? TelegramChannel {
                    if let cachedData = strongSelf.data?.cachedData as? CachedChannelData, cachedData.flags.contains(.canViewStats) {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChannelInfo_Stats, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, f in
                            f(.dismissWithoutContent)
                            
                            self?.openStats()
                        })))
                    }
                    
                    var canReport = true
                    if channel.isVerified {
                        canReport = false
                    }
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
                            self?.openReport(user: false, contextController: c, backAction: { c in
                                if let mainItemsImpl = mainItemsImpl {
                                    c.setItems(mainItemsImpl() |> map { ContextController.Items(content: .list($0)) }, minHeight: nil)
                                }
                            })
                        })))
                    }
                    
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: channel, chatPeer: channel, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: channel, chatPeer: channel)
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
                    let clearPeerHistory = ClearPeerHistory(context: strongSelf.context, peer: group, chatPeer: group, cachedData: strongSelf.data?.cachedData)
                    if clearPeerHistory.canClearForMyself != nil || clearPeerHistory.canClearForEveryone != nil {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.PeerInfo_ClearMessages, icon: { theme in
                            generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ClearMessages"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            self?.openClearHistory(contextController: c, clearPeerHistory: clearPeerHistory, peer: group, chatPeer: group)
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
                let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
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
            self.updateBlocked(block: true)
        }
    }
    
    private func openChatWithMessageSearch() {
        if let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: self.peerId), keepStack: self.nearbyPeerDistance != nil ? .always : .default, activateMessageSearch: (.everything, ""), peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
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
    
    private func openChatForReporting(_ reason: ReportReason) {
        if let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: self.peerId), keepStack: .default, reportReason: reason, completion: { _ in
            }))
        }
    }
    
    private func openChatForThemeChange() {
        if let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: self.peerId), keepStack: .default, changeColors: true, completion: { _ in
            }))
        }
    }
    
    private func openAutoremove(currentValue: Int32?) {
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, style: .default, mode: .autoremove, currentTime: currentValue, dismissByTapOutside: true, completion: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: strongSelf.peerId, timeout: value == 0 ? nil : value)
            |> deliverOnMainQueue).start(completed: {
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
                    strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
            })
        })
        self.controller?.view.endEditing(true)
        self.controller?.present(controller, in: .window(.root))
    }
    
    private func openCustomMute() {
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, style: .default, mode: .mute, currentTime: nil, dismissByTapOutside: true, completion: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if value <= 0 {
                let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: strongSelf.peerId, muteInterval: nil).start()
            } else {
                let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: strongSelf.peerId, muteInterval: value).start()
                
                let timeString = stringForPreciseRelativeTimestamp(strings: strongSelf.presentationData.strings, relativeTimestamp: Int32(Date().timeIntervalSince1970) + value, relativeTo: Int32(Date().timeIntervalSince1970), dateTimeFormat: strongSelf.presentationData.dateTimeFormat)
                
                strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .universal(animation: "anim_mute_for", scale: 0.056, colors: [:], title: nil, text: strongSelf.presentationData.strings.PeerInfo_TooltipMutedUntil(timeString).string), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            }
        })
        self.controller?.view.endEditing(true)
        self.controller?.present(controller, in: .window(.root))
    }
    
    private func setAutoremove(timeInterval: Int32?) {
        let _ = (self.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: self.peerId, timeout: timeInterval)
        |> deliverOnMainQueue).start(completed: { [weak self] in
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
                strongSelf.controller?.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text), elevatedLayout: false, action: { _ in return false }), in: .current)
            }
        })
    }
    
    private func openStartSecretChat() {
        let peerId = self.peerId
        
        let _ = (combineLatest(
            self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.peerId)),
            self.context.engine.peers.mostRecentSecretChat(id: self.peerId)
        )
        |> deliverOnMainQueue).start(next: { [weak self] peer, currentPeerId in
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
                    if let navigationController = (strongSelf.controller?.navigationController as? NavigationController) {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId)))
                    }
                }, error: { error in
                    guard let strongSelf = self else {
                        return
                    }
                    let text: String
                    switch error {
                        case .limitExceeded:
                            text = strongSelf.presentationData.strings.TwoStepAuth_FloodError
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
        }, action: { c, _ in
            c.popItems()
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
        }, action: nil as ((ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void)?)))
        
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
        
        if let _ = clearPeerHistory.canClearForMyself {
            let text: String = self.presentationData.strings.Conversation_DeleteMessagesForMe
            
            subItems.append(.action(ContextMenuActionItem(text: text, textColor: .destructive, icon: { _ in
                return nil
            }, action: { _, f in
                f(.default)
                
                beginClear(.forLocalPeer)
            })))
        }
        
        contextController.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
    }
    
    private func openUsername(value: String) {
        let shareController = ShareController(context: self.context, subject: .url("https://t.me/\(value)"), updatedPresentationData: self.controller?.updatedPresentationData)
        shareController.completed = { [weak self] peerIds in
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.engine.data.get(
                EngineDataList(
                    peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                )
            )
            |> deliverOnMainQueue).start(next: { [weak self] peerList in
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
                
                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            })
        }
        shareController.actionCompleted = { [weak self] in
            if let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }
        }
        self.view.endEditing(true)
        self.controller?.present(shareController, in: .window(.root))
    }
    
    private func requestCall(isVideo: Bool, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil, result: ((ContextMenuActionResult) -> Void)? = nil, backAction: ((ContextControllerProtocol) -> Void)? = nil) {
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
        self.context.scheduleGroupCall(peerId: self.peerId)
    }
    
    private func createExternalStream(credentialsPromise: Promise<GroupCallStreamCredentials>?) {
        self.controller?.push(CreateExternalMediaStreamScreen(context: self.context, peerId: self.peerId, credentialsPromise: credentialsPromise, mode: .create))
    }
    
    private func createAndJoinGroupCall(peerId: PeerId, joinAsPeerId: PeerId?) {
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
    
    private func openPhone(value: String) {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            if case let .user(peer) = peer, let peerPhoneNumber = peer.phone, formatPhoneNumber(value) == formatPhoneNumber(peerPhoneNumber) {
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                let dismissAction: () -> Void = { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                }
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.UserInfo_TelegramCall, action: {
                            dismissAction()
                            self?.requestCall(isVideo: false)
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.UserInfo_PhoneCall, action: {
                            dismissAction()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(value).replacingOccurrences(of: " ", with: ""))")
                        }),
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                strongSelf.view.endEditing(true)
                strongSelf.controller?.present(actionSheet, in: .window(.root))
            } else {
                strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(value).replacingOccurrences(of: " ", with: ""))")
            }
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
        |> deliverOnMainQueue).start(next: { [weak self] settings, notificationSoundList in
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
                    let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: strongSelf.peerId, sound: sound).start()
                })
                soundController.navigationPresentation = .modal
                strongSelf.controller?.push(soundController)
            }, updateSettings: { value in
                guard let strongSelf = self else {
                    return
                }
                let _ = strongSelf.context.engine.peers.updatePeerMuteSetting(peerId: strongSelf.peerId, muteInterval: value).start()
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
        |> deliverOnMainQueue).start(next: { [weak self] peerSettings, globalSettings in
            guard let strongSelf = self else {
                return
            }
            
            let soundController = notificationSoundSelectionController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData, isModal: true, currentSound: peerSettings.messageSound._asMessageSound(), defaultSound: globalSettings.groupChats.sound._asMessageSound(), completion: { sound in
                guard let strongSelf = self else {
                    return
                }
                let _ = strongSelf.context.engine.peers.updatePeerNotificationSoundInteractive(peerId: strongSelf.peerId, sound: sound).start()
            })
            strongSelf.controller?.push(soundController)
        })
    }
    
    private func editingToggleShowMessageText(value: Bool) {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            let _ = strongSelf.context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peer.id, displayPreviews: value ? .show : .hide).start()
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
                    |> deliverOnMainQueue).start(next: { peer in
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
                        |> deliverOnMainQueue).start(completed: { [weak self] in
                            if let strongSelf = self, let peer = strongSelf.data?.peer {
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                let controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.Conversation_DeletedFromContacts(EnginePeer(peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).string), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false })
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
    
    private func openChat() {
        if let navigationController = self.controller?.navigationController as? NavigationController {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: self.peerId), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), completion: { [weak self] _ in
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
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: self.peerId), keepStack: self.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: self.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0) }), setupController: { controller in
            (controller as? ChatControllerImpl)?.beginClearHistory(type: type)
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
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            openAddPersonContactImpl(context: strongSelf.context, peerId: peer.id, pushController: { c in
                self?.controller?.push(c)
            }, present: { c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            })
        })
    }
    
    private func updateBlocked(block: Bool) {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            
            let presentationData = strongSelf.presentationData
            if case let .user(peer) = peer, let _ = peer.botInfo {
                strongSelf.activeActionDisposable.set(strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: block).start())
                if !block {
                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)]).start()
                    if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peer.id)))
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
                                
                                strongSelf.activeActionDisposable.set(strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: true).start())
                                if deleteChat {
                                    let _ = strongSelf.context.engine.peers.removePeerChat(peerId: strongSelf.peerId, reportChatSpam: reportSpam).start()
                                    (strongSelf.controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
                                } else if reportSpam {
                                    let _ = strongSelf.context.engine.peers.reportPeer(peerId: strongSelf.peerId, reason: .spam, message: "").start()
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
                        strongSelf.activeActionDisposable.set(strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: block).start())
                    })]), in: .window(.root))
                }
            }
        })
    }
    
    private func openStats() {
        guard let controller = self.controller, let data = self.data, let peer = data.peer, let cachedData = data.cachedData else {
            return
        }
        self.view.endEditing(true)
        
        var statsDatacenterId: Int32?
        if let cachedData = cachedData as? CachedChannelData {
            statsDatacenterId = cachedData.statsDatacenterId
        }
        
        let statsController: ViewController
        if let channel = peer as? TelegramChannel, case .group = channel.info {
            statsController = groupStatsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, statsDatacenterId: statsDatacenterId)
        } else {
            statsController = channelStatsController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id, statsDatacenterId: statsDatacenterId)
        }
        controller.push(statsController)
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
        }).start(next: { [weak self] peers in
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
                            let _ = context.engine.calls.updateGroupCallJoinAsPeer(peerId: peerId, joinAs: joinAsPeerId).start()
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
                if channel.flags.contains(.isCreator) {
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
                contextController.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil)
            } else {
                strongSelf.state = strongSelf.state.withHighlightedButton(.voiceChat)
                if let (layout, navigationHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
                
                if let sourceNode = strongSelf.headerNode.buttonNodes[.voiceChat]?.referenceNode, let controller = strongSelf.controller {
                    let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
        }).start(next: { [weak self] peers in
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
                    }, action: { (c, _) in
                        if let backAction = backAction {
                            backAction(c)
                        }
                    })))
                }
                
                if let contextController = contextController {
                    contextController.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil)
                } else {
                    strongSelf.state = strongSelf.state.withHighlightedButton(.voiceChat)
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                    }
                    
                    if let sourceNode = strongSelf.headerNode.buttonNodes[.voiceChat]?.referenceNode, let controller = strongSelf.controller {
                        let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
    
    private func openReport(user: Bool, contextController: ContextControllerProtocol?, backAction: ((ContextControllerProtocol) -> Void)?) {
        guard let controller = self.controller else {
            return
        }
        self.view.endEditing(true)
        
        let options: [PeerReportOption]
        if user {
            options = [.spam, .fake, .violence, .pornography, .childAbuse]
        } else {
            options = [.spam, .fake, .violence, .pornography, .childAbuse, .copyright, .other]
        }
        
        presentPeerReportOptions(context: self.context, parent: controller, contextController: contextController, backAction: backAction, subject: .peer(self.peerId), options: options, passthrough: true, completion: { [weak self] reason, _ in
            if let reason = reason {
                DispatchQueue.main.async {
                    self?.openChatForReporting(reason)
                }
            }
        })
    }
    
    private func openEncryptionKey() {
        guard let data = self.data, let peer = data.peer, let encryptionKeyFingerprint = data.encryptionKeyFingerprint else {
            return
        }
        self.controller?.push(SecretChatKeyController(context: self.context, fingerprint: encryptionKeyFingerprint, peer: peer))
    }
    
    private func openShareBot() {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            if case let .user(peer) = peer, let username = peer.username {
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
                    |> deliverOnMainQueue).start(next: { [weak self] peerList in
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
                        
                        strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })
                }
                shareController.actionCompleted = { [weak self] in
                    if let strongSelf = self {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
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
        self.context.sharedContext.openResolvedUrl(.groupBotStart(peerId: peerId, payload: "", adminRights: nil), context: self.context, urlContext: .generic, navigationController: controller.navigationController as? NavigationController, forceExternal: false, openPeer: { id, navigation in
        }, sendFile: nil,
        sendSticker: nil,
        requestMessageActionUrlAuth: nil,
        joinVoiceChat: nil,
        present: { [weak controller] c, a in
            controller?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak controller] in
            controller?.view.endEditing(true)
        }, contentContext: nil)
    }
    
    private func performBotCommand(command: PeerInfoBotCommand) {
        let _ = (self.context.account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
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
            let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)]).start()
            
            if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: strongSelf.peerId)))
            }
        })
    }
    
    private func editingOpenPublicLinkSetup() {
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
    
    private func editingOpenInviteLinksSetup() {
        self.controller?.push(inviteLinkListController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: self.peerId, admin: nil))
    }
    
    private func editingOpenDiscussionGroupSetup() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        self.controller?.push(channelDiscussionGroupSetupController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id))
    }
    
    private func editingOpenReactionsSetup() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        self.controller?.push(peerAllowedReactionListController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, peerId: peer.id))
    }
    
    private func editingToggleMessageSignatures(value: Bool) {
        self.toggleShouldChannelMessagesSignaturesDisposable.set(self.context.engine.peers.toggleShouldChannelMessagesSignatures(peerId: self.peerId, enabled: value).start())
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
        guard let data = self.data, let peer = data.peer, let cachedData = data.cachedData as? CachedChannelData, let location = cachedData.peerGeoLocation else {
            return
        }
        let context = self.context
        let presentationData = self.presentationData
        let map = TelegramMediaMap(latitude: location.latitude, longitude: location.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: MapVenue(title: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), address: location.address, provider: nil, id: nil, type: nil), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)
        
        let controllerParams = LocationViewParams(sendLiveLocation: { _ in
        }, stopLiveLocation: { _ in
        }, openUrl: { url in
            context.sharedContext.applicationBindings.openUrl(url)
        }, openPeer: { _ in
        }, showAll: false)
        
        let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer, text: "", attributes: [], media: [map], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let controller = LocationViewController(context: context, updatedPresentationData: self.controller?.updatedPresentationData, subject: message, params: controllerParams)
        self.controller?.push(controller)
    }
    
    private func editingOpenSetupLocation() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        
        let controller = LocationPickerController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, mode: .pick, completion: { [weak self] location, address in
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
            |> deliverOnMainQueue).start()
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
            if case let .channelMember(channelMember) = member {
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
            if case let .channelMember(channelMember) = member {
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
        }
    }
    
    private func openPeerInfoContextMenu(subject: PeerInfoContextSubject, sourceNode: ASDisplayNode) {
        guard let data = self.data, let peer = data.peer, let controller = self.controller else {
            return
        }
        let context = self.context
        switch subject {
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
                |> deliverOnMainQueue).start(next: { [weak self] sharedData in
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
                            
                            let controller = TranslateScreen(context: context, text: text, fromLanguage: language)
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
                    
                    let contextMenuController = ContextMenuController(actions: actions)
                    controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                        if let controller = self?.controller, let sourceNode = sourceNode {
                            return (sourceNode, sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0), controller.displayNode, controller.view.bounds)
                        } else {
                            return nil
                        }
                    }))
                })
            }
        case let .phone(phone):
            let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = phone
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })])
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    return (sourceNode, sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0), controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        case .link:
            if let addressName = peer.addressName {
                let text: String
                let content: UndoOverlayContent
                if peer is TelegramChannel {
                    text = "https://t.me/\(addressName)"
                    content = .linkCopied(text: self.presentationData.strings.Conversation_LinkCopied)
                } else {
                    text = "@" + addressName
                    content = .copy(text: self.presentationData.strings.Conversation_UsernameCopied)
                }
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                    UIPasteboard.general.string = text
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                })])
                controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                    if let controller = self?.controller, let sourceNode = sourceNode {
                        return (sourceNode, sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0), controller.displayNode, controller.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
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
        |> deliverOnMainQueue).start(next: { [weak self] peer in
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
                    ActionSheetTextItem(title: title),
                    ActionSheetButtonItem(title: text, color: .destructive, action: {
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
        |> deliverOnMainQueue).start(next: { [weak self] peer in
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
    
    private func deleteProfilePhoto(_ item: PeerInfoAvatarListItem) {
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
    
    private func updateProfilePhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return
        }
        
        if self.headerNode.isAvatarExpanded {
            self.headerNode.ignoreCollapse = true
            self.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
            self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
        }
        self.scrollNode.view.setContentOffset(CGPoint(), animated: false)
        
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil)
        
        self.state = self.state.withUpdatingAvatar(.image(representation))
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
        }
        self.headerNode.ignoreCollapse = false
        
        let postbox = self.context.account.postbox
        let signal = self.isSettings ? self.context.engine.accountData.updateAccountPhoto(resource: resource, videoResource: nil, videoStartTimestamp: nil, mapResourceToAvatarSizes: { resource, representations in
            return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
        }) : self.context.engine.peers.updatePeerPhoto(peerId: self.peerId, photo: self.context.engine.peers.uploadedPeerPhoto(resource: resource), mapResourceToAvatarSizes: { resource, representations in
            return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
        })
        self.updateAvatarDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
                case .complete:
                    strongSelf.state = strongSelf.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)
                case let .progress(value):
                    strongSelf.state = strongSelf.state.withAvatarUploadProgress(CGFloat(value))
            }
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
        }))
    }
              
    private func updateProfileVideo(_ image: UIImage, asset: Any?, adjustments: TGVideoEditAdjustments?) {
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return
        }
        
        if self.headerNode.isAvatarExpanded {
            self.headerNode.ignoreCollapse = true
            self.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
            self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
        }
        self.scrollNode.view.setContentOffset(CGPoint(), animated: false)
        
        let photoResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        self.context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil)
        
        self.state = self.state.withUpdatingAvatar(.image(representation))
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
        }
        self.headerNode.ignoreCollapse = false
        
        var videoStartTimestamp: Double? = nil
        if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
            videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
        }
        
        let account = self.context.account
        let context = self.context
        let signal = Signal<TelegramMediaResource, UploadPeerPhotoError> { [weak self] subscriber in
            let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                    return LegacyPaintEntityRenderer(account: account, adjustments: adjustments)
                } else {
                    return nil
                }
            }
            let uploadInterface = LegacyLiveUploadInterface(context: context)
            let signal: SSignal
            if let asset = asset as? AVAsset {
                signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, watcher: uploadInterface, entityRenderer: entityRenderer)!
            } else if let url = asset as? URL, let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
                let durationSignal: SSignal = SSignal(generator: { subscriber in
                    let disposable = (entityRenderer.duration()).start(next: { duration in
                        subscriber.putNext(duration)
                        subscriber.putCompletion()
                    })
                    
                    return SBlockDisposable(block: {
                        disposable.dispose()
                    })
                })
                signal = durationSignal.map(toSignal: { duration -> SSignal in
                    if let duration = duration as? Double {
                        return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, watcher: nil, entityRenderer: entityRenderer)!
                    } else {
                        return SSignal.single(nil)
                    }
                })
               
            } else {
                signal = SSignal.complete()
            }
            
            let signalDisposable = signal.start(next: { next in
                if let result = next as? TGMediaVideoConversionResult {
                    if let image = result.coverImage, let data = image.jpegData(compressionQuality: 0.7) {
                        account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                    }
                    
                    if let timestamp = videoStartTimestamp {
                        videoStartTimestamp = max(0.0, min(timestamp, result.duration - 0.05))
                    }
                    
                    var value = stat()
                    if stat(result.fileURL.path, &value) == 0 {
                        if let data = try? Data(contentsOf: result.fileURL) {
                            let resource: TelegramMediaResource
                            if let liveUploadData = result.liveUploadData as? LegacyLiveUploadInterfaceResult {
                                resource = LocalFileMediaResource(fileId: liveUploadData.id)
                            } else {
                                resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                            }
                            account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                            subscriber.putNext(resource)
                        }
                    }
                    subscriber.putCompletion()
                } else if let strongSelf = self, let progress = next as? NSNumber {
                    Queue.mainQueue().async {
                        strongSelf.state = strongSelf.state.withAvatarUploadProgress(CGFloat(progress.floatValue * 0.25))
                        if let (layout, navigationHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                        }
                    }
                }
            }, error: { _ in
            }, completed: nil)
            
            let disposable = ActionDisposable {
                signalDisposable?.dispose()
            }
            
            return ActionDisposable {
                disposable.dispose()
            }
        }
        
        let peerId = self.peerId
        let isSettings = self.isSettings
        self.updateAvatarDisposable.set((signal
        |> mapToSignal { videoResource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
            if isSettings {
                return context.engine.accountData.updateAccountPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            } else {
                return context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: photoResource), video: context.engine.peers.uploadedPeerVideo(resource: videoResource) |> map(Optional.init), videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
                case .complete:
                    strongSelf.state = strongSelf.state.withUpdatingAvatar(nil).withAvatarUploadProgress(nil)
                case let .progress(value):
                    strongSelf.state = strongSelf.state.withAvatarUploadProgress(CGFloat(0.25 + value * 0.75))
            }
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
        }))
    }
    
    private func openAvatarForEditing(fromGallery: Bool = false, completion: @escaping () -> Void = {}) {
        guard let peer = self.data?.peer, canEditPeerInfo(context: self.context, peer: peer) else {
            return
        }
        
        var currentIsVideo = false
        let item = self.headerNode.avatarListNode.listContainerNode.currentItemNode?.item
        if let item = item, case let .image(_, _, videoRepresentations, _) = item {
            currentIsVideo = !videoRepresentations.isEmpty
        }
        
        let peerId = self.peerId
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.Configuration.SearchBots()
        )
        |> deliverOnMainQueue).start(next: { [weak self] peer, searchBotsConfiguration in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            
            let presentationData = strongSelf.presentationData
            
            let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
            legacyController.statusBar.statusBarStyle = .Ignore
            
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
            
            legacyController.bind(controller: navigationController)
            
            strongSelf.view.endEditing(true)
            strongSelf.controller?.present(legacyController, in: .window(.root))
            
            var hasPhotos = false
            if !peer.profileImageRepresentations.isEmpty {
                hasPhotos = true
            }
            
            let paintStickersContext = LegacyPaintStickersContext(context: strongSelf.context)
            paintStickersContext.presentStickersController = { completion in
                let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                    let coder = PostboxEncoder()
                    coder.encodeRootObject(fileReference.media)
                    completion?(coder.makeData(), fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                    return true
                })
                strongSelf.controller?.present(controller, in: .window(.root))
                return controller
            }
            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasPhotos && !fromGallery, hasViewButton: false, personalPhoto: strongSelf.isSettings, isVideo: currentIsVideo, saveEditedPhotos: false, saveCapturedMedia: false, signup: false)!
            mixin.stickersContext = paintStickersContext
            let _ = strongSelf.currentAvatarMixin.swap(mixin)
            mixin.requestSearchController = { [weak self] assetsController in
                guard let strongSelf = self else {
                    return
                }
                let controller = WebSearchController(context: strongSelf.context, updatedPresentationData: strongSelf.controller?.updatedPresentationData,  peer: peer, chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: strongSelf.isSettings ? nil : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), completion: { [weak self] result in
                    assetsController?.dismiss()
                    self?.updateProfilePhoto(result)
                }))
                controller.navigationPresentation = .modal
                strongSelf.controller?.push(controller)
                
                if fromGallery {
                    completion()
                }
            }
            mixin.didFinishWithImage = { [weak self] image in
                if let image = image {
                    completion()
                    self?.updateProfilePhoto(image)
                }
            }
            mixin.didFinishWithVideo = { [weak self] image, asset, adjustments in
                if let image = image, let asset = asset {
                    completion()
                    self?.updateProfileVideo(image, asset: asset, adjustments: adjustments)
                }
            }
            mixin.didFinishWithDelete = {
                guard let strongSelf = self else {
                    return
                }
                
                let proceed = {
                    if let item = item {
                        strongSelf.deleteProfilePhoto(item)
                    }
                    
                    let _ = strongSelf.currentAvatarMixin.swap(nil)
                    if let _ = peer.smallProfileImage {
                        strongSelf.state = strongSelf.state.withUpdatingAvatar(nil)
                        if let (layout, navigationHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                        }
                    }
                    let postbox = strongSelf.context.account.postbox
                    strongSelf.updateAvatarDisposable.set((strongSelf.context.engine.peers.updatePeerPhoto(peerId: strongSelf.peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                    })
                    |> deliverOnMainQueue).start(next: { result in
                        guard let strongSelf = self else {
                            return
                        }
                        switch result {
                        case .complete:
                            strongSelf.state = strongSelf.state.withUpdatingAvatar(nil)
                            if let (layout, navigationHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                            }
                        case .progress:
                            break
                        }
                    }))
                }
                
                let actionSheet = ActionSheetController(presentationData: presentationData)
                let items: [ActionSheetItem] = [
                    ActionSheetButtonItem(title: presentationData.strings.Settings_RemoveConfirmation, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        proceed()
                    })
                ]
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.controller?.present(actionSheet, in: .window(.root))
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
        guard let data = self.data, let groupPeer = data.peer, let controller = self.controller else {
            return
        }
        
        presentAddMembers(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, parentController: controller, groupPeer: groupPeer, selectAddMemberDisposable: self.selectAddMemberDisposable, addMemberDisposable: self.addMemberDisposable)
    }
    
    private func openQrCode() {
        guard let data = self.data, let peer = data.peer, let controller = self.controller else {
            return
        }

        controller.present(ChatQrCodeScreen(context: self.context, subject: .peer(peer)), in: .window(.root))
    }
    
    fileprivate func openSettings(section: PeerInfoSettingsSection) {
        let push: (ViewController) -> Void = { [weak self] c in
            guard let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController else {
                return
            }
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
        switch section {
            case .avatar:
                self.openAvatarForEditing()
            case .edit:
                self.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
            case .proxy:
                self.controller?.push(proxySettingsController(context: self.context))
            case .savedMessages:
                if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: self.context.account.peerId)))
                }
            case .recentCalls:
                push(CallListController(context: context, mode: .navigation))
            case .devices:
                let _ = (self.activeSessionsContextAndCount.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] activeSessionsContextAndCount in
                    if let strongSelf = self, let activeSessionsContextAndCount = activeSessionsContextAndCount {
                        let (activeSessionsContext, _, webSessionsContext) = activeSessionsContextAndCount
                        push(recentSessionsController(context: strongSelf.context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext, websitesOnly: false))
                    }
                })
            case .chatFolders:
                push(chatListFilterPresetListController(context: self.context, mode: .default))
            case .notificationsAndSounds:
                if let settings = self.data?.globalSettings {
                    push(notificationsAndSoundsController(context: self.context, exceptionsList: settings.notificationExceptions))
                }
            case .privacyAndSecurity:
                if let settings = self.data?.globalSettings {
                    let _ = (combineLatest(self.blockedPeers.get(), self.hasTwoStepAuth.get())
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] blockedPeersContext, hasTwoStepAuth in
                        if let strongSelf = self {
                            push(privacyAndSecurityController(context: strongSelf.context, initialSettings: settings.privacySettings, updatedSettings: { [weak self] settings in
                                self?.privacySettings.set(.single(settings))
                            }, updatedBlockedPeers: { [weak self] blockedPeersContext in
                                self?.blockedPeers.set(.single(blockedPeersContext))
                            }, updatedHasTwoStepAuth: { [weak self] hasTwoStepAuthValue in
                                self?.hasTwoStepAuth.set(.single(hasTwoStepAuthValue))
                            }, focusOnItemTag: nil, activeSessionsContext: settings.activeSessionsContext, webSessionsContext: settings.webSessionsContext, blockedPeersContext: blockedPeersContext, hasTwoStepAuth: hasTwoStepAuth))
                        }
                    })
                }
            case .dataAndStorage:
                push(dataAndStorageController(context: self.context))
            case .appearance:
                push(themeSettingsController(context: self.context))
            case .language:
                push(LocalizationListController(context: self.context))
            case .premium:
                self.controller?.push(PremiumIntroScreen(context: self.context, modal: false, source: .settings))
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
                    self?.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peerId in
                        if let strongSelf = self, let peerId = peerId {
                            push(strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(previewing: false)))
                        }
                    }))
                })]), in: .window(.root))
            case .faq:
                self.openFaq()
            case .tips:
                self.openTips()
            case .phoneNumber:
                if let user = self.data?.peer as? TelegramUser, let phoneNumber = user.phone {
                    let introController = PrivacyIntroController(context: self.context, mode: .changePhoneNumber(phoneNumber), proceedAction: { [weak self] in
                        if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                            navigationController.replaceTopController(ChangePhoneNumberController(context: strongSelf.context), animated: true)
                        }
                    })
                    push(introController)
                }
            case .username:
                push(usernameSetupController(context: self.context))
            case .addAccount:
                let _ = (activeAccountsAndPeers(context: context)
                |> take(1)
                |> deliverOnMainQueue
                ).start(next: { [weak self] accountAndPeer, accountsAndPeers in
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
                    let _ = dismissServerProvidedSuggestion(account: context.account, suggestion: .validatePassword).start()
                }
                push(controller)
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
                strongSelf.context.sharedContext.openResolvedUrl(resolvedUrl, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.controller?.navigationController as? NavigationController, forceExternal: false, openPeer: { peer, navigation in
                }, sendFile: nil, sendSticker: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { [weak self] controller, arguments in
                    self?.controller?.push(controller)
                }, dismissInput: {}, contentContext: nil)
            }
        })
    }
    
    private func openTips() {
        let controller = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: nil))
        self.controller?.present(controller, in: .window(.root))
        
        let context = self.context
        let navigationController = self.controller?.navigationController as? NavigationController
        self.tipsPeerDisposable.set((self.context.engine.peers.resolvePeerByName(name: self.presentationData.strings.Settings_TipsUsername) |> deliverOnMainQueue).start(next: { [weak controller] peer in
            controller?.dismiss()
            if let peer = peer, let navigationController = navigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peer.id)))
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
                let _ = logoutFromAccount(id: id, accountManager: strongSelf.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
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
                    |> deliverOnMainQueue).start(completed: {
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
        |> deliverOnMainQueue).start(next: { accountsAndPeers in
            for (account, _, _) in accountsAndPeers {
                if account.account.id == id {
                    selectedAccount = account.account
                    break
                }
            }
        })
        if let selectedAccount = selectedAccount {
            let accountContext = self.context.sharedContext.makeTempAccountContext(account: selectedAccount)
            let chatListController = accountContext.sharedContext.makeChatListController(context: accountContext, groupId: .root, controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                    
            let contextController = ContextController(account: accountContext.account, presentationData: self.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node)), items: accountContextMenuItems(context: accountContext, logout: { [weak self] in
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
            self.activeActionDisposable.set((self.context.sharedContext.chatAvailableMessageActions(engine: self.context.engine, accountPeerId: self.context.account.peerId, messageIds: messageIds)
            |> deliverOnMainQueue).start(next: { [weak self] actions in
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
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
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
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).start()
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
            let peerSelectionController = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, filter: [.onlyWriteable, .excludeDisabled], multipleSelection: true))
            peerSelectionController.multiplePeersSelected = { [weak self, weak peerSelectionController] peers, peerMap, messageText, mode, forwardOptions in
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
                            result.append(.message(text: text.string, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
                        }
                    }
                }
                
                var attributes: [MessageAttribute] = []
                attributes.append(ForwardOptionsMessageAttribute(hideNames: forwardOptions?.hideNames == true, hideCaptions: forwardOptions?.hideCaptions == true))
                
                result.append(contentsOf: messageIds.map { messageId -> EnqueueMessage in
                    return .forward(source: messageId, grouping: .auto, attributes: attributes, correlationId: nil)
                })
                
                var displayPeers: [Peer] = []
                for peer in peers {
                    let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: result)
                    |> deliverOnMainQueue).start(next: { messageIds in
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
                            |> deliverOnMainQueue).start())
                        }
                    })
                    
                    if let secretPeer = peer as? TelegramSecretChat {
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
                        let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                    } else if displayPeers.count == 2, let firstPeer = displayPeers.first, let secondPeer = displayPeers.last {
                        let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(firstPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(secondPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                    } else if let peer = displayPeers.first {
                        let peerName = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(displayPeers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(displayPeers.count - 1)").string
                    } else {
                        text = ""
                    }
                }

                strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
            }
            peerSelectionController.peerSelected = { [weak self, weak peerSelectionController] peer in
                let peerId = peer.id
                
                if let strongSelf = self, let _ = peerSelectionController {
                    if peerId == strongSelf.context.account.peerId {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: true, text: messageIds.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                        
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                        
                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                            return .forward(source: id, grouping: .auto, attributes: [], correlationId: nil)
                        })
                        |> deliverOnMainQueue).start(next: { [weak self] messageIds in
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
                                |> deliverOnMainQueue).start())
                            }
                        })
                        if let peerSelectionController = peerSelectionController {
                            peerSelectionController.dismiss()
                        }
                    } else {
                        let _ = (ChatInterfaceState.update(engine: strongSelf.context.engine, peerId: peerId, threadId: nil, { currentState in
                            return currentState.withUpdatedForwardMessageIds(Array(messageIds))
                        })
                        |> deliverOnMainQueue).start(completed: {
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone, nil, nil)
                                
                                if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                    let chatController = ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: peerId))
                                    var viewControllers = navigationController.viewControllers
                                    viewControllers.insert(chatController, at: viewControllers.count - 1)
                                    navigationController.setViewControllers(viewControllers, animated: false)
                                    
                                    strongSelf.activeActionDisposable.set((chatController.ready.get()
                                    |> filter { $0 }
                                    |> take(1)
                                    |> deliverOnMainQueue).start(next: { _ in
                                        if let peerSelectionController = peerSelectionController {
                                            peerSelectionController.dismiss()
                                        }
                                    }))
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
                }, resolvedFaqUrl: self.cachedFaq.get(), exceptionsList: .single(settings.notificationExceptions), archivedStickerPacks: .single(settings.archivedStickerPacks), privacySettings: .single(settings.privacySettings), hasTwoStepAuth: self.hasTwoStepAuth.get(), activeSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.0 }, webSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.2 }), cancel: { [weak self] in
                    self?.deactivateSearch()
                })
            }
        } else if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .members = currentPaneKey {
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, hasBackground: true, hasSeparator: true, contentNode: ChannelMembersSearchContainerNode(context: self.context, forceTheme: nil, peerId: self.peerId, mode: .searchMembers, filters: [], searchContext: self.groupMembersSearchContext, openPeer: { [weak self] peer, participant in
                self?.openPeer(peerId: peer.id, navigation: .info)
            }, updateActivity: { _ in
            }, pushController: { [weak self] c in
                self?.controller?.push(c)
            }), cancel: { [weak self] in
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
            
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, hasBackground: true, contentNode: ChatHistorySearchContainerNode(context: self.context, peerId: self.peerId, tagMask: tagMask, interfaceInteraction: self.chatInterfaceInteraction), cancel: { [weak self] in
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
        controller.present(TooltipScreen(account: self.context.account, text: self.presentationData.strings.SharedMedia_CalendarTooltip, style: .default, icon: .none, location: .point(buttonFrame.insetBy(dx: 0.0, dy: 5.0), .top), shouldDismissOnTouch: { point in
            return .dismiss(consume: false)
        }), in: .current)
    }

    private func displayMediaGalleryContextMenu(source: ContextReferenceContentNode, gesture: ContextGesture?) {
        let peerId = self.peerId
        
        let _ = (self.context.engine.data.get(EngineDataMap([
            TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, tag: .photo),
            TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: peerId, tag: .video)
        ]))
        |> deliverOnMainQueue).start(next: { [weak self] messageCounts in
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

            let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceNode: source)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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

                    guard let strongSelf = self, let controller = strongSelf.controller, let navigationController = controller.navigationController as? NavigationController else {
                        return
                    }

                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        chatController: nil,
                        context: strongSelf.context,
                        chatLocation: .peer(id: strongSelf.peerId),
                        subject: .message(id: .id(index.id), highlight: false, timecode: nil),
                        botStart: nil,
                        updateTextInputState: nil,
                        activateInput: false,
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

                let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: strongSelf.peerId), subject: .message(id: .id(index.id), highlight: false, timecode: nil), botStart: nil, mode: .standard(previewing: true))
                chatController.canReadHistory.set(false)
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, sourceRect: sourceRect, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                strongSelf.controller?.presentInGlobalOverlay(contextController)
            }
        )

        self.controller?.push(calendarScreen)
        dismissCalendarScreen = { [weak calendarScreen] in
            calendarScreen?.dismiss(completion: nil)
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
    
        self.updateNavigationExpansionPresentation(isExpanded: self.headerNode.isAvatarExpanded, animated: false)
        
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition, additive: Bool = false) {
        self.validLayout = (layout, navigationHeight)
        
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
        
        var headerHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : self.scrollNode.view.contentOffset.y, paneContainerY: self.paneContainerNode.frame.minY, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, statusData: self.data?.status, panelStatusData: self.customStatusData, isSecretChat: self.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, metrics: layout.metrics, transition: transition, additive: additive)
        if !self.isSettings && !self.state.isEditing {
            headerHeight += 71.0
        }
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
            
            let items = self.isSettings ? settingsItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction, isExpanded: self.headerNode.isAvatarExpanded) : infoItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction, nearbyPeerDistance: self.nearbyPeerDistance, callMessages: self.callMessages)
            
            contentHeight += headerHeight
            if !(self.isSettings && self.state.isEditing) {
                contentHeight += sectionSpacing
            }
              
            for (sectionId, sectionItems) in items {
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
                
                if wasAdded && transition.isAnimated && self.isSettings && !self.state.isEditing {
                    sectionNode.alpha = 0.0
                    transition.updateAlpha(node: sectionNode, alpha: 1.0, delay: 0.1)
                }
                             
                let sectionWidth = layout.size.width - insets.left - insets.right
                let sectionHeight = sectionNode.update(width: sectionWidth, safeInsets: UIEdgeInsets(), hasCorners: !insets.left.isZero, presentationData: self.presentationData, items: sectionItems, transition: transition)
                let sectionFrame = CGRect(origin: CGPoint(x: insets.left, y: contentHeight), size: CGSize(width: sectionWidth, height: sectionHeight))
                if additive {
                    transition.updateFrameAdditive(node: sectionNode, frame: sectionFrame)
                } else {
                    transition.updateFrame(node: sectionNode, frame: sectionFrame)
                }
                
                if wasAdded && transition.isAnimated && self.isSettings && !self.state.isEditing {
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
            let editItems = self.isSettings ? settingsEditingItems(data: self.data, state: self.state, context: self.context, presentationData: self.presentationData, interaction: self.interaction) : editingItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction)

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
                let sectionHeight = sectionNode.update(width: sectionWidth, safeInsets: UIEdgeInsets(), hasCorners: !insets.left.isZero, presentationData: self.presentationData, items: sectionItems, transition: transition)
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
                    |> deliverOnMainQueue).start(next: { messageMap in
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
                    strongSelf.controller?.present(peerReportOptionsController(context: strongSelf.context, subject: .messages(Array(messageIds).sorted()), passthrough: false, present: { c, a in
                        self?.controller?.present(c, in: .window(.root), with: a)
                    }, push: { c in
                        self?.controller?.push(c)
                    }, completion: { _, _ in }), in: .window(.root))
                }, displayCopyProtectionTip: { [weak self] node, save in
                    if let strongSelf = self, let peer = strongSelf.data?.peer, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty {
                        let _ = (strongSelf.context.engine.data.get(EngineDataMap(
                            messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
                        ))
                        |> deliverOnMainQueue).start(next: { [weak self] messageMap in
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
                                    if user.botInfo != nil {
                                        isBot = true
                                    }
                                    break
                                }
                            }
                            let type: PeerType
                            if isBot {
                                type = .bot
                            } else if let user = peer as? TelegramUser {
                                if user.botInfo != nil {
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
            }
            selectionPanelNode.selectionPanel.selectedMessages = selectedMessageIds
            let panelHeight = selectionPanelNode.update(layout: layout, presentationData: self.presentationData, transition: wasAdded ? .immediate : transition)
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: paneContainerSize.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
            if wasAdded {
                selectionPanelNode.frame = panelFrame
                transition.animatePositionAdditive(node: selectionPanelNode, offset: CGPoint(x: 0.0, y: panelHeight))
            } else {
                transition.updateFrame(node: selectionPanelNode, frame: panelFrame)
            }
        } else if let selectionPanelNode = self.paneContainerNode.selectionPanelNode {
            self.paneContainerNode.selectionPanelNode = nil
            transition.updateFrame(node: selectionPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: selectionPanelNode.bounds.size), completion: { [weak selectionPanelNode] _ in
                selectionPanelNode?.removeFromSupernode()
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
        self.updateNavigation(transition: transition, additive: additive)
        
        if !self.didSetReady && self.data != nil {
            self.didSetReady = true
            let avatarReady = self.headerNode.avatarListNode.isReady.get()
            let combinedSignal = combineLatest(queue: .mainQueue(),
                avatarReady,
                self.paneContainerNode.isReady.get()
            )
            |> map { lhs, rhs in
                return lhs && rhs
            }
            self._ready.set(combinedSignal
            |> filter { $0 }
            |> take(1))
        }
    }
        
    fileprivate func updateNavigation(transition: ContainedViewLayoutTransition, additive: Bool) {
        let offsetY = self.scrollNode.view.contentOffset.y
        
        if self.isSettings, !(self.controller?.movingInHierarchy == true) {
            let bottomOffsetY = max(0.0, self.scrollNode.view.contentSize.height + min(83.0, self.scrollNode.view.contentInset.bottom) - offsetY - self.scrollNode.frame.height)
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
            if !additive {
                let sectionInset: CGFloat
                if layout.size.width >= 375.0 {
                    sectionInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
                } else {
                    sectionInset = 0.0
                }
                let headerInset = sectionInset

                let _ = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : offsetY, paneContainerY: self.paneContainerNode.frame.minY, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, statusData: self.data?.status, panelStatusData: self.customStatusData, isSecretChat: self.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, metrics: layout.metrics, transition: transition, additive: additive)
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
                        
            let navigationBarHeight: CGFloat = !self.isSettings && layout.isModalOverlay ? 56.0 : 44.0
            self.paneContainerNode.update(size: self.paneContainerNode.bounds.size, sideInset: layout.safeInsets.left, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: effectiveAreaExpansionFraction, presentationData: self.presentationData, data: self.data, transition: transition)
          
            transition.updateFrame(node: self.headerNode.navigationButtonContainer, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left, y: layout.statusBarHeight ?? 0.0), size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight)))
            self.headerNode.navigationButtonContainer.isWhite = self.headerNode.isAvatarExpanded
            
            var leftNavigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            var rightNavigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            if self.state.isEditing {
                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .done, isForExpandedView: false))
            } else {
                if self.isSettings {
                    leftNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .qrCode, isForExpandedView: false))
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
                } else if peerInfoCanEdit(peer: self.data?.peer, cachedData: self.data?.cachedData, isContact: self.data?.isContact) {
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                }
                if self.state.selectedMessageIds == nil {
                    if let currentPaneKey = self.paneContainerNode.currentPaneKey {
                        switch currentPaneKey {
                        case .files, .music, .links, .members:
                            rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
                        case .media:
                            rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .more, isForExpandedView: true))
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
            self.headerNode.navigationButtonContainer.update(size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight), presentationData: self.presentationData, leftButtons: leftNavigationButtons, rightButtons: rightNavigationButtons, expandFraction: effectiveAreaExpansionFraction, transition: transition)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
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
                if let peer = self.data?.peer, peer.smallProfileImage != nil && self.state.updatingAvatar == nil && !isLandscape {
                    shouldBeExpanded = true
                    
                    if self.canOpenAvatarByDragging && self.headerNode.isAvatarExpanded && offsetY <= -32.0 {
                        if self.hapticFeedback == nil {
                            self.hapticFeedback = HapticFeedback()
                        }
                        self.hapticFeedback?.impact()
                        
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
                
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                if shouldBeExpanded {
                    self.hapticFeedback?.impact()
                } else {
                    self.hapticFeedback?.tap()
                }
                
                self.headerNode.updateIsAvatarExpanded(shouldBeExpanded, transition: transition)
                self.updateNavigationExpansionPresentation(isExpanded: shouldBeExpanded, animated: true)
                
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                }
            }
        }
        
        self.updateNavigation(transition: .immediate, additive: false)
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
    
    private func updateNavigationExpansionPresentation(isExpanded: Bool, animated: Bool) {
        if let controller = self.controller {
            controller.setStatusBarStyle(isExpanded ? .White : self.presentationData.theme.rootController.statusBarStyle.style, animated: animated)
            
            if animated {
                UIView.transition(with: controller.controllerNode.headerNode.navigationButtonContainer.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                }, completion: nil)
            }
            
            let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
            let navigationBarPresentationData = NavigationBarPresentationData(
                theme: NavigationBarTheme(
                    buttonColor: isExpanded ? .white : baseNavigationBarPresentationData.theme.buttonColor,
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
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        if self.state.isEditing {
            if self.isSettings {
                if targetContentOffset.pointee.y < navigationHeight {
                    if targetContentOffset.pointee.y < navigationHeight / 2.0 {
                        targetContentOffset.pointee.y = 0.0
                    } else {
                        targetContentOffset.pointee.y = navigationHeight
                    }
                }
            }
        } else {
            let height: CGFloat = self.isSettings ? 140.0 : 140.0
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
            if !self.isSettings {
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
}

public final class PeerInfoScreenImpl: ViewController, PeerInfoScreen {
    private let context: AccountContext
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let peerId: PeerId
    private let avatarInitiallyExpanded: Bool
    private let isOpenedFromChat: Bool
    private let nearbyPeerDistance: Int32?
    private let callMessages: [Message]
    private let isSettings: Bool
    private let hintGroupInCommon: PeerId?
    private weak var requestsContext: PeerInvitationImportersContext?
    
    fileprivate var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let cachedDataPromise = Promise<CachedPeerData?>()
    
    private let accountsAndPeers = Promise<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)])>()
    private var accountsAndPeersValue: ((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)])?
    private var accountsAndPeersDisposable: Disposable?
    
    private let activeSessionsContextAndCount = Promise<(ActiveSessionsContext, Int, WebSessionsContext)?>(nil)

    private var tabBarItemDisposable: Disposable?

    fileprivate var controllerNode: PeerInfoScreenNode {
        return self.displayNode as! PeerInfoScreenNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    override public var customNavigationData: CustomViewControllerNavigationData? {
        get {
            if !self.isSettings {
                return ChatControllerNavigationData(peerId: self.peerId)
            } else {
                return nil
            }
        }
    }
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peerId: PeerId, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, nearbyPeerDistance: Int32?, callMessages: [Message], isSettings: Bool = false, hintGroupInCommon: PeerId? = nil, requestsContext: PeerInvitationImportersContext? = nil) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.peerId = peerId
        self.avatarInitiallyExpanded = avatarInitiallyExpanded
        self.isOpenedFromChat = isOpenedFromChat
        self.nearbyPeerDistance = nearbyPeerDistance
        self.callMessages = callMessages
        self.isSettings = isSettings
        self.hintGroupInCommon = hintGroupInCommon
        self.requestsContext = requestsContext
        
        self.presentationData = updatedPresentationData?.0 ?? context.sharedContext.currentPresentationData.with { $0 }
        
        let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        super.init(navigationBarPresentationData: NavigationBarPresentationData(
            theme: NavigationBarTheme(
                buttonColor: avatarInitiallyExpanded ? .white : baseNavigationBarPresentationData.theme.buttonColor,
                disabledButtonColor: baseNavigationBarPresentationData.theme.disabledButtonColor,
                primaryTextColor: baseNavigationBarPresentationData.theme.primaryTextColor,
                backgroundColor: .clear,
                enableBackgroundBlur: false,
                separatorColor: .clear,
                badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
        ), strings: baseNavigationBarPresentationData.strings))
                
        if isSettings {
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
            |> deliverOnMainQueue).start(next: { [weak self] value in
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
                                
                                drawPeerAvatarLetters(context: context, size: CGSize(width: size.width - inset * 2.0, height: size.height - inset * 2.0), font: avatarFont, letters: displayLetters, peerId: primary.1.id)
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
            
            let tabBarItem: Signal<(String, UIImage?, UIImage?, String?, Bool), NoError> = combineLatest(queue: .mainQueue(), self.context.sharedContext.presentationData, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get(), getServerProvidedSuggestions(account: self.context.account), accountTabBarAvatar, accountTabBarAvatarBadge)
            |> map { presentationData, notificationsAuthorizationStatus, notificationsWarningSuppressed, suggestions, accountTabBarAvatar, accountTabBarAvatarBadge -> (String, UIImage?, UIImage?, String?, Bool) in
                let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
                let phoneNumberWarning = suggestions.contains(.validatePhoneNumber)
                let passwordWarning = suggestions.contains(.validatePassword)
                var otherAccountsBadge: String?
                if accountTabBarAvatarBadge > 0 {
                    otherAccountsBadge = compactNumericCountString(Int(accountTabBarAvatarBadge), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                }
                return (presentationData.strings.Settings_Title, accountTabBarAvatar?.0 ?? icon, accountTabBarAvatar?.1 ?? icon, notificationsWarning || phoneNumberWarning || passwordWarning ? "!" : otherAccountsBadge, accountTabBarAvatar != nil || presentationData.reduceMotion)
            }
            
            self.tabBarItemDisposable = (tabBarItem |> deliverOnMainQueue).start(next: { [weak self] title, image, selectedImage, badgeValue, isAvatar in
                if let strongSelf = self {
                    strongSelf.tabBarItem.title = title
                    strongSelf.tabBarItem.image = image
                    strongSelf.tabBarItem.selectedImage = selectedImage
                    strongSelf.tabBarItem.animationName = isAvatar ? nil : "TabSettings"
                    strongSelf.tabBarItem.ringSelection = isAvatar
                    strongSelf.tabBarItem.badgeValue = badgeValue
                }
            })
            
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        }
                
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
            if isInteractive && strongSelf.controllerNode.headerNode.isAvatarExpanded {
                return nil
            }
            if other.contentNode != nil {
                return nil
            }
            if let allowsCustomTransition = other.allowsCustomTransition, !allowsCustomTransition() {
                return nil
            }
            if let tag = other.userInfo as? PeerInfoNavigationSourceTag, tag.peerId == peerId {
                return PeerInfoNavigationTransitionNode(screenNode: strongSelf.controllerNode, presentationData: strongSelf.presentationData, headerNode: strongSelf.controllerNode.headerNode)
            }
            return nil
        }
        
        self.setStatusBarStyle(avatarInitiallyExpanded ? .White : self.presentationData.theme.rootController.statusBarStyle.style, animated: false)
        
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
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
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
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.accountsAndPeersDisposable?.dispose()
        self.tabBarItemDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerInfoScreenNode(controller: self, context: self.context, peerId: self.peerId, avatarInitiallyExpanded: self.avatarInitiallyExpanded, isOpenedFromChat: self.isOpenedFromChat, nearbyPeerDistance: self.nearbyPeerDistance, callMessages: self.callMessages, isSettings: self.isSettings, hintGroupInCommon: self.hintGroupInCommon, requestsContext: requestsContext)
        self.controllerNode.accountsAndPeers.set(self.accountsAndPeers.get() |> map { $0.1 })
        self.controllerNode.activeSessionsContextAndCount.set(self.activeSessionsContextAndCount.get())
        self.cachedDataPromise.set(self.controllerNode.cachedDataPromise.get())
        self._ready.set(self.controllerNode.ready.get())
        
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
                self.controllerNode.updateNavigation(transition: .immediate, additive: false)
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
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var chatNavigationStack: [PeerId] = []
        if !self.isSettings, let summary = self.customNavigationDataSummary as? ChatControllerNavigationDataSummary {
            chatNavigationStack.removeAll()
            chatNavigationStack = summary.peerIds.filter({ $0 != peerId })
        }
        
        if !chatNavigationStack.isEmpty {
            self.navigationBar?.backButtonNode.isGestureEnabled = true
            self.navigationBar?.backButtonNode.activated = { [weak self] gesture, _ in
                guard let strongSelf = self else {
                    gesture.cancel()
                    return
                }
                
                let _ = (strongSelf.context.engine.data.get(EngineDataList(
                    chatNavigationStack.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                ))
                |> deliverOnMainQueue).start(next: { peerList in
                    guard let strongSelf = self, let backButtonNode = strongSelf.navigationBar?.backButtonNode else {
                        return
                    }
                    let peers = peerList.compactMap { $0 }
                    
                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    
                    var items: [ContextMenuItem] = []
                    for peer in peers {
                        items.append(.action(ContextMenuActionItem(text: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), icon: { _ in return nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: strongSelf.context.account, peer: peer, size: avatarSize)), action: { _, f in
                            f(.default)
                            
                            guard let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController else {
                                return
                            }

                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peer.id), animated: true, completion: { _ in
                            }))
                        })))
                    }
                    let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .reference(ChatControllerContextReferenceContentSource(controller: strongSelf, sourceView: backButtonNode.view, insets: UIEdgeInsets(), contentInsets: UIEdgeInsets(top: 0.0, left: -15.0, bottom: 0.0, right: -15.0))), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                    strongSelf.presentInGlobalOverlay(contextController)
                })
            }
        }
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
        
        
        let avatarSize = CGSize(width: 28.0, height: 28.0)
        
        items.append(.action(ContextMenuActionItem(text: primary.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: primary.0.account, peer: primary.1, size: avatarSize)), action: { _, f in
            f(.default)
        })))
        
        if !other.isEmpty {
            items.append(.separator)
        }
        
        for account in other {
            let id = account.0.account.id
            items.append(.action(ContextMenuActionItem(text: account.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), badge: account.2 != 0 ? ContextMenuActionBadge(value: "\(account.2)", color: .accent) : nil, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: account.0.account, peer: account.1, size: avatarSize)), action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerNode.switchToAccount(id: id)
                f(.dismissWithoutContent)
            })))
        }
        
        let controller = ContextController(account: primary.0.account, presentationData: self.presentationData, source: .extracted(SettingsTabBarContextExtractedContentSource(controller: self, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
    }
}

private final class SettingsTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let centerActionsHorizontally: Bool = true
    
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

final class PeerInfoNavigationSourceTag {
    let peerId: PeerId
    
    init(peerId: PeerId) {
        self.peerId = peerId
    }
}

private final class PeerInfoNavigationTransitionNode: ASDisplayNode, CustomNavigationTransitionNode {
    private let screenNode: PeerInfoScreenNode
    private let presentationData: PresentationData

    private var topNavigationBar: NavigationBar?
    private var bottomNavigationBar: NavigationBar?
    private var reverseFraction: Bool = false
    
    private let headerNode: PeerInfoHeaderNode
    
    private var previousBackButtonArrow: ASDisplayNode?
    private var previousBackButton: ASDisplayNode?
    private var currentBackButtonArrow: ASDisplayNode?
    private var previousBackButtonBadge: ASDisplayNode?
    private var currentBackButton: ASDisplayNode?
    
    private var previousTitleNode: (ASDisplayNode, ASDisplayNode)?
    private var previousStatusNode: (ASDisplayNode, ASDisplayNode)?
    
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

            if let previousBackButtonArrow = bottomNavigationBar.makeTransitionBackArrowNode(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.previousBackButtonArrow = previousBackButtonArrow
                self.addSubnode(previousBackButtonArrow)
            }
            if let previousBackButton = bottomNavigationBar.makeTransitionBackButtonNode(accentColor: self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.previousBackButton = previousBackButton
                self.addSubnode(previousBackButton)
            }
            if self.screenNode.headerNode.isAvatarExpanded, let currentBackButtonArrow = topNavigationBar.makeTransitionBackArrowNode(accentColor: self.screenNode.headerNode.isAvatarExpanded ? .white : self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.currentBackButtonArrow = currentBackButtonArrow
                self.addSubnode(currentBackButtonArrow)
            }
            if let previousBackButtonBadge = bottomNavigationBar.makeTransitionBadgeNode() {
                self.previousBackButtonBadge = previousBackButtonBadge
                self.addSubnode(previousBackButtonBadge)
            }
            if let currentBackButton = topNavigationBar.makeTransitionBackButtonNode(accentColor: self.screenNode.headerNode.isAvatarExpanded ? .white : self.presentationData.theme.rootController.navigationBar.accentTextColor) {
                self.currentBackButton = currentBackButton
                self.addSubnode(currentBackButton)
            }
            if let previousTitleView = bottomNavigationBar.titleView as? ChatTitleView {
                let previousTitleNode = previousTitleView.titleNode.makeCopy()
                let previousTitleContainerNode = ASDisplayNode()
                previousTitleContainerNode.addSubnode(previousTitleNode)
                previousTitleNode.frame = previousTitleNode.frame.offsetBy(dx: -previousTitleNode.frame.width / 2.0, dy: -previousTitleNode.frame.height / 2.0)
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
            let previousBackButtonArrowFrame = bottomNavigationBar.backButtonArrow.view.convert(bottomNavigationBar.backButtonArrow.view.bounds, to: bottomNavigationBar.view)
            previousBackButtonArrow.frame = previousBackButtonArrowFrame
        }
        
        if let previousBackButton = self.previousBackButton {
            let previousBackButtonFrame = bottomNavigationBar.backButtonNode.view.convert(bottomNavigationBar.backButtonNode.view.bounds, to: bottomNavigationBar.view)
            previousBackButton.frame = previousBackButtonFrame
            transition.updateAlpha(node: previousBackButton, alpha: fraction)
        }
        
        if let currentBackButtonArrow = self.currentBackButtonArrow {
            let currentBackButtonArrowFrame = topNavigationBar.backButtonArrow.view.convert(topNavigationBar.backButtonArrow.view.bounds, to: topNavigationBar.view)
            currentBackButtonArrow.frame = currentBackButtonArrowFrame
            
            transition.updateAlpha(node: currentBackButtonArrow, alpha: 1.0 - fraction)
            if let previousBackButtonArrow = self.previousBackButtonArrow {
                transition.updateAlpha(node: previousBackButtonArrow, alpha: fraction)
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
        
        if let previousTitleView = bottomNavigationBar.titleView as? ChatTitleView, let _ = (bottomNavigationBar.rightButtonNode.singleCustomNode as? ChatAvatarNavigationNode)?.avatarNode, let (previousTitleContainerNode, previousTitleNode) = self.previousTitleNode, let (previousStatusContainerNode, previousStatusNode) = self.previousStatusNode {
            let previousTitleFrame = previousTitleView.titleNode.view.convert(previousTitleView.titleNode.bounds, to: bottomNavigationBar.view)
            let previousStatusFrame = previousTitleView.activityNode.view.convert(previousTitleView.activityNode.bounds, to: bottomNavigationBar.view)
            
            self.headerNode.navigationTransition = PeerInfoHeaderNavigationTransition(sourceNavigationBar: bottomNavigationBar, sourceTitleView: previousTitleView, sourceTitleFrame: previousTitleFrame, sourceSubtitleFrame: previousStatusFrame, fraction: fraction)
            var topHeight = topNavigationBar.backgroundNode.bounds.height
            
            if let (layout, _) = self.screenNode.validLayout {
                let sectionInset: CGFloat
                if layout.size.width >= 375.0 {
                    sectionInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
                } else {
                    sectionInset = 0.0
                }
                let headerInset = sectionInset
                
                topHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: topNavigationBar.bounds.height, isModalOverlay: layout.isModalOverlay, isMediaOnly: false, contentOffset: 0.0, paneContainerY: 0.0, presentationData: self.presentationData, peer: self.screenNode.data?.peer, cachedData: self.screenNode.data?.cachedData, notificationSettings: self.screenNode.data?.notificationSettings, statusData: self.screenNode.data?.status, panelStatusData: (nil, nil, nil), isSecretChat: self.screenNode.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.screenNode.data?.isContact ?? false, isSettings: self.screenNode.isSettings, state: self.screenNode.state, metrics: layout.metrics, transition: transition, additive: false)
            }
            
            let titleScale = (fraction * previousTitleNode.bounds.height + (1.0 - fraction) * self.headerNode.titleNodeRawContainer.bounds.height) / previousTitleNode.bounds.height
            let subtitleScale = max(0.01, min(10.0, (fraction * previousStatusNode.bounds.height + (1.0 - fraction) * self.headerNode.subtitleNodeRawContainer.bounds.height) / previousStatusNode.bounds.height))
            
            transition.updateFrame(node: previousTitleContainerNode, frame: CGRect(origin: self.headerNode.titleNodeRawContainer.frame.center, size: CGSize()))
            transition.updateFrame(node: previousTitleNode, frame: CGRect(origin: CGPoint(x: -previousTitleFrame.width / 2.0, y: -previousTitleFrame.height / 2.0), size: previousTitleFrame.size))
            transition.updateFrame(node: previousStatusContainerNode, frame: CGRect(origin: self.headerNode.subtitleNodeRawContainer.frame.center, size: CGSize()))
            transition.updateFrame(node: previousStatusNode, frame: CGRect(origin: CGPoint(x: -previousStatusFrame.size.width / 2.0, y: -previousStatusFrame.size.height / 2.0), size: previousStatusFrame.size))
            
            transition.updateSublayerTransformScale(node: previousTitleContainerNode, scale: titleScale)
            transition.updateSublayerTransformScale(node: previousStatusContainerNode, scale: subtitleScale)
            
            transition.updateAlpha(node: self.headerNode.titleNode, alpha: (1.0 - fraction))
            transition.updateAlpha(node: previousTitleNode, alpha: fraction)
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
                return (sourceNode, rect)
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

func presentAddMembers(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, parentController: ViewController, groupPeer: Peer, selectAddMemberDisposable: MetaDisposable, addMemberDisposable: MetaDisposable) {
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
    |> deliverOnMainQueue).start(next: { [weak parentController] recentIds in
        var createInviteLinkImpl: (() -> Void)?
        var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
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
        
        let contactsController: ViewController
        if groupPeer.id.namespace == Namespaces.Peer.CloudGroup {
            contactsController = context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: context, updatedPresentationData: updatedPresentationData, autoDismiss: false, title: { $0.GroupInfo_AddParticipantTitle }, options: options, confirmation: { peer in
                if let confirmationImpl = confirmationImpl, case let .peer(peer, _, _) = peer {
                    return confirmationImpl(peer.id)
                } else {
                    return .single(false)
                }
            }))
            contactsController.navigationPresentation = .modal
        } else {
            contactsController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, updatedPresentationData: updatedPresentationData, mode: .peerSelection(searchChatList: false, searchGroups: false, searchChannels: false), options: options, filters: [.excludeSelf, .disable(recentIds)]))
            contactsController.navigationPresentation = .modal
        }
        
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
        
        let addMember: (ContactListPeer) -> Signal<Void, NoError> = { [weak contactsController] memberPeer -> Signal<Void, NoError> in
            if case let .peer(selectedPeer, _, _) = memberPeer {
                let memberId = selectedPeer.id
                if groupPeer.id.namespace == Namespaces.Peer.CloudChannel {
                    return context.peerChannelMemberCategoriesContextsManager.addMember(engine: context.engine, peerId: groupPeer.id, memberId: memberId)
                    |> map { _ -> Void in
                    }
                    |> `catch` { error -> Signal<Void, NoError> in
                        let text: String
                        switch error {
                            case .limitExceeded:
                                text = presentationData.strings.Channel_ErrorAddTooMuch
                            case .tooMuchJoined:
                                text = presentationData.strings.Invite_ChannelsTooMuch
                            case .generic:
                                text = presentationData.strings.Login_UnknownError
                            case .restricted:
                                text = presentationData.strings.Channel_ErrorAddBlocked
                            case .notMutualContact:
                                if let peer = groupPeer as? TelegramChannel, case .broadcast = peer.info {
                                    text = presentationData.strings.Channel_AddUserLeftError
                                } else {
                                    text = presentationData.strings.GroupInfo_AddUserLeftError
                                }
                            case let .bot(memberId):
                                guard let peer = groupPeer as? TelegramChannel else {
                                    parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    contactsController?.dismiss()
                                    return .complete()
                                }
                                
                                if peer.hasPermission(.addAdmins) {
                                    parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_AddBotErrorHaveRights, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Channel_AddBotAsAdmin, action: {
                                        contactsController?.dismiss()
                                        
                                        parentController?.push(channelAdminController(context: context, updatedPresentationData: updatedPresentationData, peerId: groupPeer.id, adminId: memberId, initialParticipant: nil, updated: { _ in
                                        }, upgradedToSupergroup: { _, f in f () }, transferedOwnership: { _ in }))
                                    })]), in: .window(.root))
                                } else {
                                    parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_AddBotErrorHaveRights, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                }
                                
                                contactsController?.dismiss()
                                return .complete()
                            case .botDoesntSupportGroups:
                                text = presentationData.strings.Channel_BotDoesntSupportGroups
                            case .tooMuchBots:
                                text = presentationData.strings.Channel_TooMuchBots
                            case .kicked:
                                text = presentationData.strings.Channel_AddUserKickedError
                        }
                        parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        return .complete()
                    }
                } else {
                    return context.engine.peers.addGroupMember(peerId: groupPeer.id, memberId: memberId)
                    |> deliverOnMainQueue
                    |> `catch` { error -> Signal<Void, NoError> in
                        switch error {
                        case .generic:
                            return .complete()
                        case .privacy:
                            let _ = (context.account.postbox.loadedPeerWithId(memberId)
                            |> deliverOnMainQueue).start(next: { peer in
                                parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(EnginePeer(peer).compactDisplayTitle, EnginePeer(peer).compactDisplayTitle).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            })
                            return .complete()
                        case .notMutualContact:
                            let _ = (context.account.postbox.loadedPeerWithId(memberId)
                            |> deliverOnMainQueue).start(next: { peer in
                                let text: String
                                if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                    text = presentationData.strings.Channel_AddUserLeftError
                                } else {
                                    text = presentationData.strings.GroupInfo_AddUserLeftError
                                }
                                parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            })
                            return .complete()
                        case .tooManyChannels:
                            let _ = (context.account.postbox.loadedPeerWithId(memberId)
                            |> deliverOnMainQueue).start(next: { peer in
                                parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            })
                            return .complete()
                        case .groupFull:
                            let signal = context.engine.peers.convertGroupToSupergroup(peerId: groupPeer.id)
                            |> map(Optional.init)
                            |> `catch` { error -> Signal<PeerId?, NoError> in
                                switch error {
                                case .tooManyChannels:
                                    Queue.mainQueue().async {
                                        parentController?.push(oldChannelsController(context: context, intent: .upgrade))
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
                                return context.peerChannelMemberCategoriesContextsManager.addMember(engine: context.engine, peerId: upgradedPeerId, memberId: memberId)
                                |> `catch` { _ -> Signal<Never, NoError> in
                                    return .complete()
                                }
                                |> mapToSignal { _ -> Signal<PeerId?, NoError> in
                                }
                                |> then(.single(upgradedPeerId))
                            }
                            |> deliverOnMainQueue
                            |> mapToSignal { _ -> Signal<Void, NoError> in
                                return .complete()
                            }
                            return signal
                        }
                    }
                }
            } else {
                return .complete()
            }
        }
        
        let addMembers: ([ContactListPeerId]) -> Signal<Void, AddChannelMemberError> = { members -> Signal<Void, AddChannelMemberError> in
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
            |> castError(AddChannelMemberError.self)
            |> mapToSignal { view -> Signal<Void, AddChannelMemberError> in
                if memberIds.count == 1 {
                    return context.peerChannelMemberCategoriesContextsManager.addMember(engine: context.engine, peerId: groupPeer.id, memberId: memberIds[0])
                    |> map { _ -> Void in
                    }
                } else {
                    return context.peerChannelMemberCategoriesContextsManager.addMembers(engine: context.engine, peerId: groupPeer.id, memberIds: memberIds) |> map { _ in
                    }
                }
            }
        }
        
        createInviteLinkImpl = { [weak contactsController] in
            contactsController?.view.window?.endEditing(true)
            contactsController?.present(InviteLinkInviteController(context: context, updatedPresentationData: updatedPresentationData, peerId: groupPeer.id, parentNavigationController: contactsController?.navigationController as? NavigationController), in: .window(.root))
        }

        parentController?.push(contactsController)
        if let contactsController = contactsController as? ContactSelectionController {
            selectAddMemberDisposable.set((contactsController.result
            |> deliverOnMainQueue).start(next: { [weak contactsController] result in
                guard let (peers, _, _, _, _) = result, let memberPeer = peers.first else {
                    return
                }
                
                contactsController?.displayProgress = true
                addMemberDisposable.set((addMember(memberPeer)
                |> deliverOnMainQueue).start(completed: {
                    contactsController?.dismiss()
                }))
            }))
            contactsController.dismissed = {
                selectAddMemberDisposable.set(nil)
                addMemberDisposable.set(nil)
            }
        }
        if let contactsController = contactsController as? ContactMultiselectionController {
            selectAddMemberDisposable.set((contactsController.result
            |> deliverOnMainQueue).start(next: { [weak contactsController] result in
                var peers: [ContactListPeerId] = []
                if case let .result(peerIdsValue, _) = result {
                    peers = peerIdsValue
                }
                
                contactsController?.displayProgress = true
                addMemberDisposable.set((addMembers(peers)
                |> deliverOnMainQueue).start(error: { error in
                    if peers.count == 1, case .restricted = error {
                        switch peers[0] {
                            case let .peer(peerId):
                                let _ = (context.account.postbox.loadedPeerWithId(peerId)
                                |> deliverOnMainQueue).start(next: { peer in
                                    parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(EnginePeer(peer).compactDisplayTitle, EnginePeer(peer).compactDisplayTitle).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                })
                            default:
                                break
                        }
                    } else if peers.count == 1, case .notMutualContact = error {
                        let text: String
                        if let peer = groupPeer as? TelegramChannel, case .broadcast = peer.info {
                            text = presentationData.strings.Channel_AddUserLeftError
                        } else {
                            text = presentationData.strings.GroupInfo_AddUserLeftError
                        }
                        
                        parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    } else if case .tooMuchJoined = error  {
                        parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    } else if peers.count == 1, case .kicked = error {
                        parentController?.present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_AddUserKickedError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                    
                    contactsController?.dismiss()
                }, completed: {
                    contactsController?.dismiss()
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
            } else if channel.username != nil {
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
