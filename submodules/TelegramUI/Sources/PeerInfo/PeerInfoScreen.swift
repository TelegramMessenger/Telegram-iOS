import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
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

protocol PeerInfoScreenItem: class {
    var id: AnyHashable { get }
    func node() -> PeerInfoScreenItemNode
}

class PeerInfoScreenItemNode: ASDisplayNode {
    var bringToFrontForHighlight: (() -> Void)?
    
    func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        preconditionFailure()
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
    
    func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, items: [PeerInfoScreenItem], transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.topSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
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
            
            let itemHeight = itemNode.update(width: width, safeInsets: safeInsets, presentationData: presentationData, item: item, topItem: topItem, bottomItem: bottomItem, transition: itemTransition)
            let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight))
            itemTransition.updateFrame(node: itemNode, frame: itemFrame)
            if wasAdded {
                itemNode.alpha = 0.0
                transition.updateAlpha(node: itemNode, alpha: 1.0)
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
}

private final class PeerInfoScreenDynamicItemSectionContainerNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var currentItems: [PeerInfoScreenItem] = []
    private var itemNodes: [AnyHashable: PeerInfoScreenItemNode] = [:]
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
    }
    
    func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, items: [PeerInfoScreenItem], transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.topSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
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
                self.addSubnode(itemNode)
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
            
            let itemHeight = itemNode.update(width: width, safeInsets: safeInsets, presentationData: presentationData, item: item, topItem: topItem, bottomItem: bottomItem, transition: itemTransition)
            let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight))
            itemTransition.updateFrame(node: itemNode, frame: itemFrame)
            if wasAdded {
                itemNode.alpha = 0.0
                transition.updateAlpha(node: itemNode, alpha: 1.0)
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
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
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
    
    func updateVisibleItems(in rect: CGRect) {
        
    }
}

final class PeerInfoSelectionPanelNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    
    private let deleteMessages: () -> Void
    private let shareMessages: () -> Void
    private let forwardMessages: () -> Void
    private let reportMessages: () -> Void
    
    let selectionPanel: ChatMessageSelectionInputPanelNode
    let separatorNode: ASDisplayNode
    let backgroundNode: ASDisplayNode
    
    init(context: AccountContext, peerId: PeerId, deleteMessages: @escaping () -> Void, shareMessages: @escaping () -> Void, forwardMessages: @escaping () -> Void, reportMessages: @escaping () -> Void) {
        self.context = context
        self.peerId = peerId
        self.deleteMessages = deleteMessages
        self.shareMessages = shareMessages
        self.forwardMessages = forwardMessages
        self.reportMessages = reportMessages
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.separatorNode = ASDisplayNode()
        self.backgroundNode = ASDisplayNode()
        
        self.selectionPanel = ChatMessageSelectionInputPanelNode(theme: presentationData.theme, strings: presentationData.strings, peerMedia: true)
        self.selectionPanel.context = context
        self.selectionPanel.backgroundColor = presentationData.theme.chat.inputPanel.panelBackgroundColor
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, deleteSelectedMessages: {
            deleteMessages()
        }, reportSelectedMessages: {
            reportMessages()
        }, reportMessages: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
            forwardMessages()
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
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
        }, navigateToMessage: { _ in
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
        }, sendRecordedMedia: {
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _ in
            return false
        }, unblockPeer: {
        }, pinMessage: { _ in
        }, unpinMessage: {
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
        }, unarchivePeer: {}, statuses: nil)
        
        self.selectionPanel.interfaceInteraction = interfaceInteraction
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.selectionPanel)
    }
    
    func update(layout: ContainerViewLayout, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        
        let interfaceState = ChatPresentationInterfaceState(chatWallpaper: .color(0), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, limitsConfiguration: .defaultValue, fontSize: .regular, bubbleCorners: PresentationChatBubbleCorners(mainRadius: 16.0, auxiliaryRadius: 8.0, mergeBubbleCorners: true), accountPeerId: self.context.account.peerId, mode: .standard(previewing: false), chatLocation: .peer(self.peerId), isScheduledMessages: false, peerNearbyData: nil)
        let panelHeight = self.selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: 0.0, isSecondary: false, transition: transition, interfaceState: interfaceState, metrics: layout.metrics)
        
        transition.updateFrame(node: self.selectionPanel, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: panelHeight)))
        
        let panelHeightWithInset = panelHeight + layout.intrinsicInsets.bottom
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: panelHeightWithInset)))
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
    case passport
    case watch
    case support
    case faq
    case phoneNumber
    case username
    case addAccount
    case logout
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
    let editingOpenDiscussionGroupSetup: () -> Void
    let editingToggleMessageSignatures: (Bool) -> Void
    let openParticipantsSection: (PeerInfoParticipantsSection) -> Void
    let editingOpenPreHistorySetup: () -> Void
    let openPermissions: () -> Void
    let editingOpenStickerPackSetup: () -> Void
    let openLocation: () -> Void
    let editingOpenSetupLocation: () -> Void
    let openPeerInfo: (Peer, Bool) -> Void
    let performMemberAction: (PeerInfoMember, PeerInfoMemberAction) -> Void
    let openPeerInfoContextMenu: (PeerInfoContextSubject, ASDisplayNode) -> Void
    let performBioLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    let requestLayout: () -> Void
    let openEncryptionKey: () -> Void
    let openSettings: (PeerInfoSettingsSection) -> Void
    let switchToAccount: (AccountRecordId) -> Void
    let logoutAccount: (AccountRecordId) -> Void
    let accountContextMenu: (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void
    let updateBio: (String) -> Void
    
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
        editingOpenDiscussionGroupSetup: @escaping () -> Void,
        editingToggleMessageSignatures: @escaping (Bool) -> Void,
        openParticipantsSection: @escaping (PeerInfoParticipantsSection) -> Void,
        editingOpenPreHistorySetup: @escaping () -> Void,
        openPermissions: @escaping () -> Void,
        editingOpenStickerPackSetup: @escaping () -> Void,
        openLocation: @escaping () -> Void,
        editingOpenSetupLocation: @escaping () -> Void,
        openPeerInfo: @escaping (Peer, Bool) -> Void,
        performMemberAction: @escaping (PeerInfoMember, PeerInfoMemberAction) -> Void,
        openPeerInfoContextMenu: @escaping (PeerInfoContextSubject, ASDisplayNode) -> Void,
        performBioLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void,
        requestLayout: @escaping () -> Void,
        openEncryptionKey: @escaping () -> Void,
        openSettings: @escaping (PeerInfoSettingsSection) -> Void,
        switchToAccount: @escaping (AccountRecordId) -> Void,
        logoutAccount: @escaping (AccountRecordId) -> Void,
        accountContextMenu: @escaping (AccountRecordId, ASDisplayNode, ContextGesture?) -> Void,
        updateBio: @escaping (String) -> Void
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
        self.editingOpenDiscussionGroupSetup = editingOpenDiscussionGroupSetup
        self.editingToggleMessageSignatures = editingToggleMessageSignatures
        self.openParticipantsSection = openParticipantsSection
        self.editingOpenPreHistorySetup = editingOpenPreHistorySetup
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
        self.switchToAccount = switchToAccount
        self.logoutAccount = logoutAccount
        self.accountContextMenu = accountContextMenu
        self.updateBio = updateBio
    }
}

private let enabledBioEntities: EnabledEntityTypes = [.url, .mention, .hashtag]

private enum SettingsSection: Int, CaseIterable {
    case edit
    case phone
    case accounts
    case proxy
    case shortcuts
    case advanced
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
            //
            //                           entries.append(.phoneInfo(presentationData.theme, presentationData.strings.Settings_CheckPhoneNumberTitle(phoneNumber).0, presentationData.strings.Settings_CheckPhoneNumberText))
            //                           entries.append(.keepPhone(presentationData.theme, presentationData.strings.Settings_KeepPhoneNumber(phoneNumber).0))
            //                           entries.append(.changePhone(presentationData.theme, presentationData.strings.Settings_ChangePhoneNumber))
            let phoneNumber = formatPhoneNumber(peer.phone ?? "")
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_KeepPhoneNumber(phoneNumber).0, action: {
                interaction.openSettings(.addAccount)
            }))
            items[.phone]!.append(PeerInfoScreenActionItem(id: 2, text: presentationData.strings.Settings_ChangePhoneNumber, action: {
                interaction.openSettings(.addAccount)
            }))
        }
        
        if !settings.accountsAndPeers.isEmpty {
            for (peerAccount, peer, badgeCount) in settings.accountsAndPeers {
                let member: PeerInfoMember = .account(peer: RenderedPeer(peer: peer))
                items[.accounts]!.append(PeerInfoScreenMemberItem(id: member.id, context: context.sharedContext.makeTempAccountContext(account: peerAccount), enclosingPeer: nil, member: member, badge: badgeCount > 0 ? "\(compactNumericCountString(Int(badgeCount), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))" : nil, action: { action in
                    switch action {
                        case .open:
                            interaction.switchToAccount(peerAccount.id)
                        case .remove:
                            interaction.logoutAccount(peerAccount.id)
                        default:
                            break
                    }
                }, contextAction: { node, gesture in
                    interaction.accountContextMenu(peerAccount.id, node, gesture)
                }))
            }
            if settings.accountsAndPeers.count + 1 < maximumNumberOfAccounts {
                items[.accounts]!.append(PeerInfoScreenActionItem(id: 100, text: presentationData.strings.Settings_AddAccount, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), action: {
                    interaction.openSettings(.addAccount)
                }))
            }
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
    
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 0, text: presentationData.strings.Settings_SavedMessages, icon: PresentationResourcesSettings.savedMessages, action: {
        interaction.openSettings(.savedMessages)
    }))
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.CallSettings_RecentCalls, icon: PresentationResourcesSettings.recentCalls, action: {
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
    
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 2, label: .text(devicesLabel), text: presentationData.strings.Settings_Devices, icon: PresentationResourcesSettings.devices, action: {
        interaction.openSettings(.devices)
    }))
    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 3, text: presentationData.strings.Settings_ChatFolders, icon: PresentationResourcesSettings.chatFolders, action: {
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
    
    let stickersLabel: String
    if let settings = data.globalSettings {
        stickersLabel = settings.unreadTrendingStickerPacks > 0 ? "\(settings.unreadTrendingStickerPacks)" : ""
    } else {
        stickersLabel = ""
    }
    items[.advanced]!.append(PeerInfoScreenDisclosureItem(id: 5, label: .badge(stickersLabel, presentationData.theme.list.itemAccentColor), text: presentationData.strings.ChatSettings_Stickers, icon: PresentationResourcesSettings.stickers, action: {
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
        }, maxLength: 70))
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
    
    if let settings = data.globalSettings, settings.accountsAndPeers.count + 1 < maximumNumberOfAccounts {
        items[.account]!.append(PeerInfoScreenActionItem(id: ItemAddAccount, text: presentationData.strings.Settings_AddAnotherAccount, alignment: .center, action: {
            interaction.openSettings(.addAccount)
        }))
        items[.account]!.append(PeerInfoScreenCommentItem(id: ItemAddAccountHelp, text: presentationData.strings.Settings_AddAnotherAccount_Help))
    }
    
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
                interaction.requestLayout()
            }))
        }
        if let username = user.username {
            items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 1, label: presentationData.strings.Profile_Username, text: "@\(username)", textColor: .accent, action: {
                interaction.openUsername(username)
            }, longTapAction: { sourceNode in
                interaction.openPeerInfoContextMenu(.link, sourceNode)
            }, requestLayout: {
                interaction.requestLayout()
            }))
        }
        if let cachedData = data.cachedData as? CachedUserData {
            if user.isScam {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: user.botInfo != nil ? presentationData.strings.UserInfo_ScamBotWarning : presentationData.strings.UserInfo_ScamUserWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: user.botInfo != nil ? enabledBioEntities : []), action: nil, requestLayout: {
                    interaction.requestLayout()
                }))
            } else if let about = cachedData.about, !about.isEmpty {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: user.botInfo == nil ? presentationData.strings.Profile_About : presentationData.strings.Profile_BotInfo, text: about, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: []), action: nil, longTapAction: bioContextAction, linkItemAction: bioLinkAction, requestLayout: {
                    interaction.requestLayout()
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
        
            if let cachedData = data.cachedData as? CachedUserData {
                if cachedData.isBlocked {
                    items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 4, text: user.botInfo != nil ? presentationData.strings.Bot_Unblock : presentationData.strings.Conversation_Unblock, action: {
                        interaction.updateBlocked(false)
                    }))
                } else {
                    if user.flags.contains(.isSupport) || data.isContact {
                    } else {
                        items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 4, text: user.botInfo != nil ? presentationData.strings.Bot_Stop : presentationData.strings.Conversation_BlockUser, color: .destructive, action: {
                            interaction.updateBlocked(true)
                        }))
                    }
                }
            }
        }
        
        if let encryptionKeyFingerprint = data.encryptionKeyFingerprint {
            items[.peerInfo]!.append(PeerInfoScreenDisclosureEncryptionKeyItem(id: 6, text: presentationData.strings.Profile_EncryptionKey, fingerprint: encryptionKeyFingerprint, action: {
                interaction.openEncryptionKey()
            }))
        }
        
        if user.botInfo != nil, !user.isVerified {
            items[.peerInfo]!.append(PeerInfoScreenActionItem(id: 5, text: presentationData.strings.ReportPeer_Report, action: {
                interaction.openReport(false)
            }))
        }
    } else if let channel = data.peer as? TelegramChannel {
        let ItemUsername = 1
        let ItemAbout = 2
        let ItemAdmins = 3
        let ItemMembers = 4
        let ItemBanned = 5
        let ItemLocationHeader = 7
        let ItemLocation = 8
        
        if let location = (data.cachedData as? CachedChannelData)?.peerGeoLocation {
            items[.groupLocation]!.append(PeerInfoScreenHeaderItem(id: ItemLocationHeader, text: presentationData.strings.GroupInfo_Location.uppercased()))
            
            let imageSignal = chatMapSnapshotImage(account: context.account, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
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
            items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: ItemUsername, label: presentationData.strings.Channel_LinkItem, text: "https://t.me/\(username)", textColor: .accent, action: {
                interaction.openUsername(username)
            }, longTapAction: { sourceNode in
                interaction.openPeerInfoContextMenu(.link, sourceNode)
            }, requestLayout: {
                interaction.requestLayout()
            }))
        }
        if let cachedData = data.cachedData as? CachedChannelData {
            if channel.isScam {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: presentationData.strings.Channel_AboutItem, text: presentationData.strings.GroupInfo_ScamGroupWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledBioEntities), action: nil, requestLayout: {
                    interaction.requestLayout()
                }))
            } else if let about = cachedData.about, !about.isEmpty {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: ItemAbout, label: presentationData.strings.Channel_AboutItem, text: about, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledBioEntities), action: nil, longTapAction: bioContextAction, linkItemAction: bioLinkAction, requestLayout: {
                    interaction.requestLayout()
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
                        let bannedCount = cachedData.participantsSummary.kickedCount ?? 0
                        
                        items[.peerInfo]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text("\(adminCount == 0 ? "" : "\(presentationStringsFormattedNumber(adminCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Administrators, action: {
                            interaction.openParticipantsSection(.admins)
                        }))
                        items[.peerInfo]!.append(PeerInfoScreenDisclosureItem(id: ItemMembers, label: .text("\(memberCount == 0 ? "" : "\(presentationStringsFormattedNumber(memberCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.Channel_Info_Subscribers, action: {
                            interaction.openParticipantsSection(.members)
                        }))
                        items[.peerInfo]!.append(PeerInfoScreenDisclosureItem(id: ItemBanned, label: .text("\(bannedCount == 0 ? "" : "\(presentationStringsFormattedNumber(bannedCount, presentationData.dateTimeFormat.groupingSeparator))")"), text: presentationData.strings.GroupInfo_Permissions_Removed, action: {
                            interaction.openParticipantsSection(.banned)
                        }))
                    }
                }
            }
        }
    } else if let group = data.peer as? TelegramGroup {
        if let cachedData = data.cachedData as? CachedGroupData {
            if group.isScam {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: presentationData.strings.PeerInfo_GroupAboutItem, text: presentationData.strings.GroupInfo_ScamGroupWarning, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledBioEntities), action: nil, requestLayout: {
                    interaction.requestLayout()
                }))
            } else if let about = cachedData.about, !about.isEmpty {
                items[.peerInfo]!.append(PeerInfoScreenLabeledValueItem(id: 0, label: presentationData.strings.PeerInfo_GroupAboutItem, text: about, textColor: .primary, textBehavior: .multiLine(maxLines: 100, enabledEntities: enabledBioEntities), action: nil, longTapAction: bioContextAction, linkItemAction: bioLinkAction, requestLayout: {
                    interaction.requestLayout()
                }))
            }
        }
    }
    
    if let peer = data.peer, let members = data.members, case let .shortList(_, memberList) = members {
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
    }
    
    var items: [Section: [PeerInfoScreenItem]] = [:]
    for section in Section.allCases {
        items[section] = []
    }
    
    if let data = data, let notificationSettings = data.notificationSettings {
        let notificationsLabel: String
        let soundLabel: String
        if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
            if until < Int32.max - 1 {
                notificationsLabel = stringForRemainingMuteInterval(strings: presentationData.strings, muteInterval: until)
            } else {
                notificationsLabel = presentationData.strings.UserInfo_NotificationsDisabled
            }
        } else {
            notificationsLabel = presentationData.strings.UserInfo_NotificationsEnabled
        }
    
        let globalNotificationSettings: GlobalNotificationSettings = data.globalNotificationSettings ?? GlobalNotificationSettings.defaultSettings
        soundLabel = localizedPeerNotificationSoundString(strings: presentationData.strings, sound: notificationSettings.messageSound, default: globalNotificationSettings.effective.privateChats.sound)
        
        items[.notifications]!.append(PeerInfoScreenDisclosureItem(id: 0, label: .text(notificationsLabel), text: presentationData.strings.GroupInfo_Notifications, action: {
            interaction.editingOpenNotificationSettings()
        }))
        items[.notifications]!.append(PeerInfoScreenDisclosureItem(id: 1, label: .text(soundLabel), text: presentationData.strings.GroupInfo_Sound, action: {
            interaction.editingOpenSoundSettings()
        }))
        items[.notifications]!.append(PeerInfoScreenSwitchItem(id: 2, text: presentationData.strings.Notification_Exceptions_PreviewAlwaysOn, value: notificationSettings.displayPreviews != .hide, toggled: { value in
            interaction.editingToggleShowMessageText(value)
        }))
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
            let ItemUsername = 1
            let ItemDiscussionGroup = 2
            let ItemSignMessages = 3
            let ItemSignMessagesHelp = 4
            
            switch channel.info {
            case .broadcast:
                if channel.flags.contains(.isCreator) {
                    let linkText: String
                    if let username = channel.username {
                        linkText = "@\(username)"
                    } else {
                        linkText = presentationData.strings.Channel_Setup_TypePrivate
                    }
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(linkText), text: presentationData.strings.Channel_TypeSetup_Title, action: {
                        interaction.editingOpenPublicLinkSetup()
                    }))
                }
                 
                if channel.flags.contains(.isCreator) || (channel.adminRights != nil && channel.hasPermission(.pinMessages)) {
                    let discussionGroupTitle: String
                    if let _ = data.cachedData as? CachedChannelData {
                        if let peer = data.linkedDiscussionPeer {
                            if let addressName = peer.addressName, !addressName.isEmpty {
                                discussionGroupTitle = "@\(addressName)"
                            } else {
                                discussionGroupTitle = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            }
                        } else {
                            discussionGroupTitle = presentationData.strings.Channel_DiscussionGroupAdd
                        }
                    } else {
                        discussionGroupTitle = "..."
                    }
                    
                    items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemDiscussionGroup, label: .text(discussionGroupTitle), text: presentationData.strings.Channel_DiscussionGroup, action: {
                        interaction.editingOpenDiscussionGroupSetup()
                    }))
                    
                    let messagesShouldHaveSignatures: Bool
                    switch channel.info {
                    case let .broadcast(info):
                        messagesShouldHaveSignatures = info.flags.contains(.messagesShouldHaveSignatures)
                    default:
                        messagesShouldHaveSignatures = false
                    }
                    items[.peerSettings]!.append(PeerInfoScreenSwitchItem(id: ItemSignMessages, text: presentationData.strings.Channel_SignMessages, value: messagesShouldHaveSignatures, toggled: { value in
                        interaction.editingToggleMessageSignatures(value)
                    }))
                    items[.peerSettings]!.append(PeerInfoScreenCommentItem(id: ItemSignMessagesHelp, text: presentationData.strings.Channel_SignMessages_Help))
                }
            case .group:
                let ItemUsername = 1
                let ItemLinkedChannel = 2
                let ItemPreHistory = 3
                let ItemStickerPack = 4
                let ItemPermissions = 5
                let ItemAdmins = 6
                let ItemLocationHeader = 7
                let ItemLocation = 8
                let ItemLocationSetup = 9
                
                let isCreator = channel.flags.contains(.isCreator)
                let isPublic = channel.username != nil
                
                if let cachedData = data.cachedData as? CachedChannelData {
                    if isCreator, let location = cachedData.peerGeoLocation {
                        items[.groupLocation]!.append(PeerInfoScreenHeaderItem(id: ItemLocationHeader, text: presentationData.strings.GroupInfo_Location.uppercased()))
                        
                        let imageSignal = chatMapSnapshotImage(account: context.account, resource: MapSnapshotMediaResource(latitude: location.latitude, longitude: location.longitude, width: 90, height: 90))
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
                                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(linkText), text: presentationData.strings.GroupInfo_PublicLink, action: {
                                    interaction.editingOpenPublicLinkSetup()
                                }))
                            }
                        } else {
                            if cachedData.flags.contains(.canChangeUsername) {
                                items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(isPublic ? presentationData.strings.Channel_Setup_TypePublic : presentationData.strings.Channel_Setup_TypePrivate), text: presentationData.strings.GroupInfo_GroupType, action: {
                                    interaction.editingOpenPublicLinkSetup()
                                }))
                                
                                if let linkedDiscussionPeer = data.linkedDiscussionPeer {
                                    let peerTitle: String
                                    if let addressName = linkedDiscussionPeer.addressName, !addressName.isEmpty {
                                        peerTitle = "@\(addressName)"
                                    } else {
                                        peerTitle = linkedDiscussionPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                    }
                                    items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemLinkedChannel, label: .text(peerTitle), text: presentationData.strings.Group_LinkedChannel, action: {
                                        interaction.editingOpenDiscussionGroupSetup()
                                    }))
                                }
                            }
                            if !isPublic && cachedData.linkedDiscussionPeerId == nil {
                                items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPreHistory, label: .text(cachedData.flags.contains(.preHistoryEnabled) ? presentationData.strings.GroupInfo_GroupHistoryVisible : presentationData.strings.GroupInfo_GroupHistoryHidden), text: presentationData.strings.GroupInfo_GroupHistory, action: {
                                    interaction.editingOpenPreHistorySetup()
                                }))
                            }
                        }
                    }
                    
                    if cachedData.flags.contains(.canSetStickerSet) && canEditPeerInfo(context: context, peer: channel) {
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemStickerPack, label: .text(cachedData.stickerPack?.title ?? presentationData.strings.GroupInfo_SharedMediaNone), text: presentationData.strings.Stickers_GroupStickers, action: {
                            interaction.editingOpenStickerPackSetup()
                        }))
                    }
                    
                    var canViewAdminsAndBanned = false
                    if let adminRights = channel.adminRights, !adminRights.isEmpty {
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
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, action: {
                            interaction.openPermissions()
                        }))
                        
                        items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, label: .text(cachedData.participantsSummary.adminCount.flatMap { "\(presentationStringsFormattedNumber($0, presentationData.dateTimeFormat.groupingSeparator))" } ?? ""), text: presentationData.strings.GroupInfo_Administrators, action: {
                            interaction.openParticipantsSection(.admins)
                        }))
                    }
                }
            }
        } else if let group = data.peer as? TelegramGroup {
            let ItemUsername = 1
            let ItemPreHistory = 2
            let ItemPermissions = 3
            let ItemAdmins = 4
            
            if case .creator = group.role {
                if let cachedData = data.cachedData as? CachedGroupData {
                    if cachedData.flags.contains(.canChangeUsername) {
                        items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemUsername, label: .text(presentationData.strings.Group_Setup_TypePrivate), text: presentationData.strings.GroupInfo_GroupType, action: {
                            interaction.editingOpenPublicLinkSetup()
                        }))
                    }
                }
                items[.peerPublicSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPreHistory, label: .text(presentationData.strings.GroupInfo_GroupHistoryHidden), text: presentationData.strings.GroupInfo_GroupHistory, action: {
                    interaction.editingOpenPreHistorySetup()
                }))
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
                
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemPermissions, label: .text(activePermissionCount.flatMap({ "\($0)/\(allGroupPermissionList.count)" }) ?? ""), text: presentationData.strings.GroupInfo_Permissions, action: {
                    interaction.openPermissions()
                }))
                
                items[.peerSettings]!.append(PeerInfoScreenDisclosureItem(id: ItemAdmins, text: presentationData.strings.GroupInfo_Administrators, action: {
                    interaction.openParticipantsSection(.admins)
                }))
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

private final class PeerInfoScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private weak var controller: PeerInfoScreen?
    
    private let context: AccountContext
    private let peerId: PeerId
    private let isOpenedFromChat: Bool
    private let videoCallsEnabled: Bool
    private let callMessages: [Message]
    
    let isSettings: Bool
    private let isMediaOnly: Bool
    
    private var presentationData: PresentationData
    
    let scrollNode: ASScrollNode
    
    let headerNode: PeerInfoHeaderNode
    private var regularSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    private var editingSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    private let paneContainerNode: PeerInfoPaneContainerNode
    private var ignoreScrolling: Bool = false
    private var hapticFeedback: HapticFeedback?
    
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
    
    private(set) var validLayout: (ContainerViewLayout, CGFloat)?
    private(set) var data: PeerInfoScreenData?
    private(set) var state = PeerInfoState(
        isEditing: false,
        selectedMessageIds: nil,
        updatingAvatar: nil,
        updatingBio: nil,
        avatarUploadProgress: nil
    )
    private let nearbyPeerDistance: Int32?
    private var dataDisposable: Disposable?
    
    private let activeActionDisposable = MetaDisposable()
    private let resolveUrlDisposable = MetaDisposable()
    private let toggleShouldChannelMessagesSignaturesDisposable = MetaDisposable()
    private let selectAddMemberDisposable = MetaDisposable()
    private let addMemberDisposable = MetaDisposable()
    private let preloadHistoryDisposable = MetaDisposable()
    
    private let editAvatarDisposable = MetaDisposable()
    private let updateAvatarDisposable = MetaDisposable()
    private let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    private var groupMembersSearchContext: GroupMembersSearchContext?
    
    private let preloadedSticker = Promise<TelegramMediaFile?>(nil)
    private let preloadStickerDisposable = MetaDisposable()
    
    fileprivate let accountsAndPeers = Promise<[(Account, Peer, Int32)]>()
    fileprivate let activeSessionsContextAndCount = Promise<(ActiveSessionsContext, Int, WebSessionsContext)?>()
    private let notificationExceptions = Promise<NotificationExceptionsList?>()
    private let privacySettings = Promise<AccountPrivacySettings?>()
    private let archivedPacks = Promise<[ArchivedStickerPackItem]?>()
    private let blockedPeers = Promise<BlockedPeersContext?>(nil)
    private let hasTwoStepAuth = Promise<Bool?>(nil)
    private let hasPassport = Promise<Bool>(false)
    private let supportPeerDisposable = MetaDisposable()
    private let cachedFaq = Promise<ResolvedUrl?>(nil)
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    init(controller: PeerInfoScreen, context: AccountContext, peerId: PeerId, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, nearbyPeerDistance: Int32?, callMessages: [Message], isSettings: Bool, ignoreGroupInCommon: PeerId?) {
        self.controller = controller
        self.context = context
        self.peerId = peerId
        self.isOpenedFromChat = isOpenedFromChat
        self.videoCallsEnabled = VideoCallsConfiguration(appConfiguration: context.currentAppConfiguration.with { $0 }).areVideoCallsEnabled
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.nearbyPeerDistance = nearbyPeerDistance
        self.callMessages = callMessages
        self.isSettings = isSettings
        self.isMediaOnly = context.account.peerId == peerId && !isSettings
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.delaysContentTouches = false
        
        self.headerNode = PeerInfoHeaderNode(context: context, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, isSettings: isSettings)
        self.paneContainerNode = PeerInfoPaneContainerNode(context: context, peerId: peerId)
        
        super.init()
        
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
                self?.openReport(user: user)
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
            requestLayout: { [weak self] in
                self?.requestLayout()
            },
            openEncryptionKey: { [weak self] in
                self?.openEncryptionKey()
            },
            openSettings: { [weak self] section in
                self?.openSettings(section: section)
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
            }
        )
        
        self._chatInterfaceInteraction = ChatControllerInteraction(openMessage: { [weak self] message, mode in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.openMessage(id: message.id)
        }, openPeer: { [weak self] id, navigation, _ in
            if let id = id {
                self?.openPeer(peerId: id, navigation: navigation)
            }
        }, openPeerMention: { _ in
        }, openMessageContextMenu: { [weak self] message, _, node, frame, anyRecognizer in
            guard let strongSelf = self, let node = node as? ContextExtractedContentContainingNode else {
                return
            }
            let _ = storedMessageFromSearch(account: strongSelf.context.account, message: message).start()
            
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
            let _ = (chatAvailableMessageActionsImpl(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id])
            |> deliverOnMainQueue).start(next: { actions in
                guard let strongSelf = self else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                
                if let linkForCopying = linkForCopying {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuCopyLink, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c.dismiss(completion: {})
                        UIPasteboard.general.string = linkForCopying
                    })))
                }
                
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c.dismiss(completion: {
                        if let strongSelf = self {
                            strongSelf.forwardMessages(messageIds: Set([message.id]))
                        }
                    })
                })))
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c.dismiss(completion: {
                        if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), subject: .message(message.id)))
                        }
                    })
                })))
                if actions.options.contains(.deleteLocally) || actions.options.contains(.deleteGlobally) {
                    let context = strongSelf.context
                    let presentationData = strongSelf.presentationData
                    let peerId = strongSelf.peerId
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, _ in
                        c.setItems(context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                            var items: [ContextMenuItem] = []
                            let messageIds = [message.id]
                            
                            if let peer = transaction.getPeer(message.id.peerId) {
                                var personalPeerName: String?
                                var isChannel = false
                                if let user = peer as? TelegramUser {
                                    personalPeerName = user.compactDisplayTitle
                                } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                    isChannel = true
                                }
                                
                                if actions.options.contains(.deleteGlobally) {
                                    let globalTitle: String
                                    if isChannel {
                                        globalTitle = presentationData.strings.Conversation_DeleteMessagesForMe
                                    } else if let personalPeerName = personalPeerName {
                                        globalTitle = presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                                    } else {
                                        globalTitle = presentationData.strings.Conversation_DeleteMessagesForEveryone
                                    }
                                    items.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                        c.dismiss(completion: {
                                            if let strongSelf = self {
                                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
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
                                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forLocalPeer).start()
                                            }
                                        })
                                    })))
                                }
                            }
                            
                            return items
                        })
                    })))
                }
                if strongSelf.searchDisplayController == nil {
                    items.append(.separator)
                    
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuMore, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/More"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c.dismiss(completion: {
                            if let strongSelf = self {
                                strongSelf.chatInterfaceInteraction.toggleMessagesSelection([message.id], true)
                                strongSelf.expandTabs()
                            }
                        })
                    })))
                }
                
                let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node)), items: .single(items), reactionItems: [], recognizer: nil, gesture: gesture)
                strongSelf.controller?.window?.presentInGlobalOverlay(controller)
            })
        }, openMessageContextActions: { [weak self] message, node, rect, gesture in
            guard let strongSelf = self else {
                gesture?.cancel()
                return
            }
            
            let _ = (chatMediaListPreviewControllerData(context: strongSelf.context, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: strongSelf.controller?.navigationController as? NavigationController)
            |> deliverOnMainQueue).start(next: { previewData in
                guard let strongSelf = self else {
                    gesture?.cancel()
                    return
                }
                if let previewData = previewData {
                    let context = strongSelf.context
                    let strings = strongSelf.presentationData.strings
                    let items = chatAvailableMessageActionsImpl(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: [message.id])
                    |> map { actions -> [ContextMenuItem] in
                        var items: [ContextMenuItem] = []
                        
                        items.append(.action(ContextMenuActionItem(text: strings.SharedMedia_ViewInChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            c.dismiss(completion: {
                                if let strongSelf = self, let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), subject: .message(message.id)))
                                }
                            })
                        })))
                        
                        items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuForward, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                            c.dismiss(completion: {
                                if let strongSelf = self {
                                    strongSelf.forwardMessages(messageIds: [message.id])
                                }
                            })
                        })))
                        
                        if actions.options.contains(.deleteLocally) || actions.options.contains(.deleteGlobally) {
                            items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { c, f in
                                c.setItems(context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                                    var items: [ContextMenuItem] = []
                                    let messageIds = [message.id]
                                    
                                    if let peer = transaction.getPeer(message.id.peerId) {
                                        var personalPeerName: String?
                                        var isChannel = false
                                        if let user = peer as? TelegramUser {
                                            personalPeerName = user.compactDisplayTitle
                                        } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                            isChannel = true
                                        }
                                        
                                        if actions.options.contains(.deleteGlobally) {
                                            let globalTitle: String
                                            if isChannel {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                                            } else if let personalPeerName = personalPeerName {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                                            } else {
                                                globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                                            }
                                            items.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                                c.dismiss(completion: {
                                                    if let strongSelf = self {
                                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                                        let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
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
                                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                                        let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forLocalPeer).start()
                                                    }
                                                })
                                            })))
                                        }
                                    }
                                    
                                    return items
                                })
                            })))
                        }
                        
                        items.append(.separator)
                        items.append(.action(ContextMenuActionItem(text: strings.Conversation_ContextMenuMore, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/More"), color: theme.actionSheet.primaryTextColor)
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
                        let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: node)), items: items, reactionItems: [], gesture: gesture)
                        strongSelf.controller?.presentInGlobalOverlay(contextController)
                    case .instantPage:
                        break
                    }
                }
            })
        }, navigateToMessage: { fromId, id in
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
        }, sendSticker: { _, _, _, _ in
            return false
        }, sendGif: { _, _, _ in
            return false
        }, sendBotContextResultAsGif: { _, _, _, _ in
            return false
        }, requestMessageActionCallback: { _, _, _, _ in
        }, requestMessageActionUrlAuth: { _, _, _ in
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
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> Void in
                        if transaction.getMessage(galleryMessage.id) == nil {
                            storeMessageFromSearch(transaction: transaction, message: galleryMessage)
                        }
                    }).start()
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
        }, navigationController: { [weak self] in
            return self?.controller?.navigationController as? NavigationController
        }, chatControllerNode: {
            return nil
        }, reactionContainerNode: {
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
                                let actionSheet = OpenInActionSheetController(context: strongSelf.context, item: .url(url: url), openUrl: { [weak self] url in
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
        }, navigateToFirstDateMessage: { _ in
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
        }, updateMessageLike: { _, _ in
        }, openMessageReactions: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: {  
        }, greetingStickerNode: {
            return nil
        }, openPeerContextMenu: { _, _, _, _ in
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
           pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: false))
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
        self.addSubnode(self.headerNode)
        self.scrollNode.view.isScrollEnabled = !self.isMediaOnly
        
        self.paneContainerNode.chatControllerInteraction = self.chatInterfaceInteraction
        self.paneContainerNode.openPeerContextAction = { [weak self] peer, node, gesture in
            guard let strongSelf = self, let controller = strongSelf.controller else {
                return
            }
            let presentationData = strongSelf.presentationData
            let chatController = strongSelf.context.sharedContext.makeChatController(context: context, chatLocation: .peer(peer.id), subject: nil, botStart: nil, mode: .standard(previewing: true))
            chatController.canReadHistory.set(false)
            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(text: presentationData.strings.Conversation_LinkDialogOpen, icon: { _ in nil }, action: { _, f in
                    f(.dismissWithoutContent)
                    self?.chatInterfaceInteraction.openPeer(peer.id, .default, nil)
                }))
            ]
            let contextController = ContextController(account: strongSelf.context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: .single(items), reactionItems: [], gesture: gesture)
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
        
        self.headerNode.performButtonAction = { [weak self] key in
            self?.performButtonAction(key: key)
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
            let galleryController = AvatarGalleryController(context: strongSelf.context, peer: peer, sourceCorners: .round(!strongSelf.headerNode.isAvatarExpanded), remoteEntries: entriesPromise, skipInitial: true, centralEntryIndex: centralEntry.flatMap { entries.firstIndex(of: $0) }, replaceRootController: { controller, ready in
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
                let _ = self?.headerNode.avatarListNode.listContainerNode.deleteItem(PeerInfoAvatarListItem(entry: entry))
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
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Settings_CancelUpload, color: .destructive, action: { [weak self] in
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
        
        self.headerNode.requestUpdateLayout = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
            }
        }
        
        self.headerNode.navigationButtonContainer.performAction = { [weak self] key in
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
                (strongSelf.controller?.parent as? TabBarController)?.updateIsTabBarHidden(false, transition: .animated(duration: 0.3, curve: .linear))
                strongSelf.view.endEditing(true)
                if case .done = key {
                    guard let data = strongSelf.data else {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                        return
                    }
                    if let peer = data.peer as? TelegramUser {
                        if strongSelf.isSettings, let cachedData = data.cachedData as? CachedUserData {
                            let firstName = strongSelf.headerNode.editingContentNode.editingTextForKey(.firstName) ?? ""
                            let lastName = strongSelf.headerNode.editingContentNode.editingTextForKey(.lastName) ?? ""
                            let bio = strongSelf.state.updatingBio
                            
                            if peer.firstName != firstName || peer.lastName != lastName || (bio != nil && bio != cachedData.about) {
                                var updateNameSignal: Signal<Void, NoError> = .complete()
                                var hasProgress = false
                                if peer.firstName != firstName || peer.lastName != lastName {
                                    updateNameSignal = updateAccountPeerName(account: context.account, firstName: firstName, lastName: lastName)
                                    hasProgress = true
                                }
                                var updateBioSignal: Signal<Void, NoError> = .complete()
                                if let bio = bio, bio != cachedData.about {
                                    updateBioSignal = updateAbout(account: context.account, about: bio)
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
                                |> deliverOnMainQueue).start(error: { _ in
                                    dismissStatus?()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                }, completed: {
                                    dismissStatus?()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                }))
                            } else {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
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
                                    
                                    strongSelf.activeActionDisposable.set((updateContactName(account: context.account, peerId: peer.id, firstName: firstName, lastName: lastName)
                                    |> deliverOnMainQueue).start(error: { _ in
                                        dismissStatus?()
                                        
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                    }, completed: {
                                        dismissStatus?()
                                        
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let context = strongSelf.context
                                        
                                        let _ = (getUserPeer(postbox: strongSelf.context.account.postbox, peerId: peer.id)
                                        |> mapToSignal { peer, _ -> Signal<Void, NoError> in
                                            guard let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty else {
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
                                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                    }))
                                }
                            } else {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                            }
                        } else {
                            strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
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
                                    updatePeerTitle(account: strongSelf.context.account, peerId: group.id, title: title)
                                    |> ignoreValues
                                    |> mapError { _ in return Void() }
                                )
                                hasProgress = true
                            }
                            if description != (data.cachedData as? CachedGroupData)?.about {
                                updateDataSignals.append(
                                    updatePeerDescription(account: strongSelf.context.account, peerId: group.id, description: description.isEmpty ? nil : description)
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
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                            }, completed: {
                                dismissStatus?()
                                
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
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
                                        updatePeerTitle(account: strongSelf.context.account, peerId: channel.id, title: title)
                                        |> ignoreValues
                                        |> mapError { _ in return Void() }
                                    )
                                    hasProgress = true
                                }
                                if description != (data.cachedData as? CachedChannelData)?.about {
                                    updateDataSignals.append(
                                        updatePeerDescription(account: strongSelf.context.account, peerId: channel.id, description: description.isEmpty ? nil : description)
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
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                }, completed: {
                                    dismissStatus?()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
                                }))
                            }
                        }
                        
                        proceed()
                    } else {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.cancel)
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
                strongSelf.activateSearch()
            case .editPhoto, .editVideo:
                break
            }
        }
        
        let screenData: Signal<PeerInfoScreenData, NoError>
        if self.isSettings {
            self.notificationExceptions.set(.single(NotificationExceptionsList(peers: [:], settings: [:]))
            |> then(
                notificationExceptionsList(postbox: context.account.postbox, network: context.account.network)
                |> map(Optional.init)
            ))
            self.privacySettings.set(.single(nil) |> then(requestAccountPrivacySettings(account: context.account) |> map(Optional.init)))
            self.archivedPacks.set(.single(nil) |> then(archivedStickerPacks(account: context.account) |> map(Optional.init)))
            self.hasPassport.set(.single(false) |> then(twoStepAuthData(context.account.network)
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
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Settings_CopyPhoneNumber, accessibilityLabel: strongSelf.presentationData.strings.Settings_CopyPhoneNumber), action: {
                        UIPasteboard.general.string = formatPhoneNumber(phone)
                    }))
                }
                
                if copyUsername, let username = user.username, !username.isEmpty {
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Settings_CopyUsername, accessibilityLabel: strongSelf.presentationData.strings.Settings_CopyUsername), action: {
                        UIPasteboard.general.string = username
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
            screenData = peerInfoScreenData(context: context, peerId: peerId, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, isSettings: self.isSettings, ignoreGroupInCommon: ignoreGroupInCommon)
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
        })
        
        if let _ = nearbyPeerDistance {
            self.preloadHistoryDisposable.set(self.context.account.addAdditionalPreloadHistoryPeerId(peerId: peerId))
            
            self.preloadedSticker.set(.single(nil)
            |> then(randomGreetingSticker(account: context.account)
            |> map { item in
                return item?.file
            }))
            
            self.preloadStickerDisposable.set((self.preloadedSticker.get()
            |> mapToSignal { sticker -> Signal<Void, NoError> in
                if let sticker = sticker {
                    let _ = freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: sticker)).start()
                    return chatMessageAnimationData(postbox: context.account.postbox, resource: sticker.resource, fitzModifier: nil, width: 384, height: 384, synchronousLoad: false)
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
                } else {
                    return .complete()
                }
            }).start())
        }
    }
    
    deinit {
        self.dataDisposable?.dispose()
        self.hiddenMediaDisposable?.dispose()
        self.activeActionDisposable.dispose()
        self.resolveUrlDisposable.dispose()
        self.hiddenAvatarRepresentationDisposable.dispose()
        self.toggleShouldChannelMessagesSignaturesDisposable.dispose()
        self.editAvatarDisposable.dispose()
        self.selectAddMemberDisposable.dispose()
        self.addMemberDisposable.dispose()
        self.preloadHistoryDisposable.dispose()
        self.preloadStickerDisposable.dispose()
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
            
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: self.didSetReady && membersUpdated ? .animated(duration: 0.3, curve: .spring) : .immediate)
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
        self.headerNode.navigationButtonContainer.performAction?(.cancel)
    }
    
    private func openMessage(id: MessageId) -> Bool {
        guard let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return false
        }
        var foundGalleryMessage: Message?
        if let searchContentNode = self.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
            if let galleryMessage = searchContentNode.messageForGallery(id) {
                let _ = (self.context.account.postbox.transaction { transaction -> Void in
                    if transaction.getMessage(galleryMessage.id) == nil {
                        storeMessageFromSearch(transaction: transaction, message: galleryMessage)
                    }
                }).start()
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
        
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, message: galleryMessage, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: { [weak self] in
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
        }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }))
    }
    
    private func openUrl(url: String, concealed: Bool, external: Bool) {
        openUserGeneratedUrl(context: self.context, url: url, concealed: concealed, present: { [weak self] c in
            self?.controller?.present(c, in: .window(.root))
        }, openResolved: { [weak self] tempResolved in
            guard let strongSelf = self else {
                return
            }
            
            let result: ResolvedUrl = external ? .externalUrl(url) : tempResolved
            
            strongSelf.context.sharedContext.openResolvedUrl(result, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.controller?.navigationController as? NavigationController, openPeer: { peerId, navigation in
                self?.openPeer(peerId: peerId, navigation: navigation)
            }, sendFile: nil,
               sendSticker: nil,
               present: { c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, dismissInput: {
                self?.view.endEditing(true)
            }, contentContext: nil)
        })
        
        let disposable = self.resolveUrlDisposable
        
        let resolvedUrl: Signal<ResolvedUrl, NoError>
        if external {
            resolvedUrl = .single(.externalUrl(url))
        } else {
            resolvedUrl = self.context.sharedContext.resolveUrl(account: self.context.account, url: url)
        }
    }
    
    private func openPeer(peerId: PeerId, navigation: ChatControllerInteractionNavigateToPeer) {
        switch navigation {
        case .default:
            if let navigationController = self.controller?.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peerId), keepStack: .always))
            }
        case let .chat(_, subject, peekData):
            if let navigationController = self.controller?.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peerId), subject: subject, keepStack: .always, peekData: peekData))
            }
        case .info:
            self.resolveUrlDisposable.set((self.context.account.postbox.loadedPeerWithId(peerId)
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                        if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
                            (strongSelf.controller?.navigationController as? NavigationController)?.pushViewController(infoController)
                        }
                    }
                }))
        case let .withBotStartPayload(startPayload):
            if let navigationController = self.controller?.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peerId), botStart: startPayload))
            }
        }
    }
    
    private func performButtonAction(key: PeerInfoHeaderButtonKey) {
        guard let controller = self.controller else {
            return
        }
        switch key {
        case .message:
            if let navigationController = controller.navigationController as? NavigationController {
                let _ = (self.preloadedSticker.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] sticker in
                    if let strongSelf = self {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), keepStack: strongSelf.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: strongSelf.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0, sticker: sticker) }), completion: { _ in
                            if strongSelf.nearbyPeerDistance != nil {
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
                })
            }
        case .discussion:
            if let cachedData = self.data?.cachedData as? CachedChannelData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                if let navigationController = controller.navigationController as? NavigationController {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(linkedDiscussionPeerId)))
                }
            }
        case .call:
            self.requestCall(isVideo: false)
        case .videoCall:
            self.requestCall(isVideo: true)
        case .mute:
            if let notificationSettings = self.data?.notificationSettings, case .muted = notificationSettings.muteState {
                let _ = updatePeerMuteSetting(account: self.context.account, peerId: self.peerId, muteInterval: nil).start()
            } else {
                let actionSheet = ActionSheetController(presentationData: self.presentationData)
                let dismissAction: () -> Void = { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                }
                var items: [ActionSheetItem] = []
                let muteValues: [Int32] = [
                    1 * 60 * 60,
                    24 * 60 * 60,
                    2 * 24 * 60 * 60,
                    Int32.max
                ]
                for delay in muteValues {
                    let title: String
                    if delay == Int32.max {
                        title = self.presentationData.strings.MuteFor_Forever
                    } else {
                        title = muteForIntervalString(strings: self.presentationData.strings, value: delay)
                    }
                    items.append(ActionSheetButtonItem(title: title, action: {
                        dismissAction()
                        
                        let _ = updatePeerMuteSetting(account: self.context.account, peerId: self.peerId, muteInterval: delay).start()
                    }))
                }
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                self.view.endEditing(true)
                controller.present(actionSheet, in: .window(.root))
            }
        case .more:
            guard let data = self.data, let peer = data.peer else {
                return
            }
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            let dismissAction: () -> Void = { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            }
            var items: [ActionSheetItem] = []
            if !peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: self.isOpenedFromChat, videoCallsEnabled: self.videoCallsEnabled).contains(.search) || self.headerNode.isAvatarExpanded {
                items.append(ActionSheetButtonItem(title: presentationData.strings.ChatSearch_SearchPlaceholder, color: .accent, action: { [weak self] in
                    dismissAction()
                    self?.openChatWithMessageSearch()
                }))
            }
            if let user = peer as? TelegramUser {
                if let botInfo = user.botInfo {
                    if botInfo.flags.contains(.worksWithGroups) {
                        items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_InviteBotToGroup, color: .accent, action: { [weak self] in
                            dismissAction()
                            self?.openAddBotToGroup()
                        }))
                    }
                    if user.username != nil {
                        items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_ShareBot, color: .accent, action: { [weak self] in
                            dismissAction()
                            self?.openShareBot()
                        }))
                    }
                    
                    if let cachedData = data.cachedData as? CachedUserData, let botInfo = cachedData.botInfo {
                        for command in botInfo.commands {
                            if command.text == "settings" {
                                items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_BotSettings, color: .accent, action: { [weak self] in
                                    dismissAction()
                                    self?.performBotCommand(command: .settings)
                                }))
                            } else if command.text == "help" {
                                items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_BotHelp, color: .accent, action: { [weak self] in
                                    dismissAction()
                                    self?.performBotCommand(command: .help)
                                }))
                            } else if command.text == "privacy" {
                                items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_BotPrivacy, color: .accent, action: { [weak self] in
                                    dismissAction()
                                    self?.performBotCommand(command: .privacy)
                                }))
                            }
                        }
                    }
                }
                
                if user.botInfo == nil && data.isContact {
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Profile_ShareContactButton, color: .accent, action: { [weak self] in
                        dismissAction()
                        guard let strongSelf = self else {
                            return
                        }
                        if let peer = strongSelf.data?.peer as? TelegramUser, let phone = peer.phone {
                            let contact = TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)
                            let shareController = ShareController(context: strongSelf.context, subject: .media(.standalone(media: contact)))
                            strongSelf.controller?.present(shareController, in: .window(.root))
                        }
                    }))
                }
                
                if self.peerId.namespace == Namespaces.Peer.CloudUser && user.botInfo == nil && !user.flags.contains(.isSupport) {
                    items.append(ActionSheetButtonItem(title: presentationData.strings.UserInfo_StartSecretChat, color: .accent, action: { [weak self] in
                        dismissAction()
                        self?.openStartSecretChat()
                    }))
                    if data.isContact {
                        items.append(ActionSheetButtonItem(title: presentationData.strings.Conversation_BlockUser, color: .destructive, action: { [weak self] in
                            dismissAction()
                            self?.updateBlocked(block: true)
                        }))
                    }
                }
            } else if let channel = peer as? TelegramChannel {
                if let cachedData = self.data?.cachedData as? CachedChannelData, cachedData.flags.contains(.canViewStats) {
                    items.append(ActionSheetButtonItem(title: presentationData.strings.ChannelInfo_Stats, color: .accent, action: { [weak self] in
                        dismissAction()
                        self?.openStats()
                    }))
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
                    items.append(ActionSheetButtonItem(title: presentationData.strings.ReportPeer_Report, color: .destructive, action: { [weak self] in
                        dismissAction()
                        self?.openReport(user: false)
                    }))
                }
                
                switch channel.info {
                case .broadcast:
                    if channel.flags.contains(.isCreator) {
                        items.append(ActionSheetButtonItem(title: presentationData.strings.ChannelInfo_DeleteChannel, color: .destructive, action: { [weak self] in
                            dismissAction()
                            self?.openDeletePeer()
                        }))
                    } else {
                        if !peerInfoHeaderButtons(peer: peer, cachedData: data.cachedData, isOpenedFromChat: self.isOpenedFromChat, videoCallsEnabled: self.videoCallsEnabled).contains(.leave) {
                            if case .member = channel.participationStatus {
                                items.append(ActionSheetButtonItem(title: presentationData.strings.Channel_LeaveChannel, color: .destructive, action: { [weak self] in
                                    dismissAction()
                                    self?.openLeavePeer()
                                }))
                            }
                        }
                    }
                case .group:
                    if channel.flags.contains(.isCreator) {
                        items.append(ActionSheetButtonItem(title: presentationData.strings.ChannelInfo_DeleteGroup, color: .destructive, action: { [weak self] in
                            dismissAction()
                            self?.openDeletePeer()
                        }))
                    } else {
                        if case .member = channel.participationStatus {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Group_LeaveGroup, color: .destructive, action: { [weak self] in
                                dismissAction()
                                self?.openLeavePeer()
                            }))
                        }
                    }
                }
            } else if let group = peer as? TelegramGroup {
                if case .Member = group.membership {
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Group_LeaveGroup, color: .destructive, action: { [weak self] in
                        dismissAction()
                        self?.openLeavePeer()
                    }))
                }
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            self.view.endEditing(true)
            controller.present(actionSheet, in: .window(.root))
        case .addMember:
            self.openAddMember()
        case .search:
            self.openChatWithMessageSearch()
        case .leave:
            self.openLeavePeer()
        }
    }
    
    private func openChatWithMessageSearch() {
        if let navigationController = (self.controller?.navigationController as? NavigationController) {
            let _ = (self.preloadedSticker.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] sticker in
                if let strongSelf = self {
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), keepStack: strongSelf.nearbyPeerDistance != nil ? .always : .default, activateMessageSearch: (.everything, ""), peerNearbyData:  strongSelf.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0, sticker: sticker) }), completion: { _ in
                        if strongSelf.nearbyPeerDistance != nil {
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
            })
        }
    }
    
    private func openStartSecretChat() {
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, PeerId?) in
            let peer = transaction.getPeer(peerId)
            let filteredPeerIds = Array(transaction.getAssociatedPeerIds(peerId)).filter { $0.namespace == Namespaces.Peer.SecretChat }
            var activeIndices: [ChatListIndex] = []
            for associatedId in filteredPeerIds {
                if let state = (transaction.getPeer(associatedId) as? TelegramSecretChat)?.embeddedState {
                    switch state {
                        case .active, .handshake:
                            if let (_, index) = transaction.getPeerChatListIndex(associatedId) {
                                activeIndices.append(index)
                            }
                        default:
                            break
                    }
                }
            }
            activeIndices.sort()
            if let index = activeIndices.last {
                return (peer, index.messageIndex.id.peerId)
            } else {
                return (peer, nil)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer, currentPeerId in
            guard let strongSelf = self else {
                return
            }
            if let currentPeerId = currentPeerId {
                if let navigationController = (strongSelf.controller?.navigationController as? NavigationController) {
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(currentPeerId)))
                }
            } else if let controller = strongSelf.controller {
                let displayTitle = peer?.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder) ?? ""
                controller.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.UserInfo_StartSecretChatConfirmation(displayTitle).0, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.UserInfo_StartSecretChatStart, action: {
                    guard let strongSelf = self else {
                        return
                    }
                    var createSignal = createSecretChat(account: strongSelf.context.account, peerId: peerId)
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
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId)))
                        }
                    }, error: { _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }))
                })]), in: .window(.root))
            }
        })
    }
    
    private func openUsername(value: String) {
        let shareController = ShareController(context: self.context, subject: .url("https://t.me/\(value)"))
        self.view.endEditing(true)
        self.controller?.present(shareController, in: .window(.root))
    }
    
    private func requestCall(isVideo: Bool) {
        guard let peer = self.data?.peer as? TelegramUser, let cachedUserData = self.data?.cachedData as? CachedUserData else {
            return
        }
        if cachedUserData.callsPrivate {
            self.controller?.present(textAlertController(context: self.context, title: self.presentationData.strings.Call_ConnectionErrorTitle, text: self.presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            return
        }
            
        let callResult = self.context.sharedContext.callManager?.requestCall(context: self.context, peerId: peer.id, isVideo: isVideo, endCurrentIfAny: false)
        if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
            if currentPeerId == peer.id {
                self.context.sharedContext.navigateToCurrentCall()
            } else {
                let presentationData = self.presentationData
                let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, Peer?) in
                    return (transaction.getPeer(peer.id), currentPeerId.flatMap(transaction.getPeer))
                } |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                    if let peer = peer {
                        if let strongSelf = self, let current = current {
                            strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                if let strongSelf = self {
                                    let _ = strongSelf.context.sharedContext.callManager?.requestCall(context: strongSelf.context, peerId: peer.id, isVideo: isVideo, endCurrentIfAny: true)
                                }
                            })]), in: .window(.root))
                        } else if let strongSelf = self {
                            strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_ExternalCallInProgressMessage, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                            })]), in: .window(.root))
                        }
                    }
                })
                
                /*let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, Peer?) in
                    return (transaction.getPeer(peer.id), transaction.getPeer(currentPeerId))
                }
                |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                    guard let strongSelf = self else {
                        return
                    }
                    if let peer = peer, let current = current {
                        strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Call_CallInProgressTitle, text: strongSelf.presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.sharedContext.callManager?.requestCall(context: strongSelf.context, peerId: peer.id, isVideo: isVideo, endCurrentIfAny: true)
                        })]), in: .window(.root))
                    }
                })*/
            }
        }
    }
    
    private func openPhone(value: String) {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self else {
                return
            }
            if let peer = peer as? TelegramUser, let peerPhoneNumber = peer.phone, formatPhoneNumber(value) == formatPhoneNumber(peerPhoneNumber) {
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
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
            let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
            let globalSettings: GlobalNotificationSettings = (transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications) as? GlobalNotificationSettings) ?? GlobalNotificationSettings.defaultSettings
            return (peerSettings, globalSettings)
        }
        |> deliverOnMainQueue).start(next: { [weak self] peerSettings, globalSettings in
            guard let strongSelf = self else {
                return
            }
            let muteSettingsController = notificationMuteSettingsController(presentationData: strongSelf.presentationData, notificationSettings: globalSettings.effective.groupChats, soundSettings: nil, openSoundSettings: {
                guard let strongSelf = self else {
                    return
                }
                let soundController = notificationSoundSelectionController(context: strongSelf.context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = updatePeerNotificationSoundInteractive(account: strongSelf.context.account, peerId: strongSelf.peerId, sound: sound).start()
                })
                soundController.navigationPresentation = .modal
                strongSelf.controller?.push(soundController)
            }, updateSettings: { value in
                guard let strongSelf = self else {
                    return
                }
                let _ = updatePeerMuteSetting(account: strongSelf.context.account, peerId: strongSelf.peerId, muteInterval: value).start()
            })
            strongSelf.view.endEditing(true)
            strongSelf.controller?.present(muteSettingsController, in: .window(.root))
        })
    }
    
    private func editingOpenSoundSettings() {
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
            let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
            let globalSettings: GlobalNotificationSettings = (transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications) as? GlobalNotificationSettings) ?? GlobalNotificationSettings.defaultSettings
            return (peerSettings, globalSettings)
        }
        |> deliverOnMainQueue).start(next: { [weak self] peerSettings, globalSettings in
            guard let strongSelf = self else {
                return
            }
            
            let soundController = notificationSoundSelectionController(context: strongSelf.context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                guard let strongSelf = self else {
                    return
                }
                let _ = updatePeerNotificationSoundInteractive(account: strongSelf.context.account, peerId: strongSelf.peerId, sound: sound).start()
            })
            strongSelf.controller?.push(soundController)
        })
    }
    
    private func editingToggleShowMessageText(value: Bool) {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            let _ = updatePeerDisplayPreviewsSetting(account: strongSelf.context.account, peerId: peer.id, displayPreviews: value ? .show : .hide).start()
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
                    let _ = (getUserPeer(postbox: strongSelf.context.account.postbox, peerId: strongSelf.peerId)
                    |> deliverOnMainQueue).start(next: { peer, _ in
                        guard let peer = peer, let strongSelf = self else {
                            return
                        }
                        let deleteContactFromDevice: Signal<Never, NoError>
                        if let contactDataManager = strongSelf.context.sharedContext.contactDataManager {
                            deleteContactFromDevice = contactDataManager.deleteContactWithAppSpecificReference(peerId: peer.id)
                        } else {
                            deleteContactFromDevice = .complete()
                        }
                        
                        var deleteSignal = deleteContactPeerInteractively(account: strongSelf.context.account, peerId: peer.id)
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
                        |> deliverOnMainQueue).start(completed: {
                            self?.controller?.dismiss()
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
            let _ = (self.preloadedSticker.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] sticker in
                if let strongSelf = self {
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), keepStack: strongSelf.nearbyPeerDistance != nil ? .always : .default, peerNearbyData: strongSelf.nearbyPeerDistance.flatMap({ ChatPeerNearbyData(distance: $0, sticker: sticker) }), completion: { _ in
                        if strongSelf.nearbyPeerDistance != nil {
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
            })
        }
    }
    
    private func openAddContact() {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
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
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: self.peerId)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            
            let presentationData = strongSelf.presentationData
            if let peer = peer as? TelegramUser, let _ = peer.botInfo {
                strongSelf.activeActionDisposable.set(requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.id, isBlocked: block).start())
                if !block {
                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
                    if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer.id)))
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
                            ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(peer.compactDisplayTitle).0),
                            ActionSheetButtonItem(title: presentationData.strings.UserInfo_BlockActionTitle(peer.compactDisplayTitle).0, color: .destructive, action: {
                                dismissAction()
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.activeActionDisposable.set(requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.id, isBlocked: true).start())
                                if deleteChat {
                                    let _ = removePeerChat(account: strongSelf.context.account, peerId: strongSelf.peerId, reportChatSpam: reportSpam).start()
                                    (strongSelf.controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
                                } else if reportSpam {
                                    let _ = reportPeer(account: strongSelf.context.account, peerId: strongSelf.peerId, reason: .spam).start()
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
                        text = presentationData.strings.UserInfo_BlockConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).0
                    } else {
                        text = presentationData.strings.UserInfo_UnblockConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).0
                    }
                    strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Yes, action: {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.activeActionDisposable.set(requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.id, isBlocked: block).start())
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
        
        let statsController: ViewController
        if let channel = peer as? TelegramChannel, case .group = channel.info {
            statsController = groupStatsController(context: self.context, peerId: peer.id, cachedPeerData: cachedData)
        } else {
            statsController = channelStatsController(context: self.context, peerId: peer.id, cachedPeerData: cachedData)
        }
        controller.push(statsController)
    }
    
    private func openReport(user: Bool) {
        guard let controller = self.controller else {
            return
        }
        self.view.endEditing(true)
        
        let options: [PeerReportOption]
        if user {
            options = [.spam, .violence, .pornography, .childAbuse]
        } else {
            options = [.spam, .violence, .pornography, .childAbuse, .copyright, .other]
        }
        controller.present(peerReportOptionsController(context: self.context, subject: .peer(self.peerId), options: options, present: { [weak controller] c, a in
            controller?.present(c, in: .window(.root), with: a)
        }, push: { [weak controller] c in
            controller?.push(c)
        }, completion: { _ in }), in: .window(.root))
    }
    
    private func openEncryptionKey() {
        guard let data = self.data, let peer = data.peer, let encryptionKeyFingerprint = data.encryptionKeyFingerprint else {
            return
        }
        self.controller?.push(SecretChatKeyController(context: self.context, fingerprint: encryptionKeyFingerprint, peer: peer))
    }
    
    private func openShareBot() {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self else {
                return
            }
            if let peer = peer as? TelegramUser, let username = peer.username {
                let shareController = ShareController(context: strongSelf.context, subject: .url("https://t.me/\(username)"))
                strongSelf.view.endEditing(true)
                strongSelf.controller?.present(shareController, in: .window(.root))
            }
        })
    }
    
    private func openAddBotToGroup() {
        guard let controller = self.controller else {
            return
        }
        context.sharedContext.openResolvedUrl(.groupBotStart(peerId: peerId, payload: ""), context: self.context, urlContext: .generic, navigationController: controller.navigationController as? NavigationController, openPeer: { id, navigation in
        }, sendFile: nil,
        sendSticker: nil,
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
            let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: [.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
            
            if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId)))
            }
        })
    }
    
    private func editingOpenPublicLinkSetup() {
        self.controller?.push(channelVisibilityController(context: self.context, peerId: self.peerId, mode: .generic, upgradedToSupergroup: { _, f in f() }))
    }
    
    private func editingOpenDiscussionGroupSetup() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        self.controller?.push(channelDiscussionGroupSetupController(context: self.context, peerId: peer.id))
    }
    
    private func editingToggleMessageSignatures(value: Bool) {
        self.toggleShouldChannelMessagesSignaturesDisposable.set(toggleShouldChannelMessagesSignatures(account: self.context.account, peerId: self.peerId, enabled: value).start())
    }
    
    private func openParticipantsSection(section: PeerInfoParticipantsSection) {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        switch section {
        case .members:
            self.controller?.push(channelMembersController(context: self.context, peerId: self.peerId))
        case .admins:
            if peer is TelegramGroup {
                self.controller?.push(channelAdminsController(context: self.context, peerId: self.peerId))
            } else if peer is TelegramChannel {
                self.controller?.push(channelAdminsController(context: self.context, peerId: self.peerId))
            }
        case .banned:
            self.controller?.push(channelBlacklistController(context: self.context, peerId: self.peerId))
        }
    }
    
    private func editingOpenPreHistorySetup() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        var upgradedToSupergroupImpl: (() -> Void)?
        let controller = groupPreHistorySetupController(context: self.context, peerId: peer.id, upgradedToSupergroup: { _, f in
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
    
    private func openPermissions() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        self.controller?.push(channelPermissionsController(context: self.context, peerId: peer.id))
    }
    
    private func editingOpenStickerPackSetup() {
        guard let data = self.data, let peer = data.peer, let cachedData = data.cachedData as? CachedChannelData else {
            return
        }
        self.controller?.push(groupStickerPackSetupController(context: self.context, peerId: peer.id, currentPackInfo: cachedData.stickerPack))
    }
    
    private func openLocation() {
        guard let data = self.data, let peer = data.peer, let cachedData = data.cachedData as? CachedChannelData, let location = cachedData.peerGeoLocation else {
            return
        }
        let context = self.context
        let presentationData = self.presentationData
        let mapMedia = TelegramMediaMap(latitude: location.latitude, longitude: location.longitude, geoPlace: nil, venue: MapVenue(title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), address: location.address, provider: nil, id: nil, type: nil), liveBroadcastingTimeout: nil)
        let locationController = legacyLocationController(message: nil, mapMedia: mapMedia, context: context, openPeer: { _ in }, sendLiveLocation: { _, _ in }, stopLiveLocation: {}, openUrl: { url in
            context.sharedContext.applicationBindings.openUrl(url)
        })
        self.controller?.push(locationController)
    }
    
    private func editingOpenSetupLocation() {
        guard let data = self.data, let peer = data.peer else {
            return
        }
        let presentationData = self.presentationData
        let locationController = legacyLocationPickerController(context: self.context, selfPeer: peer, peer: peer, sendLocation: { [weak self] coordinate, _, address in
            guard let strongSelf = self else {
                return
            }
            let addressSignal: Signal<String, NoError>
            if let address = address {
                addressSignal = .single(address)
            } else {
                addressSignal = reverseGeocodeLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                |> map { placemark in
                    if let placemark = placemark {
                        return placemark.fullAddress
                    } else {
                        return "\(coordinate.latitude), \(coordinate.longitude)"
                    }
                }
            }
            
            let context = strongSelf.context
            let _ = (addressSignal
            |> mapToSignal { address -> Signal<Bool, NoError> in
                return updateChannelGeoLocation(postbox: context.account.postbox, network: context.account.network, channelId: peer.id, coordinate: (coordinate.latitude, coordinate.longitude), address: address)
            }
            |> deliverOnMainQueue).start()
        }, sendLiveLocation: { _, _ in }, theme: presentationData.theme, customLocationPicker: true, presentationCompleted: {
        })
        self.controller?.push(locationController)
    }
    
    private func openPeerInfo(peer: Peer, isMember: Bool) {
        var mode: PeerInfoControllerMode = .generic
        if isMember {
            mode = .group(self.peerId)
        }
        if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, peer: peer, mode: mode, avatarInitiallyExpanded: false, fromChat: false) {
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
                self.controller?.push(channelAdminController(context: self.context, peerId: peer.id, adminId: member.id, initialParticipant: channelMember.participant, updated: { _ in
                }, upgradedToSupergroup: { _, f in f() }, transferedOwnership: { _ in }))
            }
        case .restrict:
            if case let .channelMember(channelMember) = member {
                self.controller?.push(channelBannedMemberController(context: self.context, peerId: peer.id, memberId: member.id, initialParticipant: channelMember.participant, updated: { _ in
                }, upgradedToSupergroup: { _, f in f() }))
            }
        case .remove:
            data.members?.membersContext.removeMember(memberId: member.id)
        }
    }
    
    private func openPeerInfoContextMenu(subject: PeerInfoContextSubject, sourceNode: ASDisplayNode) {
        guard let data = self.data, let peer = data.peer, let controller = self.controller else {
            return
        }
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
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = text
                })])
                controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                    if let controller = self?.controller, let sourceNode = sourceNode {
                        return (sourceNode, sourceNode.bounds.insetBy(dx: 0.0, dy: -2.0), controller.displayNode, controller.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
        case let .phone(phone):
            let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: {
                UIPasteboard.general.string = phone
            })])
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    return (sourceNode, sourceNode.bounds.insetBy(dx: 0.0, dy: -2.0), controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        case .link:
            if let addressName = peer.addressName {
                let text: String
                if peer is TelegramChannel {
                    text = "https://t.me/\(addressName)"
                } else {
                    text = "@" + addressName
                }
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = text
                })])
                controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                    if let controller = self?.controller, let sourceNode = sourceNode {
                        return (sourceNode, sourceNode.bounds.insetBy(dx: 0.0, dy: -2.0), controller.displayNode, controller.view.bounds)
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
    
    private func requestLayout() {
        self.headerNode.requestUpdateLayout?()
    }
    
    private func openDeletePeer() {
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            var isGroup = false
            if let channel = peer as? TelegramChannel {
                if case .group = channel.info {
                    isGroup = true
                }
            } else if peer is TelegramGroup {
                isGroup = true
            }
            let presentationData = strongSelf.presentationData
            let actionSheet = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: isGroup ? presentationData.strings.ChannelInfo_DeleteGroupConfirmation : presentationData.strings.ChannelInfo_DeleteChannelConfirmation),
                    ActionSheetButtonItem(title: isGroup ? presentationData.strings.ChannelInfo_DeleteGroup : presentationData.strings.ChannelInfo_DeleteChannel, color: .destructive, action: {
                        dismissAction()
                        self?.deletePeerChat(peer: peer, globally: true)
                    }),
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            strongSelf.view.endEditing(true)
            strongSelf.controller?.present(actionSheet, in: .window(.root))
        })
    }
    
    private func openLeavePeer() {
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else {
                return
            }
            var isGroup = false
            if let channel = peer as? TelegramChannel {
                if case .group = channel.info {
                    isGroup = true
                }
            } else if peer is TelegramGroup {
                isGroup = true
            }
            let presentationData = strongSelf.presentationData
            let actionSheet = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: isGroup ? presentationData.strings.Group_LeaveGroup : presentationData.strings.Channel_LeaveChannel, color: .destructive, action: {
                        dismissAction()
                        self?.deletePeerChat(peer: peer, globally: false)
                    }),
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            strongSelf.view.endEditing(true)
            strongSelf.controller?.present(actionSheet, in: .window(.root))
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
                chatListController.maybeAskForPeerChatRemoval(peer: RenderedPeer(peer: peer), joined: false, deleteGloballyIfPossible: globally, completion: { [weak navigationController] deleted in
                    if deleted {
                        navigationController?.popToRoot(animated: true)
                    }
                }, removed: {
                })
                break
            }
        }
    }
    
    private func deleteAvatar(_ item: PeerInfoAvatarListItem, remove: Bool = true) {
        if self.data?.peer?.id == self.context.account.peerId {
            if case let .image(reference, _, _, _) = item {
                if let reference = reference {
                    if remove {
                        let _ = removeAccountPhoto(network: self.context.account.network, reference: reference).start()
                    }
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
        
        let resource = LocalFileMediaResource(fileId: arc4random64())
        self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [])
        
        self.state = self.state.withUpdatingAvatar(.image(representation))
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
        }
        self.headerNode.ignoreCollapse = false
        
        let postbox = self.context.account.postbox
        let signal = self.isSettings ? updateAccountPhoto(account: self.context.account, resource: resource, videoResource: nil, videoStartTimestamp: nil, mapResourceToAvatarSizes: { resource, representations in
            return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
        }) : updatePeerPhoto(postbox: postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peerId, photo: uploadedPeerPhoto(postbox: postbox, network: self.context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
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
        
        let photoResource = LocalFileMediaResource(fileId: arc4random64())
        self.context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [])
        
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
        let signal = Signal<TelegramMediaResource, UploadPeerPhotoError> { [weak self] subscriber in
            let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                    return LegacyPaintEntityRenderer(account: account, adjustments: adjustments)
                } else {
                    return nil
                }
            }
            let uploadInterface = LegacyLiveUploadInterface(account: account)
            let signal: SSignal
            if let asset = asset as? AVAsset {
                signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, watcher: uploadInterface, entityRenderer: entityRenderer)!
            } else if let url = asset as? URL, let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
                let durationSignal: SSignal = SSignal(generator: { subscriber in
                    let disposable = (entityRenderer.duration()).start(next: { duration in
                        subscriber?.putNext(duration)
                        subscriber?.putCompletion()
                    })
                    
                    return SBlockDisposable(block: {
                        disposable.dispose()
                    })
                })
                signal = durationSignal.map(toSignal: { duration -> SSignal? in
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
                                resource = LocalFileMediaResource(fileId: arc4random64())
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
                return updateAccountPhoto(account: account, resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            } else {
                return updatePeerPhoto(postbox: account.postbox, network: account.network, stateManager: account.stateManager, accountPeerId: account.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: account.postbox, network: account.network, resource: photoResource), video: uploadedPeerVideo(postbox: account.postbox, network: account.network, messageMediaPreuploadManager: account.messageMediaPreuploadManager, resource: videoResource) |> map(Optional.init), videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { resource, representations in
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
        if let item = item, case let .image(image) = item {
            currentIsVideo = !image.2.isEmpty
        }
        
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, SearchBotsConfiguration) in
            return (transaction.getPeer(peerId), currentSearchBotsConfiguration(transaction: transaction))
        }
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
                    completion?(coder.makeData(), fileReference.media.isAnimatedSticker, node.view, rect)
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
                let controller = WebSearchController(context: strongSelf.context, peer: peer, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: strongSelf.isSettings ? nil : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), completion: { [weak self] result in
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
                        strongSelf.deleteAvatar(item, remove: false)
                    }
                    
                    let _ = strongSelf.currentAvatarMixin.swap(nil)
                    if let _ = peer.smallProfileImage {
                        strongSelf.state = strongSelf.state.withUpdatingAvatar(nil)
                        if let (layout, navigationHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                        }
                    }
                    let postbox = strongSelf.context.account.postbox
                    strongSelf.updateAvatarDisposable.set((updatePeerPhoto(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, stateManager: strongSelf.context.account.stateManager, accountPeerId: strongSelf.context.account.peerId, peerId: strongSelf.peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
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
        guard let data = self.data, let groupPeer = data.peer else {
            return
        }
        
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
        |> deliverOnMainQueue).start(next: { [weak self] recentIds in
            guard let strongSelf = self else {
                return
            }
            var createInviteLinkImpl: (() -> Void)?
            var confirmationImpl: ((PeerId) -> Signal<Bool, NoError>)?
            var options: [ContactListAdditionalOption] = []
            let presentationData = strongSelf.presentationData
            
            var canCreateInviteLink = false
            if let group = groupPeer as? TelegramGroup {
                switch group.role {
                case .creator, .admin:
                    canCreateInviteLink = true
                default:
                    break
                }
            } else if let channel = groupPeer as? TelegramChannel {
                if channel.hasPermission(.inviteMembers) {
                    if channel.flags.contains(.isCreator) || (channel.adminRights != nil && channel.username == nil) {
                        canCreateInviteLink = true
                    }
                }
            }
            
            if canCreateInviteLink {
                options.append(ContactListAdditionalOption(title: presentationData.strings.GroupInfo_InviteByLink, icon: .generic(UIImage(bundleImageName: "Contact List/LinkActionIcon")!), action: {
                    createInviteLinkImpl?()
                }))
            }
            
            let contactsController: ViewController
            if groupPeer.id.namespace == Namespaces.Peer.CloudGroup {
                contactsController = strongSelf.context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: strongSelf.context, autoDismiss: false, title: { $0.GroupInfo_AddParticipantTitle }, options: options, confirmation: { peer in
                    if let confirmationImpl = confirmationImpl, case let .peer(peer, _, _) = peer {
                        return confirmationImpl(peer.id)
                    } else {
                        return .single(false)
                    }
                }))
                contactsController.navigationPresentation = .modal
            } else {
                contactsController = strongSelf.context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: strongSelf.context, mode: .peerSelection(searchChatList: false, searchGroups: false, searchChannels: false), options: options, filters: [.excludeSelf, .disable(recentIds)]))
                contactsController.navigationPresentation = .modal
            }
            
            let context = strongSelf.context
            confirmationImpl = { [weak contactsController] peerId in
                return context.account.postbox.loadedPeerWithId(peerId)
                |> deliverOnMainQueue
                |> mapToSignal { peer in
                    let result = ValuePromise<Bool>()
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    if let contactsController = contactsController {
                        let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.GroupInfo_AddParticipantConfirmation(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).0, actions: [
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
            
            let addMember: (ContactListPeer) -> Signal<Void, NoError> = { memberPeer -> Signal<Void, NoError> in
                if case let .peer(selectedPeer, _, _) = memberPeer {
                    let memberId = selectedPeer.id
                    if groupPeer.id.namespace == Namespaces.Peer.CloudChannel {
                        return context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: groupPeer.id, memberId: memberId)
                        |> map { _ -> Void in
                        }
                        |> `catch` { _ -> Signal<Void, NoError> in
                            return .complete()
                        }
                    } else {
                        return addGroupMember(account: context.account, peerId: groupPeer.id, memberId: memberId)
                        |> deliverOnMainQueue
                        |> `catch` { error -> Signal<Void, NoError> in
                            switch error {
                            case .generic:
                                return .complete()
                            case .privacy:
                                let _ = (context.account.postbox.loadedPeerWithId(memberId)
                                |> deliverOnMainQueue).start(next: { peer in
                                    self?.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(peer.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                })
                                return .complete()
                            case .notMutualContact:
                                let _ = (context.account.postbox.loadedPeerWithId(memberId)
                                |> deliverOnMainQueue).start(next: { peer in
                                    self?.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.GroupInfo_AddUserLeftError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                })
                                return .complete()
                            case .tooManyChannels:
                                let _ = (context.account.postbox.loadedPeerWithId(memberId)
                                |> deliverOnMainQueue).start(next: { peer in
                                    self?.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                })
                                return .complete()
                            case .groupFull:
                                let signal = convertGroupToSupergroup(account: context.account, peerId: groupPeer.id)
                                |> map(Optional.init)
                                |> `catch` { error -> Signal<PeerId?, NoError> in
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
                                    return context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: upgradedPeerId, memberId: memberId)
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
                        return context.peerChannelMemberCategoriesContextsManager.addMember(account: context.account, peerId: groupPeer.id, memberId: memberIds[0])
                        |> map { _ -> Void in
                        }
                    } else {
                        return context.peerChannelMemberCategoriesContextsManager.addMembers(account: context.account, peerId: groupPeer.id, memberIds: memberIds) |> map { _ in
                        }
                    }
                }
            }
            
            createInviteLinkImpl = { [weak contactsController] in
                guard let strongSelf = self else {
                    return
                }
                let mode: ChannelVisibilityControllerMode
                if groupPeer.addressName != nil {
                    mode = .generic
                } else {
                    mode = .privateLink
                }
                let visibilityController = channelVisibilityController(context: strongSelf.context, peerId: groupPeer.id, mode: mode, upgradedToSupergroup: { _, f in f() }, onDismissRemoveController: contactsController)
                //visibilityController.navigationPresentation = .modal
                
                contactsController?.push(visibilityController)
                
                /*if let navigationController = strongSelf.controller?.navigationController as? NavigationController {
                    var controllers = navigationController.viewControllers
                    if let contactsController = contactsController {
                        controllers.removeAll(where: { $0 === contactsController })
                    }
                    controllers.append(visibilityController)
                    navigationController.setViewControllers(controllers, animated: true)
                }*/
            }

            strongSelf.controller?.push(contactsController)
            let selectAddMemberDisposable = strongSelf.selectAddMemberDisposable
            let addMemberDisposable = strongSelf.addMemberDisposable
            if let contactsController = contactsController as? ContactSelectionController {
                selectAddMemberDisposable.set((contactsController.result
                |> deliverOnMainQueue).start(next: { [weak contactsController] memberPeer in
                    guard let (memberPeer, _) = memberPeer else {
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
                                        self?.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_GroupsAndChannels_InviteToGroupError(peer.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    })
                                default:
                                    break
                            }
                        } else if peers.count == 1, case .notMutualContact = error {
                            self?.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.GroupInfo_AddUserLeftError, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        } else if case .tooMuchJoined = error  {
                            self?.controller?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        }
                        
                        contactsController?.dismiss()
                    },completed: {
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
    
    fileprivate func openSettings(section: PeerInfoSettingsSection) {
        switch section {
            case .avatar:
                self.openAvatarForEditing()
            case .edit:
                self.headerNode.navigationButtonContainer.performAction?(.edit)
            case .proxy:
                self.controller?.push(proxySettingsController(context: self.context))
            case .savedMessages:
                if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(self.context.account.peerId)))
                }
            case .recentCalls:
                self.controller?.push(CallListController(context: context, mode: .navigation))
            case .devices:
                if let settings = self.data?.globalSettings {
                    let _ = (self.activeSessionsContextAndCount.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] activeSessionsContextAndCount in
                        if let strongSelf = self, let activeSessionsContextAndCount = activeSessionsContextAndCount {
                            let (activeSessionsContext, count, webSessionsContext) = activeSessionsContextAndCount
                            if count == 0 && settings.enableQRLogin {
                                strongSelf.controller?.push(AuthDataTransferSplashScreen(context: strongSelf.context, activeSessionsContext: activeSessionsContext))
                            } else {
                                strongSelf.controller?.push(recentSessionsController(context: strongSelf.context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext, websitesOnly: false))
                            }
                        }
                    })
                }
            case .chatFolders:
                self.controller?.push(chatListFilterPresetListController(context: self.context, mode: .default))
            case .notificationsAndSounds:
                if let settings = self.data?.globalSettings {
                    self.controller?.push(notificationsAndSoundsController(context: self.context, exceptionsList: settings.notificationExceptions))
                }
            case .privacyAndSecurity:
                if let settings = self.data?.globalSettings {
                    let _ = (combineLatest(self.blockedPeers.get(), self.hasTwoStepAuth.get())
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] blockedPeersContext, hasTwoStepAuth in
                        if let strongSelf = self {
                            strongSelf.controller?.push(privacyAndSecurityController(context: strongSelf.context, initialSettings: settings.privacySettings, updatedSettings: { [weak self] settings in
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
                self.controller?.push(dataAndStorageController(context: self.context))
            case .appearance:
                self.controller?.push(themeSettingsController(context: self.context))
            case .language:
                self.controller?.push(LocalizationListController(context: self.context))
            case .stickers:
                if let settings = self.data?.globalSettings {
                    self.controller?.push(installedStickerPacksController(context: self.context, mode: .general, archivedPacks: settings.archivedStickerPacks, updatedPacks: { [weak self] packs in
                        self?.archivedPacks.set(.single(packs))
                    }))
                }
            case .passport:
                self.controller?.push(SecureIdAuthController(context: self.context, mode: .list))
            case .watch:
                self.controller?.push(watchSettingsController(context: self.context))
            case .support:
                let supportPeer = Promise<PeerId?>()
                supportPeer.set(supportPeerId(account: context.account))
                
                self.controller?.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Settings_FAQ_Intro, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Settings_FAQ_Button, action: { [weak self] in
                    self?.openFaq()
                }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: { [weak self] in
                    self?.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peerId in
                        if let strongSelf = self, let peerId = peerId {
                            strongSelf.controller?.push(strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(peerId), subject: nil, botStart: nil, mode: .standard(previewing: false)))
                        }
                    }))
                })]), in: .window(.root))
            case .faq:
                self.openFaq()
            case .phoneNumber:
                if let user = self.data?.peer as? TelegramUser, let phoneNumber = user.phone {
                    self.controller?.push(ChangePhoneNumberIntroController(context: self.context, phoneNumber: phoneNumber))
                }
            case .username:
                self.controller?.push(usernameSetupController(context: self.context))
            case .addAccount:
                self.context.sharedContext.beginNewAuth(testingEnvironment: self.context.account.testingEnvironment)
            case .logout:
                if let user = self.data?.peer as? TelegramUser, let phoneNumber = user.phone, let accounts = self.data?.globalSettings?.accountsAndPeers {
                    if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                        self.controller?.push(logoutOptionsController(context: self.context, navigationController: navigationController, canAddAccounts: accounts.count + 1 < maximumNumberOfAccounts, phoneNumber: phoneNumber))
                    }
                }
        }
    }
    
    private func openFaq(anchor: String? = nil) {
        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
        self.controller?.present(controller, in: .window(.root))
        let _ = (self.cachedFaq.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self, weak controller] resolvedUrl in
            controller?.dismiss()

            if let strongSelf = self, let resolvedUrl = resolvedUrl {
                var resolvedUrl = resolvedUrl
                if case let .instantView(webPage, _) = resolvedUrl, let customAnchor = anchor {
                    resolvedUrl = .instantView(webPage, customAnchor)
                }
                strongSelf.context.sharedContext.openResolvedUrl(resolvedUrl, context: strongSelf.context, urlContext: .generic, navigationController: strongSelf.controller?.navigationController as? NavigationController, openPeer: { peer, navigation in
                }, sendFile: nil, sendSticker: nil, present: { [weak self] controller, arguments in
                    self?.controller?.push(controller)
                }, dismissInput: {}, contentContext: nil)
            }
        })
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
        return context.account.postbox.transaction { transaction -> [ContextMenuItem] in
            var items: [ContextMenuItem] = []
            
            if !transaction.getUnreadChatListPeerIds(groupId: .root, filterPredicate: nil).isEmpty {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAllAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = (context.account.postbox.transaction { transaction in
                        markAllChatsAsReadInteractively(transaction: transaction, viewTracker: context.account.viewTracker, groupId: .root, filterPredicate: nil)
                    }
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
                if account.id == id {
                    selectedAccount = account
                    break
                }
            }
        })
        if let selectedAccount = selectedAccount {
            let accountContext = self.context.sharedContext.makeTempAccountContext(account: selectedAccount)
            let chatListController = accountContext.sharedContext.makeChatListController(context: accountContext, groupId: .root, controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                    
            let contextController = ContextController(account: accountContext.account, presentationData: self.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node)), items: accountContextMenuItems(context: accountContext, logout: { [weak self] in
                self?.logoutAccount(id: id)
            }), reactionItems: [], gesture: gesture)
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
            self.activeActionDisposable.set((self.context.sharedContext.chatAvailableMessageActions(postbox: self.context.account.postbox, accountPeerId: self.context.account.peerId, messageIds: messageIds)
            |> deliverOnMainQueue).start(next: { [weak self] actions in
                if let strongSelf = self, let peer = strongSelf.data?.peer, !actions.options.isEmpty {
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    var personalPeerName: String?
                    var isChannel = false
                    if let user = peer as? TelegramUser {
                        personalPeerName = user.compactDisplayTitle
                    } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        isChannel = true
                    }
                    
                    if actions.options.contains(.deleteGlobally) {
                        let globalTitle: String
                        if isChannel {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                        } else if let personalPeerName = personalPeerName {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                        } else {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                        }
                        items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
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
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forLocalPeer).start()
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
            let peerSelectionController = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, filter: [.onlyWriteable, .excludeDisabled]))
            peerSelectionController.peerSelected = { [weak self, weak peerSelectionController] peerId in
                if let strongSelf = self, let _ = peerSelectionController {
                    if peerId == strongSelf.context.account.peerId {
                        strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                        
                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                            return .forward(source: id, grouping: .auto, attributes: [])
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
                                |> deliverOnMainQueue).start(completed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.controller?.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .success), in: .window(.root))
                                }))
                            }
                        })
                        if let peerSelectionController = peerSelectionController {
                            peerSelectionController.dismiss()
                        }
                    } else {
                        let _ = (strongSelf.context.account.postbox.transaction({ transaction -> Void in
                            transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                                if let currentState = currentState as? ChatInterfaceState {
                                    return currentState.withUpdatedForwardMessageIds(Array(messageIds))
                                } else {
                                    return ChatInterfaceState().withUpdatedForwardMessageIds(Array(messageIds))
                                }
                            })
                        }) |> deliverOnMainQueue).start(completed: {
                            if let strongSelf = self {
                                strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                                
                                let ready = Promise<Bool>()
                                strongSelf.activeActionDisposable.set((ready.get() |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                    if let peerSelectionController = peerSelectionController {
                                        peerSelectionController.dismiss()
                                    }
                                }))
                                
                                (strongSelf.controller?.navigationController as? NavigationController)?.replaceTopController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(peerId)), animated: false, ready: ready)
                            }
                        })
                    }
                }
            }
            self.controller?.push(peerSelectionController)
        }
    }
    
    private func activateSearch() {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        
        if let _ = self.searchDisplayController {
            return
        }
        
        if self.isSettings {
            if let settings = self.data?.globalSettings {
                self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Settings_Search, hasSeparator: true, contentNode: SettingsSearchContainerNode(context: self.context, openResult: { [weak self] result in
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
                    }, exceptionsList: .single(settings.notificationExceptions), archivedStickerPacks: .single(settings.archivedStickerPacks), privacySettings: .single(settings.privacySettings), hasWallet: .single(false), activeSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.0 }, webSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.2 }), cancel: { [weak self] in
                    self?.deactivateSearch()
                })
            }
        } else if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .members = currentPaneKey {
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, contentNode: ChannelMembersSearchContainerNode(context: self.context, peerId: self.peerId, mode: .searchMembers, filters: [], searchContext: self.groupMembersSearchContext, openPeer: { [weak self] peer, participant in
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
            
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, contentNode: ChatHistorySearchContainerNode(context: self.context, peerId: self.peerId, tagMask: tagMask, interfaceInteraction: self.chatInterfaceInteraction), cancel: { [weak self] in
                self?.deactivateSearch()
            })
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 0.0)
        }
        
        self.searchDisplayController?.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
            if let strongSelf = self, let navigationBar = strongSelf.controller?.navigationBar {
                strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
            }
        }, placeholder: nil)
        
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
        }
    }
    
    private func deactivateSearch() {
        guard let searchDisplayController = self.searchDisplayController else {
            return
        }
        self.searchDisplayController = nil
        searchDisplayController.deactivate(placeholder: nil)
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 1.0)
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
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: transition)
            if !searchDisplayController.isDeactivating {
                //vanillaInsets.top += (layout.statusBarHeight ?? 0.0) - navigationBarHeightDelta
            }
        }
        
        self.ignoreScrolling = true
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sectionSpacing: CGFloat = 24.0
        
        var contentHeight: CGFloat = 0.0
        
        let headerHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: layout.safeInsets.left, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : self.scrollNode.view.contentOffset.y, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, statusData: self.data?.status, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, transition: transition, additive: additive)
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
            let items = self.isSettings ? settingsItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction, isExpanded: self.headerNode.isAvatarExpanded) : infoItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction, nearbyPeerDistance: self.nearbyPeerDistance, callMessages: self.callMessages)
            
            contentHeight += headerHeight
            if !self.isSettings {
                contentHeight += sectionSpacing
            } else if let (section, _) = items.first, let sectionValue = section.base as? SettingsSection, sectionValue != .edit && !self.state.isEditing {
                contentHeight += sectionSpacing
            }
                        
            for (sectionId, sectionItems) in items {
                validRegularSections.append(sectionId)
                
                let sectionNode: PeerInfoScreenItemSectionContainerNode
                if let current = self.regularSections[sectionId] {
                    sectionNode = current
                } else {
                    sectionNode = PeerInfoScreenItemSectionContainerNode()
                    self.regularSections[sectionId] = sectionNode
                    self.scrollNode.addSubnode(sectionNode)
                }
                
                let sectionHeight = sectionNode.update(width: layout.size.width, safeInsets: layout.safeInsets, presentationData: self.presentationData, items: sectionItems, transition: transition)
                let sectionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: sectionHeight))
                if additive {
                    transition.updateFrameAdditive(node: sectionNode, frame: sectionFrame)
                } else {
                    transition.updateFrame(node: sectionNode, frame: sectionFrame)
                }
                
                transition.updateAlpha(node: sectionNode, alpha: self.state.isEditing ? 0.0 : 1.0)
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
                    sectionNode.removeFromSupernode()
                }
            }
            
            var validEditingSections: [AnyHashable] = []
            let editItems = self.isSettings ? settingsEditingItems(data: self.data, state: self.state, context: self.context, presentationData: self.presentationData, interaction: self.interaction) : editingItems(data: self.data, context: self.context, presentationData: self.presentationData, interaction: self.interaction)

            for (sectionId, sectionItems) in editItems {
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
                                
                let sectionHeight = sectionNode.update(width: layout.size.width, safeInsets: layout.safeInsets, presentationData: self.presentationData, items: sectionItems, transition: transition)
                let sectionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: sectionHeight))
                
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
                selectionPanelNode = PeerInfoSelectionPanelNode(context: self.context, peerId: self.peerId, deleteMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.deleteMessages(messageIds: nil)
                }, shareMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Message] in
                        var messages: [Message] = []
                        for id in messageIds {
                            if let message = transaction.getMessage(id) {
                                messages.append(message)
                            }
                        }
                        return messages
                    }
                    |> deliverOnMainQueue).start(next: { messages in
                        if let strongSelf = self, !messages.isEmpty {
                            strongSelf.headerNode.navigationButtonContainer.performAction?(.selectionDone)
                            
                            let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                                return lhs.index < rhs.index
                            })), externalShare: true, immediateExternalShare: true)
                            strongSelf.view.endEditing(true)
                            strongSelf.controller?.present(shareController, in: .window(.root))
                        }
                    })
                }, forwardMessages: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.forwardMessages(messageIds: nil)
                }, reportMessages: { [weak self] in
                    guard let strongSelf = self, let messageIds = strongSelf.state.selectedMessageIds, !messageIds.isEmpty else {
                        return
                    }
                    strongSelf.view.endEditing(true)
                    strongSelf.controller?.present(peerReportOptionsController(context: strongSelf.context, subject: .messages(Array(messageIds).sorted()), present: { c, a in
                        self?.controller?.present(c, in: .window(.root), with: a)
                    }, push: { c in
                        self?.controller?.push(c)
                    }, completion: { _ in }), in: .window(.root))
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
            contentHeight = max(contentHeight, layout.size.height + 140.0 + (self.headerNode.twoLineInfo ? 17.0 : 0.0) - layout.intrinsicInsets.bottom)
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
    
    private func updateNavigation(transition: ContainedViewLayoutTransition, additive: Bool) {
        let offsetY = self.scrollNode.view.contentOffset.y
        
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
                let _ = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: layout.safeInsets.left, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : offsetY, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, statusData: self.data?.status, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, transition: transition, additive: additive)
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
            
            if !self.isSettings {
                transition.updateAlpha(node: self.headerNode.separatorNode, alpha: 1.0 - effectiveAreaExpansionFraction)
            }
            
            let visibleHeight = self.scrollNode.view.contentOffset.y + self.scrollNode.view.bounds.height - self.paneContainerNode.frame.minY
            
            var bottomInset = layout.intrinsicInsets.bottom
            if let selectionPanelNode = self.paneContainerNode.selectionPanelNode {
                bottomInset = max(bottomInset, selectionPanelNode.bounds.height)
            }
                        
            let navigationBarHeight: CGFloat = layout.isModalOverlay ? 56.0 : 44.0
            self.paneContainerNode.update(size: self.paneContainerNode.bounds.size, sideInset: layout.safeInsets.left, bottomInset: bottomInset, visibleHeight: visibleHeight, expansionFraction: effectiveAreaExpansionFraction, presentationData: self.presentationData, data: self.data, transition: transition)
            self.headerNode.navigationButtonContainer.frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: layout.statusBarHeight ?? 0.0), size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight))
            self.headerNode.navigationButtonContainer.isWhite = self.headerNode.isAvatarExpanded
            
            var navigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            if self.state.isEditing {
                navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .done, isForExpandedView: false))
            } else {
                if self.isSettings {
                    navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                    navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
                } else if peerInfoCanEdit(peer: self.data?.peer, cachedData: self.data?.cachedData) {
                    navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
                }
                if self.state.selectedMessageIds == nil {
                    if let currentPaneKey = self.paneContainerNode.currentPaneKey {
                        switch currentPaneKey {
                        case .files, .music, .links, .members:
                            navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .search, isForExpandedView: true))
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
                    navigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .selectionDone, isForExpandedView: true))
                }
            }
            self.headerNode.navigationButtonContainer.update(size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight), presentationData: self.presentationData, buttons: navigationButtons, expandFraction: effectiveAreaExpansionFraction, transition: transition)
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
    
    private let velocityKey: String = encodeText("`wfsujdbmWfmpdjuz", -1)
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrolling {
            return
        }
        
        if !self.state.isEditing {
            if self.canAddVelocity {
                self.previousVelocityM1 = self.previousVelocity
                if let value = (scrollView.value(forKey: self.velocityKey) as? NSNumber)?.doubleValue {
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
            var height: CGFloat = self.isSettings ? 140.0 : 212.0
            if self.headerNode.twoLineInfo {
                height += 17.0
            }
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

public final class PeerInfoScreen: ViewController {
    private let context: AccountContext
    private let peerId: PeerId
    private let avatarInitiallyExpanded: Bool
    private let isOpenedFromChat: Bool
    private let nearbyPeerDistance: Int32?
    private let callMessages: [Message]
    private let isSettings: Bool
    private let ignoreGroupInCommon: PeerId?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let accountsAndPeers = Promise<((Account, Peer)?, [(Account, Peer, Int32)])>()
    private var accountsAndPeersValue: ((Account, Peer)?, [(Account, Peer, Int32)])?
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
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    
    public init(context: AccountContext, peerId: PeerId, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, nearbyPeerDistance: Int32?, callMessages: [Message], isSettings: Bool = false, ignoreGroupInCommon: PeerId? = nil) {
        self.context = context
        self.peerId = peerId
        self.avatarInitiallyExpanded = avatarInitiallyExpanded
        self.isOpenedFromChat = isOpenedFromChat
        self.nearbyPeerDistance = nearbyPeerDistance
        self.callMessages = callMessages
        self.isSettings = isSettings
        self.ignoreGroupInCommon = ignoreGroupInCommon
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        super.init(navigationBarPresentationData: NavigationBarPresentationData(
            theme: NavigationBarTheme(
                buttonColor: avatarInitiallyExpanded ? .white : baseNavigationBarPresentationData.theme.buttonColor,
                disabledButtonColor: baseNavigationBarPresentationData.theme.disabledButtonColor,
                primaryTextColor: baseNavigationBarPresentationData.theme.primaryTextColor,
                backgroundColor: .clear,
                separatorColor: .clear,
                badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
        ), strings: baseNavigationBarPresentationData.strings))
                
        if isSettings {
            let activeSessionsContextAndCountSignal = deferred { () -> Signal<(ActiveSessionsContext, Int, WebSessionsContext)?, NoError> in
                let activeSessionsContext = ActiveSessionsContext(account: context.account)
                let webSessionsContext = WebSessionsContext(account: context.account)
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
                let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
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
            |> map { primaryAndOther, presentationData -> (Account, Peer, PresentationTheme)? in
                if let primary = primaryAndOther.0, !primaryAndOther.1.isEmpty {
                    return (primary.0, primary.1, presentationData.theme)
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged(isEqual: { $0?.0 === $1?.0 && arePeersEqual($0?.1, $1?.1) && $0?.2 === $1?.2 })
            |> mapToSignal { primary -> Signal<(UIImage, UIImage)?, NoError> in
                if let primary = primary {
                    let size = CGSize(width: 31.0, height: 31.0)
                    let inset: CGFloat = 3.0
                    if let signal = peerAvatarImage(account: primary.0, peerReference: PeerReference(primary.1), authorOfMessage: nil, representation: primary.1.profileImageRepresentations.first, displayDimensions: size, inset: 3.0, emptyColor: nil, synchronousLoad: false) {
                        return signal
                        |> map { imageVersions -> (UIImage, UIImage)? in
                            let image = imageVersions?.0
                            if let image = image, let selectedImage = generateImage(size, rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                                context.scaleBy(x: 1.0, y: -1.0)
                                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                                context.draw(image.cgImage!, in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
                                context.setLineWidth(1.0)
                                context.setStrokeColor(primary.2.rootController.tabBar.selectedIconColor.cgColor)
                                context.strokeEllipse(in: CGRect(x: 1.5, y: 1.5, width: 28.0, height: 28.0))
                            }) {
                                return (image.withRenderingMode(.alwaysOriginal), selectedImage.withRenderingMode(.alwaysOriginal))
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
                            
                            let selectedImage = generateImage(size, rotatedContext: { size, context in
                                context.clear(CGRect(origin: CGPoint(), size: size))
                                context.translateBy(x: inset, y: inset)
                                drawPeerAvatarLetters(context: context, size: CGSize(width: size.width - inset * 2.0, height: size.height - inset * 2.0), font: avatarFont, letters: displayLetters, peerId: primary.1.id)
                                context.translateBy(x: -inset, y: -inset)
                                context.setLineWidth(1.0)
                                context.setStrokeColor(primary.2.rootController.tabBar.selectedIconColor.cgColor)
                                context.strokeEllipse(in: CGRect(x: 1.0, y: 1.0, width: 27.0, height: 27.0))
                            })?.withRenderingMode(.alwaysOriginal)
                            
                            subscriber.putNext(image.flatMap { ($0, $0) })
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
            
            let tabBarItem: Signal<(String, UIImage?, UIImage?, String?), NoError> = combineLatest(queue: .mainQueue(), self.context.sharedContext.presentationData, notificationsAuthorizationStatus.get(), notificationsWarningSuppressed.get(), accountTabBarAvatar, accountTabBarAvatarBadge)
            |> map { presentationData, notificationsAuthorizationStatus, notificationsWarningSuppressed, accountTabBarAvatar, accountTabBarAvatarBadge -> (String, UIImage?, UIImage?, String?) in
                let notificationsWarning = shouldDisplayNotificationsPermissionWarning(status: notificationsAuthorizationStatus, suppressed:  notificationsWarningSuppressed)
                var otherAccountsBadge: String?
                if accountTabBarAvatarBadge > 0 {
                    otherAccountsBadge = compactNumericCountString(Int(accountTabBarAvatarBadge), decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                }
                return (presentationData.strings.Settings_Title, accountTabBarAvatar?.0 ?? icon, accountTabBarAvatar?.1 ?? icon, notificationsWarning ? "!" : otherAccountsBadge)
            }
            
            self.tabBarItemDisposable = (tabBarItem |> deliverOnMainQueue).start(next: { [weak self] title, image, selectedImage, badgeValue in
                if let strongSelf = self {
                    strongSelf.tabBarItem.title = title
                    strongSelf.tabBarItem.image = image
                    strongSelf.tabBarItem.selectedImage = selectedImage
                    strongSelf.tabBarItem.badgeValue = badgeValue
                }
            })
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
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.controllerNode.updatePresentationData(strongSelf.presentationData)
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
        self.displayNode = PeerInfoScreenNode(controller: self, context: self.context, peerId: self.peerId, avatarInitiallyExpanded: self.avatarInitiallyExpanded, isOpenedFromChat: self.isOpenedFromChat, nearbyPeerDistance: self.nearbyPeerDistance, callMessages: self.callMessages, isSettings: self.isSettings, ignoreGroupInCommon: self.ignoreGroupInCommon)
        self.controllerNode.accountsAndPeers.set(self.accountsAndPeers.get() |> map { $0.1 })
        self.controllerNode.activeSessionsContextAndCount.set(self.activeSessionsContextAndCount.get())
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    public override func didMove(toParent viewController: UIViewController?) {
        super.didMove(toParent: viewController)
        
        if self.isSettings && viewController == nil {
            Queue.mainQueue().after(0.1) {
                self.controllerNode.resetHeaderExpansion()
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = self.isSettings ? (self.navigationBar?.frame.height ?? 0.0) : self.navigationHeight
        self.validLayout = (layout, navigationHeight)
        
        self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
    }
    
    override public func tabBarItemContextAction(sourceNode: ContextExtractedContentContainingNode, gesture: ContextGesture) {
        guard let (maybePrimary, other) = self.accountsAndPeersValue, let primary = maybePrimary else {
            return
        }
        
        let strings = self.presentationData.strings
        
        var items: [ContextMenuItem] = []
        if other.count + 1 < maximumNumberOfAccounts {
            items.append(.action(ContextMenuActionItem(text: strings.Settings_AddAccount, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerNode.openSettings(section: .addAccount)
                f(.dismissWithoutContent)
            })))
        }
        
        func accountIconSignal(account: Account, peer: Peer, size: CGSize) -> Signal<UIImage?, NoError> {
            let iconSignal: Signal<UIImage?, NoError>
            if let signal = peerAvatarImage(account: account, peerReference: PeerReference(peer), authorOfMessage: nil, representation: peer.profileImageRepresentations.first, displayDimensions: size, inset: 0.0, emptyColor: nil, synchronousLoad: false) {
                iconSignal = signal
                    |> map { imageVersions -> UIImage? in
                        return imageVersions?.0
                }
            } else {
                let peerId = peer.id
                var displayLetters = peer.displayLetters
                if displayLetters.count == 2 && displayLetters[0].isSingleEmoji && displayLetters[1].isSingleEmoji {
                    displayLetters = [displayLetters[0]]
                }
                iconSignal = Signal { subscriber in
                    let image = generateImage(size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        drawPeerAvatarLetters(context: context, size: CGSize(width: size.width, height: size.height), font: avatarPlaceholderFont(size: 13.0), letters: displayLetters, peerId: peerId)
                    })?.withRenderingMode(.alwaysOriginal)
                    
                    subscriber.putNext(image)
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
            }
            return iconSignal
        }
        
        let avatarSize = CGSize(width: 28.0, height: 28.0)
        
        items.append(.action(ContextMenuActionItem(text: primary.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: accountIconSignal(account: primary.0, peer: primary.1, size: avatarSize)), action: { _, f in
            f(.default)
        })))
        
        if !other.isEmpty {
            items.append(.separator)
        }
        
        for account in other {
            let id = account.0.id
            items.append(.action(ContextMenuActionItem(text: account.1.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), badge: account.2 != 0 ? ContextMenuActionBadge(value: "\(account.2)", color: .accent) : nil, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: accountIconSignal(account: account.0, peer: account.1, size: avatarSize)), action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerNode.switchToAccount(id: id)
                f(.dismissWithoutContent)
            })))
        }
        
        let controller = ContextController(account: primary.0, presentationData: self.presentationData, source: .extracted(SettingsTabBarContextExtractedContentSource(controller: self, sourceNode: sourceNode)), items: .single(items), reactionItems: [], recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
    }
}

private final class SettingsTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private func getUserPeer(postbox: Postbox, peerId: PeerId) -> Signal<(Peer?, CachedPeerData?), NoError> {
    return postbox.transaction { transaction -> (Peer?, CachedPeerData?) in
        guard let peer = transaction.getPeer(peerId) else {
            return (nil, nil)
        }
        var resultPeer: Peer?
        if let peer = peer as? TelegramSecretChat {
            resultPeer = transaction.getPeer(peer.regularPeerId)
        } else {
            resultPeer = peer
        }
        return (resultPeer, resultPeer.flatMap({ transaction.getPeerCachedData(peerId: $0.id) }))
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
    
    private var previousTitleNode: (ASDisplayNode, TextNode)?
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
            if let (layout, _) = self.screenNode.validLayout {
                let _ = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: layout.safeInsets.left, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: topNavigationBar.bounds.height, isModalOverlay: layout.isModalOverlay, isMediaOnly: false, contentOffset: 0.0, presentationData: self.presentationData, peer: self.screenNode.data?.peer, cachedData: self.screenNode.data?.cachedData, notificationSettings: self.screenNode.data?.notificationSettings, statusData: self.screenNode.data?.status, isContact: self.screenNode.data?.isContact ?? false, isSettings: self.screenNode.isSettings, state: self.screenNode.state, transition: transition, additive: false)
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
        }
    }
    
    func restore() {
        guard let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar else {
            return
        }
        
        topNavigationBar.isHidden = false
        bottomNavigationBar.isHidden = false
        self.headerNode.navigationTransition = nil
        self.screenNode.insertSubnode(self.headerNode, aboveSubnode: self.screenNode.scrollNode)
    }
}

private func encodeText(_ string: String, _ key: Int) -> String {
    var result = ""
    for c in string.unicodeScalars {
        result.append(Character(UnicodeScalar(UInt32(Int(c.value) + key))!))
    }
    return result
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceNode.bounds)
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
    
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(sourceNode: ContextExtractedContentContainingNode) {
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
