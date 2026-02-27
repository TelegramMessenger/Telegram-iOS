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
import PeerNameColorItem
import PeerSelectionScreen
import UIKitRuntimeUtils
import OldChannelsController
import UrlHandling
import VerifyAlertController
import GiftViewScreen
import PeerMessagesMediaPlaylist
import EdgeEffect
import Pasteboard
import AccountPeerContextItem

public enum PeerInfoAvatarEditingMode {
    case generic
    case accept
    case suggest
    case custom
    case fallback
}

enum PeerInfoBotCommand {
    case settings
    case help
    case privacy
}

enum PeerInfoParticipantsSection {
    case members
    case admins
    case banned
    case memberRequests
}

enum PeerInfoMemberAction {
    case promote
    case restrict
    case remove
    case openStories(sourceView: UIView)
}

enum PeerInfoContextSubject {
    case bio
    case phone(String)
    case link(customLink: String?)
    case businessHours(String)
    case businessLocation(String)
    case birthday
}

enum PeerInfoSettingsSection {
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
    case profileColor
    case powerSaving
    case businessSetup
    case profile
    case premiumManagement
    case stars
    case ton
}

enum PeerInfoReportType {
    case `default`
    case user
    case reaction(MessageId)
}

enum TopicsLimitedReason {
    case participants(Int)
    case discussion
}

final class PeerInfoScreenNode: ViewControllerTracingNode, PeerInfoScreenNodeProtocol, ASScrollViewDelegate {
    weak var controller: PeerInfoScreenImpl?
    
    let context: AccountContext
    let peerId: PeerId
    let isOpenedFromChat: Bool
    let videoCallsEnabled: Bool
    let callMessages: [Message]
    let chatLocation: ChatLocation
    let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    let switchToStoryFolder: Int64?
    let switchToMediaTarget: PeerInfoSwitchToMediaTarget?
    let switchToGiftsTarget: PeerInfoSwitchToGiftsTarget?
    let sharedMediaFromForumTopic: (EnginePeer.Id, Int64)?
    
    let isSettings: Bool
    let isMyProfile: Bool
    let isMediaOnly: Bool
    var initialExpandPanes: Bool
    
    private(set) var presentationData: PresentationData
    
    let cachedDataPromise = Promise<CachedPeerData?>()
    
    let scrollNode: ASScrollNode
    let edgeEffectView: EdgeEffectView
    
    let headerNode: PeerInfoHeaderNode
    var underHeaderContentsAlpha: CGFloat = 1.0
    var regularSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    var editingSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    let paneContainerNode: PeerInfoPaneContainerNode
    var ignoreScrolling: Bool = false
    lazy var hapticFeedback = { HapticFeedback() }()

    var customStatusData: (PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?)
    let customStatusPromise = Promise<(PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?)>((nil, nil, nil))
    var customStatusDisposable: Disposable?

    var refreshMessageTagStatsDisposable: Disposable?
    
    var searchDisplayController: SearchDisplayController?
    
    private var _interaction: PeerInfoInteraction?
    var interaction: PeerInfoInteraction {
        return self._interaction!
    }
    
    var _chatInterfaceInteraction: ChatControllerInteraction?
    var chatInterfaceInteraction: ChatControllerInteraction {
        return self._chatInterfaceInteraction!
    }
    var hiddenMediaDisposable: Disposable?
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    
    var autoTranslateDisposable: Disposable?
    
    var resolvePeerByNameDisposable: MetaDisposable?
    let navigationActionDisposable = MetaDisposable()
    let enqueueMediaMessageDisposable = MetaDisposable()
    
    private(set) var validLayout: (ContainerViewLayout, CGFloat)?
    private(set) var data: PeerInfoScreenData?
    
    var state = PeerInfoState(
        isEditing: false,
        selectedMessageIds: nil,
        selectedStoryIds: nil,
        paneIsReordering: false,
        updatingAvatar: nil,
        updatingBio: nil,
        updatingNote: nil,
        avatarUploadProgress: nil,
        highlightedButton: nil,
        isEditingBirthDate: false,
        updatingBirthDate: nil,
        personalChannels: nil
    )
    var forceIsContactPromise = ValuePromise<Bool>(false)
    let nearbyPeerDistance: Int32?
    let reactionSourceMessageId: MessageId?
    var dataDisposable: Disposable?
    
    let activeActionDisposable = MetaDisposable()
    let resolveUrlDisposable = MetaDisposable()
    let toggleShouldChannelMessagesSignaturesDisposable = MetaDisposable()
    let toggleMessageCopyProtectionDisposable = MetaDisposable()
    let selectAddMemberDisposable = MetaDisposable()
    let addMemberDisposable = MetaDisposable()
    let preloadHistoryDisposable = MetaDisposable()
    var shareStatusDisposable: MetaDisposable?
    let joinChannelDisposable = MetaDisposable()
    
    let updateAvatarDisposable = MetaDisposable()
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    var groupMembersSearchContext: GroupMembersSearchContext?
    
    let displayAsPeersPromise = Promise<[FoundPeer]>([])
    
    let accountsAndPeers = Promise<[(AccountContext, EnginePeer, Int32)]>()
    let activeSessionsContextAndCount = Promise<(ActiveSessionsContext, Int, WebSessionsContext)?>()
    let notificationExceptions = Promise<NotificationExceptionsList?>()
    let privacySettings = Promise<AccountPrivacySettings?>()
    let archivedPacks = Promise<[ArchivedStickerPackItem]?>()
    let blockedPeers = Promise<BlockedPeersContext?>(nil)
    let hasTwoStepAuth = Promise<Bool?>(nil)
    let twoStepAccessConfiguration = Promise<TwoStepVerificationAccessConfiguration?>(nil)
    let twoStepAuthData = Promise<TwoStepAuthData?>(nil)
    let supportPeerDisposable = MetaDisposable()
    let tipsPeerDisposable = MetaDisposable()
    
    let cachedFaq = Promise<ResolvedUrl?>(nil)
    var didSetCachedFaq = false
    
    weak var copyProtectionTooltipController: TooltipController?
    weak var emojiStatusSelectionController: ViewController?
    
    var forumTopicNotificationExceptions: [EngineMessageHistoryThread.NotificationException] = []
    var forumTopicNotificationExceptionsDisposable: Disposable?
    
    var translationState: ChatTranslationState?
    var translationStateDisposable: Disposable?
    
    var boostStatus: ChannelBoostStatus?
    var boostStatusDisposable: Disposable?
    
    var expiringStoryList: PeerExpiringStoryListContext?
    var expiringStoryListState: PeerExpiringStoryListContext.State?
    var expiringStoryListDisposable: Disposable?
    var storyUploadProgressDisposable: Disposable?
    var postingAvailabilityDisposable: Disposable?
    
    let storiesReady = ValuePromise<Bool>(true, ignoreRepeated: true)
    
    var personalChannelsDisposable: Disposable?
    
    var effectiveAreaExpansionFraction: CGFloat = 0.0
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    init(controller: PeerInfoScreenImpl, context: AccountContext, peerId: PeerId, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, nearbyPeerDistance: Int32?, reactionSourceMessageId: MessageId?, callMessages: [Message], isSettings: Bool, isMyProfile: Bool, hintGroupInCommon: PeerId?, requestsContext: PeerInvitationImportersContext?, profileGiftsContext: ProfileGiftsContext?, starsContext: StarsContext?, tonContext: StarsContext?, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, switchToGiftsTarget: PeerInfoSwitchToGiftsTarget?, switchToStoryFolder: Int64?, switchToMediaTarget: PeerInfoSwitchToMediaTarget?, initialPaneKey: PeerInfoPaneKey?, sharedMediaFromForumTopic: (EnginePeer.Id, Int64)?) {
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
        self.switchToStoryFolder = switchToStoryFolder
        self.switchToMediaTarget = switchToMediaTarget
        self.switchToGiftsTarget = switchToGiftsTarget
        self.sharedMediaFromForumTopic = sharedMediaFromForumTopic
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.canCancelAllTouchesInViews = true
        
        self.edgeEffectView = EdgeEffectView()
        
        var forumTopicThreadId: Int64?
        if case let .replyThread(message) = chatLocation {
            forumTopicThreadId = message.threadId
        }
        self.headerNode = PeerInfoHeaderNode(context: context, controller: controller, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, isMediaOnly: self.isMediaOnly, isSettings: isSettings, isMyProfile: isMyProfile, forumTopicThreadId: forumTopicThreadId, chatLocation: self.chatLocation)
        
        var switchToGiftCollection: Int64?
        switch switchToGiftsTarget {
        case let .collection(id):
            switchToGiftCollection = id
        default:
            break
        }
        
        self.paneContainerNode = PeerInfoPaneContainerNode(context: context, updatedPresentationData: controller.updatedPresentationData, peerId: peerId, chatLocation: chatLocation, sharedMediaFromForumTopic: sharedMediaFromForumTopic, chatLocationContextHolder: chatLocationContextHolder, isMediaOnly: self.isMediaOnly, initialPaneKey: initialPaneKey, initialStoryFolderId: switchToStoryFolder, initialGiftCollectionId: switchToGiftCollection, switchToMediaTarget: switchToMediaTarget)
        
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
            suggestBirthdate: { [weak self] in
                self?.suggestBirthdate()
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
            updateNote: { [weak self] note in
                if let self {
                    self.state = self.state.withUpdatingNote(note)
                }
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
            }, openNoteContextMenu: { [weak self] node, gesture in
                guard let self else {
                    return
                }
                self.openNoteContextMenu(node: node, gesture: gesture)
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
                
                let controller = makeContextController(presentationData: strongSelf.presentationData, source: .extracted(MessageContextExtractedContentSource(sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
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
                        let contextController = makeContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceNode: node, sourceRect: rect)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
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
        }, requestMessageActionCallback: { _, _, _, _, _ in
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
        }, todoItemLongTap: { _, _ in
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
        }, requestToggleTodoMessageItem: { _, _, _ in
        }, displayTodoToggleUnavailable: { _ in
        }, openStarsPurchase: { _ in
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
        self.scrollNode.view.addSubview(self.headerNode.headerEdgeEffectContainer)
        self.scrollNode.view.addSubview(self.paneContainerNode.headerContainer)
        
        self.view.addSubview(self.edgeEffectView)
        
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
            let contextController = makeContextController(presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
        
        self.paneContainerNode.openShareLink = { [weak self] url in
            guard let self else {
                return
            }
            self.openShareLink(url: url)
        }
        
        self.headerNode.performButtonAction = { [weak self] key, buttonNode, gesture in
            self?.performButtonAction(key: key, buttonNode: buttonNode, gesture: gesture)
        }
        
        self.headerNode.displaySavedMusic = { [weak self] in
            self?.displaySavedMusic()
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
                    strongSelf.activateEdit()
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
                            
                            let note = strongSelf.state.updatingNote
                            
                            let firstNameUpdated = (peer.firstName ?? "") != firstName
                            let lastNameUpdated = (peer.lastName ?? "") != lastName
                            var noteUpdated = false
                            
                            if let cachedData = data.cachedData as? CachedUserData {
                                if let note {
                                    let updatedEntities = generateChatInputTextEntities(note)
                                    if note.string != (cachedData.note?.text ?? "") || updatedEntities != (cachedData.note?.entities ?? []) {
                                        noteUpdated = true
                                    }
                                }
                            }
                            
                            if firstNameUpdated || lastNameUpdated || noteUpdated {
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
                                    
                                    enum ContactUpdateError {
                                        case generic
                                    }
                                    let nameUpdateSignal: Signal<Never, ContactUpdateError>
                                    if firstNameUpdated || lastNameUpdated {
                                        nameUpdateSignal = context.engine.contacts.updateContactName(peerId: peer.id, firstName: firstName, lastName: lastName)
                                        |> mapError { _ -> ContactUpdateError in
                                            return .generic
                                        }
                                        |> ignoreValues
                                    } else {
                                        nameUpdateSignal = .complete()
                                    }

                                    let noteUpdateSignal: Signal<Never, ContactUpdateError>
                                    if noteUpdated, let note {
                                        let entities = generateChatInputTextEntities(note)
                                        noteUpdateSignal = context.engine.contacts.updateContactNote(peerId: peer.id, text: note.string, entities: entities)
                                        |> mapError { _ -> ContactUpdateError in
                                            return .generic
                                        }
                                    } else {
                                        noteUpdateSignal = .complete()
                                    }
                                    
                                    strongSelf.activeActionDisposable.set(combineLatest(queue: Queue.mainQueue(), nameUpdateSignal, noteUpdateSignal).startStrict(error: { _ in
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
                                        
                                        let _ = (getUserPeer(engine: context.engine, peerId: peer.id)
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
                    strongSelf.state = strongSelf.state.withIsEditing(false).withUpdatingBio(nil).withUpdatingBirthDate(nil).withIsEditingBirthDate(false).withUpdatingNote(nil)
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
        
        self.headerNode.updateUnderHeaderContentsAlpha = { [weak self] alpha, transition in
            guard let self else {
                return
            }
            self.underHeaderContentsAlpha = alpha
            if !self.state.isEditing {
                for (_, section) in self.regularSections {
                    transition.updateAlpha(node: section, alpha: alpha)
                }
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
                        
            screenData = peerInfoScreenSettingsData(context: context, peerId: peerId, accountsAndPeers: self.accountsAndPeers.get(), activeSessionsContextAndCount: self.activeSessionsContextAndCount.get(), notificationExceptions: self.notificationExceptions.get(), privacySettings: self.privacySettings.get(), archivedStickerPacks: self.archivedPacks.get(), hasPassport: hasPassport, starsContext: starsContext, tonContext: tonContext)
            
            
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
            
            var switchToUpgradableGifts = false
            if let switchToGiftsTarget, case .upgradable = switchToGiftsTarget {
                switchToUpgradableGifts = true
            }
            
            screenData = peerInfoScreenData(context: context, peerId: peerId, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, isSettings: self.isSettings, isMyProfile: self.isMyProfile, hintGroupInCommon: hintGroupInCommon, existingRequestsContext: requestsContext, existingProfileGiftsContext: profileGiftsContext, existingProfileGiftsCollectionsContext: nil, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, sharedMediaFromForumTopic: self.sharedMediaFromForumTopic, privacySettings: self.privacySettings.get(), forceHasGifts: initialPaneKey == .gifts, switchToUpgradableGifts: switchToUpgradableGifts)
                       
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
                
                let contextController = makeContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: galleryController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
                            profileGiftsContext: profileGifts,
                            updateSavedToProfile: { [weak profileGifts] reference, added in
                                guard let profileGifts else {
                                    return
                                }
                                profileGifts.updateStarGiftAddedToProfile(reference: reference, added: added)
                            },
                            convertToStars: { [weak profileGifts] reference in
                                guard let profileGifts else {
                                    return
                                }
                                profileGifts.convertStarGift(reference: reference)
                            },
                            dropOriginalDetails: { [weak profileGifts] reference in
                                guard let profileGifts else {
                                    return .complete()
                                }
                                return profileGifts.dropOriginalDetails(reference: reference)
                            },
                            transferGift: { [weak profileGifts] prepaid, reference, peerId in
                                guard let profileGifts else {
                                    return .complete()
                                }
                                return profileGifts.transferStarGift(prepaid: prepaid, reference: reference, peerId: peerId)
                            },
                            upgradeGift: { [weak profileGifts] formId, reference, keepOriginalInfo in
                                guard let profileGifts else {
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
                    
                    self.headerNode.avatarListNode.avatarContainerNode.storyData = (totalCount, unseenCount, state.hasUnseenCloseFriends && peer.id != self.context.account.peerId, state.hasLiveItems)
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
    
    func activateEdit() {
        (self.controller?.parent as? TabBarController)?.updateIsTabBarHidden(true, transition: .animated(duration: 0.3, curve: .linear))
        self.state = self.state.withIsEditing(true)
        var updateOnCompletion = false
        if self.headerNode.isAvatarExpanded {
            updateOnCompletion = true
            self.headerNode.skipCollapseCompletion = true
            self.headerNode.avatarListNode.avatarContainerNode.canAttachVideo = false
            self.headerNode.editingContentNode.avatarNode.canAttachVideo = false
            self.headerNode.avatarListNode.listContainerNode.isCollapsing = true
            self.headerNode.updateIsAvatarExpanded(false, transition: .immediate)
            self.updateNavigationExpansionPresentation(isExpanded: false, animated: true)
        }
        if let (layout, navigationHeight) = self.validLayout {
            self.scrollNode.view.setContentOffset(CGPoint(), animated: false)
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
        }
        UIView.transition(with: self.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
        }, completion: { _ in
            if updateOnCompletion {
                self.headerNode.skipCollapseCompletion = false
                self.headerNode.avatarListNode.listContainerNode.isCollapsing = false
                self.headerNode.avatarListNode.avatarContainerNode.canAttachVideo = true
                self.headerNode.editingContentNode.avatarNode.canAttachVideo = true
                self.headerNode.editingContentNode.avatarNode.reset()
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate, additive: false)
                }
            }
        })
    }
    
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
            self.updateNavigationExpansionPresentation(isExpanded: false, animated: animated)
            
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
            }
        }
        
        if let (_, navigationHeight) = self.validLayout {
            let contentOffset = self.scrollNode.view.contentOffset
            let paneAreaExpansionFinalPoint: CGFloat = self.paneContainerNode.frame.minY - navigationHeight
            if contentOffset.y < paneAreaExpansionFinalPoint - CGFloat.ulpOfOne {
                let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
                
                self.ignoreScrolling = true
                transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: paneAreaExpansionFinalPoint), size: self.scrollNode.bounds.size))
                self.ignoreScrolling = false
                self.headerNode.headerEdgeEffectContainer.center = CGPoint(x: 0.0, y: self.scrollNode.view.contentOffset.y)
                self.updateNavigation(transition: transition, additive: false, animateHeader: true)
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition, additive: true)
                }
            }
        }
    }
    
    func openPeer(peerId: PeerId, navigation: ChatControllerInteractionNavigateToPeer) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        PeerInfoScreenImpl.openPeer(context: self.context, peerId: peerId, navigation: navigation, navigationController: navigationController)
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
    
    var previousSavedMusicTimestamp: Double?
    private func displaySavedMusic() {
        guard let savedMusicContext = self.data?.savedMusicContext else {
            return
        }
        
        let currentTimestamp = CACurrentMediaTime()
        if let previousTimestamp = self.previousSavedMusicTimestamp, currentTimestamp < previousTimestamp + 1.0 {
            return
        }
        self.previousSavedMusicTimestamp = currentTimestamp
        
        let _ = (self.context.sharedContext.mediaManager.globalMediaPlayerState
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] accountStateAndType in
            guard let self else {
                return
            }
            let peerId = self.peerId
            var initialId: Int32
            if let initialFileId = self.data?.savedMusicState?.files.first?.fileId {
                initialId = Int32(clamping: initialFileId.id % Int64(Int32.max))
            } else {
                initialId = 0
            }

            let canReorder = peerId == self.context.account.peerId
            var playlistLocation: PeerMessagesPlaylistLocation = .savedMusic(context: savedMusicContext, at: initialId, canReorder: canReorder)
            
            if let (account, stateOrLoading, _) = accountStateAndType, self.context.account.peerId == account.peerId, case let .state(state) = stateOrLoading, let location = state.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(savedMusicContext, _, _) = location, savedMusicContext.peerId == peerId {
                if let itemId = state.item.id as? PeerMessagesMediaPlaylistItemId {
                    initialId = itemId.messageId.id
                }
                playlistLocation = .savedMusic(context: savedMusicContext, at: initialId, canReorder: canReorder)
            } else {
                self.context.sharedContext.mediaManager.setPlaylist((self.context, PeerMessagesMediaPlaylist(context: self.context, location: playlistLocation, chatLocationContextHolder: nil)), type: .music, control: .playback(.play))
            }
            
            Queue.mainQueue().after(0.1) {
                let musicController = self.context.sharedContext.makeOverlayAudioPlayerController(
                    context: self.context,
                    chatLocation: .peer(id: peerId),
                    type: .music,
                    initialMessageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: initialId),
                    initialOrder: .regular,
                    playlistLocation: playlistLocation,
                    parentNavigationController: self.controller?.navigationController as? NavigationController
                )
                self.controller?.present(musicController, in: .window(.root))
            }
        })
    }
    
    func openAutoremove(currentValue: Int32?) {
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
    
    func openCustomMute() {
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
    
    func setAutoremove(timeInterval: Int32?) {
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
    
    func openStartSecretChat() {
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
    
    func openClearHistory(contextController: ContextControllerProtocol, clearPeerHistory: ClearPeerHistory, peer: Peer, chatPeer: Peer) {
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
    
    func openAddContact() {
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
    
    func updateBlocked(block: Bool) {
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
    
    func openStoryArchive() {
        self.controller?.push(PeerInfoStoryGridScreen(context: self.context, peerId: self.peerId, scope: .archive))
    }
    
    func openStats(section: ChannelStatsSection, boostStatus: ChannelBoostStatus? = nil) {
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
    
    func openBoost() {
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
    
    func openReport(type: PeerInfoReportType, contextController: ContextControllerProtocol?, backAction: ((ContextControllerProtocol) -> Void)?) {
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
    
    func openShareLink(url: String) {
        let shareController = ShareController(context: self.context, subject: .url(url), updatedPresentationData: self.controller?.updatedPresentationData)
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
    
    func openShareBot() {
        let _ = (getUserPeer(engine: self.context.engine, peerId: self.peerId)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let strongSelf = self else {
                return
            }
            if case let .user(peer) = peer, let username = peer.addressName {
                strongSelf.openShareLink(url: "https://t.me/\(username)")
            }
        })
    }
    
    private func openAddBotToGroup() {
        guard let controller = self.controller else {
            return
        }
        self.context.sharedContext.openResolvedUrl(.groupBotStart(peerId: peerId, payload: "", adminRights: nil, peerType: nil), context: self.context, urlContext: .generic, navigationController: controller.navigationController as? NavigationController, forceExternal: false, forceUpdate: false, openPeer: { id, navigation in
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
    
    func performBotCommand(command: PeerInfoBotCommand) {
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
    
    func openLeavePeer(delete: Bool) {
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

            strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: title, text: text, actions: [
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
    
    func openAddMember() {
        guard let controller = self.controller, !controller.presentAccountFrozenInfoIfNeeded() else {
            return
        }
        guard let data = self.data, let groupPeer = data.peer else {
            return
        }
        
        presentAddMembersImpl(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, parentController: controller, groupPeer: groupPeer, selectAddMemberDisposable: self.selectAddMemberDisposable, addMemberDisposable: self.addMemberDisposable)
    }
    
    func openQrCode() {
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
    
    func openPremiumGift() {
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
                    if let rightButton = self.headerNode.navigationButtonContainer.rightButtonNodes.first(where: { $0.key.key == .postStory })?.value {
                        cameraTransitionIn = StoryCameraTransitionIn(
                            sourceView: rightButton.view,
                            sourceRect: rightButton.view.bounds,
                            sourceCornerRadius: rightButton.view.bounds.height * 0.5,
                            useFillAnimation: false
                        )
                    }
                    
                    if let rootController = self.context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                        let coordinator = rootController.openStoryCamera(mode: .photo, customTarget: self.peerId == self.context.account.peerId ? nil : .peer(self.peerId), resumeLiveStream: false, transitionIn: cameraTransitionIn, transitionedIn: {}, transitionOut: self.storyCameraTransitionOut())
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
    
    private func updateBio(_ bio: String) {
        self.state = self.state.withUpdatingBio(bio)
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut), additive: false)
        }
    }
    
    func activateSearch() {
        guard let (layout, navigationBarHeight) = self.validLayout, self.searchDisplayController == nil else {
            return
        }
        guard let controller = self.controller else {
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
            self.setupFaqIfNeeded()
            
            if let settings = self.data?.globalSettings {
                self.searchDisplayController = SearchDisplayController(
                    presentationData: self.presentationData,
                    mode: .navigation,
                    placeholder: self.presentationData.strings.Settings_Search,
                    hasBackground: true,
                    hasSeparator: true,
                    contentNode: SettingsSearchContainerNode(
                        context: self.context,
                        openResult: { [weak self] result in
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
                        },
                        openContextMenu: { item, sourceNode, rect, gesture in
                            let link = "tg://settings/\(item.id)"
                            let items: [ContextMenuItem] = [
                                .action( ContextMenuActionItem(
                                    text: "Copy Link",
                                    icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                                    },
                                    action: { [weak self] _, f in
                                        f(.default)
                                        
                                        UIPasteboard.general.string = link
                                        guard let self else {
                                            return
                                        }
                                        self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                    }
                                ))
                            ]
                            let contextController = makeContextController(
                                presentationData: self.presentationData,
                                source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)),
                                items: .single(ContextController.Items(content: .list(items))),
                                recognizer: nil,
                                gesture: gesture as? ContextGesture
                            )
                            self.context.sharedContext.mainWindow?.presentInGlobalOverlay(contextController)
                        },
                        resolvedFaqUrl: self.cachedFaq.get(),
                        exceptionsList: .single(settings.notificationExceptions),
                        archivedStickerPacks: .single(settings.archivedStickerPacks),
                        privacySettings: .single(settings.privacySettings),
                        hasTwoStepAuth: self.hasTwoStepAuth.get(),
                        twoStepAuthData: self.twoStepAccessConfiguration.get(),
                        activeSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.0 },
                        webSessionsContext: self.activeSessionsContextAndCount.get() |> map { $0?.2 }
                    ),
                    cancel: { [weak self] in
                        self?.deactivateSearch()
                    },
                    searchBarIsExternal: true
                )
            }
        } else if let currentPaneKey = self.paneContainerNode.currentPaneKey, case .members = currentPaneKey {
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .navigation, placeholder: self.presentationData.strings.Common_Search, hasBackground: true, hasSeparator: true, contentNode: ChannelMembersSearchContainerNode(context: self.context, forceTheme: nil, peerId: self.peerId, mode: .searchMembers, filters: [], searchContext: self.groupMembersSearchContext, openPeer: { [weak self] peer, participant in
                self?.openPeer(peerId: peer.id, navigation: .info(nil))
            }, updateActivity: { _ in
            }, pushController: { [weak self] c in
                self?.controller?.push(c)
            }), cancel: { [weak self] in
                self?.deactivateSearch()
            }, fieldStyle: .glass)
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
            
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .navigation, placeholder: self.presentationData.strings.Common_Search, hasBackground: false, contentNode: ChatHistorySearchContainerNode(context: self.context, peerId: self.peerId, threadId: self.chatLocation.threadId, tagMask: tagMask, interfaceInteraction: self.chatInterfaceInteraction), cancel: { [weak self] in
                self?.deactivateSearch()
            }, fieldStyle: .glass)
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 0.0)
        }
        
        self.searchDisplayController?.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
            guard let self else {
                return
            }
            if isSearchBar {
                self.headerNode.searchBarContainer.addSubnode(subnode)
            } else {
                self.headerNode.searchContainer.addSubnode(subnode)
            }
        }, placeholder: nil)
        
        if self.isSettings {
            controller.updateTabBarSearchState(ViewController.TabBarSearchState(isActive: true), transition: transition)
            if let searchBarNode = controller.currentTabBarSearchNode?() as? SearchBarNode {
                self.searchDisplayController?.setSearchBar(searchBarNode)
                searchBarNode.activate()
            }
        }
        
        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationBarHeight, transition: .immediate)
    }
    
    func deactivateSearch() {
        guard let controller = self.controller, let searchDisplayController = self.searchDisplayController else {
            return
        }
        self.searchDisplayController = nil
        searchDisplayController.deactivate(placeholder: nil)
        
        controller.dismissAllTooltips()
        
        if self.isSettings {
            (self.controller?.parent as? TabBarController)?.updateIsTabBarHidden(false, transition: .animated(duration: 0.4, curve: .spring))
            controller.updateTabBarSearchState(ViewController.TabBarSearchState(isActive: false), transition: .animated(duration: 0.4, curve: .spring))
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
        if let navigationBar = self.controller?.navigationBar {
            transition.updateAlpha(node: navigationBar, alpha: 1.0)
        }
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring), additive: false)
        }
    }

    weak var mediaGalleryContextMenu: ContextController?

    func displaySharedMediaFastScrollingTooltip() {
        guard let buttonNode = self.headerNode.navigationButtonContainer.rightButtonNodes.first(where: { $0.key.key == .more })?.value else {
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

    func openMediaCalendar() {
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
                let contextController = makeContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, sourceRect: sourceRect, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
    
    private func suggestBirthdate() {
        let controller = context.sharedContext.makeBirthdaySuggestionScreen(
            context: self.context,
            peerId: self.peerId,
            completion: { [weak self] value in
                guard let self else {
                    return
                }
                
                let _ = self.context.engine.peers.suggestBirthday(peerId: self.peerId, birthday: value).startStandalone()
                                
                self.headerNode.navigationButtonContainer.performAction?(.cancel, nil, nil)
                self.openChat(peerId: self.peerId)
            }
        )
        self.controller?.push(controller)
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
        
        self.updateBackgroundColor()
    
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
        
        if self.isSettings {
            let edgeEffectHeight: CGFloat = layout.intrinsicInsets.bottom
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - edgeEffectHeight), size: CGSize(width: layout.size.width, height: edgeEffectHeight))
            transition.updateFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: self.presentationData.theme.list.blocksBackgroundColor, rect: edgeEffectFrame, edge: .bottom, edgeSize: edgeEffectFrame.height, transition: ComponentTransition(transition))
        }
        
        let sectionSpacing: CGFloat = 24.0
        
        var contentHeight: CGFloat = 0.0
        
        let sectionInset: CGFloat
        if layout.size.width >= 375.0 {
            sectionInset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
        } else {
            sectionInset = 0.0
        }
        let headerInset = sectionInset
        
        let headerHeight = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : self.scrollNode.view.contentOffset.y, paneContainerY: self.paneContainerNode.frame.minY, presentationData: self.presentationData, peer: self.data?.savedMessagesPeer ?? self.data?.peer, cachedData: self.data?.cachedData, threadData: self.data?.threadData, peerNotificationSettings: self.data?.peerNotificationSettings, threadNotificationSettings: self.data?.threadNotificationSettings, globalNotificationSettings: self.data?.globalNotificationSettings, statusData: self.data?.status, panelStatusData: self.customStatusData, isSecretChat: self.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, profileGiftsContext: self.data?.profileGiftsContext, screenData: self.data, isSearching: self.searchDisplayController != nil, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, transition: self.headerNode.navigationTransition == nil ? transition : .immediate, additive: additive, animateHeader: transition.isAnimated && self.headerNode.navigationTransition == nil)
        
        let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: layout.size.height))
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
                    self.scrollNode.insertSubnode(sectionNode, belowSubnode: self.paneContainerNode)
                    wasAdded = true
                }
                
                if wasAdded && transition.isAnimated && (self.isSettings || self.isMyProfile) && !self.state.isEditing {
                    sectionNode.alpha = 0.0
                    transition.updateAlpha(node: sectionNode, alpha: self.underHeaderContentsAlpha, delay: 0.1)
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
                    transition.updateAlpha(node: sectionNode, alpha: self.state.isEditing ? 0.0 : self.underHeaderContentsAlpha)
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
                    self.scrollNode.insertSubnode(sectionNode, belowSubnode: self.paneContainerNode)
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
        
        if !self.isMediaOnly {
            contentHeight -= 18.0
        }
        let paneContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: paneContainerSize)
        if self.state.isEditing || (self.data?.availablePanes ?? []).isEmpty {
            transition.updateAlpha(node: self.paneContainerNode, alpha: 0.0)
            ComponentTransition(transition).setAlpha(view: self.paneContainerNode.headerContainer, alpha: 0.0)
        } else {
            contentHeight += layout.size.height - navigationHeight
            transition.updateAlpha(node: self.paneContainerNode, alpha: 1.0)
            ComponentTransition(transition).setAlpha(view: self.paneContainerNode.headerContainer, alpha: 1.0)
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
                }, displayCopyProtectionTip: { [weak self] sourceView, save in
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
                                    let rect = sourceView.convert(sourceView.bounds, to: strongSelf.view).offsetBy(dx: 0.0, dy: 3.0)
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
        if additive {
            transition.updateFrameAdditive(view: self.paneContainerNode.headerContainer, frame: paneContainerFrame)
        } else {
            transition.updateFrame(view: self.paneContainerNode.headerContainer, frame: paneContainerFrame)
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
    
    private func updateBackgroundColor() {
        let color: UIColor
        if self.paneContainerNode.currentPaneKey == .gifts {
            color = self.presentationData.theme.list.blocksBackgroundColor
        } else {
            color = self.presentationData.theme.list.blocksBackgroundColor.mixedWith(self.presentationData.theme.list.plainBackgroundColor, alpha: self.effectiveAreaExpansionFraction)
        }
        self.backgroundColor = color
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

                let _ = self.headerNode.update(width: layout.size.width, containerHeight: layout.size.height, containerInset: headerInset, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, isModalOverlay: layout.isModalOverlay, isMediaOnly: self.isMediaOnly, contentOffset: self.isMediaOnly ? 212.0 : offsetY, paneContainerY: self.paneContainerNode.frame.minY, presentationData: self.presentationData, peer: self.data?.savedMessagesPeer ?? self.data?.peer, cachedData: self.data?.cachedData, threadData: self.data?.threadData, peerNotificationSettings: self.data?.peerNotificationSettings, threadNotificationSettings: self.data?.threadNotificationSettings, globalNotificationSettings: self.data?.globalNotificationSettings, statusData: self.data?.status, panelStatusData: self.customStatusData, isSecretChat: self.peerId.namespace == Namespaces.Peer.SecretChat, isContact: self.data?.isContact ?? false, isSettings: self.isSettings, state: self.state, profileGiftsContext: self.data?.profileGiftsContext, screenData: self.data, isSearching: self.searchDisplayController != nil, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, transition: self.headerNode.navigationTransition == nil ? transition : .immediate, additive: additive, animateHeader: animateHeader && self.headerNode.navigationTransition == nil)
            }
            
            let paneAreaExpansionDistance: CGFloat = 32.0
            let effectiveAreaExpansionFraction: CGFloat
            if self.state.isEditing {
                effectiveAreaExpansionFraction = 0.0
            } else if self.isSettings {
                effectiveAreaExpansionFraction = 0.0
            } else {
                var paneAreaExpansionDelta = (self.paneContainerNode.frame.minY - navigationHeight) - self.scrollNode.view.contentOffset.y
                paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
                effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            }
            
            self.effectiveAreaExpansionFraction = effectiveAreaExpansionFraction
            
            self.updateBackgroundColor()
            
            let visibleHeight = self.scrollNode.view.contentOffset.y + self.scrollNode.view.bounds.height - self.paneContainerNode.frame.minY
            
            var bottomInset = layout.intrinsicInsets.bottom
            if let selectionPanelNode = self.paneContainerNode.selectionPanelNode {
                bottomInset = max(bottomInset, selectionPanelNode.bounds.height)
            }
            
            var disableTabSwitching = false
            if self.state.selectedStoryIds != nil || self.state.paneIsReordering {
                disableTabSwitching = true
            }
                        
            let navigationBarHeight: CGFloat = !self.isSettings && layout.isModalOverlay ? 68.0 : 60.0
            let paneContainerTopInset = navigationBarHeight + (layout.statusBarHeight ?? 0.0)
            self.paneContainerNode.update(size: self.paneContainerNode.bounds.size, sideInset: layout.safeInsets.left, topInset: paneContainerTopInset, bottomInset: bottomInset, deviceMetrics: layout.deviceMetrics, visibleHeight: visibleHeight, expansionFraction: self.initialExpandPanes ? 1.0 : effectiveAreaExpansionFraction, presentationData: self.presentationData, data: self.data, areTabsHidden: self.headerNode.customNavigationContentNode != nil, disableTabSwitching: disableTabSwitching, navigationHeight: navigationHeight, transition: transition)
          
            transition.updateFrame(node: self.headerNode.navigationButtonContainer, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left, y: layout.statusBarHeight ?? 0.0), size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight)))
            var searchBarContainerY: CGFloat = layout.statusBarHeight ?? 0.0
            searchBarContainerY += floor((navigationBarHeight - 44.0) * 0.5) + 2.0
            transition.updateFrame(node: self.headerNode.searchBarContainer, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left, y: searchBarContainerY), size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight)))
            transition.updateFrame(node: self.headerNode.searchContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
                        
            var leftNavigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            var rightNavigationButtons: [PeerInfoHeaderNavigationButtonSpec] = []
            if self.state.isEditing {
                leftNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .cancel, isForExpandedView: false))
                rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .done, isForExpandedView: false))
            } else {
                if self.isSettings {
                    leftNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .qrCode, isForExpandedView: false))
                    rightNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .edit, isForExpandedView: false))
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
                        case .stories:
                            if let data = self.data, data.peer?.id == self.context.account.peerId {
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
                    leftNavigationButtons.append(PeerInfoHeaderNavigationButtonSpec(key: .back, isForExpandedView: true))
                }
            }
            self.headerNode.navigationButtonContainer.update(size: CGSize(width: layout.size.width - layout.safeInsets.left * 2.0, height: navigationBarHeight), presentationData: self.presentationData, leftButtons: leftNavigationButtons, rightButtons: rightNavigationButtons, expandFraction: effectiveAreaExpansionFraction, shouldAnimateIn: animateHeader, transition: transition)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        func cancelContextGestures(view: UIView) {
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
        
        self.headerNode.headerEdgeEffectContainer.center = CGPoint(x: 0.0, y: scrollView.contentOffset.y)
                        
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

public enum PeerInfoSwitchToGiftsTarget {
    case generic
    case upgradable
    case collection(Int64)
}

public struct PeerInfoSwitchToMediaTarget {
    public enum Kind {
        case photoVideo
        case file
    }
    
    public let kind: Kind
    public let messageIndex: EngineMessage.Index
    
    public init(kind: Kind, messageIndex: EngineMessage.Index) {
        self.kind = kind
        self.messageIndex = messageIndex
    }
}

public final class PeerInfoScreenImpl: ViewController, PeerInfoScreen, KeyShortcutResponder {
    let context: AccountContext
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
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
    let starsContext: StarsContext?
    let tonContext: StarsContext?
    private let switchToRecommendedChannels: Bool
    private let switchToGiftsTarget: PeerInfoSwitchToGiftsTarget?
    private let switchToGroupsInCommon: Bool
    private let switchToStoryFolder: Int64?
    private let switchToMediaTarget: PeerInfoSwitchToMediaTarget?
    private let sharedMediaFromForumTopic: (EnginePeer.Id, Int64)?
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

    var avatarPickerHolder: Any?
    
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
    
    public var twoStepAuthData: Promise<TwoStepAuthData?> {
        return self.controllerNode.twoStepAuthData
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
        sharedMediaFromForumTopic: (EnginePeer.Id, Int64)? = nil,
        switchToRecommendedChannels: Bool = false,
        switchToGiftsTarget: PeerInfoSwitchToGiftsTarget? = nil,
        switchToGroupsInCommon: Bool = false,
        switchToStoryFolder: Int64? = nil,
        switchToMediaTarget: PeerInfoSwitchToMediaTarget? = nil,
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
        self.switchToGiftsTarget = switchToGiftsTarget
        self.switchToGroupsInCommon = switchToGroupsInCommon
        self.switchToStoryFolder = switchToStoryFolder
        self.switchToMediaTarget = switchToMediaTarget
        self.sharedMediaFromForumTopic = sharedMediaFromForumTopic
        
        if let forumTopicThread = forumTopicThread {
            self.chatLocation = .replyThread(message: forumTopicThread)
        } else {
            self.chatLocation = .peer(id: peerId)
        }
        
        if isSettings {
            if let starsContext = context.starsContext {
                self.starsContext = starsContext
                starsContext.load(force: true)
            } else {
                self.starsContext = nil
            }
            if let tonContext = context.tonContext {
                self.tonContext = tonContext
                tonContext.load(force: true)
            } else {
                self.tonContext = nil
            }
        } else {
            self.starsContext = nil
            self.tonContext = nil
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
                overallDarkAppearance: true,
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
        
        self._hasGlassStyle = true
        
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
            self.navigationBar?.makeCustomTransitionNode = { _, _ in
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
            let chatTheme: Signal<ChatTheme?, NoError> = self.cachedDataPromise.get()
            |> map { cachedData -> ChatTheme? in
                if let cachedData = cachedData as? CachedUserData {
                    return cachedData.chatTheme
                } else if let cachedData = cachedData as? CachedGroupData {
                    return cachedData.chatTheme
                } else if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.chatTheme
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged
            
            presentationDataSignal = combineLatest(
                queue: Queue.mainQueue(),
                context.sharedContext.presentationData,
                context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager, onlyCached: false),
                chatTheme
            )
            |> map { presentationData, chatThemes, chatTheme -> PresentationData in
                var presentationData = presentationData
                if let chatTheme {
                    switch chatTheme {
                    case let .emoticon(emoticon):
                        if let theme = chatThemes.first(where: { $0.emoticon == emoticon }) {
                            if let theme = makePresentationTheme(cloudTheme: theme, dark: presentationData.theme.overallDarkAppearance) {
                                presentationData = presentationData.withUpdated(theme: theme)
                                presentationData = presentationData.withUpdated(chatWallpaper: theme.chat.defaultWallpaper)
                            }
                        }
                    case .gift:
                        break
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

        self.updateTabBarSearchState(ViewController.TabBarSearchState(isActive: false), transition: .immediate)
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
        } else if let _ = self.switchToGiftsTarget {
            initialPaneKey = .gifts
        } else if self.switchToGroupsInCommon {
            initialPaneKey = .groupsInCommon
        } else if self.switchToStoryFolder != nil {
            initialPaneKey = .stories
        } else if let switchToMediaTarget = self.switchToMediaTarget {
            switch switchToMediaTarget.kind {
            case .photoVideo:
                initialPaneKey = .media
            case .file:
                initialPaneKey = .files
            }
        }
        self.displayNode = PeerInfoScreenNode(controller: self, context: self.context, peerId: self.peerId, avatarInitiallyExpanded: self.avatarInitiallyExpanded, isOpenedFromChat: self.isOpenedFromChat, nearbyPeerDistance: self.nearbyPeerDistance, reactionSourceMessageId: self.reactionSourceMessageId, callMessages: self.callMessages, isSettings: self.isSettings, isMyProfile: self.isMyProfile, hintGroupInCommon: self.hintGroupInCommon, requestsContext: self.requestsContext, profileGiftsContext: self.profileGiftsContext, starsContext: self.starsContext, tonContext: self.tonContext, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, switchToGiftsTarget: self.switchToGiftsTarget, switchToStoryFolder: self.switchToStoryFolder, switchToMediaTarget: self.switchToMediaTarget, initialPaneKey: initialPaneKey, sharedMediaFromForumTopic: self.sharedMediaFromForumTopic)
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
    
    fileprivate func dismissAllTooltips() {
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
    
    public func activateEdit() {
        self.controllerNode.activateEdit()
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
            let contextController = makeContextController(presentationData: presentationData, source: .reference(PeerInfoControllerContextReferenceContentSource(controller: parentController, sourceView: backButtonView, insets: UIEdgeInsets(), contentInsets: UIEdgeInsets(top: 0.0, left: -15.0, bottom: 0.0, right: -15.0))), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
        
        if !chatNavigationStack.isEmpty, let backButtonNode = self.navigationBar?.backButtonNode as? ContextControllerSourceNode {
            backButtonNode.isGestureEnabled = true
            backButtonNode.activated = { [weak self] gesture, _ in
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
        self.controllerNode.initialExpandPanes = false
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = self.isSettings ? (self.navigationBar?.frame.height ?? 0.0) : self.navigationLayout(layout: layout).navigationFrame.maxY
        self.validLayout = (layout, navigationHeight)
        
        self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
    }
    
    override public func tabBarItemContextAction(sourceView: ContextExtractedContentContainingView, gesture: ContextGesture) {
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
        
        let controller = makeContextController(presentationData: self.presentationData, source: .reference(SettingsTabBarContextReferenceContentSource(controller: self, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
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
    
    public func openEmojiStatusSetup() {
        self.controllerNode.openSettings(section: .emojiStatus)
    }
    
    public func openBirthdaySetup() {
        self.controllerNode.interaction.updateIsEditingBirthdate(true)
        self.controllerNode.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
    }
    
    override public func tabBarActivateSearch() {
        self.controllerNode.activateSearch()
    }
    
    override public func tabBarDeactivateSearch() {
        self.controllerNode.deactivateSearch()
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
            let contextController = makeContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: sourceController, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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

final class SettingsTabBarContextReferenceContentSource: ContextReferenceContentSource {
    let keepInPlace: Bool = true
    
    private let controller: ViewController
    private let sourceView: ContextExtractedContentContainingView
    
    init(controller: ViewController, sourceView: ContextExtractedContentContainingView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceView.contentView,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            actionsPosition: .top
        )
    }
}

func getUserPeer(engine: TelegramEngine, peerId: EnginePeer.Id) -> Signal<EnginePeer?, NoError> {
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

final class ContextControllerContentSourceImpl: ContextControllerContentSource {
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

final class MessageContextExtractedContentSource: ContextExtractedContentSource {
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

final class PeerInfoContextExtractedContentSource: ContextExtractedContentSource {
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

final class PeerInfoContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    init(controller: ViewController, sourceNode: ASDisplayNode) {
        self.controller = controller
        self.sourceView = sourceNode.view
    }
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
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
