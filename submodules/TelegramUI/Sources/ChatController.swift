import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SafariServices
import MobileCoreServices
import Intents
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import TextFormat
import TelegramBaseController
import AccountContext
import TelegramStringFormatting
import OverlayStatusController
import DeviceLocationManager
import ShareController
import UrlEscaping
import ContextUI
import ComposePollUI
import AlertUI
import PresentationDataUtils
import UndoUI
import TelegramCallsUI
import TelegramNotices
import GameUI
import ScreenCaptureDetection
import GalleryUI
import OpenInExternalAppUI
import LegacyUI
import InstantPageUI
import LocationUI
import BotPaymentsUI
import DeleteChatPeerActionSheetItem
import HashtagSearchUI
import LegacyMediaPickerUI
import WebSearchUI
import Emoji
import PeerAvatarGalleryUI
import PeerInfoUI
import RaiseToListen
import UrlHandling
import AvatarNode
import AppBundle
import LocalizedPeerData
import PhoneNumberFormat
import SettingsUI
import UrlWhitelist
import TelegramIntents
import TooltipUI
import StatisticsUI
import MediaResources
import GalleryData
import ChatInterfaceState
import InviteLinksUI
import Markdown
import TelegramPermissionsUI
import Speak
import TranslateUI
import UniversalMediaPlayer
import WallpaperBackgroundNode
import ChatListUI
import CalendarMessageScreen
import ReactionSelectionNode
import LottieMeshSwift
import ReactionListContextMenuContent
import AttachmentUI
import AttachmentTextInputPanelNode
import MediaPickerUI
import ChatPresentationInterfaceState
import Pasteboard
import ChatSendMessageActionUI
import ChatTextLinkEditUI
import WebUI
import PremiumUI
import ImageTransparency

#if DEBUG
import os.signpost
#endif

public enum ChatControllerPeekActions {
    case standard
    case remove(() -> Void)
}

public final class ChatControllerOverlayPresentationData {
    public let expandData: (ASDisplayNode?, () -> Void)
    public init(expandData: (ASDisplayNode?, () -> Void)) {
        self.expandData = expandData
    }
}

private enum ChatLocationInfoData {
    case peer(Promise<PeerView>)
    case replyThread(Promise<Message?>)
    case feed
}

private enum ChatRecordingActivity {
    case voice
    case instantVideo
    case none
}

public enum NavigateToMessageLocation {
    case id(MessageId, Double?)
    case index(MessageIndex)
    case upperBound(PeerId)
    
    var messageId: MessageId? {
        switch self {
            case let .id(id, _):
                return id
            case let .index(index):
                return index.id
            case .upperBound:
                return nil
        }
    }
    
    var peerId: PeerId {
        switch self {
            case let .id(id, _):
                return id.peerId
            case let .index(index):
                return index.id.peerId
            case let .upperBound(peerId):
                return peerId
        }
    }
}

private func isTopmostChatController(_ controller: ChatControllerImpl) -> Bool {
    if let _ = controller.navigationController {
        var hasOther = false
        controller.window?.forEachController({ c in
            if c is ChatControllerImpl && controller !== c {
                hasOther = true
            }
        })
        if hasOther {
            return false
        }
    }
    return true
}

private func calculateSlowmodeActiveUntilTimestamp(account: Account, untilTimestamp: Int32?) -> Int32? {
    guard let untilTimestamp = untilTimestamp else {
        return nil
    }
    let timestamp = Int32(Date().timeIntervalSince1970)
    let remainingTime = max(0, untilTimestamp - timestamp)
    if remainingTime == 0 {
        return nil
    } else {
        return untilTimestamp
    }
}

private struct ScrolledToMessageId: Equatable {
    struct AllowedReplacementDirections: OptionSet {
        var rawValue: Int32
        
        static let up = AllowedReplacementDirections(rawValue: 1 << 0)
        static let down = AllowedReplacementDirections(rawValue: 1 << 1)
    }
    
    var id: MessageId
    var allowedReplacementDirection: AllowedReplacementDirections
}

#if DEBUG
private final class SignpostData {
    @available(iOSApplicationExtension 12.0, iOS 12.0, *)
    final class Impl {
        let signpostLog: OSLog
        let signpostId: OSSignpostID

        init() {
            self.signpostLog = OSLog(
                subsystem: "org.telegram.Telegram-iOS",
                category: "ChatAppear"
            )
            self.signpostId = OSSignpostID(log: self.signpostLog)
        }
    }

    private static var _impl: AnyObject? = {
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            return Impl()
        } else {
            return nil
        }
    }()

    @available(iOSApplicationExtension 12.0, iOS 12.0, *)
    static var impl: Impl {
        return self._impl! as! Impl
    }
}
#endif

public final class ChatControllerImpl: TelegramBaseController, ChatController, GalleryHiddenMediaTarget, UIDropInteractionDelegate {
    private var validLayout: ContainerViewLayout?
    
    public weak var parentController: ViewController?

    private let currentChatListFilter: Int32?
    private let chatNavigationStack: [PeerId]
    
    public var peekActions: ChatControllerPeekActions = .standard
    private var didSetup3dTouch: Bool = false
    
    private let context: AccountContext
    public let chatLocation: ChatLocation
    public let subject: ChatControllerSubject?
    private let botStart: ChatControllerInitialBotStart?
    private var attachBotStart: ChatControllerInitialAttachBotStart?
    
    private let peerDisposable = MetaDisposable()
    private let titleDisposable = MetaDisposable()
    private var accountPeerDisposable: Disposable?
    private let navigationActionDisposable = MetaDisposable()
    private var networkStateDisposable: Disposable?
    
    private let messageIndexDisposable = MetaDisposable()
    
    private let _chatLocationInfoReady = Promise<Bool>()
    private var didSetChatLocationInfoReady = false
    private let chatLocationInfoData: ChatLocationInfoData
    
    private let cachedDataReady = Promise<Bool>()
    private var didSetCachedDataReady = false

    private let wallpaperReady = Promise<Bool>()
    private let presentationReady = Promise<Bool>()
    
    private var presentationInterfaceState: ChatPresentationInterfaceState
    var presentationInterfaceStatePromise: ValuePromise<ChatPresentationInterfaceState>
    
    var selectedMessageIds: Set<EngineMessage.Id>? {
        return self.presentationInterfaceState.interfaceState.selectionState?.selectedIds
    }
    
    private var themeEmoticonPromise = Promise<String?>()
    
    private var chatTitleView: ChatTitleView?
    private var leftNavigationButton: ChatNavigationButton?
    private var rightNavigationButton: ChatNavigationButton?
    private var chatInfoNavigationButton: ChatNavigationButton?
    
    private var peerView: PeerView?
    
    private var historyStateDisposable: Disposable?
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    private let temporaryHiddenGalleryMediaDisposable = MetaDisposable()

    private let chatBackgroundNode: WallpaperBackgroundNode
    private(set) var controllerInteraction: ChatControllerInteraction?
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let messageContextDisposable = MetaDisposable()
    private let controllerNavigationDisposable = MetaDisposable()
    private let sentMessageEventsDisposable = MetaDisposable()
    private let failedMessageEventsDisposable = MetaDisposable()
    private weak var currentFailedMessagesAlertController: ViewController?
    private let messageActionCallbackDisposable = MetaDisposable()
    private let messageActionUrlAuthDisposable = MetaDisposable()
    private let editMessageDisposable = MetaDisposable()
    private let editMessageErrorsDisposable = MetaDisposable()
    private let enqueueMediaMessageDisposable = MetaDisposable()
    private var resolvePeerByNameDisposable: MetaDisposable?
    private var shareStatusDisposable: MetaDisposable?
    private var clearCacheDisposable: MetaDisposable?
    private var bankCardDisposable: MetaDisposable?
    private var hasActiveGroupCallDisposable: Disposable?
    private var sendAsPeersDisposable: Disposable?
    private var preloadAttachBotIconsDisposables: DisposableSet?
    
    private let editingMessage = ValuePromise<Float?>(nil, ignoreRepeated: true)
    private let startingBot = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let unblockingPeer = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let searching = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let searchResult = Promise<(SearchMessagesResult, SearchMessagesState, SearchMessagesLocation)?>()
    private let loadingMessage = Promise<ChatLoadingMessageSubject?>(nil)
    private let performingInlineSearch = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var preloadHistoryPeerId: PeerId?
    private let preloadHistoryPeerIdDisposable = MetaDisposable()

    private var preloadNextChatPeerId: PeerId?
    private let preloadNextChatPeerIdDisposable = MetaDisposable()
    
    private let botCallbackAlertMessage = Promise<String?>(nil)
    private var botCallbackAlertMessageDisposable: Disposable?
    
    private var selectMessagePollOptionDisposables: DisposableDict<MessageId>?
    private var selectPollOptionFeedback: HapticFeedback?
    
    private var resolveUrlDisposable: MetaDisposable?
    
    private var contextQueryStates: [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)] = [:]
    private var searchQuerySuggestionState: (ChatPresentationInputQuery?, Disposable)?
    private var urlPreviewQueryState: (String?, Disposable)?
    private var editingUrlPreviewQueryState: (String?, Disposable)?
    private var searchState: ChatSearchState?
    
    private var recordingModeFeedback: HapticFeedback?
    private var recorderFeedback: HapticFeedback?
    private var audioRecorderValue: ManagedAudioRecorder?
    private var audioRecorder = Promise<ManagedAudioRecorder?>()
    private var audioRecorderDisposable: Disposable?
    private var audioRecorderStatusDisposable: Disposable?
    
    private var videoRecorderValue: InstantVideoController?
    private var tempVideoRecorderValue: InstantVideoController?
    private var videoRecorder = Promise<InstantVideoController?>()
    private var videoRecorderDisposable: Disposable?
    
    private var buttonKeyboardMessageDisposable: Disposable?
    private var cachedDataDisposable: Disposable?
    private var chatUnreadCountDisposable: Disposable?
    private var buttonUnreadCountDisposable: Disposable?
    private var chatUnreadMentionCountDisposable: Disposable?
    private var peerInputActivitiesDisposable: Disposable?
    
    private var peerInputActivitiesPromise = Promise<[(Peer, PeerInputActivity)]>()
    private var interactiveEmojiSyncDisposable = MetaDisposable()
    
    private var recentlyUsedInlineBotsValue: [Peer] = []
    private var recentlyUsedInlineBotsDisposable: Disposable?
    
    private var unpinMessageDisposable: MetaDisposable?
    
    private let typingActivityPromise = Promise<Bool>(false)
    private var inputActivityDisposable: Disposable?
    private var recordingActivityValue: ChatRecordingActivity = .none
    private let recordingActivityPromise = ValuePromise<ChatRecordingActivity>(.none, ignoreRepeated: true)
    private var recordingActivityDisposable: Disposable?
    private var acquiredRecordingActivityDisposable: Disposable?
    private let choosingStickerActivityPromise = ValuePromise<Bool>(false)
    private var choosingStickerActivityDisposable: Disposable?
    
    private var searchDisposable: MetaDisposable?
    
    private var historyNavigationStack = ChatHistoryNavigationStack()
    
    public let canReadHistory = ValuePromise<Bool>(true, ignoreRepeated: true)
    private var reminderActivity: NSUserActivity?
    private var isReminderActivityEnabled: Bool = false
    
    private var canReadHistoryValue = false
    private var canReadHistoryDisposable: Disposable?
    
    private var themeEmoticonAndDarkAppearancePreviewPromise = Promise<(String?, Bool?)>((nil, nil))
    private var didSetPresentationData = false
    private var presentationData: PresentationData
    private var presentationDataPromise = Promise<PresentationData>()
    override public var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) {
        return (self.presentationData, self.presentationDataPromise.get())
    }
    private var presentationDataDisposable: Disposable?
    
    private var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    private var automaticMediaDownloadSettingsDisposable: Disposable?
    
    private var disableStickerAnimationsPromise = ValuePromise<Bool>(false)
    private var disableStickerAnimationsValue = false
    var disableStickerAnimations: Bool {
        get {
            return self.disableStickerAnimationsValue
        } set {
            self.disableStickerAnimationsPromise.set(newValue)
        }
    }
    private var stickerSettings: ChatInterfaceStickerSettings
    private var stickerSettingsDisposable: Disposable?
    
    private var applicationInForegroundDisposable: Disposable?
    private var applicationInFocusDisposable: Disposable?
    
    private let checksTooltipDisposable = MetaDisposable()
    private var shouldDisplayChecksTooltip = false
    
    private let peerSuggestionsDisposable = MetaDisposable()
    private let peerSuggestionsDismissDisposable = MetaDisposable()
    private var displayedConvertToGigagroupSuggestion = false
    
    private var checkedPeerChatServiceActions = false
    
    private var willAppear = false
    private var didAppear = false
    private var scheduledActivateInput = false
    
    private var raiseToListen: RaiseToListenManager?
    private var voicePlaylistDidEndTimestamp: Double = 0.0

    private weak var sendingOptionsTooltipController: TooltipController?
    private weak var searchResultsTooltipController: TooltipController?
    private weak var messageTooltipController: TooltipController?
    private weak var videoUnmuteTooltipController: TooltipController?
    private weak var silentPostTooltipController: TooltipController?
    private weak var mediaRecordingModeTooltipController: TooltipController?
    private weak var mediaRestrictedTooltipController: TooltipController?
    private var mediaRestrictedTooltipControllerMode = true
    private weak var checksTooltipController: TooltipController?
    private weak var copyProtectionTooltipController: TooltipController?
    
    private var currentMessageTooltipScreens: [(TooltipScreen, ListViewItemNode)] = []
    
    private weak var slowmodeTooltipController: ChatSlowmodeHintController?
    
    private weak var currentContextController: ContextController?
    
    private weak var sendMessageActionsController: ChatSendMessageActionSheetController?
    private var searchResultsController: ChatSearchResultsController?

    private weak var themeSceen: ChatThemeScreen?
    
    private weak var currentPinchController: PinchController?
    private weak var currentPinchSourceItemNode: ListViewItemNode?
    
    private var screenCaptureManager: ScreenCaptureDetectionManager?
    private let chatAdditionalDataDisposable = MetaDisposable()
    
    private var reportIrrelvantGeoNoticePromise = Promise<Bool?>()
    private var reportIrrelvantGeoNotice: Bool?
    private var reportIrrelvantGeoDisposable: Disposable?
    
    private var hasScheduledMessages: Bool = false
    
    private var volumeButtonsListener: VolumeButtonsListener?
    
    private var beginMediaRecordingRequestId: Int = 0
    private var lockMediaRecordingRequestId: Int?
    
    private var updateSlowmodeStatusDisposable = MetaDisposable()
    private var updateSlowmodeStatusTimerValue: Int32?
    
    private var isDismissed = false
    
    private var focusOnSearchAfterAppearance: (ChatSearchDomain, String)?
    
    private let keepPeerInfoScreenDataHotDisposable = MetaDisposable()
    private let preloadAvatarDisposable = MetaDisposable()
    
    private let peekData: ChatPeekTimeout?
    private let peekTimerDisposable = MetaDisposable()
    
    private let createVoiceChatDisposable = MetaDisposable()
    
    private let selectAddMemberDisposable = MetaDisposable()
    private let addMemberDisposable = MetaDisposable()
    
    private var shouldDisplayDownButton = false

    private var hasEmbeddedTitleContent = false
    private var isEmbeddedTitleContentHidden = false
    
    private let chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    
    private weak var attachmentController: AttachmentController?
    private weak var currentMenuWebAppController: ViewController?
    private weak var currentWebAppController: ViewController?
    
    private weak var currentImportMessageTooltip: UndoOverlayController?

    public override var customData: Any? {
        return self.chatLocation
    }
    
    override public var customNavigationData: CustomViewControllerNavigationData? {
        get {
            if case let .peer(peerId) = self.chatLocation {
                return ChatControllerNavigationData(peerId: peerId)
            } else {
                return nil
            }
        }
    }
    
    private var scheduledScrollToMessageId: (MessageId, Double?)?
    
    public var purposefulAction: (() -> Void)?
    var updatedClosedPinnedMessageId: ((MessageId) -> Void)?
    var requestedUnpinAllMessages: ((Int, MessageId) -> Void)?
    
    private let scrolledToMessageId = ValuePromise<ScrolledToMessageId?>(nil, ignoreRepeated: true)
    private var scrolledToMessageIdValue: ScrolledToMessageId? = nil {
        didSet {
            self.scrolledToMessageId.set(self.scrolledToMessageIdValue)
        }
    }
    
    private var importStateDisposable: Disposable?

    private var nextChannelToReadDisposable: Disposable?
    
    private var inviteRequestsContext: PeerInvitationImportersContext?
    private var inviteRequestsDisposable = MetaDisposable()
    
    public init(context: AccountContext, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?> = Atomic<ChatLocationContextHolder?>(value: nil), subject: ChatControllerSubject? = nil, botStart: ChatControllerInitialBotStart? = nil, attachBotStart: ChatControllerInitialAttachBotStart? = nil, mode: ChatControllerPresentationMode = .standard(previewing: false), peekData: ChatPeekTimeout? = nil, peerNearbyData: ChatPeerNearbyData? = nil, chatListFilter: Int32? = nil, chatNavigationStack: [PeerId] = []) {
        let _ = ChatControllerCount.modify { value in
            return value + 1
        }
        
        self.context = context
        self.chatLocation = chatLocation
        self.chatLocationContextHolder = chatLocationContextHolder
        self.subject = subject
        self.botStart = botStart
        self.attachBotStart = attachBotStart
        self.peekData = peekData
        self.currentChatListFilter = chatListFilter
        self.chatNavigationStack = chatNavigationStack

        var useSharedAnimationPhase = false
        switch mode {
        case .standard(false):
            useSharedAnimationPhase = true
        default:
            break
        }
        self.chatBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: useSharedAnimationPhase, useExperimentalImplementation: self.context.sharedContext.immediateExperimentalUISettings.experimentalBackground)
        self.wallpaperReady.set(self.chatBackgroundNode.isReady)
        
        var locationBroadcastPanelSource: LocationBroadcastPanelSource
        var groupCallPanelSource: GroupCallPanelSource
        
        switch chatLocation {
        case let .peer(peerId):
            locationBroadcastPanelSource = .peer(peerId)
            switch subject {
            case .message, .none:
                groupCallPanelSource = .peer(peerId)
            default:
                groupCallPanelSource = .none
            }
            self.chatLocationInfoData = .peer(Promise())
        case let .replyThread(replyThreadMessage):
            locationBroadcastPanelSource = .none
            groupCallPanelSource = .none
            let promise = Promise<Message?>()
            promise.set(context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: replyThreadMessage.messageId))
            |> map { message -> Message? in
                guard let message = message else {
                    return nil
                }
                return message._asMessage()
            })
            self.chatLocationInfoData = .replyThread(promise)
        case .feed:
            locationBroadcastPanelSource = .none
            groupCallPanelSource = .none
            self.chatLocationInfoData = .feed
        }
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.automaticMediaDownloadSettings = context.sharedContext.currentAutomaticMediaDownloadSettings.with { $0 }
        
        self.stickerSettings = ChatInterfaceStickerSettings(loopAnimatedStickers: false)
        
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: context.account.peerId, mode: mode, chatLocation: chatLocation, subject: subject, peerNearbyData: peerNearbyData, greetingData: context.prefetchManager?.preloadedGreetingSticker, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil)
        self.presentationInterfaceStatePromise = ValuePromise(self.presentationInterfaceState)
        
        var mediaAccessoryPanelVisibility = MediaAccessoryPanelVisibility.none
        if case .standard = mode {
            mediaAccessoryPanelVisibility = .specific(size: .compact)
        } else {
            locationBroadcastPanelSource = .none
            groupCallPanelSource = .none
        }
        let navigationBarPresentationData: NavigationBarPresentationData?
        switch mode {
            case .inline:
                navigationBarPresentationData = nil
            default:
                navigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData, hideBackground: self.context.sharedContext.immediateExperimentalUISettings.playerEmbedding ? true : false, hideBadge: false)
        }
        super.init(context: context, navigationBarPresentationData: navigationBarPresentationData, mediaAccessoryPanelVisibility: mediaAccessoryPanelVisibility, locationBroadcastPanelSource: locationBroadcastPanelSource, groupCallPanelSource: groupCallPanelSource)
        
        self.automaticallyControlPresentationContextLayout = false
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            if let attachmentController = strongSelf.attachmentController {
                attachmentController.scrollToTop?()
            } else {
                strongSelf.chatDisplayNode.scrollToTop()
            }
        }
        
        self.attemptNavigation = { [weak self] action in
            guard let strongSelf = self else {
                return true
            }
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            if strongSelf.presentVoiceMessageDiscardAlert(action: action, performAction: false) {
                return false
            }
            return true
        }
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] message, mode in
            guard let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) else {
                return false
            }
            
            strongSelf.commitPurposefulAction()
            strongSelf.dismissAllTooltips()
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            var openMessageByAction = false
            var isLocation = false
            for media in message.media {
                if media is TelegramMediaMap {
                    isLocation = true
                }
                if let file = media as? TelegramMediaFile, file.isInstantVideo {
                    if strongSelf.chatDisplayNode.isInputViewFocused {
                        strongSelf.returnInputViewFocus = true
                        strongSelf.chatDisplayNode.dismissInput()
                    }
                }
                if let action = media as? TelegramMediaAction {
                    switch action.action {
                        case .pinnedMessageUpdated:
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    strongSelf.navigateToMessage(from: message.id, to: .id(attribute.messageId, nil))
                                    break
                                }
                            }
                        case let .photoUpdated(image):
                            openMessageByAction = image != nil
                        case .gameScore:
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    strongSelf.navigateToMessage(from: message.id, to: .id(attribute.messageId, nil))
                                    break
                                }
                            }
                        case .groupPhoneCall, .inviteToGroupPhoneCall:
                            if let activeCall = strongSelf.presentationInterfaceState.activeGroupCallInfo?.activeCall {
                                strongSelf.joinGroupCall(peerId: message.id.peerId, invite: nil, activeCall: EngineGroupCallDescription(id: activeCall.id, accessHash: activeCall.accessHash, title: activeCall.title, scheduleTimestamp: activeCall.scheduleTimestamp, subscribedToScheduled: activeCall.subscribedToScheduled, isStream: activeCall.isStream))
                            } else {
                                var canManageGroupCalls = false
                                if let channel = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel {
                                    if channel.flags.contains(.isCreator) || channel.hasPermission(.manageCalls) {
                                        canManageGroupCalls = true
                                    }
                                } else if let group = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramGroup {
                                    if case .creator = group.role {
                                        canManageGroupCalls = true
                                    } else if case let .admin(rights, _) = group.role {
                                        if rights.rights.contains(.canManageCalls) {
                                            canManageGroupCalls = true
                                        }
                                    }
                                }
                                
                                if canManageGroupCalls {
                                    let text: String
                                    if let channel = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case .broadcast = channel.info {
                                        text = strongSelf.presentationData.strings.LiveStream_CreateNewVoiceChatText
                                    } else {
                                        text = strongSelf.presentationData.strings.VoiceChat_CreateNewVoiceChatText
                                    }
                                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.VoiceChat_CreateNewVoiceChatStartNow, action: {
                                        if let strongSelf = self {
                                            var dismissStatus: (() -> Void)?
                                            let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                                dismissStatus?()
                                            }))
                                            dismissStatus = { [weak self, weak statusController] in
                                                self?.createVoiceChatDisposable.set(nil)
                                                statusController?.dismiss()
                                            }
                                            strongSelf.present(statusController, in: .window(.root))
                                            strongSelf.createVoiceChatDisposable.set((strongSelf.context.engine.calls.createGroupCall(peerId: message.id.peerId, title: nil, scheduleDate: nil, isExternalStream: false)
                                            |> deliverOnMainQueue).start(next: { [weak self] info in
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.joinGroupCall(peerId: message.id.peerId, invite: nil, activeCall: EngineGroupCallDescription(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled, isStream: info.isStream))
                                            }, error: { [weak self] error in
                                                dismissStatus?()
                                                
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                            
                                                let text: String
                                                switch error {
                                                case .generic, .scheduledTooLate:
                                                    text = strongSelf.presentationData.strings.Login_UnknownError
                                                case .anonymousNotAllowed:
                                                    if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                                                        text = strongSelf.presentationData.strings.LiveStream_AnonymousDisabledAlertText
                                                    } else {
                                                        text = strongSelf.presentationData.strings.VoiceChat_AnonymousDisabledAlertText
                                                    }
                                                }
                                                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                            }, completed: {
                                                dismissStatus?()
                                            }))
                                        }
                                    }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.VoiceChat_CreateNewVoiceChatSchedule, action: {
                                        if let strongSelf = self {
                                            strongSelf.context.scheduleGroupCall(peerId: message.id.peerId)
                                        }
                                    }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})], actionLayout: .vertical), in: .window(.root))
                                }
                            }
                            return true
                        case .messageAutoremoveTimeoutUpdated:
                            var canSetupAutoremoveTimeout = false
                            
                            if let _ = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat {
                                canSetupAutoremoveTimeout = false
                            } else if let group = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                                if case .creator = group.role {
                                    canSetupAutoremoveTimeout = true
                                } else if case let .admin(rights, _) = group.role {
                                    if rights.rights.contains(.canDeleteMessages) {
                                        canSetupAutoremoveTimeout = true
                                    }
                                }
                            } else if let user = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramUser {
                                if user.id != strongSelf.context.account.peerId && user.botInfo == nil {
                                    canSetupAutoremoveTimeout = true
                                }
                            } else if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
                                if channel.hasPermission(.deleteAllMessages) {
                                    canSetupAutoremoveTimeout = true
                                }
                            }
                            
                            if canSetupAutoremoveTimeout {
                                strongSelf.presentAutoremoveSetup()
                            }
                        case .paymentSent:
                            strongSelf.present(BotReceiptController(context: strongSelf.context, messageId: message.id), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            /*for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    //strongSelf.navigateToMessage(from: message.id, to: .id(attribute.messageId))
                                    break
                                }
                            }*/
                            return true
                        case .setChatTheme:
                            strongSelf.presentThemeSelection()
                            return true
                        default:
                            break
                    }
                    if !openMessageByAction {
                        return true
                    }
                }
            }
            
            var openChatLocation = strongSelf.chatLocation
            if case let .replyThread(replyThreadMessage) = openChatLocation {
                if message.threadId != makeMessageThreadId(replyThreadMessage.messageId) {
                    openChatLocation = .peer(id: message.id.peerId)
                }
            }
            
            return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, updatedPresentationData: strongSelf.updatedPresentationData, chatLocation: openChatLocation, chatLocationContextHolder: strongSelf.chatLocationContextHolder, message: message, standalone: false, reverseMessageGalleryOrder: false, mode: mode, navigationController: strongSelf.effectiveNavigationController, dismissInput: {
                self?.chatDisplayNode.dismissInput()
            }, present: { c, a in
                self?.present(c, in: .window(.root), with: a, blockInteraction: true)
            }, transitionNode: { messageId, media in
                var selectedNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                if let strongSelf = self {
                    strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            if let result = itemNode.transitionNode(id: messageId, media: media) {
                                selectedNode = result
                            }
                        }
                    }
                }
                return selectedNode
            }, addToTransitionSurface: { view in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.chatDisplayNode.historyNode.view)
            }, openUrl: { url in
                self?.openUrl(url, concealed: false, skipConcealedAlert: isLocation, message: nil)
            }, openPeer: { peer, navigation in
                self?.openPeer(peerId: peer.id, navigation: navigation, fromMessage: nil)
            }, callPeer: { peerId, isVideo in
                self?.controllerInteraction?.callPeer(peerId, isVideo)
            }, enqueueMessage: { message in
                self?.sendMessages([message])
            }, sendSticker: canSendMessagesToChat(strongSelf.presentationInterfaceState) ? { fileReference, sourceNode, sourceRect in
                return self?.controllerInteraction?.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect) ?? false
            } : nil, setupTemporaryHiddenMedia: { signal, centralIndex, galleryMedia in
                if let strongSelf = self {
                    strongSelf.temporaryHiddenGalleryMediaDisposable.set((signal |> deliverOnMainQueue).start(next: { entry in
                        if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                            var messageIdAndMedia: [MessageId: [Media]] = [:]
                            
                            if let entry = entry as? InstantPageGalleryEntry, entry.index == centralIndex {
                                messageIdAndMedia[message.id] = [galleryMedia]
                            }
                            
                            controllerInteraction.hiddenMedia = messageIdAndMedia
                            
                            strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMessageItemView {
                                    itemNode.updateHiddenMedia()
                                }
                            }
                        }
                    }))
                }
            }, chatAvatarHiddenMedia: { signal, media in
                if let strongSelf = self {
                    strongSelf.temporaryHiddenGalleryMediaDisposable.set((signal |> deliverOnMainQueue).start(next: { messageId in
                        if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                            var messageIdAndMedia: [MessageId: [Media]] = [:]
                            
                            if let messageId = messageId {
                                messageIdAndMedia[messageId] = [media]
                            }
                            
                            controllerInteraction.hiddenMedia = messageIdAndMedia
                            
                            strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMessageItemView {
                                    itemNode.updateHiddenMedia()
                                }
                            }
                        }
                    }))
                }
            }, actionInteraction: GalleryControllerActionInteraction(openUrl: { [weak self] url, concealed in
                if let strongSelf = self {
                    strongSelf.openUrl(url, concealed: concealed, message: nil)
                }
            }, openUrlIn: { [weak self] url in
                if let strongSelf = self {
                    strongSelf.openUrlIn(url)
                }
            }, openPeerMention: { [weak self] mention in
                if let strongSelf = self {
                    strongSelf.controllerInteraction?.openPeerMention(mention)
                }
            }, openPeer: { [weak self] peerId in
                if let strongSelf = self {
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil, nil)
                }
            }, openHashtag: { [weak self] peerName, hashtag in
                if let strongSelf = self {
                    strongSelf.controllerInteraction?.openHashtag(peerName, hashtag)
                }
            }, openBotCommand: { [weak self] command in
                if let strongSelf = self {
                    strongSelf.controllerInteraction?.sendBotCommand(nil, command)
                }
            }, addContact: { [weak self] phoneNumber in
                if let strongSelf = self {
                    strongSelf.controllerInteraction?.addContact(phoneNumber)
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
                                strongSelf.present(controller, in: .window(.root))
                                return controller
                            } else {
                                return nil
                            }
                        }, getCaptionPanelView: { [weak self] in
                            return self?.getCaptionPanelView()
                        }, sendMessagesWithSignals: { [weak self] signals, _, _ in
                            if let strongSelf = self {
                                strongSelf.enqueueMediaMessages(signals: signals, silentPosting: false)
                            }
                        }, present: { [weak self] c, a in
                            self?.present(c, in: .window(.root), with: a)
                        })
                    }
                })
            })))
        }, openPeer: { [weak self] id, navigation, fromMessage, _ in
            self?.openPeer(peerId: id, navigation: navigation, fromMessage: fromMessage)
        }, openPeerMention: { [weak self] name in
            self?.openPeerMention(name)
        }, openMessageContextMenu: { [weak self] message, selectAll, node, frame, anyRecognizer in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            if strongSelf.presentationInterfaceState.interfaceState.selectionState != nil {
                return
            }
            
            strongSelf.dismissAllTooltips()
            
            let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
            let gesture: ContextGesture? = anyRecognizer as? ContextGesture
            if let messages = strongSelf.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) {
                (strongSelf.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
                strongSelf.chatDisplayNode.cancelInteractiveKeyboardGestures()
                var updatedMessages = messages
                for i in 0 ..< updatedMessages.count {
                    if updatedMessages[i].id == message.id {
                        let message = updatedMessages.remove(at: i)
                        updatedMessages.insert(message, at: 0)
                        break
                    }
                }
                
                guard let topMessage = messages.first else {
                    return
                }
                
                let _ = combineLatest(queue: .mainQueue(),
                    strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.context.account.peerId)),
                    contextMenuForChatPresentationInterfaceState(chatPresentationInterfaceState: strongSelf.presentationInterfaceState, context: strongSelf.context, messages: updatedMessages, controllerInteraction: strongSelf.controllerInteraction, selectAll: selectAll, interfaceInteraction: strongSelf.interfaceInteraction, messageNode: node as? ChatMessageItemView),
                    strongSelf.context.engine.stickers.availableReactions(),
                    peerAllowedReactions(context: strongSelf.context, peerId: topMessage.id.peerId),
                    ApplicationSpecificNotice.getChatTextSelectionTips(accountManager: strongSelf.context.sharedContext.accountManager)
                ).start(next: { peer, actions, availableReactions, allowedReactions, chatTextSelectionTips in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var hasPremium = false
                    if case let .user(user) = peer, user.isPremium {
                        hasPremium = true
                    }
                    
                    var actions = actions
                    switch actions.content {
                    case let .list(itemList):
                        if itemList.isEmpty {
                            return
                        }
                    case .custom:
                        break
                    }

                    var tip: ContextController.Tip?

                    if tip == nil {
                        var isAction = false
                        for media in message.media {
                            if media is TelegramMediaAction {
                                isAction = true
                                break
                            }
                        }
                        if strongSelf.presentationInterfaceState.copyProtectionEnabled && !isAction {
                            if case .scheduledMessages = strongSelf.subject {
                            } else {
                                var isChannel = false
                                if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
                                    isChannel = true
                                }
                                tip = .messageCopyProtection(isChannel: isChannel)
                            }
                        } else {
                            let numberOfComponents = message.text.components(separatedBy: CharacterSet.whitespacesAndNewlines).count
                            let displayTextSelectionTip = numberOfComponents >= 3 && !message.text.isEmpty && chatTextSelectionTips < 3
                            if displayTextSelectionTip {
                                let _ = ApplicationSpecificNotice.incrementChatTextSelectionTips(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                tip = .textSelection
                            }
                        }
                    }

                    if actions.tip == nil {
                        actions.tip = tip
                    }
                    
                    actions.context = strongSelf.context
                                 
                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: strongSelf.context.currentAppConfiguration.with { $0 })
                    
                    if canAddMessageReactions(message: topMessage), let availableReactions = availableReactions, let allowedReactions = allowedReactions {
                        var hasPremiumPlaceholder = false
                        filterReactions: for reaction in availableReactions.reactions {
                            guard let centerAnimation = reaction.centerAnimation else {
                                continue
                            }
                            guard let aroundAnimation = reaction.aroundAnimation else {
                                continue
                            }
                            if !reaction.isEnabled {
                                continue
                            }

                            switch allowedReactions {
                            case let .set(set):
                                if !set.contains(reaction.value) {
                                    continue filterReactions
                                }
                            case .all:
                                break
                            }
                            
                            if reaction.isPremium && !hasPremium {
                                hasPremiumPlaceholder = true
                                continue
                            }
                            
                            actions.reactionItems.append(.reaction(ReactionItem(
                                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                appearAnimation: reaction.appearAnimation,
                                stillAnimation: reaction.selectAnimation,
                                listAnimation: centerAnimation,
                                largeListAnimation: reaction.activateAnimation,
                                applicationAnimation: aroundAnimation,
                                largeApplicationAnimation: reaction.effectAnimation
                            )))
                        }
                        
                        if hasPremiumPlaceholder && !premiumConfiguration.isPremiumDisabled {
                            actions.reactionItems.append(.premium)
                        }
                    }
                    
                    strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                    
                    let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, engine: strongSelf.context.engine, message: message, selectAll: selectAll)), items: .single(actions), recognizer: recognizer, gesture: gesture)
                    controller.getOverlayViews = { [weak self] in
                        guard let strongSelf = self else {
                            return []
                        }
                        return [strongSelf.chatDisplayNode.navigateButtons.view]
                    }
                    strongSelf.currentContextController = controller
                    
                    controller.reactionSelected = { [weak controller] value, isLarge in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if case .premium = value {
                            controller?.dismissWithoutContent()

                            let context = strongSelf.context
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = PremiumDemoScreen(context: context, subject: .uniqueReactions, action: {
                                let controller = PremiumIntroScreen(context: context, source: .reactions)
                                replaceImpl?(controller)
                            })
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                            strongSelf.push(controller)
                            return
                        }
                        
                        guard let message = messages.first, let reaction = value.reaction else {
                            return
                        }
                        
                        var updatedReaction: String? = reaction.rawValue
                        var isFirst = true
                        for attribute in topMessage.attributes {
                            if let attribute = attribute as? ReactionsMessageAttribute {
                                for existingReaction in attribute.reactions {
                                    if existingReaction.value == reaction.rawValue {
                                        if existingReaction.isSelected {
                                            updatedReaction = nil
                                        }
                                        isFirst = false
                                    }
                                }
                            } else if let attribute = attribute as? PendingReactionsMessageAttribute {
                                if let current = attribute.value, current == reaction.rawValue {
                                    updatedReaction = nil
                                }
                            }
                        }
                        
                        strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                                if item.message.id == message.id {
                                    if let updatedReaction = updatedReaction {
                                        itemNode.awaitingAppliedReaction = (updatedReaction, { [weak itemNode] in
                                            guard let controller = controller else {
                                                return
                                            }
                                            if let itemNode = itemNode, let targetView = itemNode.targetReactionView(value: updatedReaction) {
                                                strongSelf.chatDisplayNode.messageTransitionNode.addMessageContextController(messageId: item.message.id, contextController: controller)
                                                
                                                var hideTargetButton: UIView?
                                                if isFirst {
                                                    hideTargetButton = targetView.superview
                                                }
                                                
                                                controller.dismissWithReaction(value: updatedReaction, targetView: targetView, hideNode: true, animateTargetContainer: hideTargetButton, addStandaloneReactionAnimation: { standaloneReactionAnimation in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                                    standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                                    strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                                }, completion: { [weak itemNode, weak targetView] in
                                                    guard let strongSelf = self, let itemNode = itemNode, let targetView = targetView else {
                                                        return
                                                    }
                                                    
                                                    let _ = strongSelf
                                                    let _ = itemNode
                                                    let _ = targetView
                                                })
                                            }
                                        })
                                    } else if updatedReaction == nil {
                                        itemNode.awaitingAppliedReaction = (nil, {
                                            controller?.dismiss()
                                        })
                                    }
                                }
                            }
                        }
                        let _ = updateMessageReactionsInteractively(account: strongSelf.context.account, messageId: message.id, reaction: updatedReaction, isLarge: isLarge).start()
                    }

                    strongSelf.forEachController({ controller in
                        if let controller = controller as? TooltipScreen {
                            controller.dismiss()
                        }
                        return true
                    })
                    strongSelf.window?.presentInGlobalOverlay(controller)
                })
            }
        }, openMessageReactionContextMenu: { [weak self] message, sourceView, gesture, value in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.stickers.availableReactions()
            |> deliverOnMainQueue).start(next: { availableReactions in
                guard let strongSelf = self else {
                    return
                }
                
                var dismissController: ((@escaping () -> Void) -> Void)?
                
                let items = ContextController.Items(content: .custom(ReactionListContextMenuContent(context: strongSelf.context, availableReactions: availableReactions, message: EngineMessage(message), reaction: value, readStats: nil, back: nil, openPeer: { id in
                    dismissController?({
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.openPeer(peerId: id, navigation: .default, fromMessage: MessageReference(message))
                    })
                })))
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageReactionContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, engine: strongSelf.context.engine, message: message, contentView: sourceView)), items: .single(items), recognizer: nil, gesture: gesture)
                
                dismissController = { [weak controller] completion in
                    controller?.dismiss(completion: {
                        completion()
                    })
                }
                
                strongSelf.forEachController({ controller in
                    if let controller = controller as? TooltipScreen {
                        controller.dismiss()
                    }
                    return true
                })
                strongSelf.window?.presentInGlobalOverlay(controller)
            })
        }, updateMessageReaction: { [weak self] initialMessage, reaction in
            guard let strongSelf = self else {
                return
            }
            guard let messages = strongSelf.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(initialMessage.id) else {
                return
            }
            guard let message = messages.first else {
                return
            }
            
            let _ = (peerAllowedReactions(context: strongSelf.context, peerId: message.id.peerId)
            |> deliverOnMainQueue).start(next: { allowedReactions in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                    guard let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item else {
                        return
                    }
                    guard item.message.id == message.id else {
                        return
                    }
                    
                    if !canAddMessageReactions(message: message) {
                        itemNode.openMessageContextMenu()
                        return
                    }
                    
                    var updatedReaction: String?
                    switch reaction {
                    case .default:
                        updatedReaction = item.associatedData.defaultReaction
                    case let .reaction(value):
                        updatedReaction = value
                    }
                    
                    var removedReaction: String?
                    var messageAlreadyHasThisReaction = false
                    
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReactionsMessageAttribute {
                            for listReaction in attribute.reactions {
                                switch reaction {
                                case .default:
                                    if listReaction.isSelected {
                                        updatedReaction = nil
                                        removedReaction = listReaction.value
                                    } else if listReaction.value == updatedReaction {
                                        messageAlreadyHasThisReaction = true
                                    }
                                case let .reaction(value):
                                    if listReaction.value == value {
                                        messageAlreadyHasThisReaction = true
                                        
                                        if listReaction.isSelected {
                                            updatedReaction = nil
                                            removedReaction = value
                                        }
                                    }
                                }
                            }
                        } else if let attribute = attribute as? PendingReactionsMessageAttribute {
                            if attribute.value != nil {
                                switch reaction {
                                case .default:
                                    updatedReaction = nil
                                    removedReaction = attribute.value
                                case let .reaction(value):
                                    if attribute.value == value {
                                        updatedReaction = nil
                                        removedReaction = value
                                    }
                                }
                            }
                        }
                    }
                    
                    if let updatedReaction = updatedReaction {
                        guard let allowedReactions = allowedReactions else {
                            itemNode.openMessageContextMenu()
                            return
                        }
                        switch allowedReactions {
                        case let .set(set):
                            if !messageAlreadyHasThisReaction && !set.contains(updatedReaction) {
                                itemNode.openMessageContextMenu()
                                return
                            }
                        case .all:
                            break
                        }
                        
                        if strongSelf.selectPollOptionFeedback == nil {
                            strongSelf.selectPollOptionFeedback = HapticFeedback()
                        }
                        strongSelf.selectPollOptionFeedback?.tap()
                        
                        itemNode.awaitingAppliedReaction = (updatedReaction, { [weak itemNode] in
                            guard let strongSelf = self else {
                                return
                            }
                            if let itemNode = itemNode, let item = itemNode.item, let availableReactions = item.associatedData.availableReactions, let targetView = itemNode.targetReactionView(value: updatedReaction) {
                                for reaction in availableReactions.reactions {
                                    guard let centerAnimation = reaction.centerAnimation else {
                                        continue
                                    }
                                    guard let aroundAnimation = reaction.aroundAnimation else {
                                        continue
                                    }
                                    
                                    if reaction.value == updatedReaction {
                                        let standaloneReactionAnimation = StandaloneReactionAnimation()
                                        
                                        strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                        
                                        strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                        standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                        standaloneReactionAnimation.animateReactionSelection(
                                            context: strongSelf.context,
                                            theme: strongSelf.presentationData.theme,
                                            reaction: ReactionItem(
                                                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                                appearAnimation: reaction.appearAnimation,
                                                stillAnimation: reaction.selectAnimation,
                                                listAnimation: centerAnimation,
                                                largeListAnimation: reaction.activateAnimation,
                                                applicationAnimation: aroundAnimation,
                                                largeApplicationAnimation: reaction.effectAnimation
                                            ),
                                            avatarPeers: [],
                                            playHaptic: false,
                                            isLarge: false,
                                            targetView: targetView,
                                            addStandaloneReactionAnimation: { standaloneReactionAnimation in
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                                standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                                strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                            },
                                            completion: { [weak standaloneReactionAnimation] in
                                                standaloneReactionAnimation?.removeFromSupernode()
                                            }
                                        )
                                        
                                        break
                                    }
                                }
                            }
                        })
                    } else {
                        strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts(itemNode: itemNode)
                        
                        if let removedReaction = removedReaction, let targetView = itemNode.targetReactionView(value: removedReaction), shouldDisplayInlineDateReactions(message: message) {
                            var hideRemovedReaction: Bool = false
                            if let reactions = mergedMessageReactions(attributes: message.attributes) {
                                for reaction in reactions.reactions {
                                    if reaction.value == removedReaction {
                                        hideRemovedReaction = reaction.count == 1
                                        break
                                    }
                                }
                            }
                            
                            let standaloneDismissAnimation = StandaloneDismissReactionAnimation()
                            standaloneDismissAnimation.frame = strongSelf.chatDisplayNode.bounds
                            strongSelf.chatDisplayNode.addSubnode(standaloneDismissAnimation)
                            standaloneDismissAnimation.animateReactionDismiss(sourceView: targetView, hideNode: hideRemovedReaction, isIncoming: message.effectivelyIncoming(strongSelf.context.account.peerId), completion: { [weak standaloneDismissAnimation] in
                                standaloneDismissAnimation?.removeFromSupernode()
                            })
                        }
                    }
                    
                    let _ = updateMessageReactionsInteractively(account: strongSelf.context.account, messageId: message.id, reaction: updatedReaction, isLarge: false).start()
                }
            })
        }, activateMessagePinch: { [weak self] sourceNode in
            guard let strongSelf = self else {
                return
            }

            var sourceItemNode: ListViewItemNode?
            strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                guard let itemNode = itemNode as? ListViewItemNode else {
                    return
                }
                if sourceNode.view.isDescendant(of: itemNode.view) {
                    sourceItemNode = itemNode
                }
            }

            let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
                guard let strongSelf = self else {
                    return CGRect()
                }

                return strongSelf.chatDisplayNode.view.convert(strongSelf.chatDisplayNode.frameForVisibleArea(), to: nil)
            })
            strongSelf.currentPinchController = pinchController
            strongSelf.currentPinchSourceItemNode = sourceItemNode
            strongSelf.window?.presentInGlobalOverlay(pinchController)
        }, openMessageContextActions: { message, node, rect, gesture in
            gesture?.cancel()
        }, navigateToMessage: { [weak self] fromId, id in
            self?.navigateToMessage(from: fromId, to: .id(id, nil), forceInCurrentChat: fromId.peerId == id.peerId)
        }, navigateToMessageStandalone: { [weak self] id in
            self?.navigateToMessage(from: nil, to: .id(id, nil), forceInCurrentChat: false)
        }, tapMessage: nil, clickThroughMessage: { [weak self] in
            self?.chatDisplayNode.dismissInput()
        }, toggleMessagesSelection: { [weak self] ids, value in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            
            if let subject = strongSelf.subject, case .forwardedMessages = subject, !value {
                let selectedCount = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds.count ?? 0
                let updatedSelectedCount = selectedCount - ids.count
                if updatedSelectedCount < 1 {
                    return
                }
            }
            
            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withToggledSelectedMessages(ids, value: value) } })
            if let selectionState = strongSelf.presentationInterfaceState.interfaceState.selectionState {
                let count = selectionState.selectedIds.count
                let text = strongSelf.presentationData.strings.VoiceOver_Chat_MessagesSelected(Int32(count))
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
                    UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: text as NSString)
                })
            }
        }, sendCurrentMessage: { [weak self] silentPosting in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.recordedMediaPreview {
                    strongSelf.sendMediaRecording(silentPosting: silentPosting)
                } else {
                    strongSelf.chatDisplayNode.sendCurrentMessage(silentPosting: silentPosting)
                }
            }
        }, sendMessage: { [weak self] text in
            guard let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) else {
                return
            }
            
            var isScheduledMessages = false
            if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                isScheduledMessages = true
            }
            
            guard !isScheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            }, nil)
            var attributes: [MessageAttribute] = []
            let entities = generateTextEntities(text, enabledTypes: .all)
            if !entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: entities))
            }
            strongSelf.sendMessages([.message(text: text, attributes: attributes, mediaReference: nil, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil, correlationId: nil)])
        }, sendSticker: { [weak self] fileReference, silentPosting, schedule, query, clearInput, sourceNode, sourceRect in
            guard let strongSelf = self else {
                return false
            }
            
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceNode, sourceRect)
                return false
            }
            
            var attributes: [MessageAttribute] = []
            if let query = query {
                attributes.append(EmojiSearchQueryMessageAttribute(query: query))
            }

            let correlationId = Int64.random(in: 0 ..< Int64.max)

            var replyPanel: ReplyAccessoryPanelNode?
            if let accessoryPanelNode = strongSelf.chatDisplayNode.accessoryPanelNode as? ReplyAccessoryPanelNode {
                replyPanel = accessoryPanelNode
            }

            var shouldAnimateMessageTransition = strongSelf.chatDisplayNode.shouldAnimateMessageTransition
            if sourceNode is ChatEmptyNodeStickerContentNode {
                shouldAnimateMessageTransition = true
            }

            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, { current in
                        var current = current
                        current = current.updatedInterfaceState { interfaceState in
                            var interfaceState = interfaceState
                            interfaceState = interfaceState.withUpdatedReplyMessageId(nil)
                            if clearInput {
                                interfaceState = interfaceState.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString()))
                            }
                            return interfaceState
                        }.updatedInputMode { current in
                            if case let .media(mode, maybeExpanded, focused) = current, maybeExpanded != nil {
                                return .media(mode: mode, expanded: nil, focused: focused)
                            }
                            return current
                        }

                        return current
                    })
                }
            }, shouldAnimateMessageTransition ? correlationId : nil)

            if shouldAnimateMessageTransition {
                if let sourceNode = sourceNode as? ChatMediaInputStickerGridItemNode {
                    strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .stickerMediaInput(input: .inputPanel(itemNode: sourceNode), replyPanel: replyPanel), initiated: {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, { current in
                            var current = current
                            current = current.updatedInputMode { current in
                                if case let .media(mode, maybeExpanded, focused) = current, maybeExpanded != nil {
                                    return .media(mode: mode, expanded: nil, focused: focused)
                                }
                                return current
                            }

                            return current
                        })
                    })
                } else if let sourceNode = sourceNode as? HorizontalStickerGridItemNode {
                    strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .stickerMediaInput(input: .mediaPanel(itemNode: sourceNode), replyPanel: replyPanel), initiated: {})
                } else if let sourceNode = sourceNode as? StickerPaneSearchStickerItemNode {
                    strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .stickerMediaInput(input: .inputPanelSearch(itemNode: sourceNode), replyPanel: replyPanel), initiated: {})
                } else if let sourceNode = sourceNode as? ChatEmptyNodeStickerContentNode {
                    strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .stickerMediaInput(input: .emptyPanel(itemNode: sourceNode), replyPanel: nil), initiated: {})
                }
            }
            
            let messages: [EnqueueMessage]  = [.message(text: "", attributes: attributes, mediaReference: fileReference.abstract, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil, correlationId: correlationId)]
            if silentPosting {
                let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: silentPosting)
                strongSelf.sendMessages(transformedMessages)
            } else if schedule {
                strongSelf.presentScheduleTimePicker(completion: { [weak self] scheduleTime in
                    if let strongSelf = self {
                        let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: scheduleTime)
                        strongSelf.sendMessages(transformedMessages)
                    }
                })
            } else {
                let transformedMessages = strongSelf.transformEnqueueMessages(messages)
                strongSelf.sendMessages(transformedMessages)
            }
            return true
        }, sendGif: { [weak self] fileReference, sourceNode, sourceRect, silentPosting, schedule in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                    strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceNode, sourceRect)
                    return false
                }
                
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }.updatedInputMode { current in
                                if case let .media(mode, maybeExpanded, focused) = current, maybeExpanded != nil  {
                                    return .media(mode: mode, expanded: nil, focused: focused)
                                }
                                return current
                            }
                        })
                    }
                }, nil)
                
                var messages = [EnqueueMessage.message(text: "", attributes: [], mediaReference: fileReference.abstract, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil, correlationId: nil)]
                if silentPosting {
                    messages = strongSelf.transformEnqueueMessages(messages, silentPosting: true)
                    strongSelf.sendMessages(messages)
                } else if schedule {
                    strongSelf.presentScheduleTimePicker(completion: { [weak self] scheduleTime in
                        if let strongSelf = self {
                            let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: scheduleTime)
                            strongSelf.sendMessages(transformedMessages)
                        }
                    })
                } else {
                    messages = strongSelf.transformEnqueueMessages(messages)
                    strongSelf.sendMessages(messages)
                }
            }
            return true
        }, sendBotContextResultAsGif: { [weak self] collection, result, sourceNode, sourceRect, silentPosting in
            guard let strongSelf = self else {
                return false
            }
            if case .pinnedMessages = strongSelf.presentationInterfaceState.subject {
                return false
            }
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceNode, sourceRect)
                return false
            }
            
            strongSelf.enqueueChatContextResult(collection, result, hideVia: true, closeMediaInput: true, silentPosting: silentPosting)
            
            return true
        }, requestMessageActionCallback: { [weak self] messageId, data, isGame, requiresPassword in
            guard let strongSelf = self else {
                return
            }
            guard strongSelf.presentationInterfaceState.subject != .scheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).start(next: { message in
                guard let strongSelf = self, let message = message else {
                    return
                }
                
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedTitlePanelContext {
                        if !$0.contains(where: {
                            switch $0 {
                                case .requestInProgress:
                                    return true
                                default:
                                    return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.append(.requestInProgress)
                            return updatedContexts.sorted()
                        }
                        return $0
                    }
                })
                
                let proceedWithResult: (MessageActionCallbackResult) -> Void = { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    switch result {
                        case .none:
                            break
                        case let .alert(text):
                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        case let .toast(text):
                            let message: Signal<String?, NoError> = .single(text)
                            let noMessage: Signal<String?, NoError> = .single(nil)
                            let delayedNoMessage: Signal<String?, NoError> = noMessage |> delay(1.0, queue: Queue.mainQueue())
                            strongSelf.botCallbackAlertMessage.set(message |> then(delayedNoMessage))
                        case let .url(url):
                            if isGame {
                                let openBot: () -> Void = {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.chatDisplayNode.dismissInput()
                                    strongSelf.effectiveNavigationController?.pushViewController(GameController(context: strongSelf.context, url: url, message: message))
                                }

                                var botPeer: TelegramUser?
                                for attribute in message.attributes {
                                    if let attribute = attribute as? InlineBotMessageAttribute {
                                        if let peerId = attribute.peerId {
                                            botPeer = message.peers[peerId] as? TelegramUser
                                        }
                                    }
                                }
                                if botPeer == nil {
                                    if case let .user(peer) = message.author, peer.botInfo != nil {
                                        botPeer = peer
                                    } else if let peer = message.peers[message.id.peerId] as? TelegramUser, peer.botInfo != nil {
                                        botPeer = peer
                                    }
                                }
                                
                                if let botPeer = botPeer {
                                    let _ = (ApplicationSpecificNotice.getBotGameNotice(accountManager: strongSelf.context.sharedContext.accountManager, peerId: botPeer.id)
                                    |> deliverOnMainQueue).start(next: { value in
                                        guard let strongSelf = self else {
                                            return
                                        }

                                        if value {
                                            openBot()
                                        } else {
                                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_BotInteractiveUrlAlert(EnginePeer(botPeer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).string, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: { }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                                                if let strongSelf = self {
                                                    let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: strongSelf.context.sharedContext.accountManager, peerId: botPeer.id).start()
                                                    openBot()
                                                }
                                            })]), in: .window(.root), with: nil)
                                        }
                                    })
                                }
                            } else {
                                strongSelf.openUrl(url, concealed: false)
                            }
                    }
                }
                
                let updateProgress = { [weak self] in
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedTitlePanelContext {
                                    if let index = $0.firstIndex(where: {
                                        switch $0 {
                                            case .requestInProgress:
                                                return true
                                            default:
                                                return false
                                        }
                                    }) {
                                        var updatedContexts = $0
                                        updatedContexts.remove(at: index)
                                        return updatedContexts
                                    }
                                    return $0
                                }
                            })
                        }
                    }
                }
                
                let context = strongSelf.context
                if requiresPassword {
                    strongSelf.messageActionCallbackDisposable.set(((strongSelf.context.engine.messages.requestMessageActionCallbackPasswordCheck(messageId: messageId, isGame: isGame, data: data)
                    |> afterDisposed {
                        updateProgress()
                    })
                    |> deliverOnMainQueue).start(error: { error in
                        let controller = ownershipTransferController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, initialError: error, present: { c, a in
                                strongSelf.present(c, in: .window(.root), with: a)
                        }, commit: { password in
                            return context.engine.messages.requestMessageActionCallback(messageId: messageId, isGame: isGame, password: password, data: data)
                            |> afterDisposed {
                                updateProgress()
                            }
                        }, completion: { result in
                            proceedWithResult(result)
                        })
                        strongSelf.present(controller, in: .window(.root))
                    }))
                } else {
                    strongSelf.messageActionCallbackDisposable.set(((context.engine.messages.requestMessageActionCallback(messageId: messageId, isGame: isGame, password: nil, data: data)
                    |> afterDisposed {
                        updateProgress()
                    })
                    |> deliverOnMainQueue).start(next: { result in
                        proceedWithResult(result)
                    }))
                }
            })
        }, requestMessageActionUrlAuth: { [weak self] defaultUrl, subject in
            if let strongSelf = self {
                guard strongSelf.presentationInterfaceState.subject != .scheduledMessages else {
                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedTitlePanelContext {
                        if !$0.contains(where: {
                            switch $0 {
                                case .requestInProgress:
                                    return true
                                default:
                                    return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.append(.requestInProgress)
                            return updatedContexts.sorted()
                        }
                        return $0
                    }
                })
                strongSelf.messageActionUrlAuthDisposable.set(((combineLatest(strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.context.account.peerId), strongSelf.context.engine.messages.requestMessageActionUrlAuth(subject: subject) |> afterDisposed {
                    Queue.mainQueue().async {
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedTitlePanelContext {
                                    if let index = $0.firstIndex(where: {
                                        switch $0 {
                                            case .requestInProgress:
                                                return true
                                            default:
                                                return false
                                        }
                                    }) {
                                        var updatedContexts = $0
                                        updatedContexts.remove(at: index)
                                        return updatedContexts
                                    }
                                    return $0
                                }
                            })
                        }
                    }
                })) |> deliverOnMainQueue).start(next: { peer, result in
                    if let strongSelf = self {
                        switch result {
                            case .default:
                                strongSelf.openUrl(defaultUrl, concealed: false, skipUrlAuth: true)
                            case let .request(domain, bot, requestWriteAccess):
                                let controller = chatMessageActionUrlAuthController(context: strongSelf.context, defaultUrl: defaultUrl, domain: domain, bot: bot, requestWriteAccess: requestWriteAccess, displayName: EnginePeer(peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), open: { [weak self] authorize, allowWriteAccess in
                                    if let strongSelf = self {
                                        if authorize {
                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                return $0.updatedTitlePanelContext {
                                                    if !$0.contains(where: {
                                                        switch $0 {
                                                            case .requestInProgress:
                                                                return true
                                                            default:
                                                                return false
                                                        }
                                                    }) {
                                                        var updatedContexts = $0
                                                        updatedContexts.append(.requestInProgress)
                                                        return updatedContexts.sorted()
                                                    }
                                                    return $0
                                                }
                                            })
                                            
                                            strongSelf.messageActionUrlAuthDisposable.set(((strongSelf.context.engine.messages.acceptMessageActionUrlAuth(subject: subject, allowWriteAccess: allowWriteAccess) |> afterDisposed {
                                                Queue.mainQueue().async {
                                                    if let strongSelf = self {
                                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                            return $0.updatedTitlePanelContext {
                                                                if let index = $0.firstIndex(where: {
                                                                    switch $0 {
                                                                        case .requestInProgress:
                                                                            return true
                                                                        default:
                                                                            return false
                                                                    }
                                                                }) {
                                                                    var updatedContexts = $0
                                                                    updatedContexts.remove(at: index)
                                                                    return updatedContexts
                                                                }
                                                                return $0
                                                            }
                                                        })
                                                    }
                                                }
                                            }) |> deliverOnMainQueue).start(next: { [weak self] result in
                                                if let strongSelf = self {
                                                    switch result {
                                                        case let .accepted(url):
                                                            strongSelf.openUrl(url, concealed: false, skipUrlAuth: true)
                                                        default:
                                                            strongSelf.openUrl(defaultUrl, concealed: false, skipUrlAuth: true)
                                                    }
                                                }
                                            }))
                                        } else {
                                            strongSelf.openUrl(defaultUrl, concealed: false, skipUrlAuth: true)
                                        }
                                    }
                                })
                                strongSelf.chatDisplayNode.dismissInput()
                                strongSelf.present(controller, in: .window(.root))
                            case let .accepted(url):
                                strongSelf.openUrl(url, concealed: false, skipUrlAuth: true)
                        }
                    }
                }))
            }
        }, activateSwitchInline: { [weak self] peerId, inputString in
            guard let strongSelf = self else {
                return
            }
            guard strongSelf.presentationInterfaceState.subject != .scheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            if let botStart = strongSelf.botStart, case let .automatic(returnToPeerId, scheduled) = botStart.behavior {
                strongSelf.openPeer(peerId: returnToPeerId, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), subject: scheduled ? .scheduledMessages : nil, peekData: nil), fromMessage: nil)
            } else {
                strongSelf.openPeer(peerId: peerId, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), subject: nil, peekData: nil), fromMessage: nil)
            }
        }, openUrl: { [weak self] url, concealed, _, message in
            if let strongSelf = self {
                strongSelf.openUrl(url, concealed: concealed, message: message)
            }
        }, shareCurrentLocation: { [weak self] in
            if let strongSelf = self {
                if case .pinnedMessages = strongSelf.presentationInterfaceState.subject {
                    return
                }
                guard strongSelf.presentationInterfaceState.subject != .scheduledMessages else {
                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.Conversation_ShareBotLocationConfirmationTitle, text: strongSelf.presentationData.strings.Conversation_ShareBotLocationConfirmation, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    if let strongSelf = self, let locationManager = strongSelf.context.sharedContext.locationManager {
                        let _ = (currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
                        |> deliverOnMainQueue).start(next: { coordinate in
                            if let strongSelf = self {
                                if let coordinate = coordinate {
                                    strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)])
                                } else {
                                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})]), in: .window(.root))
                                }
                            }
                        })
                    }
                })]), in: .window(.root))
            }
        }, shareAccountContact: { [weak self] in
            if let strongSelf = self {
                if case .pinnedMessages = strongSelf.presentationInterfaceState.subject {
                    return
                }
                
                guard strongSelf.presentationInterfaceState.subject != .scheduledMessages else {
                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.Conversation_ShareBotContactConfirmationTitle, text: strongSelf.presentationData.strings.Conversation_ShareBotContactConfirmation, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    if let strongSelf = self {
                        let _ = (strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.context.account.peerId)
                        |> deliverOnMainQueue).start(next: { peer in
                            if let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
                                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)])
                            }
                        })
                    }
                })]), in: .window(.root))
            }
        }, sendBotCommand: { [weak self] messageId, command in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({}, nil)
                var postAsReply = false
                if !command.contains("@") {
                    switch strongSelf.chatLocation {
                        case let .peer(peerId):
                            if (peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup) {
                                postAsReply = true
                            }
                        case .replyThread:
                            postAsReply = true
                        case .feed:
                            postAsReply = true
                    }
                    
                    if let messageId = messageId, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                        if let author = message.author as? TelegramUser, author.botInfo != nil {
                        } else {
                            postAsReply = false
                        }
                    }
                }
                
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil) }
                        })
                    }
                }, nil)
                var attributes: [MessageAttribute] = []
                let entities = generateTextEntities(command, enabledTypes: .all)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                strongSelf.sendMessages([.message(text: command, attributes: attributes, mediaReference: nil, replyToMessageId: (postAsReply && messageId != nil) ? messageId! : nil, localGroupingKey: nil, correlationId: nil)])
            }
        }, openInstantPage: { [weak self] message, associatedData in
            if let strongSelf = self, strongSelf.isNodeLoaded, let navigationController = strongSelf.effectiveNavigationController, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                strongSelf.chatDisplayNode.dismissInput()
                openChatInstantPage(context: strongSelf.context, message: message, sourcePeerType: associatedData?.automaticDownloadPeerType, navigationController: navigationController)
                
                if case .overlay = strongSelf.presentationInterfaceState.mode {
                    strongSelf.chatDisplayNode.dismissAsOverlay()
                }
            }
        }, openWallpaper: { [weak self] message in
            if let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                strongSelf.chatDisplayNode.dismissInput()
                openChatWallpaper(context: strongSelf.context, message: message, present: { [weak self] c, a in
                    self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                })
            }
        }, openTheme: { [weak self] message in
            if let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                strongSelf.chatDisplayNode.dismissInput()
                openChatTheme(context: strongSelf.context, message: message, pushController: { [weak self] c in
                    self?.effectiveNavigationController?.pushViewController(c)
                }, present: { [weak self] c, a in
                    self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                })
            }
        }, openHashtag: { [weak self] peerName, hashtag in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openHashtag(hashtag, peerName: peerName)
        }, updateInputState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedInterfaceState {
                        let updatedState: ChatTextInputState
                        if canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                            updatedState = f($0.effectiveInputState)
                        } else {
                            updatedState = ChatTextInputState()
                        }
                        return $0.withUpdatedEffectiveInputState(updatedState)
                    }
                })
            }
        }, updateInputMode: { [weak self] f in
            self?.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedInputMode(f)
            })
        }, openMessageShareMenu: { [weak self] id in
            if let strongSelf = self, let messages = strongSelf.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(id), let message = messages.first {
                let chatPresentationInterfaceState = strongSelf.presentationInterfaceState
                var warnAboutPrivate = false
                if case .peer = chatPresentationInterfaceState.chatLocation, let channel = message.peers[message.id.peerId] as? TelegramChannel {
                    if channel.addressName == nil {
                        warnAboutPrivate = true
                    }
                }
                let shareController = ShareController(context: strongSelf.context, subject: .messages(messages), updatedPresentationData: strongSelf.updatedPresentationData, shareAsLink: true)
                shareController.openShareAsImage = { [weak self] messages in
                    if let strongSelf = self {
                        strongSelf.present(ChatQrCodeScreen(context: strongSelf.context, subject: .messages(messages)), in: .window(.root))
                    }
                }
                shareController.dismissed = { [weak self] shared in
                    if shared {
                        self?.commitPurposefulAction()
                    }
                }
                shareController.actionCompleted = { [weak self] in
                    if let strongSelf = self {
                        let content: UndoOverlayContent
                        if warnAboutPrivate {
                            content = .linkCopied(text: strongSelf.presentationData.strings.Conversation_PrivateMessageLinkCopiedLong)
                        } else {
                            content = .linkCopied(text: strongSelf.presentationData.strings.Conversation_LinkCopied)
                        }
                        strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    }
                }
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
                            text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
                            savedMessages = true
                        } else {
                            if peers.count == 1, let peer = peers.first {
                                let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                            } else if let peer = peers.first {
                                let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(peers.count - 1)").string
                            } else {
                                text = ""
                            }
                        }
                        
                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })
                }
                strongSelf.chatDisplayNode.dismissInput()
                strongSelf.present(shareController, in: .window(.root), blockInteraction: true)
            }
        }, presentController: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }, presentControllerInCurrent: { [weak self] controller, arguments in
            self?.present(controller, in: .current, with: arguments)
        }, navigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, chatControllerNode: { [weak self] in
            return self?.chatDisplayNode
        }, presentGlobalOverlayController: { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }, callPeer: { [weak self] peerId, isVideo in
            if let strongSelf = self {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    strongSelf.commitPurposefulAction()
                    
                    let _ = (context.account.viewTracker.peerView(peerId)
                    |> take(1)
                    |> map { view -> Peer? in
                        return peerViewMainPeer(view)
                    }
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        
                        if let cachedUserData = strongSelf.peerView?.cachedData as? CachedUserData, cachedUserData.callsPrivate {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            
                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: presentationData.strings.Call_ConnectionErrorTitle, text: presentationData.strings.Call_PrivacyErrorMessage(EnginePeer(peer).compactDisplayTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            return
                        }
                        
                        context.requestCall(peerId: peer.id, isVideo: isVideo, completion: {})
                    })
                })
            }
        }, longTap: { [weak self] action, message in
            if let strongSelf = self {
                let presentationData = strongSelf.presentationData
                switch action {
                    case let .url(url):
                        var (cleanUrl, _) = parseUrl(url: url, wasConcealed: false)
                        var canAddToReadingList = true
                        var canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
                        let mailtoString = "mailto:"
                        let telString = "tel:"
                        var openText = strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                        var phoneNumber: String?
                        
                        var isPhoneNumber = false
                        var isEmail = false
                        
                        if cleanUrl.hasPrefix(mailtoString) {
                            canAddToReadingList = false
                            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
                            isEmail = true
                        } else if cleanUrl.hasPrefix(telString) {
                            canAddToReadingList = false
                            phoneNumber = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
                            cleanUrl = phoneNumber!
                            openText = strongSelf.presentationData.strings.UserInfo_PhoneCall
                            canOpenIn = false
                            isPhoneNumber = true
                        } else if canOpenIn {
                            openText = strongSelf.presentationData.strings.Conversation_FileOpenIn
                        }
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: cleanUrl))
                        items.append(ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                if canOpenIn {
                                    strongSelf.openUrlIn(url)
                                } else {
                                    strongSelf.openUrl(url, concealed: false)
                                }
                            }
                        }))
                        if let phoneNumber = phoneNumber {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddContact, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.controllerInteraction?.addContact(phoneNumber)
                                }
                            }))
                        }
                        items.append(ActionSheetButtonItem(title: canAddToReadingList ? strongSelf.presentationData.strings.ShareMenu_CopyShareLink : strongSelf.presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet, weak self] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = cleanUrl
                            
                            let content: UndoOverlayContent
                            if isPhoneNumber {
                                content = .copy(text: presentationData.strings.Conversation_PhoneCopied)
                            } else if isEmail {
                                content = .copy(text: presentationData.strings.Conversation_EmailCopied)
                            } else if canAddToReadingList {
                                content = .linkCopied(text: presentationData.strings.Conversation_LinkCopied)
                            } else {
                                content = .copy(text: presentationData.strings.Conversation_TextCopied)
                            }
                            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }))
                        if canAddToReadingList {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let link = URL(string: url) {
                                    let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                }
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .peerMention(peerId, mention):
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        var items: [ActionSheetItem] = []
                        if !mention.isEmpty {
                            items.append(ActionSheetTextItem(title: mention))
                        }
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.openPeer(peerId: peerId, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                            }
                        }))
                        if !mention.isEmpty {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                            }))
                        }
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .mention(mention):
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: mention),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.openPeerMention(mention, sourceMessageId: message?.id)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_UsernameCopied)
                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                            })
                        ]), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .command(command):
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        var items: [ActionSheetItem] = []
                        items.append(ActionSheetTextItem(title: command))
                        if canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ShareMenu_Send, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.sendMessages([.message(text: command, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)])
                                }
                            }))
                        }
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = command
                            
                            let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .hashtag(hashtag):
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: hashtag),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    let peerSignal: Signal<Peer?, NoError>
                                    guard let peerId = strongSelf.chatLocation.peerId else {
                                        return
                                    }
                                    peerSignal = strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                                    |> map(Optional.init)
                                    let _ = (peerSignal
                                    |> deliverOnMainQueue).start(next: { peer in
                                        if let strongSelf = self {
                                            let searchController = HashtagSearchController(context: strongSelf.context, peer: peer.flatMap(EnginePeer.init), query: hashtag)
                                            strongSelf.effectiveNavigationController?.pushViewController(searchController)
                                        }
                                    })
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = hashtag
                                
                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_HashtagCopied)
                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                            })
                        ]), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .timecode(timecode, text):
                        guard let message = message else {
                            return
                        }
                    
                        let context = strongSelf.context
                        let chatPresentationInterfaceState = strongSelf.presentationInterfaceState
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        
                        var isCopyLink = false
                        var isForward = false
                        if message.id.namespace == Namespaces.Message.Cloud, let _ = message.peers[message.id.peerId] as? TelegramChannel, !(message.media.first is TelegramMediaAction) {
                            isCopyLink = true
                        } else if let forwardInfo = message.forwardInfo, let _ = forwardInfo.author as? TelegramChannel {
                            isCopyLink = true
                            isForward = true
                        }
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: text),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.controllerInteraction?.seekToTimecode(message, timecode, true)
                                }
                            }),
                            ActionSheetButtonItem(title: isCopyLink ? strongSelf.presentationData.strings.Conversation_ContextMenuCopyLink : strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                var messageId = message.id
                                var channel = message.peers[message.id.peerId]
                                if isForward, let forwardMessageId = message.forwardInfo?.sourceMessageId, let forwardAuthor = message.forwardInfo?.author as? TelegramChannel {
                                    messageId = forwardMessageId
                                    channel = forwardAuthor
                                }
                                
                                if isCopyLink, let channel = channel as? TelegramChannel {
                                    var threadMessageId: MessageId?
                                   
                                    if case let .replyThread(replyThreadMessage) = chatPresentationInterfaceState.chatLocation {
                                        threadMessageId = replyThreadMessage.messageId
                                    }
                                    let _ = (context.engine.messages.exportMessageLink(peerId: messageId.peerId, messageId: messageId, isThread: threadMessageId != nil)
                                    |> map { result -> String? in
                                        return result
                                    }
                                    |> deliverOnMainQueue).start(next: { link in
                                        if let link = link {
                                            UIPasteboard.general.string = link + "?t=\(Int32(timecode))"
                                            
                                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                            
                                            var warnAboutPrivate = false
                                            if case .peer = chatPresentationInterfaceState.chatLocation {
                                                if channel.addressName == nil {
                                                    warnAboutPrivate = true
                                                }
                                            }
                                            Queue.mainQueue().after(0.2, {
                                                let content: UndoOverlayContent
                                                if warnAboutPrivate {
                                                    content = .linkCopied(text: presentationData.strings.Conversation_PrivateMessageLinkCopiedLong)
                                                } else {
                                                    content = .linkCopied(text: presentationData.strings.Conversation_LinkCopied)
                                                }
                                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                            })
                                        } else {
                                            UIPasteboard.general.string = text
                                            
                                            let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                            self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                        }
                                    })
                                } else {
                                    UIPasteboard.general.string = text
                                    
                                    let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
                                    self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                }
                            })
                            ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])])
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(actionSheet, in: .window(.root))
                    case let .bankCard(number):
                        guard let message = message else {
                            return
                        }
                        
                        var signal = strongSelf.context.engine.payments.getBankCardInfo(cardNumber: number)
                        let disposable: MetaDisposable
                        if let current = strongSelf.bankCardDisposable {
                            disposable = current
                        } else {
                            disposable = MetaDisposable()
                            strongSelf.bankCardDisposable = disposable
                        }
                        
                        var cancelImpl: (() -> Void)?
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                cancelImpl?()
                            }))
                            strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        signal = signal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        cancelImpl = {
                            disposable.set(nil)
                        }
                        disposable.set((signal
                        |> deliverOnMainQueue).start(next: { [weak self] info in
                            if let strongSelf = self, let info = info {
                                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                                var items: [ActionSheetItem] = []
                                items.append(ActionSheetTextItem(title: info.title))
                                for url in info.urls {
                                    items.append(ActionSheetButtonItem(title: url.title, color: .accent, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        if let strongSelf = self {
                                            strongSelf.controllerInteraction?.openUrl(url.url, false, false, message)
                                        }
                                    }))
                                }
                                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    UIPasteboard.general.string = number
                                    
                                    let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_CardNumberCopied)
                                    self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                }))
                                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                ])])
                                strongSelf.present(actionSheet, in: .window(.root))
                            }
                        }))
                        
                        strongSelf.chatDisplayNode.dismissInput()
                }
            }
        }, openCheckoutOrReceipt: { [weak self] messageId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.commitPurposefulAction()
            
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).start(next: { message in
                guard let strongSelf = self, let message = message else {
                    return
                }
                
                for media in message.media {
                    if let invoice = media as? TelegramMediaInvoice {
                        strongSelf.chatDisplayNode.dismissInput()
                        if let receiptMessageId = invoice.receiptMessageId {
                            strongSelf.present(BotReceiptController(context: strongSelf.context, messageId: receiptMessageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                        } else {
                            let inputData = Promise<BotCheckoutController.InputData?>()
                            inputData.set(BotCheckoutController.InputData.fetch(context: strongSelf.context, source: .message(message.id))
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                                return .single(nil)
                            })
                            strongSelf.present(BotCheckoutController(context: strongSelf.context, invoice: invoice, source: .message(messageId), inputData: inputData, completed: { currencyValue, receiptMessageId in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .paymentSent(currencyValue: currencyValue, itemTitle: invoice.title), elevatedLayout: false, action: { action in
                                    guard let strongSelf = self, let receiptMessageId = receiptMessageId else {
                                        return false
                                    }

                                    if case .info = action {
                                        strongSelf.present(BotReceiptController(context: strongSelf.context, messageId: receiptMessageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                        return true
                                    }
                                    return false
                                }), in: .current)
                            }), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                        }
                    }
                }
            })
        }, openSearch: {
        }, setupReply: { [weak self] messageId in
            self?.interfaceInteraction?.setupReplyMessage(messageId, { _ in })
        }, canSetupReply: { [weak self] message in
            if !message.flags.contains(.Incoming) {
                if !message.flags.intersection([.Failed, .Sending, .Unsent]).isEmpty {
                    return .none
                }
            }
            if let strongSelf = self {
                if case let .replyThread(replyThreadMessage) = strongSelf.chatLocation, replyThreadMessage.messageId == message.id {
                    return .none
                }
                
                if canReplyInChat(strongSelf.presentationInterfaceState) {
                    return .reply
                } else if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                }
            }
            return .none
        }, navigateToFirstDateMessage: { [weak self] timestamp, alreadyThere in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.chatLocation {
            case let .peer(peerId):
                if alreadyThere {
                    strongSelf.openCalendarSearch(timestamp: timestamp)
                } else {
                    strongSelf.navigateToMessage(from: nil, to: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp - Int32(NSTimeZone.local.secondsFromGMT()))), scrollPosition: .bottom(0.0), rememberInStack: false, animated: true, completion: nil)
                }
            case let .replyThread(replyThreadMessage):
                let peerId = replyThreadMessage.messageId.peerId
                strongSelf.navigateToMessage(from: nil, to: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp - Int32(NSTimeZone.local.secondsFromGMT()))), scrollPosition: .bottom(0.0), rememberInStack: false, animated: true, completion: nil)
            case .feed:
                //TODO:implement
                break
            }
        }, requestRedeliveryOfFailedMessages: { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            if id.namespace == Namespaces.Message.ScheduledCloud {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.MessageGroup(id: id))
                |> deliverOnMainQueue).start(next: { messages in
                    guard let strongSelf = self, let message = messages.filter({ $0.id == id }).first else {
                        return
                    }
                    
                    var actions: [ContextMenuItem] = []
                    actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ScheduledMessages_SendNow, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        if let strongSelf = self {
                            strongSelf.controllerInteraction?.sendScheduledMessagesNow(messages.map { $0.id })
                        }
                        f(.dismissWithoutContent)
                    })))
                    actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ScheduledMessages_EditTime, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Schedule"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        if let strongSelf = self {
                            strongSelf.controllerInteraction?.editScheduledMessagesTime(messages.map { $0.id })
                        }
                        f(.dismissWithoutContent)
                    })))
                    actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { [weak self] controller, f in
                        if let strongSelf = self {
                            strongSelf.interfaceInteraction?.deleteMessages(messages.map { $0._asMessage() }, controller, f)
                        }
                    })))
                    
                    strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                    
                    let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, engine: strongSelf.context.engine, message: message._asMessage(), selectAll: true)), items: .single(ContextController.Items(content: .list(actions))), recognizer: nil)
                    strongSelf.currentContextController = controller
                    strongSelf.forEachController({ controller in
                        if let controller = controller as? TooltipScreen {
                            controller.dismiss()
                        }
                        return true
                    })
                    strongSelf.window?.presentInGlobalOverlay(controller)
                })
            } else {
                let _ = (strongSelf.context.engine.messages.failedMessageGroup(id: id)
                |> deliverOnMainQueue).start(next: { messages in
                    guard let strongSelf = self else {
                        return
                    }
                    var groups: [UInt32: [Message]] = [:]
                    var notGrouped: [Message] = []
                    for message in messages {
                        if let groupInfo = message.groupInfo {
                            if groups[groupInfo.stableId] == nil {
                                groups[groupInfo.stableId] = []
                            }
                            groups[groupInfo.stableId]?.append(message._asMessage())
                        } else {
                            notGrouped.append(message._asMessage())
                        }
                    }
                    
                    let totalGroupCount = notGrouped.count + groups.count
                    
                    var maybeSelectedGroup: [Message]?
                    for (_, group) in groups {
                        if group.contains(where: { $0.id == id}) {
                            maybeSelectedGroup = group
                            break
                        }
                    }
                    for message in notGrouped {
                        if message.id == id {
                            maybeSelectedGroup = [message]
                        }
                    }
                    
                    guard let selectedGroup = maybeSelectedGroup, let topMessage = selectedGroup.first else {
                        return
                    }
                    
                    var actions: [ContextMenuItem] = []
                    actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_MessageDialogRetry, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        if let strongSelf = self {
                            let _ = resendMessages(account: strongSelf.context.account, messageIds: selectedGroup.map({ $0.id })).start()
                        }
                        f(.dismissWithoutContent)
                    })))
                    if totalGroupCount != 1 {
                        actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_MessageDialogRetryAll(totalGroupCount).string, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
                        }, action: { [weak self] _, f in
                            if let strongSelf = self {
                                let _ = resendMessages(account: strongSelf.context.account, messageIds: messages.map({ $0.id })).start()
                            }
                            f(.dismissWithoutContent)
                        })))
                    }
                    actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { [weak self] controller, f in
                        if let strongSelf = self {
                            let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: [id], type: .forLocalPeer).start()
                        }
                        f(.dismissWithoutContent)
                    })))
                    
                    strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                    
                    let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, engine: strongSelf.context.engine, message: topMessage, selectAll: true)), items: .single(ContextController.Items(content: .list(actions))), recognizer: nil)
                    strongSelf.currentContextController = controller
                    strongSelf.forEachController({ controller in
                        if let controller = controller as? TooltipScreen {
                            controller.dismiss()
                        }
                        return true
                    })
                    strongSelf.window?.presentInGlobalOverlay(controller)
                })
            }
        }, addContact: { [weak self] phoneNumber in
            if let strongSelf = self {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
                        self?.present(controller, in: .window(.root), with: arguments)
                    }, pushController: { [weak self] controller in
                        if let strongSelf = self {
                            strongSelf.effectiveNavigationController?.pushViewController(controller)
                        }
                    }, completed: {})
                })
            }
        }, rateCall: { [weak self] message, callId, isVideo in
            if let strongSelf = self {
                let controller = callRatingController(sharedContext: strongSelf.context.sharedContext, account: strongSelf.context.account, callId: callId, userInitiated: true, isVideo: isVideo, present: { [weak self] c, a in
                    if let strongSelf = self {
                        strongSelf.present(c, in: .window(.root), with: a)
                    }
                }, push: { [weak self] c in
                    if let strongSelf = self {
                        strongSelf.push(c)
                    }
                })
                strongSelf.chatDisplayNode.dismissInput()
                strongSelf.present(controller, in: .window(.root))
            }
        }, requestSelectMessagePollOptions: { [weak self] id, opaqueIdentifiers in
            guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                return
            }
            
            guard strongSelf.presentationInterfaceState.subject != .scheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_PollUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            if controllerInteraction.pollActionState.pollMessageIdsInProgress[id] == nil {
                controllerInteraction.pollActionState.pollMessageIdsInProgress[id] = opaqueIdentifiers
                strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(id)
                let disposables: DisposableDict<MessageId>
                if let current = strongSelf.selectMessagePollOptionDisposables {
                    disposables = current
                } else {
                    disposables = DisposableDict()
                    strongSelf.selectMessagePollOptionDisposables = disposables
                }
                let signal = strongSelf.context.engine.messages.requestMessageSelectPollOption(messageId: id, opaqueIdentifiers: opaqueIdentifiers)
                disposables.set((signal
                |> deliverOnMainQueue).start(next: { resultPoll in
                    guard let strongSelf = self, let resultPoll = resultPoll else {
                        return
                    }
                    guard let _ = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(id) else {
                        return
                    }
                    
                    switch resultPoll.kind {
                    case .poll:
                        if strongSelf.selectPollOptionFeedback == nil {
                            strongSelf.selectPollOptionFeedback = HapticFeedback()
                        }
                        strongSelf.selectPollOptionFeedback?.success()
                    case .quiz:
                        if let voters = resultPoll.results.voters {
                            for voter in voters {
                                if voter.selected {
                                    if voter.isCorrect {
                                        if strongSelf.selectPollOptionFeedback == nil {
                                            strongSelf.selectPollOptionFeedback = HapticFeedback()
                                        }
                                        strongSelf.selectPollOptionFeedback?.success()
                                        
                                        strongSelf.chatDisplayNode.animateQuizCorrectOptionSelected()
                                    } else {
                                        var found = false
                                        strongSelf.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                                            if !found, let itemNode = itemNode as? ChatMessageBubbleItemNode, itemNode.item?.message.id == id {
                                                found = true
                                                if strongSelf.selectPollOptionFeedback == nil {
                                                    strongSelf.selectPollOptionFeedback = HapticFeedback()
                                                }
                                                strongSelf.selectPollOptionFeedback?.error()
                                                
                                                itemNode.animateQuizInvalidOptionSelected()
                                                
                                                if let solution = resultPoll.results.solution {
                                                    for contentNode in itemNode.contentNodes {
                                                        if let contentNode = contentNode as? ChatMessagePollBubbleContentNode {
                                                            let sourceNode = contentNode.solutionTipSourceNode
                                                            strongSelf.displayPollSolution(solution: solution, sourceNode: sourceNode, isAutomatic: true)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    break
                                }
                            }
                        }
                    }
                }, error: { _ in
                    guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                        return
                    }
                    if controllerInteraction.pollActionState.pollMessageIdsInProgress.removeValue(forKey: id) != nil {
                        strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(id)
                    }
                }, completed: {
                    guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                        return
                    }
                    if controllerInteraction.pollActionState.pollMessageIdsInProgress.removeValue(forKey: id) != nil {
                        Queue.mainQueue().after(1.0, {
                            
                            strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(id)
                        })
                    }
                }), forKey: id)
            }
        }, requestOpenMessagePollResults: { [weak self] messageId, pollId in
            guard let strongSelf = self, pollId.namespace == Namespaces.Media.CloudPoll else {
                return
            }
            let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                |> deliverOnMainQueue).start(next: { message in
                    guard let message = message else {
                        return
                    }
                    for media in message.media {
                        if let poll = media as? TelegramMediaPoll, poll.pollId == pollId {
                            strongSelf.push(pollResultsController(context: strongSelf.context, messageId: messageId, poll: poll))
                            break
                        }
                    }
                })
            }, delay: true)
        }, openAppStorePage: { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.applicationBindings.openAppStorePage()
            }
        }, displayMessageTooltip: { [weak self] messageId, text, node, nodeRect in
            if let strongSelf = self {
                if let node = node {
                    strongSelf.messageTooltipController?.dismiss()
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                    strongSelf.messageTooltipController = tooltipController
                    tooltipController.dismissed = { [weak tooltipController] _ in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.messageTooltipController === tooltipController {
                            strongSelf.messageTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            var rect = node.view.convert(node.view.bounds, to: strongSelf.chatDisplayNode.view)
                            if let nodeRect = nodeRect {
                                rect = CGRect(origin: rect.origin.offsetBy(dx: nodeRect.minX, dy: nodeRect.minY - node.bounds.minY), size: nodeRect.size)
                            }
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                }
            }
        }, seekToTimecode: { [weak self] message, timestamp, forceOpen in
            if let strongSelf = self {
                var found = false
                if !forceOpen {
                    strongSelf.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                        if !found, let itemNode = itemNode as? ChatMessageItemView, itemNode.item?.message.id == message.id, let (action, _, _, _, _) = itemNode.playMediaWithSound() {
                            if case let .visible(fraction, _) = itemNode.visibility, fraction > 0.7 {
                                action(Double(timestamp))
                            } else {
                                let _ = strongSelf.controllerInteraction?.openMessage(message, .timecode(Double(timestamp)))
                            }
                            found = true
                        }
                    }
                }
                if !found {
                    if let _ = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                        let _ = strongSelf.controllerInteraction?.openMessage(message, .timecode(Double(timestamp)))
                    } else {
                        strongSelf.navigateToMessage(messageLocation: .id(message.id, Double(timestamp)), animated: true, forceInCurrentChat: true)
                    }
                }
            }
        }, scheduleCurrentMessage: { [weak self] in
            if let strongSelf = self {
                strongSelf.presentScheduleTimePicker(completion: { [weak self] time in
                    if let strongSelf = self {
                        if let _ = strongSelf.presentationInterfaceState.recordedMediaPreview {
                            strongSelf.sendMediaRecording(scheduleTime: time)
                        } else {
                            strongSelf.chatDisplayNode.sendCurrentMessage(scheduleTime: time, completion: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))) }
                                    })
                                    
                                    if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                        strongSelf.openScheduledMessages()
                                    }
                                }
                            })
                        }
                    }
                })
            }
        }, sendScheduledMessagesNow: { [weak self] messageIds in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.slowmodeState {
                    if let rect = strongSelf.chatDisplayNode.frameForInputActionButton() {
                        strongSelf.interfaceInteraction?.displaySlowmodeTooltip(strongSelf.chatDisplayNode, rect)
                    }
                    return
                } else {
                    let _ = strongSelf.context.engine.messages.sendScheduledMessageNowInteractively(messageId: messageIds.first!).start()
                }
            }
        }, editScheduledMessagesTime: { [weak self] messageIds in
            if let strongSelf = self, let messageId = messageIds.first {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                    |> deliverOnMainQueue).start(next: { [weak self] message in
                        guard let strongSelf = self, let message = message else {
                            return
                        }
                        strongSelf.presentScheduleTimePicker(selectedTime: message.timestamp, completion: { [weak self] time in
                            if let strongSelf = self {
                                var entities: TextEntitiesMessageAttribute?
                                for attribute in message.attributes {
                                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                                        entities = attribute
                                        break
                                    }
                                }
                                strongSelf.editMessageDisposable.set((strongSelf.context.engine.messages.requestEditMessage(messageId: messageId, text: message.text, media: .keep, entities: entities, disableUrlPreview: false, scheduleTime: time) |> deliverOnMainQueue).start(next: { result in
                                }, error: { error in
                                }))
                            }
                        })
                    })
                }, delay: true)
            }
        }, performTextSelectionAction: { [weak self] _, text, action in
            guard let strongSelf = self else {
                return
            }
            switch action {
            case .copy:
                storeAttributedTextInPasteboard(text)
            case .share:
                let f = {
                    guard let strongSelf = self else {
                        return
                    }
                    let shareController = ShareController(context: strongSelf.context, subject: .text(text.string), externalShare: true, immediateExternalShare: false, updatedPresentationData: strongSelf.updatedPresentationData)
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(shareController, in: .window(.root))
                }
                if let currentContextController = strongSelf.currentContextController {
                    currentContextController.dismiss(completion: {
                        f()
                    })
                } else {
                    f()
                }
            case .lookup:
                let controller = UIReferenceLibraryViewController(term: text.string)
                if let window = strongSelf.effectiveNavigationController?.view.window {
                    controller.popoverPresentationController?.sourceView = window
                    controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                    window.rootViewController?.present(controller, animated: true)
                }
            case .speak:
                let _ = speakText(context: strongSelf.context, text: text.string)
            case .translate:
                strongSelf.chatDisplayNode.dismissInput()
                let f = {
                    let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { sharedData in
                        let translationSettings: TranslationSettings
                        if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                            translationSettings = current
                        } else {
                            translationSettings = TranslationSettings.defaultSettings
                        }
                        
                        var showTranslateIfTopical = false
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, !(peer.addressName ?? "").isEmpty {
                            showTranslateIfTopical = true
                        }
                        
                        let (_, language) = canTranslateText(context: context, text: text.string, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: showTranslateIfTopical, ignoredLanguages: translationSettings.ignoredLanguages)
                        
                        let controller = TranslateScreen(context: context, text: text.string, fromLanguage: language)
                        controller.pushController = { [weak self] c in
                            self?.effectiveNavigationController?._keepModalDismissProgress = true
                            self?.push(c)
                        }
                        controller.presentController = { [weak self] c in
                            self?.present(c, in: .window(.root))
                        }
                        strongSelf.present(controller, in: .window(.root))
                    })
                }
                if let currentContextController = strongSelf.currentContextController {
                    currentContextController.dismiss(completion: {
                        f()
                    })
                } else {
                    f()
                }
                
            }
        }, displayImportedMessageTooltip: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if let _ = strongSelf.currentImportMessageTooltip {
            } else {
                let controller = UndoOverlayController(presentationData: strongSelf.presentationData, content: .importedMessage(text: strongSelf.presentationData.strings.Conversation_ImportedMessageHint), elevatedLayout: false, action: { _ in return false })
                strongSelf.currentImportMessageTooltip = controller
                strongSelf.present(controller, in: .current)
            }
        }, displaySwipeToReplyHint: {  [weak self] in
            if let strongSelf = self, let validLayout = strongSelf.validLayout, min(validLayout.size.width, validLayout.size.height) > 320.0 {
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .swipeToReply(title: strongSelf.presentationData.strings.Conversation_SwipeToReplyHintTitle, text: strongSelf.presentationData.strings.Conversation_SwipeToReplyHintText), elevatedLayout: false, action: { _ in return false }), in: .current)
            }
        }, dismissReplyMarkupMessage: { [weak self] message in
            guard let strongSelf = self, strongSelf.presentationInterfaceState.keyboardButtonsMessage?.id == message.id else {
                return
            }
            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedInputMode({ _ in .text }).updatedInterfaceState({
                    $0.withUpdatedMessageActionsState({ value in
                        var value = value
                        value.closedButtonKeyboardMessageId = message.id
                        value.dismissedButtonKeyboardMessageId = message.id
                        return value
                    })
                })
            })
        }, openMessagePollResults: { [weak self] messageId, optionOpaqueIdentifier in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                |> deliverOnMainQueue).start(next: { message in
                    guard let message = message else {
                        return
                    }
                    for media in message.media {
                        if let poll = media as? TelegramMediaPoll, poll.pollId.namespace == Namespaces.Media.CloudPoll {
                            strongSelf.push(pollResultsController(context: strongSelf.context, messageId: messageId, poll: poll, focusOnOptionWithOpaqueIdentifier: optionOpaqueIdentifier))
                            break
                        }
                    }
                })
            })
        }, openPollCreation: { [weak self] isQuiz in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                if let controller = strongSelf.configurePollCreation(isQuiz: isQuiz) {
                    strongSelf.effectiveNavigationController?.pushViewController(controller)
                }
            })
        }, displayPollSolution: { [weak self] solution, sourceNode in
            self?.displayPollSolution(solution: solution, sourceNode: sourceNode, isAutomatic: false)
        }, displayPsa: { [weak self] type, sourceNode in
            self?.displayPsa(type: type, sourceNode: sourceNode, isAutomatic: false)
        }, displayDiceTooltip: { [weak self] dice in
            self?.displayDiceTooltip(dice: dice)
        }, animateDiceSuccess: { [weak self] onlyHaptic in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.selectPollOptionFeedback == nil {
                strongSelf.selectPollOptionFeedback = HapticFeedback()
            }
            strongSelf.selectPollOptionFeedback?.success()
            if !onlyHaptic {
                strongSelf.chatDisplayNode.animateQuizCorrectOptionSelected()
            }
        }, displayPremiumStickerTooltip: { [weak self] file, message in
            self?.displayPremiumStickerTooltip(file: file, message: message)
        }, openPeerContextMenu: { [weak self] peer, messageId, node, rect, gesture in
            guard let strongSelf = self else {
                return
            }
            
            if strongSelf.presentationInterfaceState.interfaceState.selectionState != nil {
                return
            }
            
            strongSelf.dismissAllTooltips()
            
            let context = strongSelf.context
            
            let dataSignal: Signal<(EnginePeer?, EngineMessage?), NoError>
            if let messageId = messageId {
                dataSignal = context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id),
                    TelegramEngine.EngineData.Item.Messages.Message(id: messageId)
                )
            } else {
                dataSignal = context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)
                )
                |> map { peer -> (EnginePeer?, EngineMessage?) in
                    return (peer, nil)
                }
            }
            
            let _ = (dataSignal
            |> deliverOnMainQueue).start(next: { [weak self] peer, message in
                guard let strongSelf = self, let peer = peer, peer.smallProfileImage != nil else {
                    return
                }
              
                let galleryController = AvatarGalleryController(context: context, peer: peer._asPeer(), remoteEntries: nil, replaceRootController: { controller, ready in
                }, synchronousLoad: true)
                galleryController.setHintWillBePresentedInPreviewingContext(true)
                
                var isChannel = false
                if case let .channel(peer) = peer, case .broadcast = peer.info {
                    isChannel = true
                }
                var items: [ContextMenuItem] = [
                    .action(ContextMenuActionItem(text: isChannel ? strongSelf.presentationData.strings.Conversation_ContextMenuOpenChannelProfile : strongSelf.presentationData.strings.Conversation_ContextMenuOpenProfile, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        self?.openPeer(peerId: peer.id, navigation: .info, fromMessage: nil)
                    }))
                ]
                items.append(.action(ContextMenuActionItem(text: isChannel ? strongSelf.presentationData.strings.Conversation_ContextMenuOpenChannel : strongSelf.presentationData.strings.Conversation_ContextMenuSendMessage, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: isChannel ? "Chat/Context Menu/Channels" : "Chat/Context Menu/Message"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    self?.openPeer(peerId: peer.id, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                })))
                if !isChannel && canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuMention, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Mention"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                            strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                                var inputMode = inputMode
                                if inputMode == .none {
                                    inputMode = .text
                                }
                                return (chatTextInputAddMentionAttribute(current, peer: peer._asPeer()), inputMode)
                            }
                        }, delay: true)
                    })))
                }
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: galleryController, sourceNode: node, passthroughTouches: false)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                strongSelf.presentInGlobalOverlay(contextController)
            })
        }, openMessageReplies: { [weak self] messageId, isChannelPost, displayModalProgress in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.openMessageReplies(messageId: messageId, displayProgressInMessage: displayModalProgress ? nil : messageId, isChannelPost: isChannelPost, atMessage: nil, displayModalProgress: displayModalProgress)
        }, openReplyThreadOriginalMessage: { [weak self] message in
            guard let strongSelf = self else {
                return
            }
            var threadMessageId: MessageId?
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyMessageAttribute {
                    threadMessageId = attribute.threadMessageId
                    break
                }
            }
            for attribute in message.attributes {
                if let attribute = attribute as? SourceReferenceMessageAttribute {
                    if let threadMessageId = threadMessageId {
                        if let _ = strongSelf.navigationController as? NavigationController {
                            strongSelf.openMessageReplies(messageId: threadMessageId, displayProgressInMessage: message.id, isChannelPost: true, atMessage: attribute.messageId, displayModalProgress: false)
                        }
                    } else {
                        strongSelf.navigateToMessage(from: nil, to: .id(attribute.messageId, nil))
                    }
                    break
                }
            }
        }, openMessageStats: { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            
            let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
                |> mapToSignal { message -> Signal<(EngineMessage.Id, Int32?)?, NoError> in
                    if let message = message, let sourceMessageId = message.forwardInfo?.sourceMessageId {
                        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.StatsDatacenterId(id: sourceMessageId.peerId))
                        |> map { statsDatacenterId -> (EngineMessage.Id, Int32?)? in
                            return (sourceMessageId, statsDatacenterId)
                        }
                    } else {
                        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.StatsDatacenterId(id: id.peerId))
                        |> map { statsDatacenterId -> (EngineMessage.Id, Int32?)? in
                            return (id, statsDatacenterId)
                        }
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] messageIdAndStatsDatacenterId in
                    guard let strongSelf = self, let (id, statsDatacenterId) = messageIdAndStatsDatacenterId, let statsDatacenterId = statsDatacenterId else {
                        return
                    }
                    strongSelf.push(messageStatsController(context: context, messageId: id, statsDatacenterId: statsDatacenterId))
                })
            }, delay: true)
        }, editMessageMedia: { [weak self] messageId, draw in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.chatDisplayNode.dismissInput()
            
            if draw {
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
                        legacyMediaEditor(context: strongSelf.context, peer: peer, media: mediaReference, initialCaption: NSAttributedString(string: message.text), snapshots: [], transitionCompletion: nil, presentStickers: { [weak self] completion in
                            if let strongSelf = self {
                                let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                                    completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                                    return true
                                })
                                strongSelf.present(controller, in: .window(.root))
                                return controller
                            } else {
                                return nil
                            }
                        }, getCaptionPanelView: { [weak self] in
                            return self?.getCaptionPanelView()
                        }, sendMessagesWithSignals: { [weak self] signals, _, _ in
                            if let strongSelf = self {
                                strongSelf.interfaceInteraction?.setupEditMessage(messageId, { _ in })
                                strongSelf.editMessageMediaWithLegacySignals(signals!)
                            }
                        }, present: { [weak self] c, a in
                            self?.present(c, in: .window(.root), with: a)
                        })
                    }
                })
            } else {
                strongSelf.presentOldMediaPicker(fileMode: false, editingMedia: true, present: { [weak self] c, _ in
                    self?.effectiveNavigationController?.pushViewController(c)
                }, completion: { signals, _, _ in
                    self?.interfaceInteraction?.setupEditMessage(messageId, { _ in })
                    self?.editMessageMediaWithLegacySignals(signals)
                })
            }
        }, copyText: { [weak self] text in
            if let strongSelf = self {
                storeMessageTextInPasteboard(text, entities: nil)
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                        return true
                }), in: .current)
            }
        }, displayUndo: { [weak self] content in
            if let strongSelf = self {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                        return true
                }), in: .current)
            }
        }, isAnimatingMessage: { [weak self] stableId in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.chatDisplayNode.messageTransitionNode.isAnimatingMessage(stableId: stableId)
        }, getMessageTransitionNode: { [weak self] in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.chatDisplayNode.messageTransitionNode
        }, updateChoosingSticker: { [weak self] value in
            if let strongSelf = self {
                strongSelf.choosingStickerActivityPromise.set(value)
            }
        }, commitEmojiInteraction: { [weak self] messageId, emoji, interaction, file in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, peer.id != strongSelf.context.account.peerId else {
                return
            }
            
            strongSelf.context.account.updateLocalInputActivity(peerId: PeerActivitySpace(peerId: messageId.peerId, category: .global), activity: .interactingWithEmoji(emoticon: emoji, messageId: messageId, interaction: interaction), isPresent: true)
            
            let currentTimestamp = Int32(Date().timeIntervalSince1970)
            let _ = (ApplicationSpecificNotice.getInteractiveEmojiSyncTip(accountManager: strongSelf.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self] count, timestamp in
                if let strongSelf = self, count < 3 && currentTimestamp > timestamp + 24 * 60 * 60 {
                    strongSelf.interactiveEmojiSyncDisposable.set(
                        (strongSelf.peerInputActivitiesPromise.get()
                        |> filter { activities -> Bool in
                            var found = false
                            for (_, activity) in activities {
                                if case .seeingEmojiInteraction(emoji) = activity {
                                    found = true
                                    break
                                }
                            }
                            return found
                        }
                        |> map { _ -> Bool in
                            return true
                        }
                        |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(false))).start(next: { [weak self] responded in
                            if let strongSelf = self {
                                if !responded {
                                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: file, title: nil, text: strongSelf.presentationData.strings.Conversation_InteractiveEmojiSyncTip(EnginePeer(peer).compactDisplayTitle).string, undoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                                    
                                    let _ = ApplicationSpecificNotice.incrementInteractiveEmojiSyncTip(accountManager: strongSelf.context.sharedContext.accountManager, timestamp: currentTimestamp).start()
                                }
                            }
                        })
                    )
                }
            })
        }, openLargeEmojiInfo: { [weak self] _, fitz, file in
            guard let strongSelf = self else {
                return
            }
            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                LargeEmojiActionSheetItem(context: strongSelf.context, text: strongSelf.presentationData.strings.Conversation_LargeEmojiDisabledInfo, fitz: fitz, file: file),
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LargeEmojiEnable, color: .accent, action: { [weak actionSheet, weak self] in
                    actionSheet?.dismissAnimated()
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = updatePresentationThemeSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager, { current in
                        return current.withUpdatedLargeEmoji(true)
                    }).start()
                    
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .emoji(name: "TwoFactorSetupRememberSuccess", text: strongSelf.presentationData.strings.Conversation_LargeEmojiEnabled), elevatedLayout: false, action: { _ in return false }), in: .current)
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(actionSheet, in: .window(.root))
        }, openJoinLink: { [weak self] joinHash in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openResolved(result: .join(joinHash), sourceMessageId: nil)
        }, openWebView: { [weak self] buttonText, url, simple, fromMenu in
            guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramUser else {
                return
            }
            
            strongSelf.chatDisplayNode.dismissInput()
            
            let botName = EnginePeer(peer).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)
           
            if !fromMenu {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedTitlePanelContext {
                        if !$0.contains(where: {
                            switch $0 {
                                case .requestInProgress:
                                    return true
                                default:
                                    return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.append(.requestInProgress)
                            return updatedContexts.sorted()
                        }
                        return $0
                    }
                })
            }
            
            let updateProgress = { [weak self] in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            return $0.updatedTitlePanelContext {
                                if let index = $0.firstIndex(where: {
                                    switch $0 {
                                        case .requestInProgress:
                                            return true
                                        default:
                                            return false
                                    }
                                }) {
                                    var updatedContexts = $0
                                    updatedContexts.remove(at: index)
                                    return updatedContexts
                                }
                                return $0
                            }
                        })
                    }
                }
            }
            
            let openWebView = {
                if fromMenu {
                    strongSelf.updateChatPresentationInterfaceState(interactive: false) { state in
                        return state.updatedShowWebView(true).updatedForceInputCommandsHidden(true)
                    }
                    
                    let params = WebAppParameters(peerId: peerId, botId: peerId, botName: botName, url: url, queryId: nil, payload: nil, buttonText: buttonText, keepAliveSignal: nil, fromMenu: true, isSimple: false)
                    let controller = standaloneWebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, openUrl: { [weak self] url in
                        self?.openUrl(url, concealed: true, forceExternal: true)
                    }, getInputContainerNode: { [weak self] in
                        if let strongSelf = self, let layout = strongSelf.validLayout, case .compact = layout.metrics.widthClass {
                            return (strongSelf.chatDisplayNode.getWindowInputAccessoryHeight(), strongSelf.chatDisplayNode.inputPanelContainerNode, {
                                return strongSelf.chatDisplayNode.textInputPanelNode?.makeAttachmentMenuTransition(accessoryPanelNode: nil)
                            })
                        } else {
                            return nil
                        }
                    }, completion: { [weak self] in
                        self?.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }, willDismiss: { [weak self] in
                        self?.interfaceInteraction?.updateShowWebView { _ in
                            return false
                        }
                    }, didDismiss: { [weak self] in
                        if let strongSelf = self {
                            let isFocused = strongSelf.chatDisplayNode.textInputPanelNode?.isFocused ?? false
                            strongSelf.chatDisplayNode.insertSubnode(strongSelf.chatDisplayNode.inputPanelContainerNode, aboveSubnode: strongSelf.chatDisplayNode.historyNodeContainer)
                            if isFocused {
                                strongSelf.chatDisplayNode.textInputPanelNode?.ensureFocused()
                            }
                            
                            strongSelf.updateChatPresentationInterfaceState(interactive: false) { state in
                                return state.updatedForceInputCommandsHidden(false)
                            }
                        }
                    }, getNavigationController: { [weak self] in
                        return self?.effectiveNavigationController
                    })
                    controller.navigationPresentation = .flatModal
                    strongSelf.push(controller)
                    strongSelf.currentMenuWebAppController = controller
                } else if simple {
                    strongSelf.messageActionCallbackDisposable.set(((strongSelf.context.engine.messages.requestSimpleWebView(botId: peerId, url: url, themeParams: generateWebAppThemeParams(strongSelf.presentationData.theme))
                    |> afterDisposed {
                        updateProgress()
                    })
                    |> deliverOnMainQueue).start(next: { [weak self] url in
                        guard let strongSelf = self else {
                            return
                        }
                        let params = WebAppParameters(peerId: peerId, botId: peerId, botName: botName, url: url, queryId: nil, payload: nil, buttonText: buttonText, keepAliveSignal: nil, fromMenu: false, isSimple: true)
                        let controller = standaloneWebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, openUrl: { [weak self] url in
                            self?.openUrl(url, concealed: true, forceExternal: true)
                        }, getNavigationController: { [weak self] in
                            return self?.effectiveNavigationController
                        })
                        controller.navigationPresentation = .flatModal
                        strongSelf.currentWebAppController = controller
                        strongSelf.push(controller)
                    }, error: { [weak self] error in
                        if let strongSelf = self {
                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            })]), in: .window(.root))
                        }
                    }))
                } else {
                    strongSelf.messageActionCallbackDisposable.set(((strongSelf.context.engine.messages.requestWebView(peerId: peerId, botId: peerId, url: !url.isEmpty ? url : nil, payload: nil, themeParams: generateWebAppThemeParams(strongSelf.presentationData.theme), fromMenu: buttonText == "Menu", replyToMessageId: nil)
                    |> afterDisposed {
                        updateProgress()
                    })
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let strongSelf = self else {
                            return
                        }
                        let params = WebAppParameters(peerId: peerId, botId: peerId, botName: botName, url: result.url, queryId: result.queryId, payload: nil, buttonText: buttonText, keepAliveSignal: result.keepAliveSignal, fromMenu: false, isSimple: false)
                        let controller = standaloneWebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, openUrl: { [weak self] url in
                            self?.openUrl(url, concealed: true, forceExternal: true)
                        }, completion: { [weak self] in
                            self?.chatDisplayNode.historyNode.scrollToEndOfHistory()
                        }, getNavigationController: { [weak self] in
                            return self?.effectiveNavigationController
                        })
                        controller.navigationPresentation = .flatModal
                        strongSelf.currentWebAppController = controller
                        strongSelf.push(controller)
                    }, error: { [weak self] error in
                        if let strongSelf = self {
                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            })]), in: .window(.root))
                        }
                    }))
                }
            }
            
            let _ = (ApplicationSpecificNotice.getBotGameNotice(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peer.id)
            |> deliverOnMainQueue).start(next: { value in
                guard let strongSelf = self else {
                    return
                }

                if value {
                    openWebView()
                } else {
                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.WebApp_OpenWebViewAlertTitle, text: strongSelf.presentationData.strings.WebApp_OpenWebViewAlertText(botName).string, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: { }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        if let strongSelf = self {
                            let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peer.id).start()
                            openWebView()
                        }
                    })], parseMarkdown: true), in: .window(.root), with: nil)
                }
            })
        }, requestMessageUpdate: { [weak self] id in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(id)
            }
        }, cancelInteractiveKeyboardGestures: { [weak self] in
            (self?.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
            self?.chatDisplayNode.cancelInteractiveKeyboardGestures()
        }, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings, pollActionState: ChatInterfacePollActionState(), stickerSettings: self.stickerSettings, presentationContext: ChatPresentationContext(context: context, backgroundNode: self.chatBackgroundNode))
        
        self.controllerInteraction = controllerInteraction
        
        if case let .peer(peerId) = chatLocation, peerId != context.account.peerId {
            switch subject {
            case .pinnedMessages, .scheduledMessages, .forwardedMessages:
                break
            default:
                self.navigationBar?.userInfo = PeerInfoNavigationSourceTag(peerId: peerId)
            }
        }
        self.navigationBar?.allowsCustomTransition = {
            return true
        }
        
        self.chatTitleView = ChatTitleView(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder)
        self.navigationItem.titleView = self.chatTitleView
        self.chatTitleView?.pressed = { [weak self] in
            if let strongSelf = self {
                if strongSelf.chatLocation == .peer(id: strongSelf.context.account.peerId) {
                    if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
                        strongSelf.effectiveNavigationController?.pushViewController(infoController)
                    }
                } else {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        return $0.updatedTitlePanelContext {
                            if let index = $0.firstIndex(where: {
                                switch $0 {
                                    case .chatInfo:
                                        return true
                                    default:
                                        return false
                                }
                            }) {
                                var updatedContexts = $0
                                updatedContexts.remove(at: index)
                                return updatedContexts
                            } else {
                                var updatedContexts = $0
                                updatedContexts.append(.chatInfo)
                                return updatedContexts.sorted()
                            }
                        }
                    })
                }
            }
        }
        self.chatTitleView?.longPressed = { [weak self] in
            if let strongSelf = self, let peerView = strongSelf.peerView, let peer = peerView.peers[peerView.peerId], peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil && !strongSelf.presentationInterfaceState.isNotAccessible {
                strongSelf.interfaceInteraction?.beginMessageSearch(.everything, "")
            }
        }
        
        let chatInfoButtonItem: UIBarButtonItem
        switch chatLocation {
        case .peer, .replyThread:
            let avatarNode = ChatAvatarNavigationNode()
            avatarNode.contextAction = { [weak self] node, gesture in
                guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, peer.smallProfileImage != nil else {
                    return
                }
                let galleryController = AvatarGalleryController(context: strongSelf.context, peer: peer, remoteEntries: nil, replaceRootController: { controller, ready in
                }, synchronousLoad: true)
                galleryController.setHintWillBePresentedInPreviewingContext(true)
                
                let items: Signal<[ContextMenuItem], NoError> = context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.CanViewStats(id: peer.id),
                    TelegramEngine.EngineData.Item.Peer.StatsDatacenterId(id: peer.id)
                )
                |> map { canViewStats, statsDatacenterId -> [ContextMenuItem] in
                    var items: [ContextMenuItem] = [
                        .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            self?.navigationButtonAction(.openChatInfo(expandAvatar: true))
                        }))
                    ]
                    if canViewStats {
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChannelInfo_Stats, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer else {
                                return
                            }
                            strongSelf.view.endEditing(true)
                            
                            let statsController: ViewController
                            if let channel = peer as? TelegramChannel, case .group = channel.info {
                                statsController = groupStatsController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, peerId: peer.id, statsDatacenterId: statsDatacenterId)
                            } else {
                                statsController = channelStatsController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, peerId: peer.id, statsDatacenterId: statsDatacenterId)
                            }
                            strongSelf.push(statsController)
                        })))
                    }
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_Search, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Search"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        self?.interfaceInteraction?.beginMessageSearch(.everything, "")
                    })))
                    return items
                }
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: galleryController, sourceNode: node, passthroughTouches: false)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                strongSelf.presentInGlobalOverlay(contextController)
            }
            chatInfoButtonItem = UIBarButtonItem(customDisplayNode: avatarNode)!
        case .feed:
            chatInfoButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }
        chatInfoButtonItem.target = self
        chatInfoButtonItem.action = #selector(self.rightNavigationButtonAction)
        self.chatInfoNavigationButton = ChatNavigationButton(action: .openChatInfo(expandAvatar: true), buttonItem: chatInfoButtonItem)
        
        self.navigationItem.titleView = self.chatTitleView
        self.chatTitleView?.pressed = { [weak self] in
            self?.navigationButtonAction(.openChatInfo(expandAvatar: false))
        }
        
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
            if let botStart = botStart, case .interactive = botStart.behavior {
                return state.updatedBotStartPayload(botStart.payload)
            } else {
                return state
            }
        })
        
        let chatLocationPeerId: PeerId? = chatLocation.peerId
        
        self.accountPeerDisposable = (context.account.postbox.peerView(id: context.account.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peerView in
            if let strongSelf = self {
                let isPremium = peerView.peers[peerView.peerId]?.isPremium ?? false
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, {
                    return $0.updatedIsPremium(isPremium)
                })
            }
        })
        
        do {
            let peerId = chatLocationPeerId
            if case let .peer(peerView) = self.chatLocationInfoData, let peerId = peerId {
                peerView.set(context.account.viewTracker.peerView(peerId))
                var onlineMemberCount: Signal<Int32?, NoError> = .single(nil)
                var hasScheduledMessages: Signal<Bool, NoError> = .single(false)
                
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    let recentOnlineSignal: Signal<Int32?, NoError> = peerView.get()
                    |> map { view -> Bool? in
                        if let cachedData = view.cachedData as? CachedChannelData, let peer = peerViewMainPeer(view) as? TelegramChannel {
                            if case .broadcast = peer.info {
                                return nil
                            } else if let memberCount = cachedData.participantsSummary.memberCount, memberCount > 50 {
                                return true
                            } else {
                                return false
                            }
                        } else {
                            return false
                        }
                    }
                    |> distinctUntilChanged
                    |> mapToSignal { isLarge -> Signal<Int32?, NoError> in
                        if let isLarge = isLarge {
                            if isLarge {
                                return context.peerChannelMemberCategoriesContextsManager.recentOnline(account: context.account, accountPeerId: context.account.peerId, peerId: peerId)
                                |> map(Optional.init)
                            } else {
                                return context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
                                |> map(Optional.init)
                            }
                        } else {
                            return .single(nil)
                        }
                    }
                    onlineMemberCount = recentOnlineSignal
                    
                    self.reportIrrelvantGeoNoticePromise.set(context.engine.data.get(TelegramEngine.EngineData.Item.Notices.Notice(key: ApplicationSpecificNotice.irrelevantPeerGeoReportKey(peerId: peerId)))
                    |> map { entry -> Bool? in
                        if let _ = entry?.get(ApplicationSpecificBoolNotice.self) {
                            return true
                        } else {
                            return false
                        }
                    })
                } else {
                    self.reportIrrelvantGeoNoticePromise.set(.single(nil))
                }
                
                var isScheduledOrPinnedMessages = false
                switch subject {
                case .scheduledMessages, .pinnedMessages, .forwardedMessages:
                    isScheduledOrPinnedMessages = true
                default:
                    break
                }
                
                if case .peer = chatLocation, !isScheduledOrPinnedMessages, peerId.namespace != Namespaces.Peer.SecretChat {
                    let chatLocationContextHolder = self.chatLocationContextHolder
                    hasScheduledMessages = peerView.get()
                    |> take(1)
                    |> mapToSignal { view -> Signal<Bool, NoError> in
                        if let peer = peerViewMainPeer(view) as? TelegramChannel, !peer.hasPermission(.sendMessages) {
                            return .single(false)
                        } else {
                            return context.account.viewTracker.scheduledMessagesViewForLocation(context.chatLocationInput(for: chatLocation, contextHolder: chatLocationContextHolder))
                            |> map { view, _, _ in
                                return !view.entries.isEmpty
                            }
                        }
                    }
                }
                
                var displayedCountSignal: Signal<Int?, NoError> = .single(nil)
                var subtitleTextSignal: Signal<String?, NoError> = .single(nil)
                if case .pinnedMessages = subject {
                    displayedCountSignal = self.topPinnedMessageSignal(latest: true)
                    |> map { message -> Int? in
                        return message?.totalCount
                    }
                    |> distinctUntilChanged
                } else if case let .forwardedMessages(messageIds, options) = subject {
                    displayedCountSignal = self.presentationInterfaceStatePromise.get()
                    |> map { state -> Int? in
                        if let selectionState = state.interfaceState.selectionState {
                            return selectionState.selectedIds.count
                        } else {
                            return messageIds.count
                        }
                    }
                    |> distinctUntilChanged
                    
                    subtitleTextSignal = combineLatest(self.presentationInterfaceStatePromise.get(), options, displayedCountSignal)
                    |> map { state, options, count in
                        if let peer = state.renderedPeer?.chatMainPeer {
                            if let peer = peer as? TelegramUser {
                                let displayName = EnginePeer(peer).compactDisplayTitle
                                if count == 1 {
                                    if options.hideNames {
                                        return state.strings.Conversation_ForwardOptions_UserMessageForwardHidden(displayName).string
                                    } else {
                                        return state.strings.Conversation_ForwardOptions_UserMessageForwardVisible(displayName).string
                                    }
                                } else {
                                    if options.hideNames {
                                        return state.strings.Conversation_ForwardOptions_UserMessagesForwardHidden(displayName).string
                                    } else {
                                        return state.strings.Conversation_ForwardOptions_UserMessagesForwardVisible(displayName).string
                                    }
                                }
                            } else if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                if count == 1 {
                                    if options.hideNames {
                                        return state.strings.Conversation_ForwardOptions_ChannelMessageForwardHidden
                                    } else {
                                        return state.strings.Conversation_ForwardOptions_ChannelMessageForwardVisible
                                    }
                                } else {
                                    if options.hideNames {
                                        return state.strings.Conversation_ForwardOptions_ChannelMessagesForwardHidden
                                    } else {
                                        return state.strings.Conversation_ForwardOptions_ChannelMessagesForwardVisible
                                    }
                                }
                            } else {
                                if count == 1 {
                                    if options.hideNames {
                                        return state.strings.Conversation_ForwardOptions_GroupMessageForwardHidden
                                    } else {
                                        return state.strings.Conversation_ForwardOptions_GroupMessageForwardVisible
                                    }
                                } else {
                                    if options.hideNames {
                                        return state.strings.Conversation_ForwardOptions_GroupMessagesForwardHidden
                                    } else {
                                        return state.strings.Conversation_ForwardOptions_GroupMessagesForwardVisible
                                    }
                                }
                            }
                        } else {
                            return nil
                        }
                    }
                }
                
                                  
                self.titleDisposable.set((combineLatest(queue: Queue.mainQueue(), peerView.get(), onlineMemberCount, displayedCountSignal, subtitleTextSignal, self.presentationInterfaceStatePromise.get())
                |> deliverOnMainQueue).start(next: { [weak self] peerView, onlineMemberCount, displayedCount, subtitleText, presentationInterfaceState in
                    if let strongSelf = self {
                        var isScheduledMessages = false
                        if case .scheduledMessages = presentationInterfaceState.subject {
                            isScheduledMessages = true
                        }
                        
                        if let peer = peerViewMainPeer(peerView) {
                            if case .forwardedMessages = presentationInterfaceState.subject {
                                if displayedCount == 1 {
                                    strongSelf.chatTitleView?.titleContent = .custom(presentationInterfaceState.strings.Conversation_ForwardOptions_ForwardTitleSingle, subtitleText, false)
                                } else {
                                    strongSelf.chatTitleView?.titleContent = .custom(presentationInterfaceState.strings.Conversation_ForwardOptions_ForwardTitle(Int32(displayedCount ?? 1)), subtitleText, false)
                                }
                            } else if let selectionState = presentationInterfaceState.interfaceState.selectionState {
                                if selectionState.selectedIds.count > 0 {
                                    strongSelf.chatTitleView?.titleContent = .custom(presentationInterfaceState.strings.Conversation_SelectedMessages(Int32(selectionState.selectedIds.count)), nil, false)
                                } else {
                                    if let reportReason = presentationInterfaceState.reportReason {
                                        let title: String
                                        switch reportReason {
                                            case .spam:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonSpam
                                            case .fake:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonFake
                                            case .violence:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonViolence
                                            case .porno:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonPornography
                                            case .childAbuse:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonChildAbuse
                                            case .copyright:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonCopyright
                                            case .illegalDrugs:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonIllegalDrugs
                                            case .personalDetails:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonPersonalDetails
                                            case .custom:
                                                title = presentationInterfaceState.strings.ReportPeer_ReasonOther
                                            case .irrelevantLocation:
                                                title = ""
                                        }
                                        strongSelf.chatTitleView?.titleContent = .custom(title, presentationInterfaceState.strings.Conversation_SelectMessages, false)
                                    } else {
                                        strongSelf.chatTitleView?.titleContent = .custom(presentationInterfaceState.strings.Conversation_SelectMessages, nil, false)
                                    }
                                }
                            } else {
                                if case .pinnedMessages = presentationInterfaceState.subject {
                                    strongSelf.chatTitleView?.titleContent = .custom(presentationInterfaceState.strings.Chat_TitlePinnedMessages(Int32(displayedCount ?? 1)), nil, false)
                                } else {
                                    strongSelf.chatTitleView?.titleContent = .peer(peerView: peerView, onlineMemberCount: onlineMemberCount, isScheduledMessages: isScheduledMessages)
                                    let imageOverride: AvatarNodeImageOverride?
                                    if strongSelf.context.account.peerId == peer.id {
                                        imageOverride = .savedMessagesIcon
                                    } else if peer.id.isReplies {
                                        imageOverride = .repliesIcon
                                    } else if peer.isDeleted {
                                        imageOverride = .deletedIcon
                                    } else {
                                        imageOverride = nil
                                    }
                                    (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.setPeer(context: strongSelf.context, theme: strongSelf.presentationData.theme, peer: EnginePeer(peer), overrideImage: imageOverride)
                                    (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.contextActionIsEnabled =  peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil
                                    strongSelf.chatInfoNavigationButton?.buttonItem.accessibilityLabel = presentationInterfaceState.strings.Conversation_ContextMenuOpenProfile
                                }
                            }
                        }
                    }
                }))
                
                self.peerDisposable.set((combineLatest(queue: Queue.mainQueue(), peerView.get(), onlineMemberCount, hasScheduledMessages, self.reportIrrelvantGeoNoticePromise.get(), displayedCountSignal)
                |> deliverOnMainQueue).start(next: { [weak self] peerView, onlineMemberCount, hasScheduledMessages, peerReportNotice, pinnedCount in
                    if let strongSelf = self {
                        if strongSelf.peerView === peerView && strongSelf.reportIrrelvantGeoNotice == peerReportNotice && strongSelf.hasScheduledMessages == hasScheduledMessages {
                            return
                        }
                        
                        strongSelf.reportIrrelvantGeoNotice = peerReportNotice
                        strongSelf.hasScheduledMessages = hasScheduledMessages
                        
                        var upgradedToPeerId: PeerId?
                        if let previous = strongSelf.peerView, let group = previous.peers[previous.peerId] as? TelegramGroup, group.migrationReference == nil, let updatedGroup = peerView.peers[peerView.peerId] as? TelegramGroup, let migrationReference = updatedGroup.migrationReference {
                            upgradedToPeerId = migrationReference.peerId
                        }
                        
                        var shouldDismiss = false
                        if let previous = strongSelf.peerView, let group = previous.peers[previous.peerId] as? TelegramGroup, group.membership != .Removed, let updatedGroup = peerView.peers[peerView.peerId] as? TelegramGroup, updatedGroup.membership == .Removed {
                            shouldDismiss = true
                        } else if let previous = strongSelf.peerView, let channel = previous.peers[previous.peerId] as? TelegramChannel, channel.participationStatus != .kicked, let updatedChannel = peerView.peers[peerView.peerId] as? TelegramChannel, updatedChannel.participationStatus == .kicked {
                            shouldDismiss = true
                        } else if let previous = strongSelf.peerView, let secretChat = previous.peers[previous.peerId] as? TelegramSecretChat, case .active = secretChat.embeddedState, let updatedSecretChat = peerView.peers[peerView.peerId] as? TelegramSecretChat, case .terminated = updatedSecretChat.embeddedState {
                            shouldDismiss = true
                        }
                        
                        var wasGroupChannel: Bool?
                        if let previousPeerView = strongSelf.peerView, let info = (previousPeerView.peers[previousPeerView.peerId] as? TelegramChannel)?.info {
                            if case .group = info {
                                wasGroupChannel = true
                            } else {
                                wasGroupChannel = false
                            }
                        }
                        var isGroupChannel: Bool?
                        if let info = (peerView.peers[peerView.peerId] as? TelegramChannel)?.info {
                            if case .group = info {
                                isGroupChannel = true
                            } else {
                                isGroupChannel = false
                            }
                        }
                        let firstTime = strongSelf.peerView == nil
                        strongSelf.peerView = peerView
                        if wasGroupChannel != isGroupChannel {
                            if let isGroupChannel = isGroupChannel, isGroupChannel {
                                let (recentDisposable, _) = strongSelf.context.peerChannelMemberCategoriesContextsManager.recent(engine: strongSelf.context.engine, postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
                                let (adminsDisposable, _) = strongSelf.context.peerChannelMemberCategoriesContextsManager.admins(engine: strongSelf.context.engine, postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
                                let disposable = DisposableSet()
                                disposable.add(recentDisposable)
                                disposable.add(adminsDisposable)
                                strongSelf.chatAdditionalDataDisposable.set(disposable)
                            } else {
                                strongSelf.chatAdditionalDataDisposable.set(nil)
                            }
                        }
                        if strongSelf.isNodeLoaded {
                            strongSelf.chatDisplayNode.peerView = peerView
                        }
                        var peerIsMuted = false
                        if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                            if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                peerIsMuted = true
                            }
                        }
                        var peerDiscussionId: PeerId?
                        var peerGeoLocation: PeerGeoLocation?
                        if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, let cachedData = peerView.cachedData as? CachedChannelData {
                            if case .broadcast = peer.info {
                                if case let .known(value) = cachedData.linkedDiscussionPeerId {
                                    peerDiscussionId = value
                                }
                            } else {
                                peerGeoLocation = cachedData.peerGeoLocation
                            }
                        }
                        var renderedPeer: RenderedPeer?
                        var contactStatus: ChatContactStatus?
                        if let peer = peerView.peers[peerView.peerId] {
                            if let cachedData = peerView.cachedData as? CachedUserData {
                                contactStatus = ChatContactStatus(canAddContact: !peerView.peerIsContact, canReportIrrelevantLocation: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: nil)
                            } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                var invitedBy: Peer?
                                if let invitedByPeerId = cachedData.invitedBy {
                                    if let peer = peerView.peers[invitedByPeerId] {
                                        invitedBy = peer
                                    }
                                }
                                contactStatus = ChatContactStatus(canAddContact: false, canReportIrrelevantLocation: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy)
                            } else if let cachedData = peerView.cachedData as? CachedChannelData {
                                var canReportIrrelevantLocation = true
                                if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, peer.participationStatus == .member {
                                    canReportIrrelevantLocation = false
                                }
                                if let peerReportNotice = peerReportNotice, peerReportNotice {
                                    canReportIrrelevantLocation = false
                                }
                                var invitedBy: Peer?
                                if let invitedByPeerId = cachedData.invitedBy {
                                    if let peer = peerView.peers[invitedByPeerId] {
                                        invitedBy = peer
                                    }
                                }
                                contactStatus = ChatContactStatus(canAddContact: false, canReportIrrelevantLocation: canReportIrrelevantLocation, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy)
                            }
                            
                            var peers = SimpleDictionary<PeerId, Peer>()
                            peers[peer.id] = peer
                            if let associatedPeerId = peer.associatedPeerId, let associatedPeer = peerView.peers[associatedPeerId] {
                                peers[associatedPeer.id] = associatedPeer
                            }
                            renderedPeer = RenderedPeer(peerId: peer.id, peers: peers)
                        }
                        
                        var isNotAccessible: Bool = false
                        if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                            isNotAccessible = cachedChannelData.isNotAccessible
                        }
                        
                        if firstTime && isNotAccessible {
                            strongSelf.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerView.peerId)
                        }
                        
                        var hasBots: Bool = false
                        var hasBotCommands: Bool = false
                        var botMenuButton: BotMenuButton = .commands
                        var currentSendAsPeerId: PeerId?
                        var autoremoveTimeout: Int32?
                        var copyProtectionEnabled: Bool = false
                        if let peer = peerView.peers[peerView.peerId] {
                            copyProtectionEnabled = peer.isCopyProtectionEnabled
                            if let cachedGroupData = peerView.cachedData as? CachedGroupData {
                                if !cachedGroupData.botInfos.isEmpty {
                                    hasBots = true
                                }
                                let botCommands = cachedGroupData.botInfos.reduce(into: [], { result, info in
                                    result.append(contentsOf: info.botInfo.commands)
                                })
                                if !botCommands.isEmpty {
                                    hasBotCommands = true
                                }
                                if case let .known(value) = cachedGroupData.autoremoveTimeout {
                                    autoremoveTimeout = value?.effectiveValue
                                }
                            } else if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                                currentSendAsPeerId = cachedChannelData.sendAsPeerId
                                if let channel = peer as? TelegramChannel, case .group = channel.info {
                                    if !cachedChannelData.botInfos.isEmpty {
                                        hasBots = true
                                    }
                                    let botCommands = cachedChannelData.botInfos.reduce(into: [], { result, info in
                                        result.append(contentsOf: info.botInfo.commands)
                                    })
                                    if !botCommands.isEmpty {
                                        hasBotCommands = true
                                    }
                                }
                                if case let .known(value) = cachedChannelData.autoremoveTimeout {
                                    autoremoveTimeout = value?.effectiveValue
                                }
                            } else if let cachedUserData = peerView.cachedData as? CachedUserData {
                                botMenuButton = cachedUserData.botInfo?.menuButton ?? .commands
                                if case let .known(value) = cachedUserData.autoremoveTimeout {
                                    autoremoveTimeout = value?.effectiveValue
                                }
                                if let botInfo = cachedUserData.botInfo, !botInfo.commands.isEmpty {
                                    hasBotCommands = true
                                }
                            }
                        }
                        
                        let isArchived: Bool = peerView.groupId == Namespaces.PeerGroup.archive
                        
                        var explicitelyCanPinMessages: Bool = false
                        if let cachedUserData = peerView.cachedData as? CachedUserData {
                            explicitelyCanPinMessages = cachedUserData.canPinMessages
                        } else if peerView.peerId == context.account.peerId {
                            explicitelyCanPinMessages = true
                        }
                                                
                        var animated = false
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, let updated = renderedPeer?.peer as? TelegramSecretChat, peer.embeddedState != updated.embeddedState {
                            animated = true
                        }
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, let updated = renderedPeer?.peer as? TelegramChannel {
                            if peer.participationStatus != updated.participationStatus {
                                animated = true
                            }
                        }
                        
                        var didDisplayActionsPanel = false
                        if let contactStatus = strongSelf.presentationInterfaceState.contactStatus, !contactStatus.isEmpty, let peerStatusSettings = contactStatus.peerStatusSettings {
                            if !peerStatusSettings.flags.isEmpty {
                                if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                                    didDisplayActionsPanel = true
                                } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                                    didDisplayActionsPanel = true
                                } else if peerStatusSettings.contains(.canShareContact) {
                                    didDisplayActionsPanel = true
                                } else if contactStatus.canReportIrrelevantLocation && peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
                                    didDisplayActionsPanel = true
                                } else if peerStatusSettings.contains(.suggestAddMembers) {
                                    didDisplayActionsPanel = true
                                }
                            }
                        }
                        
                        var displayActionsPanel = false
                        if let contactStatus = contactStatus, !contactStatus.isEmpty, let peerStatusSettings = contactStatus.peerStatusSettings {
                            if !peerStatusSettings.flags.isEmpty {
                                if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                                    displayActionsPanel = true
                                } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                                    displayActionsPanel = true
                                } else if peerStatusSettings.contains(.canShareContact) {
                                    displayActionsPanel = true
                                } else if contactStatus.canReportIrrelevantLocation && peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
                                    displayActionsPanel = true
                                } else if peerStatusSettings.contains(.suggestAddMembers) {
                                    displayActionsPanel = true
                                }
                            }
                        }
                        
                        if displayActionsPanel != didDisplayActionsPanel {
                            animated = true
                        }
                        
                        if strongSelf.preloadHistoryPeerId != peerDiscussionId {
                            strongSelf.preloadHistoryPeerId = peerDiscussionId
                            if let peerDiscussionId = peerDiscussionId {
                                let combinedDisposable = DisposableSet()
                                strongSelf.preloadHistoryPeerIdDisposable.set(combinedDisposable)
                                combinedDisposable.add(strongSelf.context.account.viewTracker.polledChannel(peerId: peerDiscussionId).start())
                                combinedDisposable.add(strongSelf.context.account.addAdditionalPreloadHistoryPeerId(peerId: peerDiscussionId))
                            } else {
                                strongSelf.preloadHistoryPeerIdDisposable.set(nil)
                            }
                        }
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: animated, interactive: false, {
                            return $0.updatedPeer { _ in
                                return renderedPeer
                            }.updatedIsNotAccessible(isNotAccessible).updatedContactStatus(contactStatus).updatedHasBots(hasBots).updatedHasBotCommands(hasBotCommands).updatedBotMenuButton(botMenuButton).updatedIsArchived(isArchived).updatedPeerIsMuted(peerIsMuted).updatedPeerDiscussionId(peerDiscussionId).updatedPeerGeoLocation(peerGeoLocation).updatedExplicitelyCanPinMessages(explicitelyCanPinMessages).updatedHasScheduledMessages(hasScheduledMessages)
                                .updatedAutoremoveTimeout(autoremoveTimeout)
                                .updatedCurrentSendAsPeerId(currentSendAsPeerId)
                                .updatedCopyProtectionEnabled(copyProtectionEnabled)
                        })

                        if case .standard(previewing: false) = mode, let channel = renderedPeer?.chatMainPeer as? TelegramChannel, case .broadcast = channel.info {
                            var isRegularChat = false
                            if let subject = subject {
                                if case .message = subject {
                                    isRegularChat = true
                                }
                            } else {
                                isRegularChat = true
                            }
                            if isRegularChat, strongSelf.nextChannelToReadDisposable == nil {
                                strongSelf.nextChannelToReadDisposable = (combineLatest(queue: .mainQueue(),
                                    strongSelf.context.engine.peers.getNextUnreadChannel(peerId: channel.id, chatListFilterId: strongSelf.currentChatListFilter, getFilterPredicate: chatListFilterPredicate),
                                    ApplicationSpecificNotice.getNextChatSuggestionTip(accountManager: strongSelf.context.sharedContext.accountManager)
                                )
                                |> then(.complete() |> delay(1.0, queue: .mainQueue()))
                                |> restart).start(next: { nextPeer, nextChatSuggestionTip in
                                    guard let strongSelf = self else {
                                        return
                                    }

                                    strongSelf.chatDisplayNode.historyNode.offerNextChannelToRead = true
                                    strongSelf.chatDisplayNode.historyNode.nextChannelToRead = nextPeer.flatMap { nextPeer -> (peer: EnginePeer, unreadCount: Int, location: TelegramEngine.NextUnreadChannelLocation) in
                                        return (peer: nextPeer.peer, unreadCount: nextPeer.unreadCount, location: nextPeer.location)
                                    }
                                    strongSelf.chatDisplayNode.historyNode.nextChannelToReadDisplayName = nextChatSuggestionTip >= 3

                                    let nextPeerId = nextPeer?.peer.id

                                    if strongSelf.preloadNextChatPeerId != nextPeerId {
                                        strongSelf.preloadNextChatPeerId = nextPeerId
                                        if let nextPeerId = nextPeerId {
                                            let combinedDisposable = DisposableSet()
                                            strongSelf.preloadNextChatPeerIdDisposable.set(combinedDisposable)
                                            combinedDisposable.add(strongSelf.context.account.viewTracker.polledChannel(peerId: nextPeerId).start())
                                            combinedDisposable.add(strongSelf.context.account.addAdditionalPreloadHistoryPeerId(peerId: nextPeerId))
                                        } else {
                                            strongSelf.preloadNextChatPeerIdDisposable.set(nil)
                                        }
                                    }
                                })
                            }
                        }

                        if !strongSelf.didSetChatLocationInfoReady {
                            strongSelf.didSetChatLocationInfoReady = true
                            strongSelf._chatLocationInfoReady.set(.single(true))
                        }
                        strongSelf.updateReminderActivity()
                        if let upgradedToPeerId = upgradedToPeerId {
                            if let navigationController = strongSelf.effectiveNavigationController {
                                var viewControllers = navigationController.viewControllers
                                if let index = viewControllers.firstIndex(where: { $0 === strongSelf }) {
                                    viewControllers[index] = ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: upgradedToPeerId))
                                    navigationController.setViewControllers(viewControllers, animated: false)
                                }
                            }
                        } else if shouldDismiss {
                            strongSelf.dismiss()
                        }
                    }
                }))
            } else if case let .replyThread(messagePromise) = self.chatLocationInfoData, let peerId = peerId {
                self.reportIrrelvantGeoNoticePromise.set(.single(nil))
                
                let replyThreadType: ChatTitleContent.ReplyThreadType
                switch chatLocation {
                case .peer:
                    replyThreadType = .replies
                case let .replyThread(replyThreadMessage):
                    if replyThreadMessage.isChannelPost {
                        replyThreadType = .comments
                    } else {
                        replyThreadType = .replies
                    }
                case .feed:
                    replyThreadType = .replies
                }
                
                let peerView = context.account.viewTracker.peerView(peerId)
                
                self.titleDisposable.set(nil)
                self.peerDisposable.set((combineLatest(queue: Queue.mainQueue(),
                    peerView,
                    messagePromise.get()
                )
                |> deliverOnMainQueue).start(next: { [weak self] peerView, message in
                    if let strongSelf = self {
                        var count = 0
                        if let message = message {
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyThreadMessageAttribute {
                                    count = Int(attribute.count)
                                    break
                                }
                            }
                        }
                        
                        strongSelf.chatTitleView?.titleContent = .replyThread(type: replyThreadType, count: count)
                        
                        let firstTime = strongSelf.peerView == nil
                        strongSelf.peerView = peerView
                        
                        if strongSelf.isNodeLoaded {
                            strongSelf.chatDisplayNode.peerView = peerView
                        }
                        var peerIsMuted = false
                        if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                            if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                peerIsMuted = true
                            }
                        }
                        var peerDiscussionId: PeerId?
                        var peerGeoLocation: PeerGeoLocation?
                        var currentSendAsPeerId: PeerId?
                        if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, let cachedData = peerView.cachedData as? CachedChannelData {
                            currentSendAsPeerId = cachedData.sendAsPeerId
                            if case .broadcast = peer.info {
                                if case let .known(value) = cachedData.linkedDiscussionPeerId {
                                    peerDiscussionId = value
                                }
                            } else {
                                peerGeoLocation = cachedData.peerGeoLocation
                            }
                        }
                        var renderedPeer: RenderedPeer?
                        var contactStatus: ChatContactStatus?
                        var copyProtectionEnabled: Bool = false
                        if let peer = peerView.peers[peerView.peerId] {
                            copyProtectionEnabled = peer.isCopyProtectionEnabled
                            if let cachedData = peerView.cachedData as? CachedUserData {
                                contactStatus = ChatContactStatus(canAddContact: !peerView.peerIsContact, canReportIrrelevantLocation: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: nil)
                            } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                var invitedBy: Peer?
                                if let invitedByPeerId = cachedData.invitedBy {
                                    if let peer = peerView.peers[invitedByPeerId] {
                                        invitedBy = peer
                                    }
                                }
                                contactStatus = ChatContactStatus(canAddContact: false, canReportIrrelevantLocation: false, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy)
                            } else if let cachedData = peerView.cachedData as? CachedChannelData {
                                var canReportIrrelevantLocation = true
                                if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, peer.participationStatus == .member {
                                    canReportIrrelevantLocation = false
                                }
                                canReportIrrelevantLocation = false
                                var invitedBy: Peer?
                                if let invitedByPeerId = cachedData.invitedBy {
                                    if let peer = peerView.peers[invitedByPeerId] {
                                        invitedBy = peer
                                    }
                                }
                                contactStatus = ChatContactStatus(canAddContact: false, canReportIrrelevantLocation: canReportIrrelevantLocation, peerStatusSettings: cachedData.peerStatusSettings, invitedBy: invitedBy)
                            }
                            
                            var peers = SimpleDictionary<PeerId, Peer>()
                            peers[peer.id] = peer
                            if let associatedPeerId = peer.associatedPeerId, let associatedPeer = peerView.peers[associatedPeerId] {
                                peers[associatedPeer.id] = associatedPeer
                            }
                            renderedPeer = RenderedPeer(peerId: peer.id, peers: peers)
                        }
                        
                        var isNotAccessible: Bool = false
                        if let cachedChannelData = peerView.cachedData as? CachedChannelData {
                            isNotAccessible = cachedChannelData.isNotAccessible
                        }
                        
                        if firstTime && isNotAccessible {
                            strongSelf.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peerView.peerId)
                        }
                        
                        var hasBots: Bool = false
                        if let peer = peerView.peers[peerView.peerId] {
                            if let cachedGroupData = peerView.cachedData as? CachedGroupData {
                                if !cachedGroupData.botInfos.isEmpty {
                                    hasBots = true
                                }
                            } else if let cachedChannelData = peerView.cachedData as? CachedChannelData, let channel = peer as? TelegramChannel, case .group = channel.info {
                                if !cachedChannelData.botInfos.isEmpty {
                                    hasBots = true
                                }
                            }
                        }
                        
                        let isArchived: Bool = peerView.groupId == Namespaces.PeerGroup.archive
                        
                        var explicitelyCanPinMessages: Bool = false
                        if let cachedUserData = peerView.cachedData as? CachedUserData {
                            explicitelyCanPinMessages = cachedUserData.canPinMessages
                        } else if peerView.peerId == context.account.peerId {
                            explicitelyCanPinMessages = true
                        }
                        
                        var animated = false
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, let updated = renderedPeer?.peer as? TelegramSecretChat, peer.embeddedState != updated.embeddedState {
                            animated = true
                        }
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, let updated = renderedPeer?.peer as? TelegramChannel {
                            if peer.participationStatus != updated.participationStatus {
                                animated = true
                            }
                        }
                        
                        var didDisplayActionsPanel = false
                        if let contactStatus = strongSelf.presentationInterfaceState.contactStatus, !contactStatus.isEmpty, let peerStatusSettings = contactStatus.peerStatusSettings {
                            if !peerStatusSettings.flags.isEmpty {
                                if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                                    didDisplayActionsPanel = true
                                } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                                    didDisplayActionsPanel = true
                                } else if peerStatusSettings.contains(.canShareContact) {
                                    didDisplayActionsPanel = true
                                } else if contactStatus.canReportIrrelevantLocation && peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
                                    didDisplayActionsPanel = true
                                } else if peerStatusSettings.contains(.suggestAddMembers) {
                                    didDisplayActionsPanel = true
                                }
                            }
                        }
                        
                        var displayActionsPanel = false
                        if let contactStatus = contactStatus, !contactStatus.isEmpty, let peerStatusSettings = contactStatus.peerStatusSettings {
                            if !peerStatusSettings.flags.isEmpty {
                                if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                                    displayActionsPanel = true
                                } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                                    displayActionsPanel = true
                                } else if peerStatusSettings.contains(.canShareContact) {
                                    displayActionsPanel = true
                                } else if contactStatus.canReportIrrelevantLocation && peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
                                    displayActionsPanel = true
                                } else if peerStatusSettings.contains(.suggestAddMembers) {
                                    displayActionsPanel = true
                                }
                            }
                        }
                        
                        if displayActionsPanel != didDisplayActionsPanel {
                            animated = true
                        }
                        
                        if strongSelf.preloadHistoryPeerId != peerDiscussionId {
                            strongSelf.preloadHistoryPeerId = peerDiscussionId
                            if let peerDiscussionId = peerDiscussionId {
                                strongSelf.preloadHistoryPeerIdDisposable.set(strongSelf.context.account.addAdditionalPreloadHistoryPeerId(peerId: peerDiscussionId))
                            } else {
                                strongSelf.preloadHistoryPeerIdDisposable.set(nil)
                            }
                        }
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: animated, interactive: false, {
                            return $0.updatedPeer { _ in
                                return renderedPeer
                            }.updatedIsNotAccessible(isNotAccessible).updatedContactStatus(contactStatus).updatedHasBots(hasBots).updatedIsArchived(isArchived).updatedPeerIsMuted(peerIsMuted).updatedPeerDiscussionId(peerDiscussionId).updatedPeerGeoLocation(peerGeoLocation).updatedExplicitelyCanPinMessages(explicitelyCanPinMessages).updatedHasScheduledMessages(false).updatedCurrentSendAsPeerId(currentSendAsPeerId)
                                .updatedCopyProtectionEnabled(copyProtectionEnabled)
                        })
                        if !strongSelf.didSetChatLocationInfoReady {
                            strongSelf.didSetChatLocationInfoReady = true
                            strongSelf._chatLocationInfoReady.set(.single(true))
                        }
                    }
                }))
            } else if case .feed = self.chatLocationInfoData {
                self.reportIrrelvantGeoNoticePromise.set(.single(nil))
                self.titleDisposable.set(nil)
                
                self.chatTitleView?.titleContent = .custom("Feed", nil, false)
                
                if !self.didSetChatLocationInfoReady {
                    self.didSetChatLocationInfoReady = true
                    self._chatLocationInfoReady.set(.single(true))
                }
            }
        }
        
        self.botCallbackAlertMessageDisposable = (self.botCallbackAlertMessage.get()
            |> deliverOnMainQueue).start(next: { [weak self] message in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        return $0.updatedTitlePanelContext {
                            if let message = message {
                                if let index = $0.firstIndex(where: {
                                    switch $0 {
                                        case .toastAlert:
                                            return true
                                        default:
                                            return false
                                    }
                                }) {
                                    if $0[index] != ChatTitlePanelContext.toastAlert(message) {
                                        var updatedContexts = $0
                                        updatedContexts[index] = .toastAlert(message)
                                        return updatedContexts
                                    } else {
                                        return $0
                                    }
                                } else {
                                    var updatedContexts = $0
                                    updatedContexts.append(.toastAlert(message))
                                    return updatedContexts.sorted()
                                }
                            } else {
                                if let index = $0.firstIndex(where: {
                                    switch $0 {
                                        case .toastAlert:
                                            return true
                                        default:
                                            return false
                                    }
                                }) {
                                    var updatedContexts = $0
                                    updatedContexts.remove(at: index)
                                    return updatedContexts
                                } else {
                                    return $0
                                }
                            }
                        }
                    })
                }
            })
        
        self.audioRecorderDisposable = (self.audioRecorder.get()
        |> deliverOnMainQueue).start(next: { [weak self] audioRecorder in
            if let strongSelf = self {
                if strongSelf.audioRecorderValue !== audioRecorder {
                    strongSelf.audioRecorderValue = audioRecorder
                    strongSelf.lockOrientation = audioRecorder != nil
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            let isLocked = strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId
                            if let audioRecorder = audioRecorder {
                                if panelState.mediaRecordingState == nil {
                                    return panelState.withUpdatedMediaRecordingState(.audio(recorder: audioRecorder, isLocked: isLocked))
                                }
                            } else {
                                if case .waitingForPreview = panelState.mediaRecordingState {
                                    return panelState
                                }
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })
                    strongSelf.audioRecorderStatusDisposable?.dispose()
                    
                    if let audioRecorder = audioRecorder {
                        if !audioRecorder.beginWithTone {
                            strongSelf.recorderFeedback?.impact(.light)
                        }
                        audioRecorder.start()
                        strongSelf.audioRecorderStatusDisposable = (audioRecorder.recordingState
                        |> deliverOnMainQueue).start(next: { value in
                            if case .stopped = value {
                                self?.stopMediaRecorder()
                            }
                        })
                    } else {
                        strongSelf.audioRecorderStatusDisposable = nil
                    }
                    strongSelf.updateDownButtonVisibility()
                }
            }
        })
        
        self.videoRecorderDisposable = (self.videoRecorder.get()
        |> deliverOnMainQueue).start(next: { [weak self] videoRecorder in
            if let strongSelf = self {
                if strongSelf.videoRecorderValue !== videoRecorder {
                    let previousVideoRecorderValue = strongSelf.videoRecorderValue
                    strongSelf.videoRecorderValue = videoRecorder
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            if let videoRecorder = videoRecorder {
                                if panelState.mediaRecordingState == nil {
                                    return panelState.withUpdatedMediaRecordingState(.video(status: .recording(videoRecorder.audioStatus), isLocked: strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId))
                                }
                            } else {
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })
                    
                    if let videoRecorder = videoRecorder {
                        strongSelf.recorderFeedback?.impact(.light)
                        
                        videoRecorder.onDismiss = { [weak self] isCancelled in
                            self?.chatDisplayNode.updateRecordedMediaDeleted(isCancelled)
                            self?.beginMediaRecordingRequestId += 1
                            self?.lockMediaRecordingRequestId = nil
                            self?.videoRecorder.set(.single(nil))
                        }
                        videoRecorder.onStop = {
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedInputTextPanelState { panelState in
                                        return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                                    }
                                })
                            }
                        }
                        strongSelf.present(videoRecorder, in: .window(.root))
                        
                        if strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId {
                            videoRecorder.lockVideo()
                        }
                    }
                    strongSelf.updateDownButtonVisibility()
                    
                    if let previousVideoRecorderValue = previousVideoRecorderValue {
                        previousVideoRecorderValue.dismissVideo()
                    }
                }
            }
        })
        
        if let botStart = botStart, case .automatic = botStart.behavior {
            self.startBot(botStart.payload)
        }
        
        let activitySpace: PeerActivitySpace?
        switch self.chatLocation {
        case let .peer(peerId):
            activitySpace = PeerActivitySpace(peerId: peerId, category: .global)
        case let .replyThread(replyThreadMessage):
            activitySpace = PeerActivitySpace(peerId: replyThreadMessage.messageId.peerId, category: .thread(makeMessageThreadId(replyThreadMessage.messageId)))
        case .feed:
            activitySpace = nil
        }
        
        if let activitySpace = activitySpace {
            self.inputActivityDisposable = (self.typingActivityPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil && strongSelf.presentationInterfaceState.subject != .scheduledMessages && strongSelf.presentationInterfaceState.currentSendAsPeerId == nil {
                    strongSelf.context.account.updateLocalInputActivity(peerId: activitySpace, activity: .typingText, isPresent: value)
                }
            })
        
            self.choosingStickerActivityDisposable = (self.choosingStickerActivityPromise.get()
            |> mapToSignal { value -> Signal<Bool, NoError> in
                if value {
                    return .single(true)
                } else {
                    return .single(false) |> delay(2.0, queue: Queue.mainQueue())
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil && strongSelf.presentationInterfaceState.subject != .scheduledMessages && strongSelf.presentationInterfaceState.currentSendAsPeerId == nil {
                    if value {
                        strongSelf.context.account.updateLocalInputActivity(peerId: activitySpace, activity: .typingText, isPresent: false)
                    }
                    strongSelf.context.account.updateLocalInputActivity(peerId: activitySpace, activity: .choosingSticker, isPresent: value)
                }
            })
            
            self.recordingActivityDisposable = (self.recordingActivityPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let strongSelf = self, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil && strongSelf.presentationInterfaceState.subject != .scheduledMessages && strongSelf.presentationInterfaceState.currentSendAsPeerId == nil {
                    strongSelf.acquiredRecordingActivityDisposable?.dispose()
                    switch value {
                        case .voice:
                            strongSelf.acquiredRecordingActivityDisposable = strongSelf.context.account.acquireLocalInputActivity(peerId: activitySpace, activity: .recordingVoice)
                        case .instantVideo:
                            strongSelf.acquiredRecordingActivityDisposable = strongSelf.context.account.acquireLocalInputActivity(peerId: activitySpace, activity: .recordingInstantVideo)
                        case .none:
                            strongSelf.acquiredRecordingActivityDisposable = nil
                    }
                }
            })
        }
        
        let themeEmoticon: Signal<String?, NoError> = self.themeEmoticonPromise.get()
        |> distinctUntilChanged
        
        let themeSettings = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationThemeSettings])
        |> map { sharedData -> PresentationThemeSettings in
            let themeSettings: PresentationThemeSettings
            if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) {
                themeSettings = current
            } else {
                themeSettings = PresentationThemeSettings.defaultSettings
            }
            return themeSettings
        }
        
        let accountManager = context.sharedContext.accountManager
        let currentThemeEmoticon = Atomic<(String?, Bool)?>(value: nil)
        self.presentationDataDisposable = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, themeSettings, context.engine.themes.getChatThemes(accountManager: accountManager, onlyCached: true), themeEmoticon, self.themeEmoticonAndDarkAppearancePreviewPromise.get()).start(next: { [weak self] presentationData, themeSettings, chatThemes, themeEmoticon, themeEmoticonAndDarkAppearance in
            if let strongSelf = self {
                let (themeEmoticonPreview, darkAppearancePreview) = themeEmoticonAndDarkAppearance
                
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                let previousChatWallpaper = strongSelf.presentationData.chatWallpaper
                
                var themeEmoticon = themeEmoticon
                if let themeEmoticonPreview = themeEmoticonPreview {
                    if !themeEmoticonPreview.isEmpty {
                        themeEmoticon = themeEmoticonPreview
                    } else {
                        themeEmoticon = nil
                    }
                }
                if strongSelf.chatLocation.peerId == strongSelf.context.account.peerId {
                    themeEmoticon = nil
                }
                                
                var presentationData = presentationData
                var useDarkAppearance = presentationData.theme.overallDarkAppearance
                
                if let themeEmoticon = themeEmoticon, let theme = chatThemes.first(where: { $0.emoticon?.strippedEmoji == themeEmoticon.strippedEmoji }) {
                    if let darkAppearancePreview = darkAppearancePreview {
                        useDarkAppearance = darkAppearancePreview
                    }
                    if let theme = makePresentationTheme(cloudTheme: theme, dark: useDarkAppearance) {
                        theme.forceSync = true
                        presentationData = presentationData.withUpdated(theme: theme).withUpdated(chatWallpaper: theme.chat.defaultWallpaper)
                        
                        Queue.mainQueue().after(1.0, {
                            theme.forceSync = false
                        })
                    }
                } else if let darkAppearancePreview = darkAppearancePreview {
                    useDarkAppearance = darkAppearancePreview
                    let lightTheme: PresentationTheme
                    let lightWallpaper: TelegramWallpaper
                    
                    let darkTheme: PresentationTheme
                    let darkWallpaper: TelegramWallpaper
                    
                    if presentationData.autoNightModeTriggered {
                        darkTheme = presentationData.theme
                        darkWallpaper = presentationData.chatWallpaper
                        
                        var currentColors = themeSettings.themeSpecificAccentColors[themeSettings.theme.index]
                        if let colors = currentColors, colors.baseColor == .theme {
                            currentColors = nil
                        }
                        
                        let themeSpecificWallpaper = (themeSettings.themeSpecificChatWallpapers[coloredThemeIndex(reference: themeSettings.theme, accentColor: currentColors)] ?? themeSettings.themeSpecificChatWallpapers[themeSettings.theme.index])
                        
                        if let themeSpecificWallpaper = themeSpecificWallpaper {
                            lightWallpaper = themeSpecificWallpaper
                        } else {
                            let theme = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: themeSettings.theme, accentColor: currentColors?.color, bubbleColors: currentColors?.customBubbleColors ?? [], wallpaper: currentColors?.wallpaper, baseColor: currentColors?.baseColor, preview: true) ?? defaultPresentationTheme
                            lightWallpaper = theme.chat.defaultWallpaper
                        }
                        
                        lightTheme = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: themeSettings.theme, accentColor: currentColors?.color, bubbleColors: currentColors?.customBubbleColors ?? [], wallpaper: currentColors?.wallpaper, baseColor: currentColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
                    } else {
                        lightTheme = presentationData.theme
                        lightWallpaper = presentationData.chatWallpaper
                        
                        let automaticTheme = themeSettings.automaticThemeSwitchSetting.theme
                        let effectiveColors = themeSettings.themeSpecificAccentColors[automaticTheme.index]
                        let themeSpecificWallpaper = (themeSettings.themeSpecificChatWallpapers[coloredThemeIndex(reference: automaticTheme, accentColor: effectiveColors)] ?? themeSettings.themeSpecificChatWallpapers[automaticTheme.index])
                        
                        darkTheme = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: automaticTheme, accentColor: effectiveColors?.color, bubbleColors: effectiveColors?.customBubbleColors ?? [], wallpaper: effectiveColors?.wallpaper, baseColor: effectiveColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
                        
                        if let themeSpecificWallpaper = themeSpecificWallpaper {
                            darkWallpaper = themeSpecificWallpaper
                        } else {
                            switch lightWallpaper {
                                case .builtin, .color, .gradient:
                                    darkWallpaper = darkTheme.chat.defaultWallpaper
                                case .file:
                                    if lightWallpaper.isPattern {
                                        darkWallpaper = darkTheme.chat.defaultWallpaper
                                    } else {
                                        darkWallpaper = lightWallpaper
                                    }
                                default:
                                    darkWallpaper = lightWallpaper
                            }
                        }
                    }
                    
                    if darkAppearancePreview {
                        darkTheme.forceSync = true
                        Queue.mainQueue().after(1.0, {
                            darkTheme.forceSync = false
                        })
                        presentationData = presentationData.withUpdated(theme: darkTheme).withUpdated(chatWallpaper: darkWallpaper)
                    } else {
                        lightTheme.forceSync = true
                        Queue.mainQueue().after(1.0, {
                            lightTheme.forceSync = false
                        })
                        presentationData = presentationData.withUpdated(theme: lightTheme).withUpdated(chatWallpaper: lightWallpaper)
                    }
                }
                let isFirstTime = !strongSelf.didSetPresentationData
                strongSelf.presentationData = presentationData
                strongSelf.didSetPresentationData = true
                
                let previousThemeEmoticon = currentThemeEmoticon.swap((themeEmoticon, useDarkAppearance))
                
                if isFirstTime || previousTheme != presentationData.theme || previousStrings !== presentationData.strings || presentationData.chatWallpaper != previousChatWallpaper {
                    strongSelf.themeAndStringsUpdated()
                    
                    controllerInteraction.updatedPresentationData = strongSelf.updatedPresentationData
                    strongSelf.presentationDataPromise.set(.single(strongSelf.presentationData))
                    
                    if !isFirstTime && (previousThemeEmoticon?.0 != themeEmoticon || previousThemeEmoticon?.1 != useDarkAppearance) {
                        strongSelf.presentCrossfadeSnapshot()
                    }
                }
                strongSelf.presentationReady.set(.single(true))
            }
        })
        
        self.automaticMediaDownloadSettingsDisposable = (context.sharedContext.automaticMediaDownloadSettings
        |> deliverOnMainQueue).start(next: { [weak self] downloadSettings in
            if let strongSelf = self, strongSelf.automaticMediaDownloadSettings != downloadSettings {
                strongSelf.automaticMediaDownloadSettings = downloadSettings
                strongSelf.controllerInteraction?.automaticMediaDownloadSettings = downloadSettings
                if strongSelf.isNodeLoaded {
                    strongSelf.chatDisplayNode.updateAutomaticMediaDownloadSettings(downloadSettings)
                }
            }
        })
        
        self.stickerSettingsDisposable = combineLatest(queue: Queue.mainQueue(), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]), self.disableStickerAnimationsPromise.get()).start(next: { [weak self] sharedData, disableStickerAnimations in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
                stickerSettings = value
            }
            
            let chatStickerSettings = ChatInterfaceStickerSettings(stickerSettings: stickerSettings)
            if let strongSelf = self, strongSelf.stickerSettings != chatStickerSettings || strongSelf.disableStickerAnimationsValue != disableStickerAnimations {
                strongSelf.stickerSettings = chatStickerSettings
                strongSelf.disableStickerAnimationsValue = disableStickerAnimations
                strongSelf.controllerInteraction?.stickerSettings = chatStickerSettings
                if strongSelf.isNodeLoaded {
                    strongSelf.chatDisplayNode.updateStickerSettings(chatStickerSettings, forceStopAnimations: disableStickerAnimations)
                }
            }
        })
        
        var wasInForeground = true
        self.applicationInForegroundDisposable = (context.sharedContext.applicationBindings.applicationInForeground
        |> distinctUntilChanged
        |> deliverOn(Queue.mainQueue())).start(next: { [weak self] value in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if !value {
                    strongSelf.saveInterfaceState()
                    strongSelf.raiseToListen?.applicationResignedActive()
                    
                    strongSelf.stopMediaRecorder()
                } else {
                    if !wasInForeground {
                        strongSelf.chatDisplayNode.recursivelyEnsureDisplaySynchronously(true)
                    }
                }
                wasInForeground = value
            }
        })
        
        if case let .peer(peerId) = chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
            self.applicationInFocusDisposable = (context.sharedContext.applicationBindings.applicationIsActive
            |> distinctUntilChanged
            |> deliverOn(Queue.mainQueue())).start(next: { [weak self] value in
                guard let strongSelf = self, strongSelf.isNodeLoaded else {
                    return
                }
                strongSelf.chatDisplayNode.updateIsBlurred(!value)
            })
        }
        
        self.canReadHistoryDisposable = (combineLatest(context.sharedContext.applicationBindings.applicationInForeground, self.canReadHistory.get()) |> map { a, b in
            return a && b
        } |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self, strongSelf.canReadHistoryValue != value {
                strongSelf.canReadHistoryValue = value
                strongSelf.raiseToListen?.enabled = value
                strongSelf.isReminderActivityEnabled = value
                strongSelf.updateReminderActivity()
            }
        })
        
        self.networkStateDisposable = (context.account.networkState |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self, case .standard(previewing: false) = strongSelf.presentationInterfaceState.mode {
                strongSelf.chatTitleView?.networkState = state
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        let _ = ChatControllerCount.modify { value in
            return value - 1
        }
        self.historyStateDisposable?.dispose()
        self.messageIndexDisposable.dispose()
        self.navigationActionDisposable.dispose()
        self.galleryHiddenMesageAndMediaDisposable.dispose()
        self.temporaryHiddenGalleryMediaDisposable.dispose()
        self.peerDisposable.dispose()
        self.accountPeerDisposable?.dispose()
        self.titleDisposable.dispose()
        self.messageContextDisposable.dispose()
        self.controllerNavigationDisposable.dispose()
        self.sentMessageEventsDisposable.dispose()
        self.failedMessageEventsDisposable.dispose()
        self.messageActionCallbackDisposable.dispose()
        self.messageActionUrlAuthDisposable.dispose()
        self.editMessageDisposable.dispose()
        self.editMessageErrorsDisposable.dispose()
        self.enqueueMediaMessageDisposable.dispose()
        self.resolvePeerByNameDisposable?.dispose()
        self.shareStatusDisposable?.dispose()
        self.clearCacheDisposable?.dispose()
        self.bankCardDisposable?.dispose()
        self.botCallbackAlertMessageDisposable?.dispose()
        self.selectMessagePollOptionDisposables?.dispose()
        for (_, info) in self.contextQueryStates {
            info.1.dispose()
        }
        self.urlPreviewQueryState?.1.dispose()
        self.audioRecorderDisposable?.dispose()
        self.audioRecorderStatusDisposable?.dispose()
        self.videoRecorderDisposable?.dispose()
        self.buttonKeyboardMessageDisposable?.dispose()
        self.cachedDataDisposable?.dispose()
        self.resolveUrlDisposable?.dispose()
        self.chatUnreadCountDisposable?.dispose()
        self.buttonUnreadCountDisposable?.dispose()
        self.chatUnreadMentionCountDisposable?.dispose()
        self.peerInputActivitiesDisposable?.dispose()
        self.interactiveEmojiSyncDisposable.dispose()
        self.recentlyUsedInlineBotsDisposable?.dispose()
        self.unpinMessageDisposable?.dispose()
        self.inputActivityDisposable?.dispose()
        self.recordingActivityDisposable?.dispose()
        self.acquiredRecordingActivityDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.searchDisposable?.dispose()
        self.applicationInForegroundDisposable?.dispose()
        self.applicationInFocusDisposable?.dispose()
        self.canReadHistoryDisposable?.dispose()
        self.networkStateDisposable?.dispose()
        self.chatAdditionalDataDisposable.dispose()
        self.shareStatusDisposable?.dispose()
        self.context.sharedContext.mediaManager.galleryHiddenMediaManager.removeTarget(self)
        self.preloadHistoryPeerIdDisposable.dispose()
        self.preloadNextChatPeerIdDisposable.dispose()
        self.reportIrrelvantGeoDisposable?.dispose()
        self.reminderActivity?.invalidate()
        self.updateSlowmodeStatusDisposable.dispose()
        self.keepPeerInfoScreenDataHotDisposable.dispose()
        self.preloadAvatarDisposable.dispose()
        self.peekTimerDisposable.dispose()
        self.hasActiveGroupCallDisposable?.dispose()
        self.createVoiceChatDisposable.dispose()
        self.checksTooltipDisposable.dispose()
        self.peerSuggestionsDisposable.dispose()
        self.peerSuggestionsDismissDisposable.dispose()
        self.selectAddMemberDisposable.dispose()
        self.addMemberDisposable.dispose()
        self.importStateDisposable?.dispose()
        self.nextChannelToReadDisposable?.dispose()
        self.inviteRequestsDisposable.dispose()
        self.sendAsPeersDisposable?.dispose()
        self.preloadAttachBotIconsDisposables?.dispose()
    }
    
    public func updatePresentationMode(_ mode: ChatControllerPresentationMode) {
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, {
            return $0.updatedMode(mode)
        })
    }
    
    var chatDisplayNode: ChatControllerNode {
        get {
            return super.displayNode as! ChatControllerNode
        }
    }
    
    private func themeAndStringsUpdated() {
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        switch self.presentationInterfaceState.mode {
        case .standard:
            self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
            self.deferScreenEdgeGestures = []
        case .overlay:
            self.statusBar.statusBarStyle = .Hide
            self.deferScreenEdgeGestures = [.top]
        case .inline:
            self.statusBar.statusBarStyle = .Ignore
        }
        self.updateNavigationBarPresentation()
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
            var state = state
            state = state.updatedPresentationReady(self.didSetPresentationData)
            state = state.updatedTheme(self.presentationData.theme)
            state = state.updatedStrings(self.presentationData.strings)
            state = state.updatedDateTimeFormat(self.presentationData.dateTimeFormat)
            state = state.updatedChatWallpaper(self.presentationData.chatWallpaper)
            state = state.updatedBubbleCorners(self.presentationData.chatBubbleCorners)
            return state
        })
        
        self.currentContextController?.updateTheme(presentationData: self.presentationData)
    }
    
    private func updateNavigationBarPresentation() {
        let navigationBarTheme: NavigationBarTheme
            
        if self.hasEmbeddedTitleContent {
            navigationBarTheme = NavigationBarTheme(rootControllerTheme: defaultDarkPresentationTheme, hideBackground: self.context.sharedContext.immediateExperimentalUISettings.playerEmbedding ? true : false, hideBadge: true)
        } else {
            navigationBarTheme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme, hideBackground: self.context.sharedContext.immediateExperimentalUISettings.playerEmbedding ? true : false, hideBadge: false)
        }
        
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.chatTitleView?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings, hasEmbeddedTitleContent: self.hasEmbeddedTitleContent)
    }
    
    private func topPinnedMessageSignal(latest: Bool) -> Signal<ChatPinnedMessage?, NoError> {
        let topPinnedMessage: Signal<ChatPinnedMessage?, NoError>
        switch self.chatLocation {
        case let .peer(peerId):
            struct ReferenceMessage {
                var id: MessageId
                var isScrolled: Bool
            }
            
            let referenceMessage: Signal<ReferenceMessage?, NoError>
            if latest {
                referenceMessage = .single(nil)
            } else {
                referenceMessage = combineLatest(
                    queue: Queue.mainQueue(),
                    self.scrolledToMessageId.get(),
                    self.chatDisplayNode.historyNode.topVisibleMessageRange.get()
                )
                |> map { scrolledToMessageId, topVisibleMessageRange -> ReferenceMessage? in
                    let topVisibleMessage: MessageId?
                    topVisibleMessage = topVisibleMessageRange?.upperBound.id
                    
                    if let scrolledToMessageId = scrolledToMessageId {
                        if let topVisibleMessage = topVisibleMessage {
                            if scrolledToMessageId.allowedReplacementDirection.contains(.up) && topVisibleMessage < scrolledToMessageId.id {
                                return ReferenceMessage(id: topVisibleMessage, isScrolled: false)
                            }
                        }
                        return ReferenceMessage(id: scrolledToMessageId.id, isScrolled: true)
                    } else if let topVisibleMessage = topVisibleMessage {
                        return ReferenceMessage(id: topVisibleMessage, isScrolled: false)
                    } else {
                        return nil
                    }
                }
            }
            
            let context = self.context
            
            func pinnedHistorySignal(anchorMessageId: MessageId?, count: Int) -> Signal<ChatHistoryViewUpdate, NoError> {
                let location: ChatHistoryLocation
                if let anchorMessageId = anchorMessageId {
                    location = .InitialSearch(location: .id(anchorMessageId), count: count, highlight: false)
                } else {
                    location = .Initial(count: count)
                }
                
                return (chatHistoryViewForLocation(ChatHistoryLocationInput(content: location, id: 0), ignoreMessagesInTimestampRange: nil, context: context, chatLocation: .peer(id: peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), scheduled: false, fixedCombinedReadStates: nil, tagMask: MessageTags.pinned, appendMessagesFromTheSameGroup: false, additionalData: [], orderStatistics: .combinedLocation)
                |> castError(Bool.self)
                |> mapToSignal { update -> Signal<ChatHistoryViewUpdate, Bool> in
                    switch update {
                    case let .Loading(_, type):
                        if case .Generic(.FillHole) = type {
                            return .fail(true)
                        }
                    case let .HistoryView(_, type, _, _, _, _, _):
                        if case .Generic(.FillHole) = type {
                            return .fail(true)
                        }
                    }
                    return .single(update)
                })
                |> restartIfError
            }
            
            struct TopMessage {
                var message: Message
                var index: Int
            }
            
            let topMessage = pinnedHistorySignal(anchorMessageId: nil, count: 3)
            |> map { update -> TopMessage? in
                switch update {
                case .Loading:
                    return nil
                case let .HistoryView(viewValue, _, _, _, _, _, _):
                    if let entry = viewValue.entries.last {
                        let index: Int
                        if let location = entry.location {
                            index = location.index
                        } else {
                            index = viewValue.entries.count - 1
                        }
                        
                        return TopMessage(
                            message: entry.message,
                            index: index
                        )
                    } else {
                        return nil
                    }
                }
            }
            
            let loadCount = 100
            
            struct PinnedHistory {
                struct PinnedMessage {
                    var message: Message
                    var index: Int
                }
                
                var messages: [PinnedMessage]
                var totalCount: Int
            }
            
            let adjustedReplyHistory: Signal<PinnedHistory, NoError>
            if latest {
                adjustedReplyHistory = pinnedHistorySignal(anchorMessageId: nil, count: loadCount)
                |> map { view -> PinnedHistory in
                    switch view {
                    case .Loading:
                        return PinnedHistory(messages: [], totalCount: 0)
                    case let .HistoryView(viewValue, _, _, _, _, _, _):
                        var messages: [PinnedHistory.PinnedMessage] = []
                        var totalCount = viewValue.entries.count
                        for i in 0 ..< viewValue.entries.count {
                            let index: Int
                            if !viewValue.holeEarlier && viewValue.earlierId == nil {
                                index = i
                            } else if let location = viewValue.entries[i].location {
                                index = location.index
                                totalCount = location.count
                            } else {
                                index = i
                            }
                            messages.append(PinnedHistory.PinnedMessage(
                                message: viewValue.entries[i].message,
                                index: index
                            ))
                        }
                        return PinnedHistory(messages: messages, totalCount: totalCount)
                    }
                }
            } else {
                adjustedReplyHistory = (Signal<PinnedHistory, NoError> { subscriber in
                    var referenceMessageValue: ReferenceMessage?
                    var view: ChatHistoryViewUpdate?
                    
                    let updateState: () -> Void = {
                        guard let view = view else {
                            return
                        }
                        guard case let .HistoryView(viewValue, _, _, _, _, _, _) = view else {
                            subscriber.putNext(PinnedHistory(messages: [], totalCount: 0))
                            return
                        }
                        
                        var messages: [PinnedHistory.PinnedMessage] = []
                        for i in 0 ..< viewValue.entries.count {
                            messages.append(PinnedHistory.PinnedMessage(
                                message: viewValue.entries[i].message,
                                index: i
                            ))
                        }
                        let result = PinnedHistory(messages: messages, totalCount: messages.count)
                        
                        if let referenceId = referenceMessageValue?.id {
                            if viewValue.entries.count < loadCount {
                                subscriber.putNext(result)
                            } else if referenceId < viewValue.entries[1].message.id {
                                if viewValue.earlierId != nil {
                                    subscriber.putCompletion()
                                } else {
                                    subscriber.putNext(result)
                                }
                            } else if referenceId > viewValue.entries[viewValue.entries.count - 2].message.id {
                                if viewValue.laterId != nil {
                                    subscriber.putCompletion()
                                } else {
                                    subscriber.putNext(result)
                                }
                            } else {
                                subscriber.putNext(result)
                            }
                        } else {
                            if viewValue.isLoading {
                                subscriber.putNext(result)
                            } else  if viewValue.holeLater || viewValue.laterId != nil {
                                subscriber.putCompletion()
                            } else {
                                subscriber.putNext(result)
                            }
                        }
                    }
                    
                    var initializedView = false
                    let viewDisposable = MetaDisposable()
                    
                    let referenceDisposable = (referenceMessage
                    |> deliverOnMainQueue).start(next: { referenceMessage in
                        referenceMessageValue = referenceMessage
                        if !initializedView {
                            initializedView = true
                            //print("reload at \(String(describing: referenceMessage?.id)) disposable \(unsafeBitCast(viewDisposable, to: UInt64.self))")
                            viewDisposable.set((pinnedHistorySignal(anchorMessageId: referenceMessage?.id, count: loadCount)
                            |> deliverOnMainQueue).start(next: { next in
                                view = next
                                updateState()
                            }))
                        }
                        updateState()
                    })
                    
                    return ActionDisposable {
                        //print("dispose \(unsafeBitCast(viewDisposable, to: UInt64.self))")
                        referenceDisposable.dispose()
                        viewDisposable.dispose()
                    }
                }
                |> runOn(.mainQueue()))
                |> restart
            }
            
            topPinnedMessage = combineLatest(queue: .mainQueue(),
                adjustedReplyHistory,
                topMessage,
                referenceMessage
            )
            |> map { pinnedMessages, topMessage, referenceMessage -> ChatPinnedMessage? in
                var message: ChatPinnedMessage?
                
                let topMessageId: MessageId
                if pinnedMessages.messages.isEmpty {
                    return nil
                }
                topMessageId = topMessage?.message.id ?? pinnedMessages.messages[pinnedMessages.messages.count - 1].message.id
                
                if let referenceMessage = referenceMessage, referenceMessage.isScrolled, !pinnedMessages.messages.isEmpty, referenceMessage.id == pinnedMessages.messages[0].message.id, let topMessage = topMessage {
                    var index = topMessage.index
                    for message in pinnedMessages.messages {
                        if message.message.id == topMessage.message.id {
                            index = message.index
                            break
                        }
                    }
                    
                    return ChatPinnedMessage(message: topMessage.message, index: index, totalCount: pinnedMessages.totalCount, topMessageId: topMessageId)
                }
                
                //print("reference: \(String(describing: referenceMessage?.id.id)) entries: \(view.entries.map(\.index.id.id))")
                for i in 0 ..< pinnedMessages.messages.count {
                    let entry = pinnedMessages.messages[i]
                    var matches = false
                    if message == nil {
                        matches = true
                    } else if let referenceMessage = referenceMessage {
                        if referenceMessage.isScrolled {
                            if entry.message.id < referenceMessage.id {
                                matches = true
                            }
                        } else {
                            if entry.message.id <= referenceMessage.id {
                                matches = true
                            }
                        }
                    } else {
                        matches = true
                    }
                    if matches {
                        message = ChatPinnedMessage(message: entry.message, index: entry.index, totalCount: pinnedMessages.totalCount, topMessageId: topMessageId)
                    }
                }

                return message
            }
            |> distinctUntilChanged
        case .replyThread, .feed:
            return .single(nil)
        }
        return topPinnedMessage
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatControllerNode(context: self.context, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, subject: self.subject, controllerInteraction: self.controllerInteraction!, chatPresentationInterfaceState: self.presentationInterfaceState, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings, navigationBar: self.navigationBar, backgroundNode: self.chatBackgroundNode, controller: self)
        
        if let currentItem = self.tempVoicePlaylistCurrentItem {
            self.chatDisplayNode.historyNode.voicePlaylistItemChanged(nil, currentItem)
        }
    
        self.chatDisplayNode.historyNode.didScrollWithOffset = { [weak self] offset, transition, itemNode in
            guard let strongSelf = self else {
                return
            }

            //print("didScrollWithOffset offset: \(offset), itemNode: \(String(describing: itemNode))")
            
            if offset > 0.0 {
                if var scrolledToMessageIdValue = strongSelf.scrolledToMessageIdValue {
                    scrolledToMessageIdValue.allowedReplacementDirection.insert(.up)
                    strongSelf.scrolledToMessageIdValue = scrolledToMessageIdValue
                }
            } else if offset < 0.0 {
                strongSelf.scrolledToMessageIdValue = nil
            }

            if let currentPinchSourceItemNode = strongSelf.currentPinchSourceItemNode {
                if let itemNode = itemNode {
                    if itemNode === currentPinchSourceItemNode {
                        strongSelf.currentPinchController?.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                    }
                } else {
                    strongSelf.currentPinchController?.addRelativeContentOffset(CGPoint(x: 0.0, y: -offset), transition: transition)
                }
            }
            
            strongSelf.chatDisplayNode.messageTransitionNode.addExternalOffset(offset: offset, transition: transition, itemNode: itemNode)
        }
        
        self.chatDisplayNode.historyNode.hasPlentyOfMessagesUpdated = { [weak self] hasPlentyOfMessages in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: false, { $0.updatedHasPlentyOfMessages(hasPlentyOfMessages) })
            }
        }

        self.chatDisplayNode.historyNode.addContentOffset = { [weak self] offset, itemNode in
            guard let strongSelf = self else {
                return
            }
            strongSelf.chatDisplayNode.messageTransitionNode.addContentOffset(offset: offset, itemNode: itemNode)
        }
        
        if case .pinnedMessages = self.presentationInterfaceState.subject {
            self.chatDisplayNode.historyNode.setLoadStateUpdated({ [weak self] state, _ in
                guard let strongSelf = self else {
                    return
                }
                if case .empty = state {
                    strongSelf.dismiss()
                }
            })
        }
        
        self.chatDisplayNode.peerView = self.peerView
        
        let currentAccountPeer = self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> map { peer in
            return FoundPeer(peer: peer, subscribers: nil)
        }
        
        if let peerId = self.chatLocation.peerId, [Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup].contains(peerId.namespace) {
            self.sendAsPeersDisposable = (combineLatest(queue: Queue.mainQueue(), currentAccountPeer, self.context.account.postbox.peerView(id: peerId), self.context.engine.peers.sendAsAvailablePeers(peerId: peerId)))
            .start(next: { [weak self] currentAccountPeer, peerView, peers in
                guard let strongSelf = self else {
                    return
                }
                var allPeers: [FoundPeer]?
                if !peers.isEmpty {
                    if let channel = peerViewMainPeer(peerView) as? TelegramChannel, case .group = channel.info, channel.hasPermission(.canBeAnonymous) {
                        allPeers = peers
                        
                        var hasAnonymousPeer = false
                        for peer in peers {
                            if peer.peer.id == channel.id {
                                hasAnonymousPeer = true
                                break
                            }
                        }
                        if !hasAnonymousPeer {
                            allPeers?.insert(FoundPeer(peer: channel, subscribers: 0), at: 0)
                        }
                    } else {
                        allPeers = peers.filter { $0.peer.id != peerViewMainPeer(peerView)?.id }
                        allPeers?.insert(currentAccountPeer, at: 0)
                    }
                }
                if allPeers?.count == 1 {
                    allPeers = nil
                }
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                    return $0.updatedSendAsPeers(allPeers)
                })
            })
        }
        
        let initialData = self.chatDisplayNode.historyNode.initialData
        |> take(1)
        |> beforeNext { [weak self] combinedInitialData in
            guard let strongSelf = self, let combinedInitialData = combinedInitialData else {
                return
            }

            if let opaqueState = (combinedInitialData.initialData?.storedInterfaceState).flatMap(_internal_decodeStoredChatInterfaceState) {
                let interfaceState = ChatInterfaceState.parse(opaqueState)

                var pinnedMessageId: MessageId?
                var peerIsBlocked: Bool = false
                var callsAvailable: Bool = true
                var callsPrivate: Bool = false
                var activeGroupCallInfo: ChatActiveGroupCallInfo?
                var slowmodeState: ChatSlowmodeState?
                if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                    pinnedMessageId = cachedData.pinnedMessageId
                    if let channel = combinedInitialData.initialData?.peer as? TelegramChannel, channel.isRestrictedBySlowmode, let timeout = cachedData.slowModeTimeout {
                        if let slowmodeUntilTimestamp = calculateSlowmodeActiveUntilTimestamp(account: strongSelf.context.account, untilTimestamp: cachedData.slowModeValidUntilTimestamp) {
                            slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .timestamp(slowmodeUntilTimestamp))
                        }
                    }
                    if let activeCall = cachedData.activeCall {
                        activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                    }
                } else if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                    peerIsBlocked = cachedData.isBlocked
                    callsAvailable = cachedData.voiceCallsAvailable
                    callsPrivate = cachedData.callsPrivate
                    pinnedMessageId = cachedData.pinnedMessageId
                } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                    pinnedMessageId = cachedData.pinnedMessageId
                    if let activeCall = cachedData.activeCall {
                        activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                    }
                } else if let _ = combinedInitialData.cachedData as? CachedSecretChatData {
                }
                
                if case let .replyThread(replyThreadMessageId) = strongSelf.chatLocation {
                    pinnedMessageId = replyThreadMessageId.effectiveTopId
                }
                
                var pinnedMessage: ChatPinnedMessage?
                if let pinnedMessageId = pinnedMessageId {
                    if let cachedDataMessages = combinedInitialData.cachedDataMessages {
                        if let message = cachedDataMessages[pinnedMessageId] {
                            pinnedMessage = ChatPinnedMessage(message: message, index: 0, totalCount: 1, topMessageId: message.id)
                        }
                    }
                }
                
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { updated in
                    var updated = updated
                
                    updated = updated.updatedInterfaceState({ _ in return interfaceState })
                    
                    updated = updated.updatedKeyboardButtonsMessage(combinedInitialData.buttonKeyboardMessage)
                    updated = updated.updatedPinnedMessageId(pinnedMessageId)
                    updated = updated.updatedPinnedMessage(pinnedMessage)
                    updated = updated.updatedPeerIsBlocked(peerIsBlocked)
                    updated = updated.updatedCallsAvailable(callsAvailable)
                    updated = updated.updatedCallsPrivate(callsPrivate)
                    updated = updated.updatedActiveGroupCallInfo(activeGroupCallInfo)
                    updated = updated.updatedTitlePanelContext({ context in
                        if pinnedMessageId != nil {
                            if !context.contains(where: {
                                switch $0 {
                                    case .pinnedMessage:
                                        return true
                                    default:
                                        return false
                                }
                            }) {
                                var updatedContexts = context
                                updatedContexts.append(.pinnedMessage)
                                return updatedContexts.sorted()
                            } else {
                                return context
                            }
                        } else {
                            if let index = context.firstIndex(where: {
                                switch $0 {
                                    case .pinnedMessage:
                                        return true
                                    default:
                                        return false
                                }
                            }) {
                                var updatedContexts = context
                                updatedContexts.remove(at: index)
                                return updatedContexts
                            } else {
                                return context
                            }
                        }
                    })
                    if let editMessage = interfaceState.editMessage, let message = combinedInitialData.initialData?.associatedMessages[editMessage.messageId] {
                        updated = updatedChatEditInterfaceMessageState(state: updated, message: message)
                    }
                    updated = updated.updatedSlowmodeState(slowmodeState)
                    return updated
                })
            }
            if let readStateData = combinedInitialData.readStateData {
                if case let .peer(peerId) = strongSelf.chatLocation, let peerReadStateData = readStateData[peerId], let notificationSettings = peerReadStateData.notificationSettings {
                    
                    let inAppSettings = strongSelf.context.sharedContext.currentInAppNotificationSettings.with { $0 }
                    let (count, _) = renderedTotalUnreadCount(inAppSettings: inAppSettings, totalUnreadState: peerReadStateData.totalState ?? ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:]))
                    
                    var globalRemainingUnreadChatCount = count
                    if !notificationSettings.isRemovedFromTotalUnreadCount(default: false) && peerReadStateData.unreadCount > 0 {
                        if case .messages = inAppSettings.totalUnreadCountDisplayCategory {
                            globalRemainingUnreadChatCount -= peerReadStateData.unreadCount
                        } else {
                            globalRemainingUnreadChatCount -= 1
                        }
                    }
                    if globalRemainingUnreadChatCount > 0 {
                        strongSelf.navigationItem.badge = "\(globalRemainingUnreadChatCount)"
                    } else {
                        strongSelf.navigationItem.badge = ""
                    }
                }
            }
        }
        
        self.buttonKeyboardMessageDisposable = self.chatDisplayNode.historyNode.buttonKeyboardMessage.start(next: { [weak self] message in
            if let strongSelf = self {
                var buttonKeyboardMessageUpdated = false
                if let currentButtonKeyboardMessage = strongSelf.presentationInterfaceState.keyboardButtonsMessage, let message = message {
                    if currentButtonKeyboardMessage.id != message.id || currentButtonKeyboardMessage.stableVersion != message.stableVersion {
                        buttonKeyboardMessageUpdated = true
                    }
                } else if (strongSelf.presentationInterfaceState.keyboardButtonsMessage != nil) != (message != nil) {
                    buttonKeyboardMessageUpdated = true
                }
                if buttonKeyboardMessageUpdated {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedKeyboardButtonsMessage(message) })
                }
            }
        })
        
        let hasPendingMessages: Signal<Bool, NoError>
        let chatLocationPeerId = self.chatLocation.peerId
        
        if let chatLocationPeerId = chatLocationPeerId {
            hasPendingMessages = self.context.account.pendingMessageManager.hasPendingMessages
            |> mapToSignal { peerIds -> Signal<Bool, NoError> in
                let value = peerIds.contains(chatLocationPeerId)
                if value {
                    return .single(true)
                } else {
                    return .single(false)
                    |> delay(0.1, queue: .mainQueue())
                }
            }
            |> distinctUntilChanged
        } else {
            hasPendingMessages = .single(false)
        }
        
        let isTopReplyThreadMessageShown: Signal<Bool, NoError> = self.chatDisplayNode.historyNode.isTopReplyThreadMessageShown.get()
        |> distinctUntilChanged
        
        let topPinnedMessage: Signal<ChatPinnedMessage?, NoError> = self.topPinnedMessageSignal(latest: false)
        
        if let peerId = self.chatLocation.peerId {
            self.themeEmoticonPromise.set(self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ThemeEmoticon(id: peerId)))
        } else {
            self.themeEmoticonPromise.set(.single(nil))
        }
        
        if let peerId = self.chatLocation.peerId {
            self.cachedDataDisposable = combineLatest(queue: .mainQueue(), self.chatDisplayNode.historyNode.cachedPeerDataAndMessages, hasPendingMessages, isTopReplyThreadMessageShown, topPinnedMessage).start(next: { [weak self] cachedDataAndMessages, hasPendingMessages, isTopReplyThreadMessageShown, topPinnedMessage in
                if let strongSelf = self {
                    let (cachedData, messages) = cachedDataAndMessages
                    
                    if cachedData != nil {
                        var themeEmoticon: String? = nil
                        if let cachedData = cachedData as? CachedUserData {
                            themeEmoticon = cachedData.themeEmoticon
                        } else if let cachedData = cachedData as? CachedGroupData {
                            themeEmoticon = cachedData.themeEmoticon
                        } else if let cachedData = cachedData as? CachedChannelData {
                            themeEmoticon = cachedData.themeEmoticon
                        }
                        
                        strongSelf.themeEmoticonPromise.set(.single(themeEmoticon))
                    }
                    
                    var pinnedMessageId: MessageId?
                    var peerIsBlocked: Bool = false
                    var callsAvailable: Bool = false
                    var callsPrivate: Bool = false
                    var slowmodeState: ChatSlowmodeState?
                    var activeGroupCallInfo: ChatActiveGroupCallInfo?
                    var inviteRequestsPending: Int32?
                    if let cachedData = cachedData as? CachedChannelData {
                        pinnedMessageId = cachedData.pinnedMessageId
                        if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isRestrictedBySlowmode, let timeout = cachedData.slowModeTimeout {
                            if hasPendingMessages {
                                slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .pendingMessages)
                            } else if let slowmodeUntilTimestamp = calculateSlowmodeActiveUntilTimestamp(account: strongSelf.context.account, untilTimestamp: cachedData.slowModeValidUntilTimestamp) {
                                slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .timestamp(slowmodeUntilTimestamp))
                            }
                        }
                        if let activeCall = cachedData.activeCall {
                            activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                        }
                        inviteRequestsPending = cachedData.inviteRequestsPending
                    } else if let cachedData = cachedData as? CachedUserData {
                        peerIsBlocked = cachedData.isBlocked
                        callsAvailable = cachedData.voiceCallsAvailable
                        callsPrivate = cachedData.callsPrivate
                        pinnedMessageId = cachedData.pinnedMessageId
                    } else if let cachedData = cachedData as? CachedGroupData {
                        pinnedMessageId = cachedData.pinnedMessageId
                        if let activeCall = cachedData.activeCall {
                            activeGroupCallInfo = ChatActiveGroupCallInfo(activeCall: activeCall)
                        }
                        inviteRequestsPending = cachedData.inviteRequestsPending
                    } else if let _ = cachedData as? CachedSecretChatData {
                    }
                    
                    var pinnedMessage: ChatPinnedMessage?
                    switch strongSelf.chatLocation {
                    case let .replyThread(replyThreadMessage):
                        if isTopReplyThreadMessageShown {
                            pinnedMessageId = nil
                        } else {
                            pinnedMessageId = replyThreadMessage.effectiveTopId
                        }
                        if let pinnedMessageId = pinnedMessageId {
                            if let message = messages?[pinnedMessageId] {
                                pinnedMessage = ChatPinnedMessage(message: message, index: 0, totalCount: 1, topMessageId: message.id)
                            }
                        }
                    case .peer:
                        pinnedMessageId = topPinnedMessage?.message.id
                        pinnedMessage = topPinnedMessage
                    case .feed:
                        pinnedMessageId = nil
                        pinnedMessage = nil
                    }
                    
                    var pinnedMessageUpdated = false
                    if let current = strongSelf.presentationInterfaceState.pinnedMessage, let updated = pinnedMessage {
                        if current != updated {
                            pinnedMessageUpdated = true
                        }
                    } else if (strongSelf.presentationInterfaceState.pinnedMessage != nil) != (pinnedMessage != nil) {
                        pinnedMessageUpdated = true
                    }
                    
                    let callsDataUpdated = strongSelf.presentationInterfaceState.callsAvailable != callsAvailable || strongSelf.presentationInterfaceState.callsPrivate != callsPrivate
                
                    var canManageInvitations = false
                    if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.flags.contains(.isCreator) || (channel.adminRights?.rights.contains(.canInviteUsers) == true) {
                        canManageInvitations = true
                    } else if let group = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                        if case .creator = group.role {
                            canManageInvitations = true
                        } else if case let .admin(rights, _) = group.role, rights.rights.contains(.canInviteUsers) {
                            canManageInvitations = true
                        }
                    }
                    
                    if canManageInvitations, let inviteRequestsPending = inviteRequestsPending, inviteRequestsPending >= 0 {
                        if strongSelf.inviteRequestsContext == nil {
                            let inviteRequestsContext = strongSelf.context.engine.peers.peerInvitationImporters(peerId: peerId, subject: .requests(query: nil))
                            strongSelf.inviteRequestsContext = inviteRequestsContext
                                                    
                            strongSelf.inviteRequestsDisposable.set((combineLatest(queue: Queue.mainQueue(), inviteRequestsContext.state, ApplicationSpecificNotice.dismissedInvitationRequests(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peerId))).start(next: { [weak self] requestsState, dismissedInvitationRequests in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, { state in
                                    return state
                                    .updatedTitlePanelContext({ context in
                                        let peers: [EnginePeer] = Array(requestsState.importers.compactMap({ $0.peer.peer.flatMap({ EnginePeer($0) }) }).prefix(3))
                                        
                                        var peersDismissed = false
                                        if let dismissedInvitationRequests = dismissedInvitationRequests, Set(peers.map({ $0.id.toInt64() })) == Set(dismissedInvitationRequests) {
                                            peersDismissed = true
                                        }
                                        
                                        if requestsState.count > 0 && !peersDismissed {
                                            if !context.contains(where: {
                                                switch $0 {
                                                    case .inviteRequests(peers, requestsState.count):
                                                        return true
                                                    default:
                                                        return false
                                                }
                                            }) {
                                                var updatedContexts = context.filter { c in
                                                    if case .inviteRequests = c {
                                                        return false
                                                    } else {
                                                        return true
                                                    }
                                                }
                                                updatedContexts.append(.inviteRequests(peers, requestsState.count))
                                                return updatedContexts.sorted()
                                            } else {
                                                return context
                                            }
                                        } else {
                                            if let index = context.firstIndex(where: {
                                                switch $0 {
                                                    case .inviteRequests:
                                                        return true
                                                    default:
                                                        return false
                                                }
                                            }) {
                                                var updatedContexts = context
                                                updatedContexts.remove(at: index)
                                                return updatedContexts
                                            } else {
                                                return context
                                            }
                                        }
                                    })
                                    .updatedSlowmodeState(slowmodeState)
                                })
                            }))
                        } else if let inviteRequestsContext = strongSelf.inviteRequestsContext {
                            let _ = (inviteRequestsContext.state
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak inviteRequestsContext] state in
                                if state.count != inviteRequestsPending {
                                    inviteRequestsContext?.loadMore()
                                }
                            })
                        }
                    }
                
                    if strongSelf.presentationInterfaceState.pinnedMessageId != pinnedMessageId || strongSelf.presentationInterfaceState.pinnedMessage != pinnedMessage || strongSelf.presentationInterfaceState.peerIsBlocked != peerIsBlocked || pinnedMessageUpdated || callsDataUpdated || strongSelf.presentationInterfaceState.slowmodeState != slowmodeState || strongSelf.presentationInterfaceState.activeGroupCallInfo != activeGroupCallInfo {
                        strongSelf.updateChatPresentationInterfaceState(animated: strongSelf.willAppear, interactive: strongSelf.willAppear, { state in
                            return state
                            .updatedPinnedMessageId(pinnedMessageId)
                            .updatedActiveGroupCallInfo(activeGroupCallInfo)
                            .updatedPinnedMessage(pinnedMessage)
                            .updatedPeerIsBlocked(peerIsBlocked)
                            .updatedCallsAvailable(callsAvailable)
                            .updatedCallsPrivate(callsPrivate)
                            .updatedTitlePanelContext({ context in
                                if pinnedMessageId != nil {
                                    if !context.contains(where: {
                                        switch $0 {
                                            case .pinnedMessage:
                                                return true
                                            default:
                                                return false
                                        }
                                    }) {
                                        var updatedContexts = context
                                        updatedContexts.append(.pinnedMessage)
                                        return updatedContexts.sorted()
                                    } else {
                                        return context
                                    }
                                } else {
                                    if let index = context.firstIndex(where: {
                                        switch $0 {
                                            case .pinnedMessage:
                                                return true
                                            default:
                                                return false
                                        }
                                    }) {
                                        var updatedContexts = context
                                        updatedContexts.remove(at: index)
                                        return updatedContexts
                                    } else {
                                        return context
                                    }
                                }
                            })
                            .updatedSlowmodeState(slowmodeState)
                        })
                    }
                    
                    if !strongSelf.didSetCachedDataReady {
                        strongSelf.didSetCachedDataReady = true
                        strongSelf.cachedDataReady.set(.single(true))
                    }
                }
            })
        } else {
            if !self.didSetCachedDataReady {
                self.didSetCachedDataReady = true
                self.cachedDataReady.set(.single(true))
            }
        }
        
        self.historyStateDisposable = self.chatDisplayNode.historyNode.historyState.get().start(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: strongSelf.isViewLoaded && strongSelf.view.window != nil, {
                    $0.updatedChatHistoryState(state)
                })
            }
        })
        
        let effectiveCachedDataReady: Signal<Bool, NoError>
        if case .replyThread = self.chatLocation {
            effectiveCachedDataReady = self.cachedDataReady.get()
        } else {
            //effectiveCachedDataReady = .single(true)
            effectiveCachedDataReady = self.cachedDataReady.get()
        }
        self.ready.set(combineLatest(queue: .mainQueue(),
            self.chatDisplayNode.historyNode.historyState.get(),
            self._chatLocationInfoReady.get(),
            effectiveCachedDataReady,
            initialData,
            self.wallpaperReady.get(),
            self.presentationReady.get()
        )
        |> map { _, chatLocationInfoReady, cachedDataReady, _, wallpaperReady, presentationReady in
            return chatLocationInfoReady && cachedDataReady && wallpaperReady && presentationReady
        }
        |> distinctUntilChanged)
        
        if self.context.sharedContext.immediateExperimentalUISettings.crashOnLongQueries {
            let _ = (self.ready.get()
            |> filter({ $0 })
            |> take(1)
            |> timeout(0.8, queue: .concurrentDefaultQueue(), alternate: Signal { _ in
                preconditionFailure()
            })).start()
        }
        
        self.chatDisplayNode.historyNode.contentPositionChanged = { [weak self] offset in
            guard let strongSelf = self else { return }

            var minOffsetForNavigation: CGFloat = 40.0
            strongSelf.chatDisplayNode.historyNode.enumerateItemNodes { itemNode in
                if let itemNode = itemNode as? ChatMessageBubbleItemNode {
                    if let message = itemNode.item?.content.firstMessage, message.adAttribute != nil {
                        minOffsetForNavigation += itemNode.bounds.height

                        switch offset {
                        case let .known(offset):
                            if offset <= 50.0 {
                                strongSelf.chatDisplayNode.historyNode.adSeenProcessingManager.add([message.id])
                            }
                        default:
                            break
                        }
                    }
                }
                return false
            }
            
            let offsetAlpha: CGFloat
            let plainInputSeparatorAlpha: CGFloat
            switch offset {
                case let .known(offset):
                    if offset < minOffsetForNavigation {
                        offsetAlpha = 0.0
                    } else {
                        offsetAlpha = 1.0
                    }
                    if offset < 4.0 {
                        plainInputSeparatorAlpha = 0.0
                    } else {
                        plainInputSeparatorAlpha = 1.0
                    }
                case .unknown:
                    offsetAlpha = 1.0
                    plainInputSeparatorAlpha = 1.0
                case .none:
                    offsetAlpha = 0.0
                    plainInputSeparatorAlpha = 0.0
            }
            
            strongSelf.shouldDisplayDownButton = !offsetAlpha.isZero
            strongSelf.updateDownButtonVisibility()
            strongSelf.chatDisplayNode.updatePlainInputSeparatorAlpha(plainInputSeparatorAlpha, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
        
        self.chatDisplayNode.historyNode.scrolledToIndex = { [weak self] toIndex, initial in
            if let strongSelf = self, case let .message(index) = toIndex {
                if case let .message(messageSubject, _, _) = strongSelf.subject, initial, case let .id(messageId) = messageSubject, messageId != index.id {
                    if messageId.peerId == index.id.peerId {
                        strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(title: nil, text: strongSelf.presentationData.strings.Conversation_MessageDoesntExist), elevatedLayout: false, action: { _ in return true }), in: .current)
                    }
                } else if let controllerInteraction = strongSelf.controllerInteraction {
                    if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(index.id) {
                        let highlightedState = ChatInterfaceHighlightedState(messageStableId: message.stableId)
                        controllerInteraction.highlightedState = highlightedState
                        strongSelf.updateItemNodesHighlightedStates(animated: false)
                        strongSelf.scrolledToMessageIdValue = ScrolledToMessageId(id: index.id, allowedReplacementDirection: [])
                        
                        strongSelf.messageContextDisposable.set((Signal<Void, NoError>.complete() |> delay(0.7, queue: Queue.mainQueue())).start(completed: {
                            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                if controllerInteraction.highlightedState == highlightedState {
                                    controllerInteraction.highlightedState = nil
                                    strongSelf.updateItemNodesHighlightedStates(animated: true)
                                }
                            }
                        }))
                        
                        if let (messageId, maybeTimecode) = strongSelf.scheduledScrollToMessageId {
                            strongSelf.scheduledScrollToMessageId = nil
                            if let timecode = maybeTimecode, message.id == messageId {
                                Queue.mainQueue().after(0.2) {
                                    let _ = strongSelf.controllerInteraction?.openMessage(message, .timecode(timecode))
                                }
                            }
                        } else if case let .message(_, _, maybeTimecode) = strongSelf.subject, let timecode = maybeTimecode, initial {
                            Queue.mainQueue().after(0.2) {
                                let _ = strongSelf.controllerInteraction?.openMessage(message, .timecode(timecode))
                            }
                        }
                    }
                }
            }
        }
        
        self.chatDisplayNode.historyNode.scrolledToSomeIndex = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.scrolledToMessageIdValue = nil
        }
        
        self.chatDisplayNode.historyNode.maxVisibleMessageIndexUpdated = { [weak self] index in
            if let strongSelf = self, !strongSelf.historyNavigationStack.isEmpty {
                strongSelf.historyNavigationStack.filterOutIndicesLessThan(index)
            }
        }
        
        self.chatDisplayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        
        self.chatDisplayNode.setupSendActionOnViewUpdate = { [weak self] f, messageCorrelationId in
            //print("setup layoutActionOnViewTransition")

            self?.chatDisplayNode.historyNode.layoutActionOnViewTransition = ({ [weak self] transition in
                f()
                if let strongSelf = self, let validLayout = strongSelf.validLayout {
                    var mappedTransition: (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?)?
                    
                    let isScheduledMessages: Bool
                    if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                        isScheduledMessages = true
                    } else {
                        isScheduledMessages = false
                    }
                    let duration: Double = strongSelf.chatDisplayNode.messageTransitionNode.hasScheduledTransitions ? ChatMessageTransitionNode.animationDuration : 0.18
                    let curve: ContainedViewLayoutTransitionCurve = strongSelf.chatDisplayNode.messageTransitionNode.hasScheduledTransitions ? ChatMessageTransitionNode.verticalAnimationCurve : .easeInOut
                    let controlPoints: (Float, Float, Float, Float) = strongSelf.chatDisplayNode.messageTransitionNode.hasScheduledTransitions ? ChatMessageTransitionNode.verticalAnimationControlPoints : (0.5, 0.33, 0.0, 0.0)

                    let shouldUseFastMessageSendAnimation = strongSelf.chatDisplayNode.shouldUseFastMessageSendAnimation
                    
                    strongSelf.chatDisplayNode.containerLayoutUpdated(validLayout, navigationBarHeight: strongSelf.navigationLayout(layout: validLayout).navigationFrame.maxY, transition: .animated(duration: duration, curve: curve), listViewTransaction: { updateSizeAndInsets, _, _, _ in

                        var options = transition.options
                        let _ = options.insert(.Synchronous)
                        let _ = options.insert(.LowLatency)
                        let _ = options.insert(.PreferSynchronousResourceLoading)

                        var deleteItems = transition.deleteItems
                        var insertItems: [ListViewInsertItem] = []
                        var stationaryItemRange: (Int, Int)?
                        var scrollToItem: ListViewScrollToItem?

                        if shouldUseFastMessageSendAnimation {
                            options.remove(.AnimateInsertion)
                            options.insert(.RequestItemInsertionAnimations)

                            deleteItems = transition.deleteItems.map({ item in
                                return ListViewDeleteItem(index: item.index, directionHint: nil)
                            })

                            var maxInsertedItem: Int?
                            var insertedIndex: Int?
                            for i in 0 ..< transition.insertItems.count {
                                let item = transition.insertItems[i]
                                if item.directionHint == .Down && (maxInsertedItem == nil || maxInsertedItem! < item.index) {
                                    maxInsertedItem = item.index
                                }
                                insertedIndex = item.index
                                insertItems.append(ListViewInsertItem(index: item.index, previousIndex: item.previousIndex, item: item.item, directionHint: item.directionHint == .Down ? .Up : nil))
                            }

                            if isScheduledMessages, let insertedIndex = insertedIndex {
                                scrollToItem = ListViewScrollToItem(index: insertedIndex, position: .visible, animated: true, curve: .Custom(duration: duration, controlPoints.0, controlPoints.1, controlPoints.2, controlPoints.3), directionHint: .Down)
                            } else if transition.historyView.originalView.laterId == nil {
                                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Custom(duration: duration, controlPoints.0, controlPoints.1, controlPoints.2, controlPoints.3), directionHint: .Up)
                            }

                            if let maxInsertedItem = maxInsertedItem {
                                stationaryItemRange = (maxInsertedItem + 1, Int.max)
                            }
                        }
                        
                        mappedTransition = (ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: deleteItems, insertItems: insertItems, updateItems: transition.updateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex, scrolledToSomeIndex: transition.scrolledToSomeIndex, peerType: transition.peerType, networkType: transition.networkType, animateIn: false, reason: transition.reason, flashIndicators: transition.flashIndicators), updateSizeAndInsets)
                    }, updateExtraNavigationBarBackgroundHeight: { value, _ in
                        strongSelf.additionalNavigationBarBackgroundHeight = value
                    })
                    
                    if let mappedTransition = mappedTransition {
                        return mappedTransition
                    }
                }
                return (transition, nil)
            }, messageCorrelationId)
        }
        
        self.chatDisplayNode.sendMessages = { [weak self] messages, silentPosting, scheduleTime, isAnyMessageTextPartitioned in
            if let strongSelf = self, let peerId = strongSelf.chatLocation.peerId {
                var correlationIds: [Int64] = []
                for message in messages {
                    switch message {
                    case let .message(_, _, _, _, _, correlationId):
                        if let correlationId = correlationId {
                            correlationIds.append(correlationId)
                        }
                    default:
                        break
                    }
                }
                strongSelf.commitPurposefulAction()
                
                if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isRestrictedBySlowmode {
                    let forwardCount = messages.reduce(0, { count, message -> Int in
                        if case .forward = message {
                            return count + 1
                        } else {
                            return count
                        }
                    })
                    
                    var errorText: String?
                    if forwardCount > 1 {
                        errorText = strongSelf.presentationData.strings.Chat_AttachmentMultipleForwardDisabled
                    } else if isAnyMessageTextPartitioned {
                        errorText = strongSelf.presentationData.strings.Chat_MultipleTextMessagesDisabled
                    }
                    
                    if let errorText = errorText {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        return
                    }
                }
                
                let transformedMessages: [EnqueueMessage]
                if let silentPosting = silentPosting {
                    transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: silentPosting)
                } else if let scheduleTime = scheduleTime {
                    transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: scheduleTime)
                } else {
                    transformedMessages = strongSelf.transformEnqueueMessages(messages)
                }
                
                var forwardedMessages: [[EnqueueMessage]] = []
                var forwardSourcePeerIds = Set<PeerId>()
                for message in transformedMessages {
                    if case let .forward(source, _, _, _) = message {
                        forwardSourcePeerIds.insert(source.peerId)
                        
                        var added = false
                        if var last = forwardedMessages.last {
                            if let currentMessage = last.first, case let .forward(currentSource, _, _, _) = currentMessage, currentSource.peerId == source.peerId {
                                last.append(message)
                                added = true
                            }
                        }
                        if !added {
                            forwardedMessages.append([message])
                        }
                    }
                }
                
                let signal: Signal<[MessageId?], NoError>
                if forwardSourcePeerIds.count > 1 {
                    var signals: [Signal<[MessageId?], NoError>] = []
                    for messagesGroup in forwardedMessages {
                        signals.append(enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messagesGroup))
                    }
                    signal = combineLatest(signals)
                    |> map { results in
                        var ids: [MessageId?] = []
                        for result in results {
                            ids.append(contentsOf: result)
                        }
                        return ids
                    }
                } else {
                    signal = enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: transformedMessages)
                }
                
                let _ = (signal
                |> deliverOnMainQueue).start(next: { messageIds in
                    if let strongSelf = self {
                        if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                        } else {
                            strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                        }
                    }
                })
                
                donateSendMessageIntent(account: strongSelf.context.account, sharedContext: strongSelf.context.sharedContext, intentContext: .chat, peerIds: [peerId])
                
                strongSelf.updateChatPresentationInterfaceState(interactive: true, { $0.updatedShowCommands(false) })
            }
        }
        
        self.chatDisplayNode.requestUpdateChatInterfaceState = { [weak self] transition, saveInterfaceState, f in
            self?.updateChatPresentationInterfaceState(transition: transition, interactive: true, saveInterfaceState: saveInterfaceState, { $0.updatedInterfaceState(f) })
        }
        
        self.chatDisplayNode.requestUpdateInterfaceState = { [weak self] transition, interactive, f in
            self?.updateChatPresentationInterfaceState(transition: transition, interactive: interactive, f)
        }
        
        self.chatDisplayNode.displayAttachmentMenu = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interfaceInteraction?.updateShowWebView { _ in
                return false
            }
            if strongSelf.presentationInterfaceState.interfaceState.editMessage == nil, let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                if let rect = strongSelf.chatDisplayNode.frameForAttachmentButton() {
                    strongSelf.interfaceInteraction?.displaySlowmodeTooltip(strongSelf.chatDisplayNode, rect)
                }
                return
            }
            if let messageId = strongSelf.presentationInterfaceState.interfaceState.editMessage?.messageId {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                |> deliverOnMainQueue).start(next: { message in
                    guard let strongSelf = self, let editMessageState = strongSelf.presentationInterfaceState.editMessageState, case let .media(options) = editMessageState.content else {
                        return
                    }
                    var originalMediaReference: AnyMediaReference?
                    if let message = message {
                        for media in message.media {
                            if let image = media as? TelegramMediaImage {
                                originalMediaReference = .message(message: MessageReference(message._asMessage()), media: image)
                            } else if let file = media as? TelegramMediaFile {
                                if file.isVideo || file.isAnimated {
                                    originalMediaReference = .message(message: MessageReference(message._asMessage()), media: file)
                                }
                            }
                        }
                    }
                    strongSelf.oldPresentAttachmentMenu(editMediaOptions: options, editMediaReference: originalMediaReference)
                })
            } else {
                strongSelf.presentAttachmentMenu(editMediaOptions: nil, editMediaReference: nil)
            }
        }
        self.chatDisplayNode.paste = { [weak self] data in
            switch data {
                case let .images(images):
                   self?.displayPasteMenu(images)
                case let .video(data):
                    self?.enqueueVideoData(data)
                case let .gif(data):
                    self?.enqueueGifData(data)
                case let .sticker(image, isMemoji):
                    self?.enqueueStickerImage(image, isMemoji: isMemoji)
            }
        }
        self.chatDisplayNode.updateTypingActivity = { [weak self] value in
            if let strongSelf = self {
                if value {
                    strongSelf.typingActivityPromise.set(Signal<Bool, NoError>.single(true)
                    |> then(
                        Signal<Bool, NoError>.single(false)
                        |> delay(4.0, queue: Queue.mainQueue())
                    ))
                } else {
                    strongSelf.typingActivityPromise.set(.single(false))
                }
            }
        }
        
        self.chatDisplayNode.dismissUrlPreview = { [weak self] in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.interfaceState.editMessage {
                    if let (link, _) = strongSelf.presentationInterfaceState.editingUrlPreview {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            $0.updatedInterfaceState {
                                $0.withUpdatedEditMessage($0.editMessage.flatMap { $0.withUpdatedDisableUrlPreview(link) })
                            }
                        })
                    }
                } else {
                    if let (link, _) = strongSelf.presentationInterfaceState.urlPreview {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            $0.updatedInterfaceState {
                                $0.withUpdatedComposeDisableUrlPreview(link)
                            }
                        })
                    }
                }
            }
        }
        
        self.chatDisplayNode.navigateButtons.downPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if let messageId = strongSelf.historyNavigationStack.removeLast() {
                    strongSelf.navigateToMessage(from: nil, to: .id(messageId.id, nil), rememberInStack: false)
                } else {
                    if case .known = strongSelf.chatDisplayNode.historyNode.visibleContentOffset() {
                        strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    } else if case .peer = strongSelf.chatLocation {
                        strongSelf.scrollToEndOfHistory()
                     } else if case .replyThread = strongSelf.chatLocation {
                        strongSelf.scrollToEndOfHistory()
                    } else {
                        strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }
                }
            }
        }
        
        self.chatDisplayNode.navigateButtons.mentionsPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded, case let .peer(peerId) = strongSelf.chatLocation {
                let signal = strongSelf.context.engine.messages.earliestUnseenPersonalMentionMessage(peerId: peerId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { result in
                    if let strongSelf = self {
                        switch result {
                            case let .result(messageId):
                                if let messageId = messageId {
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId, nil))
                                }
                            case .loading:
                                break
                        }
                    }
                }))
            }
        }
        
        self.chatDisplayNode.navigateButtons.mentionsButton.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                gesture.cancel()
                return
            }
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            var menuItems: [ContextMenuItem] = []
            menuItems.append(.action(ContextMenuActionItem(
                id: nil,
                text: strongSelf.presentationData.strings.WebSearch_RecentSectionClear,
                textColor: .primary,
                textLayout: .singleLine,
                icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Read"), color: theme.contextMenu.primaryColor)
                },
                action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                        return
                    }
                    let _ = clearPeerUnseenPersonalMessagesInteractively(account: strongSelf.context.account, peerId: peerId).start()
                }
            )))
            let items = ContextController.Items(content: .list(menuItems))
            
            let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageNavigationButtonContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, contentNode: strongSelf.chatDisplayNode.navigateButtons.mentionsButton.containerNode)), items: .single(items), recognizer: nil, gesture: gesture)
            
            strongSelf.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss()
                }
                return true
            })
            strongSelf.window?.presentInGlobalOverlay(controller)
        }
        
        self.chatDisplayNode.navigateButtons.reactionsPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded, case let .peer(peerId) = strongSelf.chatLocation {
                let signal = strongSelf.context.engine.messages.earliestUnseenPersonalReactionMessage(peerId: peerId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { result in
                    if let strongSelf = self {
                        switch result {
                            case let .result(messageId):
                                if let messageId = messageId {
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId, nil), scrollPosition: .center(.top), completion: {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                            guard let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item else {
                                                return
                                            }
                                            guard item.message.id == messageId else {
                                                return
                                            }
                                            var maybeUpdatedReaction: (String, Bool, EnginePeer?)?
                                            if let attribute = item.message.reactionsAttribute {
                                                for recentPeer in attribute.recentPeers {
                                                    if recentPeer.isUnseen {
                                                        maybeUpdatedReaction = (recentPeer.value, recentPeer.isLarge, item.message.peers[recentPeer.peerId].flatMap(EnginePeer.init))
                                                        break
                                                    }
                                                }
                                            }
                                            
                                            guard let (updatedReaction, updatedReactionIsLarge, updatedReactionPeer) = maybeUpdatedReaction else {
                                                return
                                            }
                                            
                                            var avatarPeers: [EnginePeer] = []
                                            if item.message.id.peerId.namespace != Namespaces.Peer.CloudUser, let updatedReactionPeer = updatedReactionPeer {
                                                avatarPeers.append(updatedReactionPeer)
                                            }
                                            
                                            guard let availableReactions = item.associatedData.availableReactions, let targetView = itemNode.targetReactionView(value: updatedReaction) else {
                                                return
                                            }
                                            for reaction in availableReactions.reactions {
                                                guard let centerAnimation = reaction.centerAnimation else {
                                                    continue
                                                }
                                                guard let aroundAnimation = reaction.aroundAnimation else {
                                                    continue
                                                }
                                                
                                                if reaction.value == updatedReaction {
                                                    let standaloneReactionAnimation = StandaloneReactionAnimation()
                                                    
                                                    strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                                    
                                                    strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                                    standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                                    standaloneReactionAnimation.animateReactionSelection(
                                                        context: strongSelf.context,
                                                        theme: strongSelf.presentationData.theme,
                                                        reaction: ReactionItem(
                                                            reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                                            appearAnimation: reaction.appearAnimation,
                                                            stillAnimation: reaction.selectAnimation,
                                                            listAnimation: centerAnimation,
                                                            largeListAnimation: reaction.activateAnimation,
                                                            applicationAnimation: aroundAnimation,
                                                            largeApplicationAnimation: reaction.effectAnimation
                                                        ),
                                                        avatarPeers: avatarPeers,
                                                        playHaptic: true,
                                                        isLarge: updatedReactionIsLarge,
                                                        targetView: targetView,
                                                        addStandaloneReactionAnimation: { standaloneReactionAnimation in
                                                            guard let strongSelf = self else {
                                                                return
                                                            }
                                                            strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                                            standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                                            strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                                        },
                                                        completion: { [weak standaloneReactionAnimation] in
                                                            standaloneReactionAnimation?.removeFromSupernode()
                                                        }
                                                    )
                                                    
                                                    break
                                                }
                                            }
                                        }
                                    })
                                }
                            case .loading:
                                break
                        }
                    }
                }))
            }
        }
        
        self.chatDisplayNode.navigateButtons.reactionsButton.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                gesture.cancel()
                return
            }
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            var menuItems: [ContextMenuItem] = []
            menuItems.append(.action(ContextMenuActionItem(
                id: nil,
                text: strongSelf.presentationData.strings.Conversation_ReadAllReactions,
                textColor: .primary,
                textLayout: .singleLine,
                icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Read"), color: theme.contextMenu.primaryColor)
                },
                action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                        return
                    }
                    let _ = clearPeerUnseenReactionsInteractively(account: strongSelf.context.account, peerId: peerId).start()
                }
            )))
            let items = ContextController.Items(content: .list(menuItems))
            
            let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageNavigationButtonContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, contentNode: strongSelf.chatDisplayNode.navigateButtons.reactionsButton.containerNode)), items: .single(items), recognizer: nil, gesture: gesture)
            
            strongSelf.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss()
                }
                return true
            })
            strongSelf.window?.presentInGlobalOverlay(controller)
        }
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { [weak self] messageId, completion in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            if let messageId = messageId {
                if canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                    let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                        if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageId(message.id) }).updatedSearch(nil).updatedShowCommands(false) }, completion: completion)
                            strongSelf.updateItemNodesSearchTextHighlightStates()
                            strongSelf.chatDisplayNode.ensureInputViewFocused()
                        } else {
                            completion(.immediate)
                        }
                    }, alertAction: {
                        completion(.immediate)
                    }, delay: true)
                } else {
                    completion(.immediate)
                }
            } else {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageId(nil) }) }, completion: completion)
            }
        }, setupEditMessage: { [weak self] messageId, completion in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                guard let messageId = messageId else {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        var state = state
                        state = state.updatedInterfaceState {
                            $0.withUpdatedEditMessage(nil)
                        }
                        state = state.updatedEditMessageState(nil)
                        return state
                    }, completion: completion)
                    
                    return
                }
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            var updated = state.updatedInterfaceState {
                                var entities: [MessageTextEntity] = []
                                for attribute in message.attributes {
                                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                                        entities = attribute.entities
                                        break
                                    }
                                }
                                var inputTextMaxLength: Int32 = 4096
                                var webpageUrl: String?
                                for media in message.media {
                                    if media is TelegramMediaImage || media is TelegramMediaFile {
                                        inputTextMaxLength = strongSelf.context.currentLimitsConfiguration.with { $0 }.maxMediaCaptionLength
                                    } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                        webpageUrl = content.url
                                    }
                                }
                                let inputText = chatInputStateStringWithAppliedEntities(message.text, entities: entities)
                                var disableUrlPreview: String?
                                if let detectedWebpageUrl = detectUrl(inputText), webpageUrl == nil {
                                    disableUrlPreview = detectedWebpageUrl
                                }
                                return $0.withUpdatedEditMessage(ChatEditMessageState(messageId: messageId, inputState: ChatTextInputState(inputText: inputText), disableUrlPreview: disableUrlPreview, inputTextMaxLength: inputTextMaxLength))
                            }
                            
                            updated = updatedChatEditInterfaceMessageState(state: updated, message: message)
                            updated = updated.updatedInputMode({ _ in
                                return .text
                            })
                            updated = updated.updatedShowCommands(false)
                            
                            return updated
                        }, completion: completion)
                    }
                }, alertAction: {
                    completion(.immediate)
                }, delay: true)
            }
        }, beginMessageSelection: { [weak self] messageIds, completion in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withUpdatedSelectedMessages(messageIds) }.updatedShowCommands(false) }, completion: completion)
                    
                    if let selectionState = strongSelf.presentationInterfaceState.interfaceState.selectionState {
                        let count = selectionState.selectedIds.count
                        let text = strongSelf.presentationData.strings.VoiceOver_Chat_MessagesSelected(Int32(count))
                        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: text)
                    }
                }, alertAction: {
                    completion(.immediate)
                }, delay: true)
            } else {
                completion(.immediate)
            }
        }, deleteSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                    strongSelf.messageContextDisposable.set((strongSelf.context.sharedContext.chatAvailableMessageActions(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: messageIds)
                    |> deliverOnMainQueue).start(next: { actions in
                        if let strongSelf = self, !actions.options.isEmpty {
                            if let banAuthor = actions.banAuthor {
                                strongSelf.presentBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, author: banAuthor, messageIds: messageIds, options: actions.options)
                            } else {
                                if actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty {
                                    strongSelf.presentClearCacheSuggestion()
                                } else {
                                    strongSelf.presentDeleteMessageOptions(messageIds: messageIds, options: actions.options, contextController: nil, completion: { _ in })
                                }
                            }
                        }
                    }))
                }
            }
        }, reportSelectedMessages: { [weak self] in
            if let strongSelf = self, let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                if let reportReason = strongSelf.presentationInterfaceState.reportReason {
                    let presentationData = strongSelf.presentationData
                    let controller = ActionSheetController(presentationData: presentationData, allowInputInset: true)
                    let dismissAction: () -> Void = { [weak self, weak controller] in
                        self?.view.window?.endEditing(true)
                        controller?.dismissAnimated()
                    }
                    var message = ""
                    var items: [ActionSheetItem] = []
                    items.append(ReportPeerHeaderActionSheetItem(context: strongSelf.context, text: presentationData.strings.Report_AdditionalDetailsText))
                    items.append(ReportPeerDetailsActionSheetItem(context: strongSelf.context, placeholderText: presentationData.strings.Report_AdditionalDetailsPlaceholder, textUpdated: { text in
                        message = text
                    }))
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Report_Report, color: .accent, font: .bold, enabled: true, action: {
                        dismissAction()
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } }, completion: { _ in
                            let _ = (strongSelf.context.engine.peers.reportPeerMessages(messageIds: Array(messageIds), reason: reportReason, message: message)
                            |> deliverOnMainQueue).start(completed: {
                                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .emoji(name: "PoliceCar", text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                            })
                        })
                    }))
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    strongSelf.present(controller, in: .window(.root))
                } else {
                    strongSelf.present(peerReportOptionsController(context: strongSelf.context, subject: .messages(Array(messageIds).sorted()), passthrough: false, present: { c, a in
                        self?.present(c, in: .window(.root), with: a)
                    }, push: { c in
                        self?.push(c)
                    }, completion: { _, done in
                        if done {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                        }
                    }), in: .window(.root))
                }
            }
        }, reportMessages: { [weak self] messages, contextController in
            if let strongSelf = self, !messages.isEmpty {
                let options: [PeerReportOption] = [.spam, .violence, .pornography, .childAbuse, .copyright, .illegalDrugs, .personalDetails, .other]
                presentPeerReportOptions(context: strongSelf.context, parent: strongSelf, contextController: contextController, subject: .messages(messages.map({ $0.id }).sorted()), options: options, completion: { _, _ in })
            }
        }, blockMessageAuthor: { [weak self] message, contextController in
            contextController?.dismiss(completion: {
                guard let strongSelf = self else {
                    return
                }
                
                let author = message.forwardInfo?.author
                
                guard let peer = author else {
                    return
                }
                
                let presentationData = strongSelf.presentationData
                let controller = ActionSheetController(presentationData: presentationData)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                var reportSpam = true
                var items: [ActionSheetItem] = []
                items.append(ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(EnginePeer(peer).compactDisplayTitle).string))
                items.append(contentsOf: [
                    ActionSheetCheckboxItem(title: presentationData.strings.Conversation_Moderate_Report, label: "", value: reportSpam, action: { [weak controller] checkValue in
                        reportSpam = checkValue
                        controller?.updateItem(groupIndex: 0, itemIndex: 1, { item in
                            if let item = item as? ActionSheetCheckboxItem {
                                return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                            }
                            return item
                        })
                    }),
                    ActionSheetButtonItem(title: presentationData.strings.Replies_BlockAndDeleteRepliesActionTitle, color: .destructive, action: {
                        dismissAction()
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: true).start()
                        let context = strongSelf.context
                        let _ = context.engine.messages.deleteAllMessagesWithForwardAuthor(peerId: message.id.peerId, forwardAuthorId: peer.id, namespace: Namespaces.Message.Cloud).start()
                        let _ = strongSelf.context.engine.peers.reportRepliesMessage(messageId: message.id, deleteMessage: true, deleteHistory: true, reportSpam: reportSpam).start()
                    })
                ] as [ActionSheetItem])
                
                controller.setItemGroups([
                    ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
        }, deleteMessages: { [weak self] messages, contextController, completion in
            if let strongSelf = self, !messages.isEmpty {
                let messageIds = Set(messages.map { $0.id })
                strongSelf.messageContextDisposable.set((strongSelf.context.sharedContext.chatAvailableMessageActions(engine: strongSelf.context.engine, accountPeerId: strongSelf.context.account.peerId, messageIds: messageIds)
                |> deliverOnMainQueue).start(next: { actions in
                    if let strongSelf = self, !actions.options.isEmpty {
                        if let banAuthor = actions.banAuthor {
                            if let contextController = contextController {
                                contextController.dismiss(completion: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.presentBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, author: banAuthor, messageIds: messageIds, options: actions.options)
                                })
                            } else {
                                strongSelf.presentBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, author: banAuthor, messageIds: messageIds, options: actions.options)
                                completion(.default)
                            }
                        } else {
                            var isAction = false
                            if messages.count == 1 {
                                for media in messages[0].media {
                                    if media is TelegramMediaAction {
                                        isAction = true
                                    }
                                }
                            }
                            if isAction && (actions.options == .deleteGlobally || actions.options == .deleteLocally) {
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: actions.options == .deleteLocally ? .forLocalPeer : .forEveryone).start()
                                completion(.dismissWithoutContent)
                            } else if (messages.first?.flags.isSending ?? false) {
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone, deleteAllInGroup: true).start()
                                completion(.dismissWithoutContent)
                            } else {
                                if actions.options.intersection([.deleteLocally, .deleteGlobally]).isEmpty {
                                    strongSelf.presentClearCacheSuggestion()
                                    completion(.default)
                                } else {
                                    var isScheduled = false
                                    for id in messageIds {
                                        if Namespaces.Message.allScheduled.contains(id.namespace) {
                                            isScheduled = true
                                            break
                                        }
                                    }
                                    strongSelf.presentDeleteMessageOptions(messageIds: messageIds, options: isScheduled ? [.deleteLocally] : actions.options, contextController: contextController, completion: completion)
                                }
                            }
                        }
                    }
                }))
            }
        }, forwardSelectedMessages: { [weak self] in
            if let strongSelf = self {
                strongSelf.commitPurposefulAction()
                if let forwardMessageIdsSet = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds {
                    let forwardMessageIds = Array(forwardMessageIdsSet).sorted()
                    strongSelf.forwardMessages(messageIds: forwardMessageIds)
                }
            }
        }, forwardCurrentForwardMessages: { [weak self] in
            if let strongSelf = self {
                strongSelf.commitPurposefulAction()
                if let forwardMessageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds {
                    strongSelf.forwardMessages(messageIds: forwardMessageIds, options: strongSelf.presentationInterfaceState.interfaceState.forwardOptionsState, resetCurrent: true)
                }
            }
        }, forwardMessages: { [weak self] messages in
            if let strongSelf = self, !messages.isEmpty {
                strongSelf.commitPurposefulAction()
                let forwardMessageIds = messages.map { $0.id }.sorted()
                strongSelf.forwardMessages(messageIds: forwardMessageIds)
            }
        }, updateForwardOptionsState: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardOptionsState(f($0.forwardOptionsState ?? ChatInterfaceForwardOptionsState(hideNames: false, hideCaptions: false, unhideNamesOnCaptionChange: false))) }) })
            }
        }, presentForwardOptions: { [weak self] sourceNode in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                let presentationData = strongSelf.presentationData
                
                let forwardOptions: Signal<ChatControllerSubject.ForwardOptions, NoError>
                if peerId.namespace == Namespaces.Peer.SecretChat {
                    forwardOptions = .single(ChatControllerSubject.ForwardOptions(hideNames: true, hideCaptions: false))
                } else {
                    forwardOptions = strongSelf.presentationInterfaceStatePromise.get()
                    |> map { state -> ChatControllerSubject.ForwardOptions in
                        return ChatControllerSubject.ForwardOptions(hideNames: state.interfaceState.forwardOptionsState?.hideNames ?? false, hideCaptions: state.interfaceState.forwardOptionsState?.hideCaptions ?? false)
                    }
                    |> distinctUntilChanged
                }
                
                let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: .forwardedMessages(ids: strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? [], options: forwardOptions), botStart: nil, mode: .standard(previewing: true))
                chatController.canReadHistory.set(false)
                
                let messageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
                let messagesCount: Signal<Int, NoError>
                if let chatController = chatController as? ChatControllerImpl, messageIds.count > 1 {
                    messagesCount = .single(messageIds.count)
                    |> then(
                        chatController.presentationInterfaceStatePromise.get()
                        |> map { state -> Int in
                            return state.interfaceState.selectionState?.selectedIds.count ?? 1
                        }
                    )
                } else {
                    messagesCount = .single(1)
                }
                
                let accountPeerId = strongSelf.context.account.peerId
                let items = combineLatest(forwardOptions, strongSelf.context.account.postbox.messagesAtIds(messageIds), messagesCount)
                |> map { forwardOptions, messages, messagesCount -> [ContextMenuItem] in
                    var items: [ContextMenuItem] = []
                    
                    var hasCaptions = false
                    var uniquePeerIds = Set<PeerId>()
                    
                    var hasOther = false
                    var hasNotOwnMessages = false
                    for message in messages {
                        if let author = message.effectiveAuthor {
                            if !uniquePeerIds.contains(author.id) {
                                uniquePeerIds.insert(author.id)
                            }
                            
                            if message.id.peerId == accountPeerId && message.forwardInfo == nil {
                            } else {
                                hasNotOwnMessages = true
                            }
                        }
                        
                        var isDice = false
                        var isMusic = false
                        for media in message.media {
                            if let media = media as? TelegramMediaFile, media.isMusic {
                                isMusic = true
                            } else if media is TelegramMediaDice {
                                isDice = true
                            } else {
                                if !message.text.isEmpty {
                                    if media is TelegramMediaImage || media is TelegramMediaFile {
                                        hasCaptions = true
                                    }
                                }
                            }
                        }
                        if !isDice && !isMusic {
                            hasOther = true
                        }
                    }
                    
                    let canHideNames = hasNotOwnMessages && hasOther
                    
                    let hideNames = forwardOptions.hideNames
                    let hideCaptions = forwardOptions.hideCaptions
                    
                    if case let .peer(peerId) = strongSelf.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                        
                    } else {
                        if canHideNames {
                            items.append(.action(ContextMenuActionItem(text: uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_ShowSendersName : presentationData.strings.Conversation_ForwardOptions_ShowSendersNames, icon: { theme in
                                if hideNames {
                                    return nil
                                } else {
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                }
                            }, action: { [weak self] _, f in
                                self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                    var updated = current
                                    updated.hideNames = false
                                    updated.hideCaptions = false
                                    updated.unhideNamesOnCaptionChange = false
                                    return updated
                                })
                            })))
                            
                            items.append(.action(ContextMenuActionItem(text: uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_HideSendersName : presentationData.strings.Conversation_ForwardOptions_HideSendersNames, icon: { theme in
                                if hideNames {
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                } else {
                                    return nil
                                }
                            }, action: { _, f in
                                self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                    var updated = current
                                    updated.hideNames = true
                                    updated.unhideNamesOnCaptionChange = false
                                    return updated
                                })
                            })))
                            
                            items.append(.separator)
                        }
                        
                        if hasCaptions {
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_ShowCaption, icon: { theme in
                                if hideCaptions {
                                    return nil
                                } else {
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                }
                            }, action: { [weak self] _, f in
                                self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                    var updated = current
                                    updated.hideCaptions = false
                                    if updated.unhideNamesOnCaptionChange {
                                        updated.unhideNamesOnCaptionChange = false
                                        updated.hideNames = false
                                    }
                                    return updated
                                })
                            })))
                            
                            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_HideCaption, icon: { theme in
                                if hideCaptions {
                                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                                } else {
                                    return nil
                                }
                            }, action: { _, f in
                                self?.interfaceInteraction?.updateForwardOptionsState({ current in
                                    var updated = current
                                    updated.hideCaptions = true
                                    if !updated.hideNames {
                                        updated.hideNames = true
                                        updated.unhideNamesOnCaptionChange = true
                                    }
                                    return updated
                                })
                            })))
                            
                            items.append(.separator)
                        }
                    }
                    
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_ChangeRecipient, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { c, f in
                        self?.interfaceInteraction?.forwardCurrentForwardMessages()
                        
                        f(.default)
                    })))
                    
                    items.append(.action(ContextMenuActionItem(text: messagesCount == 1 ? presentationData.strings.Conversation_ForwardOptions_SendMessage : presentationData.strings.Conversation_ForwardOptions_SendMessages, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { [weak self, weak chatController] c, f in
                        guard let strongSelf = self else {
                            return
                        }
                        if let selectedMessageIds = (chatController as? ChatControllerImpl)?.selectedMessageIds {
                            var forwardMessageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
                            forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
                            strongSelf.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
                        }
                        
                        self?.controllerInteraction?.sendCurrentMessage(false)
                        
                        f(.default)
                    })))
                    
                    return items
                }
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()

                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)), items: items |> map { ContextController.Items(content: .list($0)) })
                contextController.dismissedForCancel = { [weak chatController] in
                    if let selectedMessageIds = (chatController as? ChatControllerImpl)?.selectedMessageIds {
                        var forwardMessageIds = strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
                        forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
                        strongSelf.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
                    }
                }
                contextController.immediateItemsTransitionAnimation = true
                strongSelf.presentInGlobalOverlay(contextController)
            }
        }, shareSelectedMessages: { [weak self] in
            if let strongSelf = self, let selectedIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !selectedIds.isEmpty {
                strongSelf.commitPurposefulAction()
                let _ = (strongSelf.context.engine.data.get(EngineDataMap(
                    selectedIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
                ))
                |> map { messages -> [EngineMessage] in
                    return messages.values.compactMap { $0 }
                }
                |> deliverOnMainQueue).start(next: { messages in
                    if let strongSelf = self, !messages.isEmpty {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                        
                        let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                            return lhs.index < rhs.index
                        }).map { $0._asMessage() }), externalShare: true, immediateExternalShare: true, updatedPresentationData: strongSelf.updatedPresentationData)
                        strongSelf.chatDisplayNode.dismissInput()
                        strongSelf.present(shareController, in: .window(.root))
                    }
                })
            }
        }, updateTextInputStateAndMode: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    let (updatedState, updatedMode) = f(state.interfaceState.effectiveInputState, state.inputMode)
                    return state.updatedInterfaceState { interfaceState in
                        return interfaceState.withUpdatedEffectiveInputState(updatedState)
                        }.updatedInputMode({ _ in updatedMode })
                })
                
                if !strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText.string.isEmpty {
                    strongSelf.silentPostTooltipController?.dismiss()
                }
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    var updated = $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({
                        $0.withUpdatedMessageActionsState({ value in
                            var value = value
                            value.closedButtonKeyboardMessageId = updatedClosedButtonKeyboardMessageId
                            return value
                        })
                    })
                    var dismissWebView = false
                    switch updatedInputMode {
                        case .text, .media, .inputButtons:
                            dismissWebView = true
                        default:
                            break
                    }
                    if dismissWebView {
                        updated = updated.updatedShowWebView(false)
                    }
                    return updated
                })
            }
        }, openStickers: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.chatDisplayNode.openStickers()
            strongSelf.mediaRecordingModeTooltipController?.dismissImmediately()
        }, editMessage: { [weak self] in
            if let strongSelf = self, let editMessage = strongSelf.presentationInterfaceState.interfaceState.editMessage {
                var disableUrlPreview = false
                if let (link, _) = strongSelf.presentationInterfaceState.editingUrlPreview {
                    if editMessage.disableUrlPreview == link {
                        disableUrlPreview = true
                    }
                }
                
                let text = trimChatInputText(convertMarkdownToAttributes(editMessage.inputState.inputText))
                let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                var entitiesAttribute: TextEntitiesMessageAttribute?
                if !entities.isEmpty {
                    entitiesAttribute = TextEntitiesMessageAttribute(entities: entities)
                }
                
                var updatingMedia = false
                let media: RequestEditMessageMedia
                if let editMediaReference = strongSelf.presentationInterfaceState.editMessageState?.mediaReference {
                    media = .update(editMediaReference)
                    updatingMedia = true
                } else {
                    media = .keep
                }
                
                let _ = (strongSelf.context.account.postbox.messageAtId(editMessage.messageId)
                |> deliverOnMainQueue)
                .start(next: { [weak self] currentMessage in
                    if let strongSelf = self {
                        if let currentMessage = currentMessage {
                            let currentEntities = currentMessage.textEntitiesAttribute?.entities ?? []
                            if currentMessage.text != text.string || currentEntities != entities || updatingMedia {
                                strongSelf.context.account.pendingUpdateMessageManager.add(messageId: editMessage.messageId, text: text.string, media: media, entities: entitiesAttribute, disableUrlPreview: disableUrlPreview)
                            }
                        }
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            var state = state
                            state = state.updatedInterfaceState({ $0.withUpdatedEditMessage(nil) })
                            state = state.updatedEditMessageState(nil)
                            return state
                        })
                    }
                })
            }
        }, beginMessageSearch: { [weak self] domain, query in
            guard let strongSelf = self else {
                return
            }
            
            let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                var interactive = true
                if strongSelf.chatDisplayNode.isInputViewFocused {
                    interactive = false
                    strongSelf.context.sharedContext.mainWindow?.doNotAnimateLikelyKeyboardAutocorrectionSwitch()
                }
                
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: interactive, { current in
                    return current.updatedTitlePanelContext {
                        if let index = $0.firstIndex(where: {
                            switch $0 {
                            case .chatInfo:
                                return true
                            default:
                                return false
                            }
                        }) {
                            var updatedContexts = $0
                            updatedContexts.remove(at: index)
                            return updatedContexts
                        } else {
                            return $0
                        }
                    }.updatedSearch(current.search == nil ? ChatSearchData(domain: domain).withUpdatedQuery(query) : current.search?.withUpdatedDomain(domain).withUpdatedQuery(query))
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
            })
        }, dismissMessageSearch: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    return current.updatedSearch(nil)
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
                strongSelf.searchResultsController = nil
            }
        }, updateMessageSearch: { [weak self] query in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    if let data = current.search {
                        return current.updatedSearch(data.withUpdatedQuery(query))
                    } else {
                        return current
                    }
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
                strongSelf.searchResultsController = nil
            }
        }, openSearchResults: { [weak self] in
            if let strongSelf = self, let searchData = strongSelf.presentationInterfaceState.search, let _ = searchData.resultsState {
                if let controller = strongSelf.searchResultsController {
                    strongSelf.chatDisplayNode.dismissInput()
                    if case let .inline(navigationController) = strongSelf.presentationInterfaceState.mode {
                        navigationController?.pushViewController(controller)
                    } else {
                        strongSelf.push(controller)
                    }
                } else {
                    let _ = (strongSelf.searchResult.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] searchResult in
                        if let strongSelf = self, let (searchResult, searchState, searchLocation) = searchResult {
                            
                            let controller = ChatSearchResultsController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, location: searchLocation, searchQuery: searchData.query, searchResult: searchResult, searchState: searchState, navigateToMessageIndex: { index in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.interfaceInteraction?.navigateMessageSearch(.index(index))
                            }, resultsUpdated: { results, state in
                                guard let strongSelf = self else {
                                    return
                                }
                                let updatedValue: (SearchMessagesResult, SearchMessagesState, SearchMessagesLocation)? = (results, state, searchLocation)
                                strongSelf.searchResult.set(.single(updatedValue))
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                    if let data = current.search {
                                        let messageIndices = results.messages.map({ $0.index }).sorted()
                                        var currentIndex = messageIndices.last
                                        if let previousResultId = data.resultsState?.currentId {
                                            for index in messageIndices {
                                                if index.id >= previousResultId {
                                                    currentIndex = index
                                                    break
                                                }
                                            }
                                        }
                                        return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: currentIndex?.id, state: state, totalCount: results.totalCount, completed: results.completed)))
                                    } else {
                                        return current
                                    }
                                })
                            })
                            strongSelf.chatDisplayNode.dismissInput()
                            if case let .inline(navigationController) = strongSelf.presentationInterfaceState.mode {
                                navigationController?.pushViewController(controller)
                            } else {
                                strongSelf.push(controller)
                            }
                            strongSelf.searchResultsController = controller
                        }
                    })
                }
            }
        }, navigateMessageSearch: { [weak self] action in
            if let strongSelf = self {
                var navigateIndex: MessageIndex?
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                    if let data = current.search, let resultsState = data.resultsState {
                        if let currentId = resultsState.currentId, let index = resultsState.messageIndices.firstIndex(where: { $0.id == currentId }) {
                            var updatedIndex: Int?
                            switch action {
                                case .earlier:
                                    if index != 0 {
                                        updatedIndex = index - 1
                                    }
                                case .later:
                                    if index != resultsState.messageIndices.count - 1 {
                                        updatedIndex = index + 1
                                    }
                                case let .index(index):
                                    if index >= 0 && index < resultsState.messageIndices.count {
                                        updatedIndex = index
                                    }
                            }
                            if let updatedIndex = updatedIndex {
                                navigateIndex = resultsState.messageIndices[updatedIndex]
                                return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: resultsState.messageIndices, currentId: resultsState.messageIndices[updatedIndex].id, state: resultsState.state, totalCount: resultsState.totalCount, completed: resultsState.completed)))
                            }
                        }
                    }
                    return current
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
                if let navigateIndex = navigateIndex {
                    switch strongSelf.chatLocation {
                    case .peer, .replyThread, .feed:
                        strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex), forceInCurrentChat: true)
                    }
                }
            }
        }, openCalendarSearch: { [weak self] in
            self?.openCalendarSearch(timestamp: Int32(Date().timeIntervalSince1970))
        }, toggleMembersSearch: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    if value {
                        return state.updatedSearch(ChatSearchData(query: "", domain: .members, domainSuggestionContext: .none, resultsState: nil))
                    } else if let search = state.search {
                        switch search.domain {
                            case .everything:
                                return state
                            case .members:
                                return state.updatedSearch(ChatSearchData(query: "", domain: .everything, domainSuggestionContext: .none, resultsState: nil))
                            case .member:
                                return state.updatedSearch(ChatSearchData(query: "", domain: .members, domainSuggestionContext: .none, resultsState: nil))
                        }
                    } else {
                        return state
                    }
                })
                strongSelf.updateItemNodesSearchTextHighlightStates()
            }
        }, navigateToMessage: { [weak self] messageId, dropStack, forceInCurrentChat, statusSubject in
            self?.navigateToMessage(from: nil, to: .id(messageId, nil), forceInCurrentChat: forceInCurrentChat, dropStack: dropStack, statusSubject: statusSubject)
        }, navigateToChat: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            if let navigationController = strongSelf.effectiveNavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), subject: nil, keepStack: .always))
            }
        }, navigateToProfile: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openPeer(peerId: peerId, navigation: .default, fromMessage: nil)
        }, openPeerInfo: { [weak self] in
            self?.navigationButtonAction(.openChatInfo(expandAvatar: false))
        }, togglePeerNotifications: { [weak self] in
            if let strongSelf = self, let peerId = strongSelf.chatLocation.peerId {
                let _ = strongSelf.context.engine.peers.togglePeerMuted(peerId: peerId).start()
            }
        }, sendContextResult: { [weak self] results, result, node, rect in
            guard let strongSelf = self else {
                return false
            }
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                strongSelf.interfaceInteraction?.displaySlowmodeTooltip(node, rect)
                return false
            }
            
            strongSelf.enqueueChatContextResult(results, result)
            return true
        }, sendBotCommand: { [weak self] botPeer, command in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    let messageText: String
                    if let addressName = botPeer.addressName {
                        if peer is TelegramUser {
                            messageText = command
                        } else {
                            messageText = command + "@" + addressName
                        }
                    } else {
                        messageText = command
                    }
                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil) }
                            })
                        }
                    }, nil)
                    var attributes: [MessageAttribute] = []
                    let entities = generateTextEntities(messageText, enabledTypes: .all)
                    if !entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                    }
                    strongSelf.sendMessages([.message(text: messageText, attributes: attributes, mediaReference: nil, replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)])
                    strongSelf.interfaceInteraction?.updateShowCommands { _ in
                        return false
                    }
                }
            }
        }, sendBotStart: { [weak self] payload in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.startBot(payload)
            }
        }, botSwitchChatWithPayload: { [weak self] peerId, payload in
            if let strongSelf = self, case let .peer(currentPeerId) = strongSelf.chatLocation {
                var isScheduled = false
                if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                    isScheduled = true
                }
                strongSelf.openPeer(peerId: peerId, navigation: .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .automatic(returnToPeerId: currentPeerId, scheduled: isScheduled))), fromMessage: nil)
            }
        }, beginMediaRecording: { [weak self] isVideo in
            guard let strongSelf = self else {
                return
            }
            strongSelf.mediaRecordingModeTooltipController?.dismiss()
            strongSelf.interfaceInteraction?.updateShowWebView { _ in
                return false
            }
            
            let requestId = strongSelf.beginMediaRecordingRequestId
            let begin: () -> Void = {
                guard let strongSelf = self, strongSelf.beginMediaRecordingRequestId == requestId else {
                    return
                }
                guard checkAvailableDiskSpace(context: strongSelf.context, push: { [weak self] c in
                    self?.push(c)
                }) else {
                    return
                }
                let hasOngoingCall: Signal<Bool, NoError> = strongSelf.context.sharedContext.hasOngoingCall.get()
                let _ = (hasOngoingCall
                |> deliverOnMainQueue).start(next: { hasOngoingCall in
                    guard let strongSelf = self, strongSelf.beginMediaRecordingRequestId == requestId else {
                        return
                    }
                    if hasOngoingCall {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.Call_CallInProgressTitle, text: strongSelf.presentationData.strings.Call_RecordingDisabledMessage, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        })]), in: .window(.root))
                    } else {
                        if isVideo {
                            strongSelf.requestVideoRecorder()
                        } else {
                            strongSelf.requestAudioRecorder(beginWithTone: false)
                        }
                    }
                })
            }
            DeviceAccess.authorizeAccess(to: .microphone(isVideo ? .video : .audio), presentationData: strongSelf.presentationData, present: { c, a in
                self?.present(c, in: .window(.root), with: a)
            }, openSettings: {
                self?.context.sharedContext.applicationBindings.openSettings()
            }, { granted in
                guard let strongSelf = self, granted else {
                    return
                }
                if isVideo {
                    DeviceAccess.authorizeAccess(to: .camera(.video), presentationData: strongSelf.presentationData, present: { c, a in
                        self?.present(c, in: .window(.root), with: a)
                    }, openSettings: {
                        self?.context.sharedContext.applicationBindings.openSettings()
                    }, { granted in
                        if granted {
                            begin()
                        }
                    })
                } else {
                    begin()
                }
            })
        }, finishMediaRecording: { [weak self] action in
            guard let strongSelf = self else {
                return
            }
            strongSelf.beginMediaRecordingRequestId += 1
            strongSelf.dismissMediaRecorder(action)
        }, stopMediaRecording: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.beginMediaRecordingRequestId += 1
            strongSelf.lockMediaRecordingRequestId = nil
            strongSelf.stopMediaRecorder()
        }, lockMediaRecording: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.lockMediaRecordingRequestId = strongSelf.beginMediaRecordingRequestId
            strongSelf.lockMediaRecorder()
        }, deleteRecordedMedia: { [weak self] in
            self?.deleteMediaRecording()
        }, sendRecordedMedia: { [weak self] silentPosting in
            self?.sendMediaRecording(silentPosting: silentPosting)
        }, displayRestrictedInfo: { [weak self] subject, displayType in
            guard let strongSelf = self else {
                return
            }
            let subjectFlags: TelegramChatBannedRightsFlags
            switch subject {
                case .stickers:
                    subjectFlags = .banSendStickers
                case .mediaRecording:
                    subjectFlags = .banSendMedia
            }
                        
            let bannedPermission: (Int32, Bool)?
            if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
                bannedPermission = channel.hasBannedPermission(subjectFlags)
            } else if let group = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                if group.hasBannedPermission(subjectFlags) {
                    bannedPermission = (Int32.max, false)
                } else {
                    bannedPermission = nil
                }
            } else {
                bannedPermission = nil
            }
            
            if let (untilDate, personal) = bannedPermission {
                let banDescription: String
                switch subject {
                    case .stickers:
                        if untilDate != 0 && untilDate != Int32.max {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedStickersTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).string
                        } else if personal {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedStickers
                        } else {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_DefaultRestrictedStickers
                        }
                    case .mediaRecording:
                        if untilDate != 0 && untilDate != Int32.max {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).string
                        } else if personal {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMedia
                        } else {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_DefaultRestrictedMedia
                        }
                }
                if strongSelf.recordingModeFeedback == nil {
                    strongSelf.recordingModeFeedback = HapticFeedback()
                    strongSelf.recordingModeFeedback?.prepareError()
                }
                
                strongSelf.recordingModeFeedback?.error()
                
                switch displayType {
                    case .tooltip:
                        var rect: CGRect?
                        let isStickers: Bool = subject == .stickers
                        switch subject {
                        case .stickers:
                            rect = strongSelf.chatDisplayNode.frameForStickersButton()
                            if var rectValue = rect, let actionRect = strongSelf.chatDisplayNode.frameForInputActionButton() {
                                rectValue.origin.y = actionRect.minY
                                rect = rectValue
                            }
                        case .mediaRecording:
                            rect = strongSelf.chatDisplayNode.frameForInputActionButton()
                        }
                        
                        if let tooltipController = strongSelf.mediaRestrictedTooltipController, strongSelf.mediaRestrictedTooltipControllerMode == isStickers {
                            tooltipController.updateContent(.text(banDescription), animated: true, extendTimer: true)
                        } else if let rect = rect {
                            strongSelf.mediaRestrictedTooltipController?.dismiss()
                            let tooltipController = TooltipController(content: .text(banDescription), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize)
                            strongSelf.mediaRestrictedTooltipController = tooltipController
                            strongSelf.mediaRestrictedTooltipControllerMode = isStickers
                            tooltipController.dismissed = { [weak tooltipController] _ in
                                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRestrictedTooltipController === tooltipController {
                                    strongSelf.mediaRestrictedTooltipController = nil
                                }
                            }
                            strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                                if let strongSelf = self {
                                    return (strongSelf.chatDisplayNode, rect)
                                }
                                return nil
                            }))
                        }
                    case .alert:
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: banDescription, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
            
            if case .mediaRecording = subject, strongSelf.presentationInterfaceState.hasActiveGroupCall {
                let rect = strongSelf.chatDisplayNode.frameForInputActionButton()
                if let rect = rect {
                    strongSelf.mediaRestrictedTooltipController?.dismiss()
                    let text: String
                    if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
                        text = strongSelf.presentationInterfaceState.strings.Conversation_LiveStreamMediaRecordingRestricted
                    } else {
                        text = strongSelf.presentationInterfaceState.strings.Conversation_VoiceChatMediaRecordingRestricted
                    }
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize)
                    strongSelf.mediaRestrictedTooltipController = tooltipController
                    strongSelf.mediaRestrictedTooltipControllerMode = false
                    tooltipController.dismissed = { [weak tooltipController] _ in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRestrictedTooltipController === tooltipController {
                            strongSelf.mediaRestrictedTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                }
            }
        }, displayVideoUnmuteTip: { [weak self] location in
            guard let strongSelf = self, let layout = strongSelf.validLayout, strongSelf.traceVisibility() && isTopmostChatController(strongSelf) else {
                return
            }
            
            if let location = location, location.y < strongSelf.navigationLayout(layout: layout).navigationFrame.maxY {
                return
            }
            
            let icon: UIImage?
            if layout.deviceMetrics.hasTopNotch {
                icon = UIImage(bundleImageName: "Chat/Message/VolumeButtonIconX")
            } else {
                icon = UIImage(bundleImageName: "Chat/Message/VolumeButtonIcon")
            }
            if let location = location, let icon = icon {
                strongSelf.videoUnmuteTooltipController?.dismiss()
                let tooltipController = TooltipController(content: .iconAndText(icon, strongSelf.presentationInterfaceState.strings.Conversation_PressVolumeButtonForSound), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, timeout: 3.5, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                strongSelf.videoUnmuteTooltipController = tooltipController
                tooltipController.dismissed = { [weak tooltipController] _ in
                    if let strongSelf = self, let tooltipController = tooltipController, strongSelf.videoUnmuteTooltipController === tooltipController {
                        strongSelf.videoUnmuteTooltipController = nil
                        ApplicationSpecificNotice.setVolumeButtonToUnmute(accountManager: strongSelf.context.sharedContext.accountManager)
                    }
                }
                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                    if let strongSelf = self {
                        return (strongSelf.chatDisplayNode, CGRect(origin: location, size: CGSize()))
                    }
                    return nil
                }))
            } else if let tooltipController = strongSelf.videoUnmuteTooltipController {
                tooltipController.dismissImmediately()
            }
        }, switchMediaRecordingMode: { [weak self] in
            if let strongSelf = self {
                if strongSelf.recordingModeFeedback == nil {
                    strongSelf.recordingModeFeedback = HapticFeedback()
                    strongSelf.recordingModeFeedback?.prepareImpact()
                }
                
                strongSelf.recordingModeFeedback?.impact()
                var updatedMode: ChatTextInputMediaRecordingButtonMode?
                
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedInterfaceState({ current in
                        let mode: ChatTextInputMediaRecordingButtonMode
                        switch current.mediaRecordingMode {
                            case .audio:
                                mode = .video
                            case .video:
                                mode = .audio
                        }
                        updatedMode = mode
                        return current.withUpdatedMediaRecordingMode(mode)
                    }).updatedShowWebView(false)
                })
                
                if let updatedMode = updatedMode, updatedMode == .video {
                    let _ = ApplicationSpecificNotice.incrementChatMediaMediaRecordingTips(accountManager: strongSelf.context.sharedContext.accountManager, count: 3).start()
                }
                
                strongSelf.displayMediaRecordingTooltip()
            }
        }, setupMessageAutoremoveTimeout: { [weak self] in
            guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            guard let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            if peerId.namespace == Namespaces.Peer.SecretChat {
                strongSelf.chatDisplayNode.dismissInput()
                
                if let peer = peer as? TelegramSecretChat {
                    let controller = ChatSecretAutoremoveTimerActionSheetController(context: strongSelf.context, currentValue: peer.messageAutoremoveTimeout == nil ? 0 : peer.messageAutoremoveTimeout!, applyValue: { value in
                        if let strongSelf = self {
                            let _ = strongSelf.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peer.id, timeout: value == 0 ? nil : value).start()
                        }
                    })
                    strongSelf.present(controller, in: .window(.root))
                }
            } else {
                var currentAutoremoveTimeout: Int32? = strongSelf.presentationInterfaceState.autoremoveTimeout
                var canSetupAutoremoveTimeout = false
                
                if let secretChat = peer as? TelegramSecretChat {
                    currentAutoremoveTimeout = secretChat.messageAutoremoveTimeout
                    canSetupAutoremoveTimeout = true
                } else if let group = peer as? TelegramGroup {
                    if case .creator = group.role {
                        canSetupAutoremoveTimeout = true
                    } else if case let .admin(rights, _) = group.role {
                        if rights.rights.contains(.canDeleteMessages) {
                            canSetupAutoremoveTimeout = true
                        }
                    }
                } else if let user = peer as? TelegramUser {
                    if user.id != strongSelf.context.account.peerId && user.botInfo == nil {
                        canSetupAutoremoveTimeout = true
                    }
                } else if let channel = peer as? TelegramChannel {
                    if channel.hasPermission(.deleteAllMessages) {
                        canSetupAutoremoveTimeout = true
                    }
                }
                
                if canSetupAutoremoveTimeout {
                    strongSelf.presentAutoremoveSetup()
                } else if let currentAutoremoveTimeout = currentAutoremoveTimeout, let rect = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.messageAutoremoveTimeout(currentAutoremoveTimeout)) {
                    
                    let intervalText = timeIntervalString(strings: strongSelf.presentationData.strings, value: currentAutoremoveTimeout)
                    let text: String = strongSelf.presentationData.strings.Conversation_AutoremoveTimerSetToastText(intervalText).string
                    
                    strongSelf.mediaRecordingModeTooltipController?.dismiss()
                    
                    if let tooltipController = strongSelf.silentPostTooltipController {
                        tooltipController.updateContent(.text(text), animated: true, extendTimer: true)
                    } else {
                        let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, timeout: 4.0)
                        strongSelf.silentPostTooltipController = tooltipController
                        tooltipController.dismissed = { [weak tooltipController] _ in
                            if let strongSelf = self, let tooltipController = tooltipController, strongSelf.silentPostTooltipController === tooltipController {
                                strongSelf.silentPostTooltipController = nil
                            }
                        }
                        strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                            if let strongSelf = self {
                                return (strongSelf.chatDisplayNode, rect)
                            }
                            return nil
                        }))
                    }
                }
            }
        }, sendSticker: { [weak self] file, clearInput, sourceNode, sourceRect in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                return strongSelf.controllerInteraction?.sendSticker(file, false, false, nil, clearInput, sourceNode, sourceRect) ?? false
            } else {
                return false
            }
        }, unblockPeer: { [weak self] in
            self?.unblockPeer()
        }, pinMessage: { [weak self] messageId, contextController in
            if let strongSelf = self, case let .peer(currentPeerId) = strongSelf.chatLocation {
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    if strongSelf.canManagePin() {
                        let pinAction: (Bool, Bool) -> Void = { notify, forThisPeerOnlyIfPossible in
                            if let strongSelf = self {
                                let disposable: MetaDisposable
                                if let current = strongSelf.unpinMessageDisposable {
                                    disposable = current
                                } else {
                                    disposable = MetaDisposable()
                                    strongSelf.unpinMessageDisposable = disposable
                                }
                                disposable.set(strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: currentPeerId, update: .pin(id: messageId, silent: !notify, forThisPeerOnlyIfPossible: forThisPeerOnlyIfPossible)).start(completed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.scrolledToMessageIdValue = nil
                                }))
                            }
                        }
                        
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info, let contextController = contextController {
                            contextController.dismiss(completion: {
                                pinAction(true, false)
                            })
                        } else if let peer = peer as? TelegramUser, let contextController = contextController {
                            if peer.id == strongSelf.context.account.peerId {
                                contextController.dismiss(completion: {
                                    pinAction(true, true)
                                })
                            } else {
                                var contextItems: [ContextMenuItem] = []
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessagesFor(EnginePeer(peer).compactDisplayTitle).string, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c.dismiss(completion: {
                                        pinAction(true, false)
                                    })
                                })))
                                
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessagesForMe, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c.dismiss(completion: {
                                        pinAction(true, true)
                                    })
                                })))
                                
                                contextController.setItems(.single(ContextController.Items(content: .list(contextItems))), minHeight: nil)
                            }
                            return
                        } else {
                            if let contextController = contextController {
                                var contextItems: [ContextMenuItem] = []
                                
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessageAlert_PinAndNotifyMembers, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c.dismiss(completion: {
                                        pinAction(true, false)
                                    })
                                })))
                                
                                contextItems.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_PinMessageAlert_OnlyPin, textColor: .primary, icon: { _ in nil }, action: { c, _ in
                                    c.dismiss(completion: {
                                        pinAction(false, false)
                                    })
                                })))
                                
                                contextController.setItems(.single(ContextController.Items(content: .list(contextItems))), minHeight: nil)
                                
                                return
                            } else {
                                let continueAction: () -> Void = {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    var pinImmediately = false
                                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                        pinImmediately = true
                                    } else if let _ = peer as? TelegramUser {
                                        pinImmediately = true
                                    }
                                    
                                    if pinImmediately {
                                        pinAction(true, false)
                                    } else {
                                        let topPinnedMessage: Signal<ChatPinnedMessage?, NoError> = strongSelf.topPinnedMessageSignal(latest: true)
                                        |> take(1)
                                        
                                        let _ = (topPinnedMessage
                                        |> deliverOnMainQueue).start(next: { value in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            
                                            let title: String?
                                            let text: String
                                            let actionLayout: TextAlertContentActionLayout
                                            let actions: [TextAlertAction]
                                            if let value = value, value.message.id > messageId {
                                                title = strongSelf.presentationData.strings.Conversation_PinOlderMessageAlertTitle
                                                text = strongSelf.presentationData.strings.Conversation_PinOlderMessageAlertText
                                                actionLayout = .vertical
                                                actions = [
                                                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Conversation_PinMessageAlertPin, action: {
                                                        pinAction(false, false)
                                                    }),
                                                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                                    })
                                                ]
                                            } else {
                                                title = nil
                                                text = strongSelf.presentationData.strings.Conversation_PinMessageAlertGroup
                                                actionLayout = .horizontal
                                                actions = [
                                                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_PinMessageAlert_OnlyPin, action: {
                                                        pinAction(false, false)
                                                    }),
                                                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                                                        pinAction(true, false)
                                                    })
                                                ]
                                            }
                                            
                                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: title, text: text, actions: actions, actionLayout: actionLayout), in: .window(.root))
                                        })
                                    }
                                }
                                
                                continueAction()
                            }
                        }
                    } else {
                        if let topPinnedMessageId = strongSelf.presentationInterfaceState.pinnedMessage?.topMessageId {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                    var value = value
                                    value.closedPinnedMessageId = topPinnedMessageId
                                    return value
                                    })
                                })
                            })
                        }
                    }
                }
            }
        }, unpinMessage: { [weak self] id, askForConfirmation, contextController in
            let impl: () -> Void = {
                guard let strongSelf = self else {
                    return
                }
                guard let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                    return
                }
                
                if strongSelf.canManagePin() {
                    let action: () -> Void = {
                        if let strongSelf = self {
                            let disposable: MetaDisposable
                            if let current = strongSelf.unpinMessageDisposable {
                                disposable = current
                            } else {
                                disposable = MetaDisposable()
                                strongSelf.unpinMessageDisposable = disposable
                            }
                            
                            if askForConfirmation {
                                strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = true
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    return $0.updatedPendingUnpinnedAllMessages(true)
                                })
                                    
                                strongSelf.present(
                                    UndoOverlayController(
                                        presentationData: strongSelf.presentationData,
                                        content: .messagesUnpinned(
                                            title: strongSelf.presentationData.strings.Chat_MessagesUnpinned(1),
                                            text: "",
                                            undo: askForConfirmation,
                                            isHidden: false
                                        ),
                                        elevatedLayout: false,
                                        action: { action in
                                            switch action {
                                            case .commit:
                                                disposable.set((strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: peer.id, update: .clear(id: id))
                                                |> deliverOnMainQueue).start(error: { _ in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                        return $0.updatedPendingUnpinnedAllMessages(false)
                                                    })
                                                }, completed: {
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                        return $0.updatedPendingUnpinnedAllMessages(false)
                                                    })
                                                }))
                                            case .undo:
                                                strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                    return $0.updatedPendingUnpinnedAllMessages(false)
                                                })
                                            default:
                                                break
                                            }
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            } else {
                                if case .pinnedMessages = strongSelf.presentationInterfaceState.subject {
                                    strongSelf.chatDisplayNode.historyNode.pendingRemovedMessages.insert(id)
                                    strongSelf.present(
                                        UndoOverlayController(
                                            presentationData: strongSelf.presentationData,
                                            content: .messagesUnpinned(
                                                title: strongSelf.presentationData.strings.Chat_MessagesUnpinned(1),
                                                text: "",
                                                undo: true,
                                                isHidden: false
                                            ),
                                            elevatedLayout: false,
                                            action: { action in
                                                guard let strongSelf = self else {
                                                    return true
                                                }
                                                switch action {
                                                case .commit:
                                                    let _ = (strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: peer.id, update: .clear(id: id))
                                                    |> deliverOnMainQueue).start(completed: {
                                                        Queue.mainQueue().after(1.0, {
                                                            guard let strongSelf = self else {
                                                                return
                                                            }
                                                            strongSelf.chatDisplayNode.historyNode.pendingRemovedMessages.remove(id)
                                                        })
                                                    })
                                                case .undo:
                                                    strongSelf.chatDisplayNode.historyNode.pendingRemovedMessages.remove(id)
                                                default:
                                                    break
                                                }
                                                return true
                                            }
                                        ),
                                        in: .current
                                    )
                                } else {
                                    disposable.set((strongSelf.context.engine.messages.requestUpdatePinnedMessage(peerId: peer.id, update: .clear(id: id))
                                    |> deliverOnMainQueue).start())
                                }
                            }
                        }
                    }
                    if askForConfirmation {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_UnpinMessageAlert, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_Unpin, action: {
                            action()
                        }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})], actionLayout: .vertical), in: .window(.root))
                    } else {
                        action()
                    }
                } else {
                    if let pinnedMessage = strongSelf.presentationInterfaceState.pinnedMessage {
                        let previousClosedPinnedMessageId = strongSelf.presentationInterfaceState.interfaceState.messageActionsState.closedPinnedMessageId
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                var value = value
                                value.closedPinnedMessageId = pinnedMessage.topMessageId
                                return value
                            }) })
                        })
                        strongSelf.present(
                            UndoOverlayController(
                                presentationData: strongSelf.presentationData,
                                content: .messagesUnpinned(
                                    title: strongSelf.presentationData.strings.Chat_PinnedMessagesHiddenTitle,
                                    text: strongSelf.presentationData.strings.Chat_PinnedMessagesHiddenText,
                                    undo: true,
                                    isHidden: false
                                ),
                                elevatedLayout: false,
                                action: { action in
                                    guard let strongSelf = self else {
                                        return true
                                    }
                                    switch action {
                                    case .commit:
                                        break
                                    case .undo:
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                            return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                                var value = value
                                                value.closedPinnedMessageId = previousClosedPinnedMessageId
                                                return value
                                            }) })
                                        })
                                    default:
                                        break
                                    }
                                    return true
                                }
                            ),
                            in: .current
                        )
                        strongSelf.updatedClosedPinnedMessageId?(pinnedMessage.topMessageId)
                    }
                }
            }
            
            if let contextController = contextController {
                contextController.dismiss(completion: {
                    impl()
                })
            } else {
                impl()
            }
        }, unpinAllMessages: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let topPinnedMessage: Signal<ChatPinnedMessage?, NoError> = strongSelf.topPinnedMessageSignal(latest: true)
            |> take(1)
            
            let _ = (topPinnedMessage
            |> deliverOnMainQueue).start(next: { topPinnedMessage in
                guard let strongSelf = self, let topPinnedMessage = topPinnedMessage else {
                    return
                }
                
                if strongSelf.canManagePin() {
                    let count = strongSelf.presentationInterfaceState.pinnedMessage?.totalCount ?? 1
                    
                    strongSelf.requestedUnpinAllMessages?(count, topPinnedMessage.topMessageId)
                    strongSelf.dismiss()
                } else {
                    strongSelf.updatedClosedPinnedMessageId?(topPinnedMessage.topMessageId)
                    strongSelf.dismiss()
                }
            })
        }, openPinnedList: { [weak self] messageId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openPinnedMessages(at: messageId)
        }, shareAccountContact: { [weak self] in
            self?.shareAccountContact()
        }, reportPeer: { [weak self] in
            self?.reportPeer()
        }, presentPeerContact: { [weak self] in
            self?.addPeerContact()
        }, dismissReportPeer: { [weak self] in
            self?.dismissPeerContactOptions()
        }, deleteChat: { [weak self] in
            self?.deleteChat(reportChatSpam: false)
        }, beginCall: { [weak self] isVideo in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.controllerInteraction?.callPeer(peerId, isVideo)
            }
        }, toggleMessageStickerStarred: { [weak self] messageId in
            if let strongSelf = self, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                var stickerFile: TelegramMediaFile?
                for media in message.media {
                    if let file = media as? TelegramMediaFile, file.isSticker {
                        stickerFile = file
                    }
                }
                if let stickerFile = stickerFile {
                    let context = strongSelf.context
                    let _ = (context.engine.stickers.isStickerSaved(id: stickerFile.fileId)
                    |> castError(AddSavedStickerError.self)
                    |> mapToSignal { isSaved -> Signal<(SavedStickerResult, Bool), AddSavedStickerError> in
                        return context.engine.stickers.toggleStickerSaved(file: stickerFile, saved: !isSaved)
                        |> map { result -> (SavedStickerResult, Bool) in
                            return (result, !isSaved)
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] result, added in
                        if let strongSelf = self {
                            switch result {
                                case .generic:
                                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: stickerFile, title: nil, text: added ? strongSelf.presentationData.strings.Conversation_StickerAddedToFavorites : strongSelf.presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil), elevatedLayout: true, action: { _ in return false }), with: nil)
                                case let .limitExceeded(limit, premiumLimit):
                                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                    let text: String
                                    if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                        text = strongSelf.presentationData.strings.Premium_MaxFavedStickersFinalText
                                    } else {
                                        text = strongSelf.presentationData.strings.Premium_MaxFavedStickersText("\(premiumLimit)").string
                                    }
                                    strongSelf.presentInGlobalOverlay(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: stickerFile, title: strongSelf.presentationData.strings.Premium_MaxFavedStickersTitle("\(limit)").string, text: text, undoText: nil), elevatedLayout: true, action: { [weak self] action in
                                        if let strongSelf = self {
                                            if case .info = action {
                                                let controller = PremiumIntroScreen(context: strongSelf.context, source: .savedStickers)
                                                strongSelf.push(controller)
                                                return true
                                            }
                                        }
                                        return false
                                    }), with: nil)
                            }
                        }
                    })
                }
            }
        }, presentController: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, presentGlobalOverlayController: { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }, navigateFeed: { [weak self] in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.historyNode.scrollToNextMessage()
            }
        }, openGrouping: {
        }, toggleSilentPost: { [weak self] in
            if let strongSelf = self {
                var value: Bool = false
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    $0.updatedInterfaceState {
                        value = !$0.silentPosting
                        return $0.withUpdatedSilentPosting(value)
                    }
                })
                strongSelf.saveInterfaceState()
                
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    for controller in navigationController.globalOverlayControllers {
                        if controller is VoiceChatOverlayController {
                            return
                        }
                    }
                }
                
                var rect: CGRect? = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.silentPost(true))
                if rect == nil {
                    rect = strongSelf.chatDisplayNode.frameForInputPanelAccessoryButton(.silentPost(false))
                }
                
                let text: String
                if !value {
                    text = strongSelf.presentationData.strings.Conversation_SilentBroadcastTooltipOn
                } else {
                    text = strongSelf.presentationData.strings.Conversation_SilentBroadcastTooltipOff
                }
                
                if let tooltipController = strongSelf.silentPostTooltipController {
                    tooltipController.updateContent(.text(text), animated: true, extendTimer: true)
                } else if let rect = rect {
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize)
                    strongSelf.silentPostTooltipController = tooltipController
                    tooltipController.dismissed = { [weak tooltipController] _ in
                        if let strongSelf = self, let tooltipController = tooltipController, strongSelf.silentPostTooltipController === tooltipController {
                            strongSelf.silentPostTooltipController = nil
                        }
                    }
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                }
            }
        }, requestUnvoteInMessage: { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            let disposables: DisposableDict<MessageId>
            if let current = strongSelf.selectMessagePollOptionDisposables {
                disposables = current
            } else {
                disposables = DisposableDict()
                strongSelf.selectMessagePollOptionDisposables = disposables
            }
            let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
            strongSelf.present(controller, in: .window(.root))
            let signal = strongSelf.context.engine.messages.requestMessageSelectPollOption(messageId: id, opaqueIdentifiers: [])
            |> afterDisposed { [weak controller] in
                Queue.mainQueue().async {
                    controller?.dismiss()
                }
            }
            disposables.set((signal
            |> deliverOnMainQueue).start(error: { _ in
                guard let _ = self else {
                    return
                }
            }, completed: {
                if strongSelf.selectPollOptionFeedback == nil {
                    strongSelf.selectPollOptionFeedback = HapticFeedback()
                }
                strongSelf.selectPollOptionFeedback?.success()
            }), forKey: id)
        }, requestStopPollInMessage: { [weak self] id in
            guard let strongSelf = self, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(id) else {
                return
            }
            
            var maybePoll: TelegramMediaPoll?
            for media in message.media {
                if let poll = media as? TelegramMediaPoll {
                    maybePoll = poll
                    break
                }
            }
            
            guard let poll = maybePoll else {
                return
            }
            
            let actionTitle: String
            let actionButtonText: String
            switch poll.kind {
            case .poll:
                actionTitle = strongSelf.presentationData.strings.Conversation_StopPollConfirmationTitle
                actionButtonText = strongSelf.presentationData.strings.Conversation_StopPollConfirmation
            case .quiz:
                actionTitle = strongSelf.presentationData.strings.Conversation_StopQuizConfirmationTitle
                actionButtonText = strongSelf.presentationData.strings.Conversation_StopQuizConfirmation
            }
            
            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: actionTitle),
                ActionSheetButtonItem(title: actionButtonText, color: .destructive, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    guard let strongSelf = self else {
                        return
                    }
                    let disposables: DisposableDict<MessageId>
                    if let current = strongSelf.selectMessagePollOptionDisposables {
                        disposables = current
                    } else {
                        disposables = DisposableDict()
                        strongSelf.selectMessagePollOptionDisposables = disposables
                    }
                    let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                    strongSelf.present(controller, in: .window(.root))
                    let signal = strongSelf.context.engine.messages.requestClosePoll(messageId: id)
                    |> afterDisposed { [weak controller] in
                        Queue.mainQueue().async {
                            controller?.dismiss()
                        }
                    }
                    disposables.set((signal
                    |> deliverOnMainQueue).start(error: { _ in
                    }, completed: {
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.selectPollOptionFeedback == nil {
                            strongSelf.selectPollOptionFeedback = HapticFeedback()
                        }
                        strongSelf.selectPollOptionFeedback?.success()
                    }), forKey: id)
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(actionSheet, in: .window(.root))
        }, updateInputLanguage: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    return $0.updatedInterfaceState({ $0.withUpdatedInputLanguage(f($0.inputLanguage)) })
                })
            }
        }, unarchiveChat: { [weak self] in
            guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            strongSelf.updateChatPresentationInterfaceState(interactive: true, { state in
                return state.updatedTitlePanelContext({
                    $0.filter({ item in
                        if case .chatInfo = item {
                            return false
                        } else {
                            return true
                        }
                    })
                })
            })
            let _ = (strongSelf.context.engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .root)
            |> deliverOnMainQueue).start()
        }, openLinkEditing: { [weak self] in
            if let strongSelf = self {
                var selectionRange: Range<Int>?
                var text: String?
                var inputMode: ChatInputMode?
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
                    selectionRange = state.interfaceState.effectiveInputState.selectionRange
                    if let selectionRange = selectionRange {
                        text = state.interfaceState.effectiveInputState.inputText.attributedSubstring(from: NSRange(location: selectionRange.startIndex, length: selectionRange.count)).string
                    }
                    inputMode = state.inputMode
                    return state
                })
                
                let controller = chatTextLinkEditController(sharedContext: strongSelf.context.sharedContext, updatedPresentationData: strongSelf.updatedPresentationData, account: strongSelf.context.account, text: text ?? "", link: nil, apply: { [weak self] link in
                    if let strongSelf = self, let inputMode = inputMode, let selectionRange = selectionRange {
                        if let link = link {
                            strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                                return (chatTextInputAddLinkAttribute(current, selectionRange: selectionRange, url: link), inputMode)
                            }
                        } else {
                            
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, {
                            return $0.updatedInputMode({ _ in return inputMode }).updatedInterfaceState({
                                $0.withUpdatedEffectiveInputState(ChatTextInputState(inputText: $0.effectiveInputState.inputText, selectionRange: selectionRange.endIndex ..< selectionRange.endIndex))
                            })
                        })
                    }
                })
                strongSelf.present(controller, in: .window(.root))
                
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { $0.updatedInputMode({ _ in return .none }) })
            }
        }, reportPeerIrrelevantGeoLocation: { [weak self] in
            guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            
            strongSelf.chatDisplayNode.dismissInput()
            
            let actions = [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
            }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.ReportGroupLocation_Report, action: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reportIrrelvantGeoDisposable = (strongSelf.context.engine.peers.reportPeer(peerId: peerId, reason: .irrelevantLocation, message: "")
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.reportIrrelvantGeoNoticePromise.set(.single(true))
                        let _ = ApplicationSpecificNotice.setIrrelevantPeerGeoReport(engine: strongSelf.context.engine, peerId: peerId).start()
                        
                        strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .emoji(name: "PoliceCar", text: strongSelf.presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                    }
                })
            })]
            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.ReportGroupLocation_Title, text: strongSelf.presentationData.strings.ReportGroupLocation_Text, actions: actions), in: .window(.root))
        }, displaySlowmodeTooltip: { [weak self] node, nodeRect in
            guard let strongSelf = self, let slowmodeState = strongSelf.presentationInterfaceState.slowmodeState else {
                return
            }
            let rect = node.view.convert(nodeRect, to: strongSelf.view)
            if let slowmodeTooltipController = strongSelf.slowmodeTooltipController {
                if let arguments = slowmodeTooltipController.presentationArguments as? TooltipControllerPresentationArguments, case let .node(f) = arguments.sourceAndRect, let (previousNode, previousRect) = f() {
                    if previousNode === strongSelf.chatDisplayNode && previousRect == rect {
                        return
                    }
                }
                
                strongSelf.slowmodeTooltipController = nil
                slowmodeTooltipController.dismiss()
            }
            let slowmodeTooltipController = ChatSlowmodeHintController(presentationData: strongSelf.presentationData, slowmodeState: 
                slowmodeState)
            slowmodeTooltipController.presentationArguments = TooltipControllerPresentationArguments(sourceNodeAndRect: {
                if let strongSelf = self {
                    return (strongSelf.chatDisplayNode, rect)
                }
                return nil
            })
            strongSelf.slowmodeTooltipController = slowmodeTooltipController
            
            strongSelf.window?.presentInGlobalOverlay(slowmodeTooltipController)
        }, displaySendMessageOptions: { [weak self] node, gesture in
            if let strongSelf = self, let textInputNode = strongSelf.chatDisplayNode.textInputNode(), let layout = strongSelf.validLayout {
                let previousSupportedOrientations = strongSelf.supportedOrientations
                if layout.size.width > layout.size.height {
                    strongSelf.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .landscape)
                } else {
                    strongSelf.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
                }
                
                let _ = ApplicationSpecificNotice.incrementChatMessageOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager, count: 4).start()
                
                let controller = ChatSendMessageActionSheetController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, interfaceState: strongSelf.presentationInterfaceState, gesture: gesture, sourceSendButton: node, textInputNode: textInputNode, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.supportedOrientations = previousSupportedOrientations
                    }
                }, sendMessage: { [weak self] silently in
                    if let strongSelf = self {
                        strongSelf.controllerInteraction?.sendCurrentMessage(silently)
                    }
                }, schedule: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.controllerInteraction?.scheduleCurrentMessage()
                    }
                })
                strongSelf.sendMessageActionsController = controller
                if layout.isNonExclusive {
                    strongSelf.present(controller, in: .window(.root))
                } else {
                    strongSelf.presentInGlobalOverlay(controller, with: nil)
                }
            }
        }, openScheduledMessages: { [weak self] in
            if let strongSelf = self {
                strongSelf.openScheduledMessages()
            }
        }, openPeersNearby: { [weak self] in
            if let strongSelf = self {
                let controller = strongSelf.context.sharedContext.makePeersNearbyController(context: strongSelf.context)
                controller.navigationPresentation = .master
                strongSelf.effectiveNavigationController?.pushViewController(controller, animated: true, completion: { })
            }
        }, displaySearchResultsTooltip: { [weak self] node, nodeRect in
            if let strongSelf = self {
                strongSelf.searchResultsTooltipController?.dismiss()
                let tooltipController = TooltipController(content: .text(strongSelf.presentationData.strings.ChatSearch_ResultsTooltip), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
                strongSelf.searchResultsTooltipController = tooltipController
                tooltipController.dismissed = { [weak tooltipController] _ in
                    if let strongSelf = self, let tooltipController = tooltipController, strongSelf.searchResultsTooltipController === tooltipController {
                        strongSelf.searchResultsTooltipController = nil
                    }
                }
                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                    if let strongSelf = self {
                        var rect = node.view.convert(node.view.bounds, to: strongSelf.chatDisplayNode.view)
                        rect = CGRect(origin: rect.origin.offsetBy(dx: nodeRect.minX, dy: nodeRect.minY - node.bounds.minY), size: nodeRect.size)
                        return (strongSelf.chatDisplayNode, rect)
                    }
                    return nil
                }))
           }
        }, unarchivePeer: { [weak self] in
            guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            unarchiveAutomaticallyArchivedPeer(account: strongSelf.context.account, peerId: peerId)
            
            strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .succeed(text: strongSelf.presentationData.strings.Conversation_UnarchiveDone), elevatedLayout: false, action: { _ in return false }), in: .current)
        }, scrollToTop: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.chatDisplayNode.historyNode.scrollToStartOfHistory()
        }, viewReplies: { [weak self] sourceMessageId, replyThreadResult in
            guard let strongSelf = self else {
                return
            }
            
            if let navigationController = strongSelf.effectiveNavigationController {
                let subject: ChatControllerSubject? = sourceMessageId.flatMap { ChatControllerSubject.message(id: .id($0), highlight: true, timecode: nil) }
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .replyThread(message: replyThreadResult), subject: subject, keepStack: .always))
            }
        }, activatePinnedListPreview: { [weak self] node, gesture in
            guard let strongSelf = self else {
                return
            }
            guard case let .peer(peerId) = strongSelf.chatLocation else {
                return
            }
            guard let pinnedMessage = strongSelf.presentationInterfaceState.pinnedMessage else {
                return
            }
            let count = pinnedMessage.totalCount
            let topMessageId = pinnedMessage.topMessageId
            
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_PinnedListPreview_ShowAllMessages, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PinnedList"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.openPinnedMessages(at: nil)
                f(.dismissWithoutContent)
            })))
            
            if strongSelf.canManagePin() {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_PinnedListPreview_UnpinAllMessages, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unpin"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.performRequestedUnpinAllMessages(count: count, pinnedMessageId: topMessageId)
                    f(.dismissWithoutContent)
                })))
            } else {
                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_PinnedListPreview_HidePinnedMessages, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unpin"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    strongSelf.performUpdatedClosedPinnedMessageId(pinnedMessageId: topMessageId)
                    f(.dismissWithoutContent)
                })))
            }
            
            let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: .pinnedMessages(id: pinnedMessage.message.id), botStart: nil, mode: .standard(previewing: true))
            chatController.canReadHistory.set(false)
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            strongSelf.presentInGlobalOverlay(contextController)
        }, joinGroupCall: { [weak self] activeCall in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            strongSelf.joinGroupCall(peerId: peer.id, invite: nil, activeCall: EngineGroupCallDescription(activeCall))
        }, presentInviteMembers: { [weak self] in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            if !(peer is TelegramGroup || peer is TelegramChannel) {
                return
            }
            presentAddMembers(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, parentController: strongSelf, groupPeer: peer, selectAddMemberDisposable: strongSelf.selectAddMemberDisposable, addMemberDisposable: strongSelf.addMemberDisposable)
        }, presentGigagroupHelp: { [weak self] in
            if let strongSelf = self {
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(title: nil, text: strongSelf.presentationData.strings.Conversation_GigagroupDescription), elevatedLayout: false, action: { _ in return true }), in: .current)
            }
        }, editMessageMedia: { [weak self] messageId, draw in
            if let strongSelf = self {
                strongSelf.controllerInteraction?.editMessageMedia(messageId, draw)
            }
        }, updateShowCommands: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedShowCommands(f($0.showCommands))
                })
            }
        }, updateShowSendAsPeers: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedShowSendAsPeers(f($0.showSendAsPeers))
                })
            }
        }, openInviteRequests: { [weak self] in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                let controller = inviteRequestsController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peerId: peer.id, existingContext: strongSelf.inviteRequestsContext)
                controller.navigationPresentation = .modal
                strongSelf.push(controller)
            }
        }, openSendAsPeer: { [weak self] node, gesture in
            guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId, let node = node as? ContextReferenceContentNode, let peers = strongSelf.presentationInterfaceState.sendAsPeers, let layout = strongSelf.validLayout else {
                return
            }
            
            let cleanInsets = layout.intrinsicInsets
            let insets = layout.insets(options: .input)
            let bottomInset = max(insets.bottom, cleanInsets.bottom) + 43.0
            
            let defaultMyPeerId: PeerId
            if let channel = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case .group = channel.info, channel.hasPermission(.canBeAnonymous) {
                defaultMyPeerId = channel.id
            } else {
                defaultMyPeerId = strongSelf.context.account.peerId
            }
            let myPeerId = strongSelf.presentationInterfaceState.currentSendAsPeerId ?? defaultMyPeerId
            
            var items: [ContextMenuItem] = []
            items.append(.custom(ChatSendAsPeerTitleContextItem(text: strongSelf.presentationInterfaceState.strings.Conversation_SendMesageAs.uppercased()), false))
            items.append(.custom(ChatSendAsPeerListContextItem(context: strongSelf.context, chatPeerId: peerId, peers: peers, selectedPeerId: myPeerId), false))
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .reference(ChatControllerContextReferenceContentSource(controller: strongSelf, sourceView: node.view, insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0))), items: .single(ContextController.Items(content: .list(items))), gesture: gesture, workaroundUseLegacyImplementation: true)
            contextController.dismissed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                        return $0.updatedShowSendAsPeers(false)
                    })
                }
            }
            strongSelf.presentInGlobalOverlay(contextController)
            
            strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                return $0.updatedShowSendAsPeers(true)
            })
        }, presentChatRequestAdminInfo: { [weak self] in
            self?.presentChatRequestAdminInfo()
        }, displayCopyProtectionTip: { [weak self] node, save in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer, let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds {
                let _ = (strongSelf.context.engine.data.get(EngineDataMap(
                    messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
                ))
                |> map { messages -> [EngineMessage] in
                    return messages.values.compactMap { $0 }
                }
                |> deliverOnMainQueue).start(next: { [weak self] messages in
                    guard let strongSelf = self else {
                        return
                    }
                    enum PeerType {
                        case group
                        case channel
                        case bot
                        case user
                    }
                    var isBot = false
                    for message in messages {
                        if let author = message.author, case let .user(user) = author, user.botInfo != nil {
                            isBot = true
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
                        text = save ? strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionSavingDisabledGroup : strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionForwardingDisabledGroup
                    case .channel:
                        text = save ? strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionSavingDisabledChannel : strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionForwardingDisabledChannel
                    case .bot:
                        text = save ? strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionSavingDisabledBot : strongSelf.presentationInterfaceState.strings.Conversation_CopyProtectionForwardingDisabledBot
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
                    strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: {
                        if let strongSelf = self {
                            let rect = node.view.convert(node.view.bounds, to: strongSelf.chatDisplayNode.view).offsetBy(dx: 0.0, dy: 3.0)
                            return (strongSelf.chatDisplayNode, rect)
                        }
                        return nil
                    }))
                })
           }
        }, openWebView: { [weak self] buttonText, url, simple, fromMenu in
            if let strongSelf = self {
                strongSelf.controllerInteraction?.openWebView(buttonText, url, simple, fromMenu)
            }
        }, updateShowWebView: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(interactive: true, {
                    return $0.updatedShowWebView(f($0.showWebView))
                })
            }
        }, chatController: { [weak self] in
            return self
        }, statuses: ChatPanelInterfaceInteractionStatuses(editingMessage: self.editingMessage.get(), startingBot: self.startingBot.get(), unblockingPeer: self.unblockingPeer.get(), searching: self.searching.get(), loadingMessage: self.loadingMessage.get(), inlineSearch: self.performingInlineSearch.get()))
        
        do {
            let peerId = self.chatLocation.peerId
            if let subject = self.subject, case .scheduledMessages = subject {
            } else {
                self.buttonUnreadCountDisposable = (self.context.chatLocationUnreadCount(for: self.chatLocation, contextHolder: self.chatLocationContextHolder)
                |> deliverOnMainQueue).start(next: { [weak self] count in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatDisplayNode.navigateButtons.unreadCount = Int32(count)
                })

                if case let .peer(peerId) = self.chatLocation {
                    self.chatUnreadCountDisposable = (self.context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Messages.PeerUnreadCount(id: peerId),
                        TelegramEngine.EngineData.Item.Messages.TotalReadCounters(),
                        TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId)
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] peerUnreadCount, totalReadCounters, notificationSettings in
                        guard let strongSelf = self else {
                            return
                        }
                        let unreadCount: Int32 = Int32(peerUnreadCount)
                        
                        let inAppSettings = strongSelf.context.sharedContext.currentInAppNotificationSettings.with { $0 }
                        let totalChatCount: Int32 = renderedTotalUnreadCount(inAppSettings: inAppSettings, totalUnreadState: totalReadCounters._asCounters()).0
                        
                        var globalRemainingUnreadChatCount = totalChatCount
                        if !notificationSettings._asNotificationSettings().isRemovedFromTotalUnreadCount(default: false) && unreadCount > 0 {
                            if case .messages = inAppSettings.totalUnreadCountDisplayCategory {
                                globalRemainingUnreadChatCount -= unreadCount
                            } else {
                                globalRemainingUnreadChatCount -= 1
                            }
                        }
                        
                        if globalRemainingUnreadChatCount > 0 {
                            strongSelf.navigationItem.badge = "\(globalRemainingUnreadChatCount)"
                        } else {
                            strongSelf.navigationItem.badge = ""
                        }
                    })
                
                    self.chatUnreadMentionCountDisposable = (self.context.account.viewTracker.unseenPersonalMessagesAndReactionCount(peerId: peerId) |> deliverOnMainQueue).start(next: { [weak self] mentionCount, reactionCount in
                        if let strongSelf = self {
                            if case let .standard(previewing) = strongSelf.presentationInterfaceState.mode, previewing {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = 0
                                strongSelf.chatDisplayNode.navigateButtons.reactionsCount = 0
                            } else {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = mentionCount
                                strongSelf.chatDisplayNode.navigateButtons.reactionsCount = reactionCount
                            }
                        }
                    })
                }
                
                let engine = self.context.engine
                let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])

                let activitySpace: PeerActivitySpace?
                switch self.chatLocation {
                case let .peer(peerId):
                    activitySpace = PeerActivitySpace(peerId: peerId, category: .global)
                case let .replyThread(replyThreadMessage):
                    activitySpace = PeerActivitySpace(peerId: replyThreadMessage.messageId.peerId, category: .thread(makeMessageThreadId(replyThreadMessage.messageId)))
                case .feed:
                    activitySpace = nil
                }
                
                if let activitySpace = activitySpace, let peerId = peerId {
                    self.peerInputActivitiesDisposable = (self.context.account.peerInputActivities(peerId: activitySpace)
                    |> mapToSignal { activities -> Signal<[(Peer, PeerInputActivity)], NoError> in
                        var foundAllPeers = true
                        var cachedResult: [(Peer, PeerInputActivity)] = []
                        previousPeerCache.with { dict -> Void in
                            for (peerId, activity) in activities {
                                if let peer = dict[peerId] {
                                    cachedResult.append((peer, activity))
                                } else {
                                    foundAllPeers = false
                                    break
                                }
                            }
                        }
                        if foundAllPeers {
                            return .single(cachedResult)
                        } else {
                            return engine.data.get(EngineDataMap(
                                activities.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0.0) }
                            ))
                            |> map { peerMap -> [(Peer, PeerInputActivity)] in
                                var result: [(Peer, PeerInputActivity)] = []
                                var peerCache: [PeerId: Peer] = [:]
                                for (peerId, activity) in activities {
                                    if let maybePeer = peerMap[peerId], let peer = maybePeer {
                                        result.append((peer._asPeer(), activity))
                                        peerCache[peerId] = peer._asPeer()
                                    }
                                }
                                let _ = previousPeerCache.swap(peerCache)
                                return result
                            }
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] activities in
                        if let strongSelf = self {
                            let displayActivities = activities.filter({
                                switch $0.1 {
                                    case .speakingInGroupCall, .interactingWithEmoji:
                                        return false
                                    default:
                                        return true
                                }
                            })
                            strongSelf.chatTitleView?.inputActivities = (peerId, displayActivities)
                            
                            strongSelf.peerInputActivitiesPromise.set(.single(activities))
                            
                            for activity in activities {
                                if case let .interactingWithEmoji(emoticon, messageId, maybeInteraction) = activity.1, let interaction = maybeInteraction {
                                    var found = false
                                    strongSelf.chatDisplayNode.historyNode.forEachVisibleItemNode({ itemNode in
                                        if !found, let itemNode = itemNode as? ChatMessageAnimatedStickerItemNode, let item = itemNode.item {
                                            if item.message.id == messageId {
                                                itemNode.playEmojiInteraction(interaction)
                                                found = true
                                            }
                                        }
                                    })
                                    
                                    if found {
                                        let _ = strongSelf.context.account.updateLocalInputActivity(peerId: activitySpace, activity: .seeingEmojiInteraction(emoticon: emoticon), isPresent: true)
                                    }
                                }
                            }
                        }
                    })
                }
            }
            
            if let peerId = peerId {
                self.sentMessageEventsDisposable.set((self.context.account.pendingMessageManager.deliveredMessageEvents(peerId: peerId)
                |> deliverOnMainQueue).start(next: { [weak self] namespace, silent in
                    if let strongSelf = self {
                        let inAppNotificationSettings = strongSelf.context.sharedContext.currentInAppNotificationSettings.with { $0 }
                        if inAppNotificationSettings.playSounds && !silent {
                            serviceSoundManager.playMessageDeliveredSound()
                        }
                        if strongSelf.presentationInterfaceState.subject != .scheduledMessages && namespace == Namespaces.Message.ScheduledCloud {
                            strongSelf.openScheduledMessages()
                        }
                        
                        if strongSelf.shouldDisplayChecksTooltip {
                            Queue.mainQueue().after(1.0) {
                                strongSelf.displayChecksTooltip()
                            }
                            strongSelf.shouldDisplayChecksTooltip = false
                            strongSelf.checksTooltipDisposable.set(dismissServerProvidedSuggestion(account: strongSelf.context.account, suggestion: .newcomerTicks).start())
                        }
                    }
                }))
            
                self.failedMessageEventsDisposable.set((self.context.account.pendingMessageManager.failedMessageEvents(peerId: peerId)
                |> deliverOnMainQueue).start(next: { [weak self] reason in
                    if let strongSelf = self, strongSelf.currentFailedMessagesAlertController == nil {
                        let text: String
                        let moreInfo: Bool
                        switch reason {
                        case .flood:
                            text = strongSelf.presentationData.strings.Conversation_SendMessageErrorFlood
                            moreInfo = true
                        case .publicBan:
                            text = strongSelf.presentationData.strings.Conversation_SendMessageErrorGroupRestricted
                            moreInfo = true
                        case .mediaRestricted:
                            strongSelf.interfaceInteraction?.displayRestrictedInfo(.mediaRecording, .alert)
                            return
                        case .slowmodeActive:
                            text = strongSelf.presentationData.strings.Chat_SlowmodeSendError
                            moreInfo = false
                        case .tooMuchScheduled:
                            text = strongSelf.presentationData.strings.Conversation_SendMessageErrorTooMuchScheduled
                            moreInfo = false
                        }
                        let actions: [TextAlertAction]
                        if moreInfo {
                            actions = [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Generic_ErrorMoreInfo, action: {
                                self?.openPeerMention("spambot", navigation: .chat(textInputState: nil, subject: nil, peekData: nil))
                            }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]
                        } else {
                            actions = [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]
                        }
                        let controller = textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: text, actions: actions)
                        strongSelf.currentFailedMessagesAlertController = controller
                        strongSelf.present(controller, in: .window(.root))
                    }
                }))
            }
        }
        
        self.interfaceInteraction = interfaceInteraction
        
        if let search = self.focusOnSearchAfterAppearance {
            self.focusOnSearchAfterAppearance = nil
            self.interfaceInteraction?.beginMessageSearch(search.0, search.1)
        }
        
        self.chatDisplayNode.interfaceInteraction = interfaceInteraction
        
        self.context.sharedContext.mediaManager.galleryHiddenMediaManager.addTarget(self)
        self.galleryHiddenMesageAndMediaDisposable.set(self.context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                var messageIdAndMedia: [MessageId: [Media]] = [:]
                
                for id in ids {
                    if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                        messageIdAndMedia[messageId] = [media]
                    }
                }
                
                controllerInteraction.hiddenMedia = messageIdAndMedia
            
                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView {
                        itemNode.updateHiddenMedia()
                    }
                }
            }
        }))
        
        self.chatDisplayNode.dismissAsOverlay = { [weak self] in
            if let strongSelf = self {
                strongSelf.statusBar.statusBarStyle = .Ignore
                strongSelf.chatDisplayNode.animateDismissAsOverlay(completion: {
                    self?.dismiss()
                })
            }
        }
        
        let hasActiveCalls: Signal<Bool, NoError>
        if let callManager = self.context.sharedContext.callManager as? PresentationCallManagerImpl {
            hasActiveCalls = callManager.hasActiveCalls
            
            self.hasActiveGroupCallDisposable = ((callManager.currentGroupCallSignal
            |> map { call -> Bool in
                return call != nil
            }) |> deliverOnMainQueue).start(next: { [weak self] hasActiveGroupCall in
                self?.updateChatPresentationInterfaceState(animated: true, interactive: false, { state in
                    return state.updatedHasActiveGroupCall(hasActiveGroupCall)
                })
            })
        } else {
            hasActiveCalls = .single(false)
        }
        
        let shouldBeActive = combineLatest(self.context.sharedContext.mediaManager.audioSession.isPlaybackActive() |> deliverOnMainQueue, self.chatDisplayNode.historyNode.hasVisiblePlayableItemNodes, hasActiveCalls)
        |> mapToSignal { [weak self] isPlaybackActive, hasVisiblePlayableItemNodes, hasActiveCalls -> Signal<Bool, NoError> in
            if hasVisiblePlayableItemNodes && !isPlaybackActive && !hasActiveCalls {
                return Signal<Bool, NoError> { [weak self] subscriber in
                    guard let strongSelf = self else {
                        subscriber.putCompletion()
                        return EmptyDisposable
                    }
                    
                    subscriber.putNext(strongSelf.traceVisibility() && isTopmostChatController(strongSelf) && !strongSelf.context.sharedContext.mediaManager.audioSession.isOtherAudioPlaying())
                    subscriber.putCompletion()
                    return EmptyDisposable
                } |> then(.complete() |> delay(1.0, queue: Queue.mainQueue())) |> restart
            } else {
                return .single(false)
            }
        }
        
        self.volumeButtonsListener = VolumeButtonsListener(shouldBeActive: shouldBeActive, valueChanged: { [weak self] in
            guard let strongSelf = self, strongSelf.traceVisibility() && isTopmostChatController(strongSelf) else {
                return
            }
            strongSelf.videoUnmuteTooltipController?.dismiss()
            
            var actions: [(Bool, (Double?) -> Void)] = []
            var hasUnconsumed = false
            strongSelf.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView, let (action, _, _, isUnconsumed, _) = itemNode.playMediaWithSound() {
                    if case let .visible(fraction, _) = itemNode.visibility, fraction > 0.7 {
                        actions.insert((isUnconsumed, action), at: 0)
                        if !hasUnconsumed && isUnconsumed {
                            hasUnconsumed = true
                        }
                    }
                }
            }
            for (isUnconsumed, action) in actions {
                if (!hasUnconsumed || isUnconsumed) {
                    action(nil)
                    break
                }
            }
        })

        self.chatDisplayNode.historyNode.openNextChannelToRead = { [weak self] peer, location in
            guard let strongSelf = self else {
                return
            }
            if let navigationController = strongSelf.effectiveNavigationController {
                let _ = ApplicationSpecificNotice.incrementNextChatSuggestionTip(accountManager: strongSelf.context.sharedContext.accountManager).start()

                let snapshotState = strongSelf.chatDisplayNode.prepareSnapshotState(
                    titleViewSnapshotState: strongSelf.chatTitleView?.prepareSnapshotState(),
                    avatarSnapshotState: (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.prepareSnapshotState()
                )

                var nextFolderId: Int32?
                switch location {
                case let .folder(id, _):
                    nextFolderId = id
                case .same:
                    nextFolderId = strongSelf.currentChatListFilter
                default:
                    nextFolderId = nil
                }
                
                var updatedChatNavigationStack = strongSelf.chatNavigationStack
                updatedChatNavigationStack.removeAll(where: { $0 ==  peer.id})
                if case let .peer(peerId) = strongSelf.chatLocation {
                    updatedChatNavigationStack.insert(peerId, at: 0)
                }

                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peer.id), animated: false, chatListFilter: nextFolderId, chatNavigationStack: updatedChatNavigationStack, completion: { nextController in
                    (nextController as! ChatControllerImpl).animateFromPreviousController(snapshotState: snapshotState)
                }))
            }
        }
        
        if case let .forwardedMessages(messageIds, _) = self.subject, messageIds.count > 1 {
            self.updateChatPresentationInterfaceState(interactive: false, { state in
                return state.updatedInterfaceState({ $0.withUpdatedSelectedMessages(messageIds) })
            })
        }
        
        self.displayNodeDidLoad()
    }

    private var storedAnimateFromSnapshotState: ChatControllerNode.SnapshotState?

    private func animateFromPreviousController(snapshotState: ChatControllerNode.SnapshotState) {
        self.storedAnimateFromSnapshotState = snapshotState
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        #if DEBUG
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            os_signpost(
                .begin,
                log: SignpostData.impl.signpostLog,
                name: "Appear",
                signpostID: SignpostData.impl.signpostId
            )
        }
        #endif

        super.viewWillAppear(animated)
                
        if self.willAppear {
            self.chatDisplayNode.historyNode.refreshPollActionsForVisibleMessages()
        } else {
            self.willAppear = true
            
            // Limit this to reply threads just to be safe now
            if case .replyThread = self.chatLocation {
                self.chatDisplayNode.historyNode.refocusOnUnreadMessagesIfNeeded()
            }
        }
        
        if self.scheduledActivateInput {
            self.scheduledActivateInput = false
            
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                return state.updatedInputMode({ _ in .text })
            })
        }
        
        var chatNavigationStack: [PeerId] = self.chatNavigationStack
        if case let .peer(peerId) = self.chatLocation, let summary = self.customNavigationDataSummary as? ChatControllerNavigationDataSummary {
            chatNavigationStack.removeAll()
            chatNavigationStack = summary.peerIds.filter({ $0 != peerId })
        }
        
        if !chatNavigationStack.isEmpty {
            self.chatDisplayNode.navigationBar?.backButtonNode.isGestureEnabled = true
            self.chatDisplayNode.navigationBar?.backButtonNode.activated = { [weak self] gesture, _ in
                guard let strongSelf = self else {
                    gesture.cancel()
                    return
                }
                
                let _ = (strongSelf.context.engine.data.get(EngineDataList(
                    chatNavigationStack.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                ))
                |> deliverOnMainQueue).start(next: { peerList in
                    guard let strongSelf = self, let backButtonNode = strongSelf.chatDisplayNode.navigationBar?.backButtonNode else {
                        return
                    }
                    
                    let peers = peerList.compactMap { $0 }
                    
                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    
                    var items: [ContextMenuItem] = []
                    for peer in peers {
                        let title: String
                        let iconSource: ContextMenuActionItemIconSource?
                        if peer.id == strongSelf.context.account.peerId {
                            title = strongSelf.presentationData.strings.DialogList_SavedMessages
                            iconSource = nil
                        } else {
                            title = peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)
                            iconSource = ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: strongSelf.context.account, peer: peer, size: avatarSize))
                        }
                        
                        let isSavedMessages = peer.id == strongSelf.context.account.peerId
                        
                        items.append(.action(ContextMenuActionItem(text: title, icon: { _ in
                            if isSavedMessages {
                                return generateAvatarImage(size: avatarSize, icon: savedMessagesIcon, iconScale: 0.5, color: .blue)
                            }
                            return nil
                        }, iconSource: iconSource, action: { _, f in
                            f(.default)
                            
                            guard let strongSelf = self, let navigationController = strongSelf.effectiveNavigationController else {
                                return
                            }

                            let nextFolderId: Int32? = strongSelf.currentChatListFilter
                            
                            var updatedChatNavigationStack = strongSelf.chatNavigationStack
                            if let index = updatedChatNavigationStack.firstIndex(of: peer.id) {
                                updatedChatNavigationStack.removeSubrange(0 ..< (index + 1))
                            }

                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peer.id), useBackAnimation: true, animated: true, chatListFilter: nextFolderId, chatNavigationStack: updatedChatNavigationStack, completion: { nextController in
                                let _ = nextController
                            }))
                        })))
                    }
                    let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .reference(ChatControllerContextReferenceContentSource(controller: strongSelf, sourceView: backButtonNode.view, insets: UIEdgeInsets(), contentInsets: UIEdgeInsets(top: 0.0, left: -15.0, bottom: 0.0, right: -15.0))), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                    strongSelf.presentInGlobalOverlay(contextController)
                })
            }
        }
    }
    
    private var returnInputViewFocus = false
    
    override public func viewDidAppear(_ animated: Bool) {
        #if DEBUG
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            os_signpost(
                .end,
                log: SignpostData.impl.signpostLog,
                name: "Appear",
                signpostID: SignpostData.impl.signpostId
            )
        }
        #endif

        super.viewDidAppear(animated)
        
        self.didAppear = true
        
        self.chatDisplayNode.historyNode.experimentalSnapScrollToItem = false
        self.chatDisplayNode.historyNode.canReadHistory.set(combineLatest(context.sharedContext.applicationBindings.applicationInForeground, self.canReadHistory.get()) |> map { a, b in
            return a && b
        })
        
        self.chatDisplayNode.loadInputPanels(theme: self.presentationInterfaceState.theme, strings: self.presentationInterfaceState.strings, fontSize: self.presentationInterfaceState.fontSize)
        
        self.recentlyUsedInlineBotsDisposable = (self.context.engine.peers.recentlyUsedInlineBots() |> deliverOnMainQueue).start(next: { [weak self] peers in
            self?.recentlyUsedInlineBotsValue = peers.filter({ $0.1 >= 0.14 }).map({ $0.0._asPeer() })
        })
        
        if case .standard(false) = self.presentationInterfaceState.mode, self.raiseToListen == nil {
            self.raiseToListen = RaiseToListenManager(shouldActivate: { [weak self] in
                if let strongSelf = self, strongSelf.isNodeLoaded && strongSelf.canReadHistoryValue, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil, strongSelf.playlistStateAndType == nil {
                    if strongSelf.presentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
                        return false
                    }
                    
                    if !strongSelf.traceVisibility() {
                        return false
                    }
                    
                    if !isTopmostChatController(strongSelf) {
                        return false
                    }
                    
                    if strongSelf.firstLoadedMessageToListen() != nil || strongSelf.chatDisplayNode.isTextInputPanelActive {
                        if strongSelf.context.sharedContext.immediateHasOngoingCall {
                            return false
                        }
                        
                        if case let .media(_, expanded, _) = strongSelf.presentationInterfaceState.inputMode, expanded != nil {
                            return false
                        }
                        
                        if !strongSelf.context.sharedContext.currentMediaInputSettings.with({ $0.enableRaiseToSpeak }) {
                            return false
                        }
                        
                        return true
                    }
                }
                return false
            }, activate: { [weak self] in
                self?.activateRaiseGesture()
            }, deactivate: { [weak self] in
                self?.deactivateRaiseGesture()
            })
            self.raiseToListen?.enabled = self.canReadHistoryValue
            self.tempVoicePlaylistEnded = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if !canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                    return
                }
                
                if let raiseToListen = strongSelf.raiseToListen {
                    strongSelf.voicePlaylistDidEndTimestamp = CACurrentMediaTime()
                    raiseToListen.activateBasedOnProximity(delay: 0.0)
                }
                
                if strongSelf.returnInputViewFocus {
                    strongSelf.returnInputViewFocus = false
                    strongSelf.chatDisplayNode.ensureInputViewFocused()
                }
            }
            self.tempVoicePlaylistItemChanged = { [weak self] previousItem, currentItem in
                guard let strongSelf = self, case .peer = strongSelf.chatLocation else {
                    return
                }
                
                strongSelf.chatDisplayNode.historyNode.voicePlaylistItemChanged(previousItem, currentItem)
//                if let currentItem = currentItem?.id as? PeerMessagesMediaPlaylistItemId {
//                    self.controllerInteraction?.currentlyPlayingMessageId = currentItem.messageId
//                    if let previousItem = previousItem?.id as? PeerMessagesMediaPlaylistItemId, previousItem.messageId.peerId == peerId, currentItem.messageId.peerId == peerId, currentItem.messageId != previousItem.messageId {
//                        if strongSelf.chatDisplayNode.historyNode.isMessageVisibleOnScreen(currentItem.messageId) {
//                            strongSelf.navigateToMessage(from: nil, to: .id(currentItem.messageId, nil), scrollPosition: .center(.bottom), rememberInStack: false, animated: true, completion: nil)
//                        }
//                    }
//                }
            }
        }
        
        if let arguments = self.presentationArguments as? ChatControllerOverlayPresentationData {
            //TODO clear arguments
            self.chatDisplayNode.animateInAsOverlay(from: arguments.expandData.0, completion: {
                arguments.expandData.1()
            })
        }
        
        if !self.didSetup3dTouch {
            self.didSetup3dTouch = true
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                let dropInteraction = UIDropInteraction(delegate: self)
                self.chatDisplayNode.view.addInteraction(dropInteraction)
            }
        }
        
        if !self.checkedPeerChatServiceActions {
            self.checkedPeerChatServiceActions = true
            
            if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat, self.screenCaptureManager == nil {
                self.screenCaptureManager = ScreenCaptureDetectionManager(check: { [weak self] in
                    if let strongSelf = self, strongSelf.canReadHistoryValue, strongSelf.traceVisibility() {
                        let _ = strongSelf.context.engine.messages.addSecretChatMessageScreenshot(peerId: peerId).start()
                        return true
                    } else {
                        return false
                    }
                })
            }
            
            if case let .peer(peerId) = self.chatLocation {
                let _ = self.context.engine.peers.checkPeerChatServiceActions(peerId: peerId).start()
            }
            
            if self.chatDisplayNode.frameForInputActionButton() != nil {
                let inputText = self.presentationInterfaceState.interfaceState.effectiveInputState.inputText.string
                if !inputText.isEmpty {
                    if inputText.count > 4 {
                        let _ = (ApplicationSpecificNotice.getChatMessageOptionsTip(accountManager: self.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).start(next: { [weak self] counter in
                            if let strongSelf = self, counter < 3 {
                                let _ = ApplicationSpecificNotice.incrementChatMessageOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                strongSelf.displaySendingOptionsTooltip()
                            }
                        })
                    }
                } else if self.presentationInterfaceState.interfaceState.mediaRecordingMode == .audio {
                    var canSendMedia = false
                    if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
                        if channel.hasBannedPermission(.banSendMedia) == nil {
                            canSendMedia = true
                        }
                    } else if let group = self.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                        if !group.hasBannedPermission(.banSendMedia) {
                            canSendMedia = true
                        }
                    } else {
                        canSendMedia = true
                    }
                    if canSendMedia {
                        let _ = (ApplicationSpecificNotice.getChatMediaMediaRecordingTips(accountManager: self.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).start(next: { [weak self] counter in
                            guard let strongSelf = self else {
                                return
                            }
                            var displayTip = false
                            if counter == 0 {
                                displayTip = true
                            } else if counter < 3 && arc4random_uniform(4) == 1 {
                                displayTip = true
                            }
                            if displayTip {
                                let _ = ApplicationSpecificNotice.incrementChatMediaMediaRecordingTips(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                strongSelf.displayMediaRecordingTooltip()
                            }
                        })
                    }
                }
            }
            
            self.editMessageErrorsDisposable.set((self.context.account.pendingUpdateMessageManager.errors
            |> deliverOnMainQueue).start(next: { [weak self] (_, error) in
                guard let strongSelf = self else {
                    return
                }
                
                let text: String
                switch error {
                case .generic, .textTooLong, .invalidGrouping:
                    text = strongSelf.presentationData.strings.Channel_EditMessageErrorGeneric
                case .restricted:
                    text = strongSelf.presentationData.strings.Group_ErrorSendRestrictedMedia
                }
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                })]), in: .window(.root))
            }))
            
            if case let .peer(peerId) = self.chatLocation {
                let context = self.context
                self.keepPeerInfoScreenDataHotDisposable.set(keepPeerInfoScreenDataHot(context: context, peerId: peerId).start())
                
                if peerId.namespace == Namespaces.Peer.CloudUser {
                    self.preloadAvatarDisposable.set((peerInfoProfilePhotosWithCache(context: context, peerId: peerId)
                    |> mapToSignal { (complete, result) -> Signal<Never, NoError> in
                        var signals: [Signal<Never, NoError>] = [.complete()]
                        for i in 0 ..< min(1, result.count) {
                            if let video = result[i].videoRepresentations.first {
                                let duration: Double = (video.representation.startTimestamp ?? 0.0) + (i == 0 ? 4.0 : 2.0)
                                signals.append(preloadVideoResource(postbox: context.account.postbox, resourceReference: video.reference, duration: duration))
                            }
                        }
                        return combineLatest(signals) |> mapToSignal { _ in
                            return .never()
                        }
                    }).start())
                }
            }
            
            self.preloadAttachBotIconsDisposables = AttachmentController.preloadAttachBotIcons(context: self.context)
        }
        
        if let _ = self.focusOnSearchAfterAppearance {
            self.focusOnSearchAfterAppearance = nil
            if let searchNode = self.navigationBar?.contentNode as? ChatSearchNavigationContentNode {
                searchNode.activate()
            }
        }
        
        if let peekData = self.peekData, case let .peer(peerId) = self.chatLocation {
            let timestamp = Int32(Date().timeIntervalSince1970)
            let remainingTime = max(1, peekData.deadline - timestamp)
            self.peekTimerDisposable.set((
                combineLatest(
                    self.context.account.postbox.peerView(id: peerId),
                    Signal<Bool, NoError>.single(true)
                    |> suspendAwareDelay(Double(remainingTime), granularity: 2.0, queue: .mainQueue())
                )
                |> deliverOnMainQueue
            ).start(next: { [weak self] peerView, _ in
                guard let strongSelf = self, let peer = peerViewMainPeer(peerView) else {
                    return
                }
                if let peer = peer as? TelegramChannel {
                    switch peer.participationStatus {
                    case .member:
                        return
                    default:
                        break
                    }
                }
                strongSelf.present(textAlertController(
                    context: strongSelf.context,
                    title: strongSelf.presentationData.strings.Conversation_PrivateChannelTimeLimitedAlertTitle,
                    text: strongSelf.presentationData.strings.Conversation_PrivateChannelTimeLimitedAlertText,
                    actions: [
                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_PrivateChannelTimeLimitedAlertJoin, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.peekTimerDisposable.set(
                                (strongSelf.context.engine.peers.joinChatInteractively(with: peekData.linkData)
                                |> deliverOnMainQueue).start(next: { peerId in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if peerId == nil {
                                        strongSelf.dismiss()
                                    }
                                }, error: { _ in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.dismiss()
                                })
                            )
                        }),
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.dismiss()
                        })
                    ],
                    actionLayout: .vertical,
                    dismissOnOutsideTap: false
                ), in: .window(.root))
            }))
        }
        
        self.checksTooltipDisposable.set((getServerProvidedSuggestions(account: self.context.account)
        |> deliverOnMainQueue).start(next: { [weak self] values in
            guard let strongSelf = self, strongSelf.chatLocation.peerId != strongSelf.context.account.peerId else {
                return
            }
            if !values.contains(.newcomerTicks) {
                return
            }
            strongSelf.shouldDisplayChecksTooltip = true
        }))
        
        if case let .peer(peerId) = self.chatLocation {
            self.peerSuggestionsDisposable.set((getPeerSpecificServerProvidedSuggestions(postbox: self.context.account.postbox, peerId: peerId)
            |> deliverOnMainQueue).start(next: { [weak self] values in
                guard let strongSelf = self else {
                    return
                }
                
                if !strongSelf.traceVisibility() || strongSelf.navigationController?.topViewController != strongSelf {
                    return
                }
                
                if values.contains(.convertToGigagroup) && !strongSelf.displayedConvertToGigagroupSuggestion {
                    strongSelf.displayedConvertToGigagroupSuggestion = true
                    
                    let attributedTitle = NSAttributedString(string: strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_Title, font: Font.medium(17.0), textColor: strongSelf.presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                    let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: strongSelf.presentationData.theme.actionSheet.primaryTextColor)
                    let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: strongSelf.presentationData.theme.actionSheet.primaryTextColor)
                    
                    let participantsLimit = strongSelf.context.currentLimitsConfiguration.with { $0 }.maxSupergroupMemberCount
                    let text = strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_Text(presentationStringsFormattedNumber(participantsLimit, strongSelf.presentationData.dateTimeFormat.groupingSeparator)).string
                    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
                    
                    let controller = richTextAlertController(context: strongSelf.context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                        strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(title: nil, text: strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_SettingsTip), elevatedLayout: false, action: { _ in return false }), in: .current)
                    }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_LearnMore, action: {
                        
                        let context = strongSelf.context
                        let presentationData = strongSelf.presentationData
                        let controller = PermissionController(context: context, splashScreen: true)
                        controller.navigationPresentation = .modal
                        controller.setState(.custom(icon: .animation("BroadcastGroup"), title: presentationData.strings.BroadcastGroups_IntroTitle, subtitle: nil, text: presentationData.strings.BroadcastGroups_IntroText, buttonTitle: presentationData.strings.BroadcastGroups_Convert, secondaryButtonTitle: presentationData.strings.BroadcastGroups_Cancel, footerText: nil), animated: false)
                        controller.proceed = { [weak controller] result in
                            let attributedTitle = NSAttributedString(string: presentationData.strings.BroadcastGroups_ConfirmationAlert_Title, font: Font.medium(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                            let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
                            let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
                            let attributedText = parseMarkdownIntoAttributedString(presentationData.strings.BroadcastGroups_ConfirmationAlert_Text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
                            
                            let alertController = richTextAlertController(context: context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                let _ = dismissPeerSpecificServerProvidedSuggestion(account: context.account, peerId: peerId, suggestion: .convertToGigagroup).start()
                            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.BroadcastGroups_ConfirmationAlert_Convert, action: { [weak controller] in
                                controller?.dismiss()
                                
                                let _ = dismissPeerSpecificServerProvidedSuggestion(account: context.account, peerId: peerId, suggestion: .convertToGigagroup).start()
                                
                                let _ = (convertGroupToGigagroup(account: context.account, peerId: peerId)
                                |> deliverOnMainQueue).start(completed: {
                                    let participantsLimit = context.currentLimitsConfiguration.with { $0 }.maxSupergroupMemberCount
                                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .gigagroupConversion(text: presentationData.strings.BroadcastGroups_Success(presentationStringsFormattedNumber(participantsLimit, presentationData.dateTimeFormat.decimalSeparator)).string), elevatedLayout: false, action: { _ in return false }), in: .current)
                                })
                            })])
                            controller?.present(alertController, in: .window(.root))
                        }
                        strongSelf.push(controller)
                    })])
                    strongSelf.present(controller, in: .window(.root))
                }
            }))
        }
        
        if self.scheduledActivateInput {
            self.scheduledActivateInput = false
            
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                return state.updatedInputMode({ _ in .text })
            })
        }

        if let snapshotState = self.storedAnimateFromSnapshotState {
            self.storedAnimateFromSnapshotState = nil

            if let titleViewSnapshotState = snapshotState.titleViewSnapshotState {
                self.chatTitleView?.animateFromSnapshot(titleViewSnapshotState)
            }
            if let avatarSnapshotState = snapshotState.avatarSnapshotState {
                (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.animateFromSnapshot(avatarSnapshotState)
            }
            self.chatDisplayNode.animateFromSnapshot(snapshotState, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.chatDisplayNode.historyNode.preloadPages = true
            })
        } else {
            self.chatDisplayNode.historyNode.preloadPages = true
        }
        
        if let attachBotStart = self.attachBotStart {
            self.attachBotStart = nil
            self.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload)
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UIView.performWithoutAnimation {
            self.view.endEditing(true)
        }
        
        self.chatDisplayNode.historyNode.canReadHistory.set(.single(false))
        self.saveInterfaceState()
        
        self.dismissAllTooltips()
        
        self.sendMessageActionsController?.dismiss()
        self.themeSceen?.dismiss()
        
        self.attachmentController?.dismiss()
        
        self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
        
        if let _ = self.peekData {
            self.peekTimerDisposable.set(nil)
        }
    }
    
    private func saveInterfaceState(includeScrollState: Bool = true) {
        if case .forwardedMessages = self.subject {
            return
        }
        
        var peerId: PeerId
        var threadId: Int64?
        switch self.chatLocation {
        case let .peer(peerIdValue):
            peerId = peerIdValue
        case let .replyThread(replyThreadMessage):
            peerId = replyThreadMessage.messageId.peerId
            threadId = makeMessageThreadId(replyThreadMessage.messageId)
        case .feed:
            return
        }
        
        let timestamp = Int32(Date().timeIntervalSince1970)
        var interfaceState = self.presentationInterfaceState.interfaceState.withUpdatedTimestamp(timestamp)
        if includeScrollState && threadId == nil {
            let scrollState = self.chatDisplayNode.historyNode.immediateScrollState()
            interfaceState = interfaceState.withUpdatedHistoryScrollState(scrollState)
        }
        interfaceState = interfaceState.withUpdatedInputLanguage(self.chatDisplayNode.currentTextInputLanguage)
        let _ = ChatInterfaceState.update(engine: self.context.engine, peerId: peerId, threadId: threadId, { _ in
            return interfaceState
        }).start()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, {
            $0.updatedTitlePanelContext {
                if let index = $0.firstIndex(where: {
                    switch $0 {
                        case .chatInfo:
                            return true
                        default:
                            return false
                    }
                }) {
                    var updatedContexts = $0
                    updatedContexts.remove(at: index)
                    return updatedContexts
                } else {
                    return $0
                }
            }
        })
    }
    
    override public func viewWillLeaveNavigation() {
        self.chatDisplayNode.willNavigateAway()
    }
    
    override public func inFocusUpdated(isInFocus: Bool) {
        self.disableStickerAnimationsPromise.set(!isInFocus)
        self.chatDisplayNode.inFocusUpdated(isInFocus: isInFocus)
    }
    
    private func canManagePin() -> Bool {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return false
        }
        
        var canManagePin = false
        if let channel = peer as? TelegramChannel {
            canManagePin = channel.hasPermission(.pinMessages)
        } else if let group = peer as? TelegramGroup {
            switch group.role {
                case .creator, .admin:
                    canManagePin = true
                default:
                    if let defaultBannedRights = group.defaultBannedRights {
                        canManagePin = !defaultBannedRights.flags.contains(.banPinMessages)
                    } else {
                        canManagePin = true
                    }
            }
        } else if let _ = peer as? TelegramUser, self.presentationInterfaceState.explicitelyCanPinMessages {
            canManagePin = true
        }
        
        return canManagePin
    }

    private var suspendNavigationBarLayout: Bool = false
    private var suspendedNavigationBarLayout: ContainerViewLayout?
    private var additionalNavigationBarBackgroundHeight: CGFloat = 0.0

    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.suspendNavigationBarLayout {
            self.suspendedNavigationBarLayout = layout
            return
        }
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, transition: transition)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.suspendNavigationBarLayout = true
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        self.chatTitleView?.layout = layout
        
        switch self.presentationInterfaceState.mode {
        case .standard, .inline:
            break
        case .overlay:
            if case .Ignore = self.statusBar.statusBarStyle {
            } else if layout.safeInsets.top.isZero {
                self.statusBar.statusBarStyle = .Hide
            } else {
                self.statusBar.statusBarStyle = .Ignore
            }
        }
        
        var layout = layout
        if case .compact = layout.metrics.widthClass, let _ = self.attachmentController {
            layout = layout.withUpdatedInputHeight(nil)
        }
                
        var navigationBarTransition = transition
        self.chatDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition, listViewTransaction: { updateSizeAndInsets, additionalScrollDistance, scrollToTop, completion in
            self.chatDisplayNode.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: additionalScrollDistance, scrollToTop: scrollToTop, completion: completion)
        }, updateExtraNavigationBarBackgroundHeight: { value, extraNavigationTransition in
            navigationBarTransition = extraNavigationTransition
            self.additionalNavigationBarBackgroundHeight = value
        })
        
        if case .compact = layout.metrics.widthClass {
            let hasOverlayNodes = self.context.sharedContext.mediaManager.overlayMediaManager.controller?.hasNodes ?? false
            if self.validLayout != nil && layout.size.width > layout.size.height && !hasOverlayNodes && self.traceVisibility() && isTopmostChatController(self) {
                var completed = false
                self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                    if !completed, let itemNode = itemNode as? ChatMessageItemView, let message = itemNode.item?.message, let (_, soundEnabled, _, _, _) = itemNode.playMediaWithSound(), soundEnabled {
                        let _ = self.controllerInteraction?.openMessage(message, .landscape)
                        completed = true
                    }
                }
            }
        }

        self.suspendNavigationBarLayout = false
        if let suspendedNavigationBarLayout = self.suspendedNavigationBarLayout {
            self.suspendedNavigationBarLayout = suspendedNavigationBarLayout
            self.applyNavigationBarLayout(suspendedNavigationBarLayout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, transition: navigationBarTransition)
        }
    }
    
    func updateChatPresentationInterfaceState(animated: Bool = true, interactive: Bool, saveInterfaceState: Bool = false, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        self.updateChatPresentationInterfaceState(transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, interactive: interactive, saveInterfaceState: saveInterfaceState, f, completion: completion)
    }
    
    func updateChatPresentationInterfaceState(transition: ContainedViewLayoutTransition, interactive: Bool, saveInterfaceState: Bool = false, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion externalCompletion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        var completion = externalCompletion
        var temporaryChatPresentationInterfaceState = f(self.presentationInterfaceState)
        
        if self.presentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup != temporaryChatPresentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup || self.presentationInterfaceState.keyboardButtonsMessage?.id != temporaryChatPresentationInterfaceState.keyboardButtonsMessage?.id {
            if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, let _ = keyboardButtonsMessage.visibleButtonKeyboardMarkup {
                if self.presentationInterfaceState.interfaceState.editMessage == nil && self.presentationInterfaceState.interfaceState.composeInputState.inputText.length == 0 && keyboardButtonsMessage.id != temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.closedButtonKeyboardMessageId && keyboardButtonsMessage.id != temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.dismissedButtonKeyboardMessageId && temporaryChatPresentationInterfaceState.botStartPayload == nil {
                    temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputMode({ _ in
                        return .inputButtons
                    })
                }
                
                if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                    if temporaryChatPresentationInterfaceState.interfaceState.replyMessageId == nil && temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.processedSetupReplyMessageId != keyboardButtonsMessage.id  {
                        temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInterfaceState({ $0.withUpdatedReplyMessageId(keyboardButtonsMessage.id).withUpdatedMessageActionsState({ value in
                            var value = value
                            value.processedSetupReplyMessageId = keyboardButtonsMessage.id
                            return value
                        }) })
                    }
                }
            } else {
                temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputMode({ mode in
                    if case .inputButtons = mode {
                        return .text
                    } else {
                        return mode
                    }
                })
            }
        }
        
        if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, keyboardButtonsMessage.requestsSetupReply {
            if temporaryChatPresentationInterfaceState.interfaceState.replyMessageId == nil && temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.processedSetupReplyMessageId != keyboardButtonsMessage.id  {
                temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInterfaceState({ $0.withUpdatedReplyMessageId(keyboardButtonsMessage.id).withUpdatedMessageActionsState({ value in
                    var value = value
                    value.processedSetupReplyMessageId = keyboardButtonsMessage.id
                    return value
                }) })
            }
        }
        
        let inputTextPanelState = inputTextPanelStateForChatPresentationInterfaceState(temporaryChatPresentationInterfaceState, context: self.context)
        var updatedChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputTextPanelState({ _ in return inputTextPanelState })
        
        let contextQueryUpdates = contextQueryResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, context: self.context, currentQueryStates: &self.contextQueryStates, requestBotLocationStatus: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            let _ = (ApplicationSpecificNotice.updateInlineBotLocationRequestState(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peerId, timestamp: Int32(Date().timeIntervalSince1970 + 10 * 60))
            |> deliverOnMainQueue).start(next: { value in
                guard let strongSelf = self, value else {
                    return
                }
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_ShareInlineBotLocationConfirmation, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peerId, value: 0).start()
                })]), in: .window(.root))
            })
        })
        
        for (kind, update) in contextQueryUpdates {
            switch update {
            case .remove:
                if let (_, disposable) = self.contextQueryStates[kind] {
                    disposable.dispose()
                    self.contextQueryStates.removeValue(forKey: kind)
                    
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult(queryKind: kind, { _ in
                        return nil
                    })
                }
                if case .contextRequest = kind {
                    self.performingInlineSearch.set(false)
                }
            case let .update(query, signal):
                let currentQueryAndDisposable = self.contextQueryStates[kind]
                currentQueryAndDisposable?.1.dispose()
                
                var inScope = true
                var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                self.contextQueryStates[kind] = (query, (signal
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    if let strongSelf = self {
                        if Thread.isMainThread && inScope {
                            inScope = false
                            inScopeResult = result
                        } else {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInputQueryResult(queryKind: kind, { previousResult in
                                    return result(previousResult)
                                })
                            })
                        }
                    }
                }, error: { [weak self] error in
                    if let strongSelf = self {
                        if case .contextRequest = kind {
                            strongSelf.performingInlineSearch.set(false)
                        }
                        
                        switch error {
                        case .generic:
                            break
                        case let .inlineBotLocationRequest(peerId):
                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_ShareInlineBotLocationConfirmation, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peerId, value: Int32(Date().timeIntervalSince1970 + 10 * 60)).start()
                            }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                                let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peerId, value: 0).start()
                            })]), in: .window(.root))
                        }
                    }
                }, completed: { [weak self] in
                    if let strongSelf = self {
                        if case .contextRequest = kind {
                            strongSelf.performingInlineSearch.set(false)
                        }
                    }
                }))
                inScope = false
                if let inScopeResult = inScopeResult {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult(queryKind: kind, { previousResult in
                        return inScopeResult(previousResult)
                    })
                } else {
                    if case .contextRequest = kind {
                        self.performingInlineSearch.set(true)
                    }
                }
            
                if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                    if case .contextRequest = query {
                        let _ = (ApplicationSpecificNotice.getSecretChatInlineBotUsage(accountManager: self.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).start(next: { [weak self] value in
                            if let strongSelf = self, !value {
                                let _ = ApplicationSpecificNotice.setSecretChatInlineBotUsage(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_SecretChatContextBotAlert, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        })
                    }
                }
            }
        }
        
        if let (updatedSearchQuerySuggestionState, updatedSearchQuerySuggestionSignal) = searchQuerySuggestionResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, context: context, currentQuery: self.searchQuerySuggestionState?.0) {
            self.searchQuerySuggestionState?.1.dispose()
            var inScope = true
            var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
            self.searchQuerySuggestionState = (updatedSearchQuerySuggestionState, (updatedSearchQuerySuggestionSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    if Thread.isMainThread && inScope {
                        inScope = false
                        inScopeResult = result
                    } else {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedSearchQuerySuggestionResult { previousResult in
                                return result(previousResult)
                            }
                        })
                    }
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedSearchQuerySuggestionResult { previousResult in
                    return inScopeResult(previousResult)
                }
            }
        }
        
        if let (updatedUrlPreviewUrl, updatedUrlPreviewSignal) = urlPreviewStateForInputText(updatedChatPresentationInterfaceState.interfaceState.composeInputState.inputText, context: self.context, currentQuery: self.urlPreviewQueryState?.0) {
            self.urlPreviewQueryState?.1.dispose()
            var inScope = true
            var inScopeResult: ((TelegramMediaWebpage?) -> TelegramMediaWebpage?)?
            let linkPreviews: Signal<Bool, NoError>
            if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                linkPreviews = interactiveChatLinkPreviewsEnabled(accountManager: self.context.sharedContext.accountManager, displayAlert: { [weak self] f in
                    if let strongSelf = self {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Conversation_SecretLinkPreviewAlert, actions: [
                            TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                            f.f(true)
                        }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_No, action: {
                            f.f(false)
                        })]), in: .window(.root))
                    }
                })
            } else {
                var bannedEmbedLinks = false
                if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.hasBannedPermission(.banEmbedLinks) != nil {
                    bannedEmbedLinks = true
                } else if let group = self.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup, group.hasBannedPermission(.banEmbedLinks) {
                    bannedEmbedLinks = true
                }
                if bannedEmbedLinks {
                    linkPreviews = .single(false)
                } else {
                    linkPreviews = .single(true)
                }
            }
            let filteredPreviewSignal = linkPreviews
            |> take(1)
            |> mapToSignal { value -> Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError> in
                if value {
                    return updatedUrlPreviewSignal
                } else {
                    return .single({ _ in return nil })
                }
            }
            
            self.urlPreviewQueryState = (updatedUrlPreviewUrl, (filteredPreviewSignal |> deliverOnMainQueue).start(next: { [weak self] (result) in
                if let strongSelf = self {
                    if Thread.isMainThread && inScope {
                        inScope = false
                        inScopeResult = result
                    } else {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            if let updatedUrlPreviewUrl = updatedUrlPreviewUrl, let webpage = result($0.urlPreview?.1) {
                                return $0.updatedUrlPreview((updatedUrlPreviewUrl, webpage))
                            } else {
                                return $0.updatedUrlPreview(nil)
                            }
                        })
                    }
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                if let updatedUrlPreviewUrl = updatedUrlPreviewUrl, let webpage = inScopeResult(updatedChatPresentationInterfaceState.urlPreview?.1) {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedUrlPreview((updatedUrlPreviewUrl, webpage))
                } else {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedUrlPreview(nil)
                }
            }
        }
        
        let isEditingMedia: Bool = updatedChatPresentationInterfaceState.editMessageState?.content != .plaintext
        let editingUrlPreviewText: NSAttributedString? = isEditingMedia ? nil : updatedChatPresentationInterfaceState.interfaceState.editMessage?.inputState.inputText
        if let (updatedEditingUrlPreviewUrl, updatedEditingUrlPreviewSignal) = urlPreviewStateForInputText(editingUrlPreviewText, context: self.context, currentQuery: self.editingUrlPreviewQueryState?.0) {
            self.editingUrlPreviewQueryState?.1.dispose()
            var inScope = true
            var inScopeResult: ((TelegramMediaWebpage?) -> TelegramMediaWebpage?)?
            self.editingUrlPreviewQueryState = (updatedEditingUrlPreviewUrl, (updatedEditingUrlPreviewSignal |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    if Thread.isMainThread && inScope {
                        inScope = false
                        inScopeResult = result
                    } else {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            if let updatedEditingUrlPreviewUrl = updatedEditingUrlPreviewUrl, let webpage = result($0.editingUrlPreview?.1) {
                                return $0.updatedEditingUrlPreview((updatedEditingUrlPreviewUrl, webpage))
                            } else {
                                return $0.updatedEditingUrlPreview(nil)
                            }
                        })
                    }
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                if let updatedEditingUrlPreviewUrl = updatedEditingUrlPreviewUrl, let webpage = inScopeResult(updatedChatPresentationInterfaceState.editingUrlPreview?.1) {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedEditingUrlPreview((updatedEditingUrlPreviewUrl, webpage))
                } else {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedEditingUrlPreview(nil)
                }
            }
        }
        
        if let updated = self.updateSearch(updatedChatPresentationInterfaceState) {
            updatedChatPresentationInterfaceState = updated
        }
        
        let recordingActivityValue: ChatRecordingActivity
        if let mediaRecordingState = updatedChatPresentationInterfaceState.inputTextPanelState.mediaRecordingState {
            switch mediaRecordingState {
                case .audio:
                    recordingActivityValue = .voice
                case .video(ChatVideoRecordingStatus.recording, _):
                    recordingActivityValue = .instantVideo
                default:
                    recordingActivityValue = .none
            }
        } else {
            recordingActivityValue = .none
        }
        if recordingActivityValue != self.recordingActivityValue {
            self.recordingActivityValue = recordingActivityValue
            self.recordingActivityPromise.set(recordingActivityValue)
        }
        
        self.presentationInterfaceState = updatedChatPresentationInterfaceState
        
        self.updateSlowmodeStatus()
        
        if self.isNodeLoaded {
            self.chatDisplayNode.updateChatPresentationInterfaceState(updatedChatPresentationInterfaceState, transition: transition, interactive: interactive, completion: completion)
        } else {
            completion(.immediate)
        }
        
        if let button = leftNavigationButtonForChatInterfaceState(updatedChatPresentationInterfaceState, subject: self.subject, strings: updatedChatPresentationInterfaceState.strings, currentButton: self.leftNavigationButton, target: self, selector: #selector(self.leftNavigationButtonAction))  {
            if self.leftNavigationButton != button {
                var animated = transition.isAnimated
                if let currentButton = self.leftNavigationButton?.action, currentButton == button.action {
                    animated = false
                }
                animated = false
                self.navigationItem.setLeftBarButton(button.buttonItem, animated: animated)
                self.leftNavigationButton = button
            }
        } else if let _ = self.leftNavigationButton {
            self.navigationItem.setLeftBarButton(nil, animated: transition.isAnimated)
            self.leftNavigationButton = nil
        }
        
        if let button = rightNavigationButtonForChatInterfaceState(updatedChatPresentationInterfaceState, strings: updatedChatPresentationInterfaceState.strings, currentButton: self.rightNavigationButton, target: self, selector: #selector(self.rightNavigationButtonAction), chatInfoNavigationButton: self.chatInfoNavigationButton) {
            if self.rightNavigationButton != button {
                var animated = transition.isAnimated
                if let currentButton = self.rightNavigationButton?.action, currentButton == button.action {
                    animated = false
                }
                if case .replyThread = self.chatLocation {
                    animated = false
                }
                self.navigationItem.setRightBarButton(button.buttonItem, animated: animated)
                self.rightNavigationButton = button
            }
        } else if let _ = self.rightNavigationButton {
            self.navigationItem.setRightBarButton(nil, animated: transition.isAnimated)
            self.rightNavigationButton = nil
        }
        
        if let controllerInteraction = self.controllerInteraction {
            if updatedChatPresentationInterfaceState.interfaceState.selectionState != controllerInteraction.selectionState {
                controllerInteraction.selectionState = updatedChatPresentationInterfaceState.interfaceState.selectionState
                let isBlackout = controllerInteraction.selectionState != nil
                completion = { [weak self] transition in
                    completion(transition)
                    (self?.navigationController as? NavigationController)?.updateMasterDetailsBlackout(isBlackout ? .master : nil, transition: transition)
                }
                self.updateItemNodesSelectionStates(animated: transition.isAnimated)
            }
        }
        
        switch updatedChatPresentationInterfaceState.mode {
            case .standard:
                if self.hasEmbeddedTitleContent {
                    self.statusBar.statusBarStyle = .White
                } else {
                    self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
                }
                self.deferScreenEdgeGestures = []
            case .overlay:
                self.deferScreenEdgeGestures = [.top]
            case .inline:
                self.statusBar.statusBarStyle = .Ignore
        }
        
        if saveInterfaceState {
            self.saveInterfaceState(includeScrollState: false)
        }
        
        if let navigationController = self.navigationController as? NavigationController, isTopmostChatController(self) {
            var voiceChatOverlayController: VoiceChatOverlayController?
            for controller in navigationController.globalOverlayControllers {
                if let controller = controller as? VoiceChatOverlayController {
                    voiceChatOverlayController = controller
                    break
                }
            }
            
            if let controller = voiceChatOverlayController {
                controller.updateVisibility()
            }
        }
     
        if let currentMenuWebAppController = self.currentMenuWebAppController, !self.presentationInterfaceState.showWebView {
            self.currentMenuWebAppController = nil
            if let currentMenuWebAppController = currentMenuWebAppController as? AttachmentController {
                currentMenuWebAppController.ensureUnfocused = false
            }
            currentMenuWebAppController.dismiss(animated: true, completion: nil)
        }
        
        self.presentationInterfaceStatePromise.set(self.presentationInterfaceState)
    }
    
    private func updateItemNodesSelectionStates(animated: Bool) {
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateSelectionState(animated: animated)
            }
        }

        self.chatDisplayNode.historyNode.forEachItemHeaderNode{ itemHeaderNode in
            if let avatarNode = itemHeaderNode as? ChatMessageAvatarHeaderNode {
                avatarNode.updateSelectionState(animated: animated)
            }
        }
    }
    
    private func updatePollTooltipMessageState(animated: Bool) {
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageBubbleItemNode {
                for contentNode in itemNode.contentNodes {
                    if let contentNode = contentNode as? ChatMessagePollBubbleContentNode {
                        contentNode.updatePollTooltipMessageState(animated: animated)
                    }
                }
                itemNode.updatePsaTooltipMessageState(animated: animated)
            }
        }
    }
    
    private func updateItemNodesSearchTextHighlightStates() {
        var searchString: String?
        var resultsMessageIndices: [MessageIndex]?
        if let search = self.presentationInterfaceState.search, let resultsState = search.resultsState, !resultsState.messageIndices.isEmpty {
            searchString = search.query
            resultsMessageIndices = resultsState.messageIndices
        }
        if searchString != self.controllerInteraction?.searchTextHighightState?.0 || resultsMessageIndices?.count != self.controllerInteraction?.searchTextHighightState?.1.count {
            var searchTextHighightState: (String, [MessageIndex])?
            if let searchString = searchString, let resultsMessageIndices = resultsMessageIndices {
                searchTextHighightState = (searchString, resultsMessageIndices)
            }
            self.controllerInteraction?.searchTextHighightState = searchTextHighightState
            self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ChatMessageItemView {
                    itemNode.updateSearchTextHighlightState()
                }
            }
        }
    }
    
    private func updateItemNodesHighlightedStates(animated: Bool) {
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateHighlightedState(animated: animated)
            }
        }
    }
    
    @objc func leftNavigationButtonAction() {
        if let button = self.leftNavigationButton {
            self.navigationButtonAction(button.action)
        }
    }
    
    @objc func rightNavigationButtonAction() {
        if let button = self.rightNavigationButton {
            self.navigationButtonAction(button.action)
        }
    }
    
    func beginClearHistory(type: InteractiveHistoryClearingType) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
        self.chatDisplayNode.historyNode.historyAppearsCleared = true
        
        let statusText: String
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            statusText = self.presentationData.strings.Undo_ScheduledMessagesCleared
        } else if case .forEveryone = type {
            if peerId.namespace == Namespaces.Peer.CloudUser {
                statusText = self.presentationData.strings.Undo_ChatClearedForBothSides
            } else {
                statusText = self.presentationData.strings.Undo_ChatClearedForEveryone
            }
        } else {
            statusText = self.presentationData.strings.Undo_ChatCleared
        }
        
        self.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: statusText), elevatedLayout: false, action: { [weak self] value in
            guard let strongSelf = self else {
                return false
            }
            if value == .commit {
                let _ = strongSelf.context.engine.messages.clearHistoryInteractively(peerId: peerId, type: type).start(completed: {
                    self?.chatDisplayNode.historyNode.historyAppearsCleared = false
                })
                return true
            } else if value == .undo {
                strongSelf.chatDisplayNode.historyNode.historyAppearsCleared = false
                return true
            }
            return false
        }), in: .current)
    }
    
    private func navigationButtonAction(_ action: ChatNavigationButtonAction) {
        switch action {
        case .spacer:
            break
        case .cancelMessageSelection:
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
        case .clearHistory:
            if case let .peer(peerId) = self.chatLocation {
                let beginClear: (InteractiveHistoryClearingType) -> Void = { [weak self] type in
                    self?.beginClearHistory(type: type)
                }
                
                let _ = (self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.CanDeleteHistory(id: peerId)
                )
                |> map { participantCount, canDeleteHistory -> (isLargeGroupOrChannel: Bool, canClearChannel: Bool) in
                    if let participantCount = participantCount {
                        return (participantCount > 1000, canDeleteHistory)
                    } else {
                        return (false, false)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] parameters in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let (isLargeGroupOrChannel, canClearChannel) = parameters
                    
                    guard let peer = strongSelf.presentationInterfaceState.renderedPeer, let chatPeer = peer.peers[peer.peerId], let mainPeer = peer.chatMainPeer else {
                        return
                    }
                    
                    enum ClearType {
                        case savedMessages
                        case secretChat
                        case group
                        case channel
                        case user
                    }
                    
                    let canClearCache: Bool
                    let canClearForMyself: ClearType?
                    let canClearForEveryone: ClearType?
                    
                    if peerId == strongSelf.context.account.peerId {
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
                            canClearForEveryone = nil
                        case .admin, .member:
                            canClearForMyself = .group
                            canClearForEveryone = nil
                        }
                    } else if let channel = chatPeer as? TelegramChannel {
                        if let username = channel.username, !username.isEmpty {
                            if isLargeGroupOrChannel {
                                canClearCache = true
                                canClearForMyself = nil
                                canClearForEveryone = canClearChannel ? .channel : nil
                            } else {
                                canClearCache = true
                                canClearForMyself = nil
                                
                                switch channel.info {
                                case .broadcast:
                                    if channel.flags.contains(.isCreator) {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    } else {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    }
                                case .group:
                                    if channel.flags.contains(.isCreator) {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    } else {
                                        canClearForEveryone = canClearChannel ? .channel : nil
                                    }
                                }
                            }
                        } else {
                            if isLargeGroupOrChannel {
                                switch channel.info {
                                case .broadcast:
                                    canClearCache = true
                                    
                                    canClearForMyself = .channel
                                    canClearForEveryone = nil
                                case .group:
                                    canClearCache = false
                                    
                                    canClearForMyself = .channel
                                    canClearForEveryone = nil
                                }
                            } else {
                                switch channel.info {
                                case .broadcast:
                                    canClearCache = true
                                    
                                    if channel.flags.contains(.isCreator) {
                                        canClearForMyself = .channel
                                        canClearForEveryone = nil
                                    } else {
                                        canClearForMyself = .channel
                                        canClearForEveryone = nil
                                    }
                                case .group:
                                    canClearCache = false
                                    
                                    if channel.flags.contains(.isCreator) {
                                        canClearForMyself = .group
                                        canClearForEveryone = nil
                                    } else {
                                        canClearForMyself = .group
                                        canClearForEveryone = nil
                                    }
                                }
                            }
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
                    
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    
                    if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ScheduledMessages_ClearAllConfirmation, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle, text: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText, actions: [
                                TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                }),
                                TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: {
                                    beginClear(.scheduledMessages)
                                })
                            ], parseMarkdown: true), in: .window(.root))
                        }))
                    } else {
                        if let _ = canClearForMyself ?? canClearForEveryone {
                            items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: EnginePeer(mainPeer), chatPeer: EnginePeer(chatPeer), action: .clearHistory(canClearCache: canClearCache), strings: strongSelf.presentationData.strings, nameDisplayOrder: strongSelf.presentationData.nameDisplayOrder))
                            
                            if let canClearForEveryone = canClearForEveryone {
                                let text: String
                                let confirmationText: String
                                switch canClearForEveryone {
                                case .user:
                                    text = strongSelf.presentationData.strings.ChatList_DeleteForEveryone(EnginePeer(mainPeer).compactDisplayTitle).string
                                    confirmationText = strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationText
                                default:
                                    text = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                                    confirmationText = strongSelf.presentationData.strings.ChatList_DeleteForAllMembersConfirmationText
                                }
                                items.append(ActionSheetButtonItem(title: text, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle, text: confirmationText, actions: [
                                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                        }),
                                        TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                                            beginClear(.forEveryone)
                                        })
                                    ], parseMarkdown: true), in: .window(.root))
                                }))
                            }
                            if let canClearForMyself = canClearForMyself {
                                let text: String
                                switch canClearForMyself {
                                case .savedMessages, .secretChat:
                                    text = strongSelf.presentationData.strings.Conversation_ClearAll
                                default:
                                    text = strongSelf.presentationData.strings.ChatList_DeleteForCurrentUser
                                }
                                items.append(ActionSheetButtonItem(title: text, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    beginClear(.forLocalPeer)
                                }))
                            }
                        }
                        
                        if canClearCache {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ClearCache, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.navigationButtonAction(.clearCache)
                            }))
                        }
                        
                        if chatPeer.canSetupAutoremoveTimeout(accountPeerId: strongSelf.context.account.peerId) {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationInterfaceState.autoremoveTimeout == nil ? strongSelf.presentationData.strings.Conversation_AutoremoveActionEnable : strongSelf.presentationData.strings.Conversation_AutoremoveActionEdit, color: .accent, action: { [weak actionSheet] in
                                guard let actionSheet = actionSheet else {
                                    return
                                }
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                actionSheet.dismissAnimated()
                                
                                strongSelf.presentAutoremoveSetup()
                            }))
                        }
                    }

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(actionSheet, in: .window(.root))
                })
            }
        case let .openChatInfo(expandAvatar):
            let _ = self.presentVoiceMessageDiscardAlert(action: {
                switch self.chatLocationInfoData {
                case let .peer(peerView):
                    self.navigationActionDisposable.set((peerView.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] peerView in
                        if let strongSelf = self, let peer = peerView.peers[peerView.peerId], peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil && !strongSelf.presentationInterfaceState.isNotAccessible {
                            if peer.id == strongSelf.context.account.peerId {
                                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
                                    strongSelf.effectiveNavigationController?.pushViewController(infoController)
                                }
                            } else {
                                var expandAvatar = expandAvatar
                                if peer.smallProfileImage == nil {
                                    expandAvatar = false
                                }
                                if let validLayout = strongSelf.validLayout, validLayout.deviceMetrics.type == .tablet {
                                    expandAvatar = false
                                }
                                if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: peer, mode: .generic, avatarInitiallyExpanded: expandAvatar, fromChat: true, requestsContext: strongSelf.inviteRequestsContext) {
                                    strongSelf.effectiveNavigationController?.pushViewController(infoController)
                                }
                            }
                        }
                    }))
                case .replyThread:
                    break
                case .feed:
                    break
                }
            })
        case .search:
            self.interfaceInteraction?.beginMessageSearch(.everything, "")
        case .dismiss:
            self.dismiss()
        case .clearCache:
            let controller = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: nil))
            self.present(controller, in: .window(.root))
            
            let disposable: MetaDisposable
            if let currentDisposable = self.clearCacheDisposable {
                disposable = currentDisposable
            } else {
                disposable = MetaDisposable()
                self.clearCacheDisposable = disposable
            }
        
            switch self.chatLocationInfoData {
            case let .peer(peerView):
                self.navigationActionDisposable.set((peerView.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] peerView in
                    guard let strongSelf = self, let peer = peerView.peers[peerView.peerId] else {
                        return
                    }
                    let peerId = peer.id
                    
                    let _ = (strongSelf.context.engine.resources.collectCacheUsageStats(peerId: peer.id)
                    |> deliverOnMainQueue).start(next: { [weak self, weak controller] result in
                        controller?.dismiss()
                        
                        guard let strongSelf = self, case let .result(stats) = result, let categories = stats.media[peer.id] else {
                            return
                        }
                        let presentationData = strongSelf.presentationData
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        
                        var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
                        
                        var itemIndex = 1
                        
                        var selectedSize: Int64 = 0
                        let updateTotalSize: () -> Void = { [weak controller] in
                            controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                                let title: String
                                let filteredSize = sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
                                selectedSize = filteredSize
                                
                                if filteredSize == 0 {
                                    title = presentationData.strings.Cache_ClearNone
                                } else {
                                    title = presentationData.strings.Cache_Clear("\(dataSizeString(filteredSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string
                                }
                                
                                if let item = item as? ActionSheetButtonItem {
                                    return ActionSheetButtonItem(title: title, color: filteredSize != 0 ? .accent : .disabled, enabled: filteredSize != 0, action: item.action)
                                }
                                return item
                            })
                        }
                        
                        let toggleCheck: (PeerCacheUsageCategory, Int) -> Void = { [weak controller] category, itemIndex in
                            if let (value, size) = sizeIndex[category] {
                                sizeIndex[category] = (!value, size)
                            }
                            controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                                if let item = item as? ActionSheetCheckboxItem {
                                    return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                                }
                                return item
                            })
                            updateTotalSize()
                        }
                        var items: [ActionSheetItem] = []
                        
                        items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: EnginePeer(peer), chatPeer: EnginePeer(peer), action: .clearCache, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder))
                        
                        let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file]
                        
                        var totalSize: Int64 = 0
                        
                        func stringForCategory(strings: PresentationStrings, category: PeerCacheUsageCategory) -> String {
                            switch category {
                                case .image:
                                    return strings.Cache_Photos
                                case .video:
                                    return strings.Cache_Videos
                                case .audio:
                                    return strings.Cache_Music
                                case .file:
                                    return strings.Cache_Files
                            }
                        }
                        
                        for categoryId in validCategories {
                            if let media = categories[categoryId] {
                                var categorySize: Int64 = 0
                                for (_, size) in media {
                                    categorySize += size
                                }
                                sizeIndex[categoryId] = (true, categorySize)
                                totalSize += categorySize
                                if categorySize > 1024 {
                                    let index = itemIndex
                                    items.append(ActionSheetCheckboxItem(title: stringForCategory(strings: presentationData.strings, category: categoryId), label: dataSizeString(categorySize, formatting: DataSizeStringFormatting(presentationData: presentationData)), value: true, action: { value in
                                        toggleCheck(categoryId, index)
                                    }))
                                    itemIndex += 1
                                }
                            }
                        }
                        selectedSize = totalSize
                        
                        if items.isEmpty {
                            strongSelf.presentClearCacheSuggestion()
                        } else {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_Clear("\(dataSizeString(totalSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))").string, action: {
                                let clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
                                var clearMediaIds = Set<MediaId>()
                                
                                var media = stats.media
                                if var categories = media[peerId] {
                                    for category in clearCategories {
                                        if let contents = categories[category] {
                                            for (mediaId, _) in contents {
                                                clearMediaIds.insert(mediaId)
                                            }
                                        }
                                        categories.removeValue(forKey: category)
                                    }
                                    
                                    media[peerId] = categories
                                }
                                
                                var clearResourceIds = Set<MediaResourceId>()
                                for id in clearMediaIds {
                                    if let ids = stats.mediaResourceIds[id] {
                                        for resourceId in ids {
                                            clearResourceIds.insert(resourceId)
                                        }
                                    }
                                }
                                
                                var signal = strongSelf.context.engine.resources.clearCachedMediaResources(mediaResourceIds: clearResourceIds)
                                
                                var cancelImpl: (() -> Void)?
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                let progressSignal = Signal<Never, NoError> { subscriber in
                                    let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                                        cancelImpl?()
                                    }))
                                    strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    return ActionDisposable { [weak controller] in
                                        Queue.mainQueue().async() {
                                            controller?.dismiss()
                                        }
                                    }
                                }
                                |> runOn(Queue.mainQueue())
                                |> delay(0.15, queue: Queue.mainQueue())
                                let progressDisposable = progressSignal.start()
                                
                                signal = signal
                                |> afterDisposed {
                                    Queue.mainQueue().async {
                                        progressDisposable.dispose()
                                    }
                                }
                                cancelImpl = {
                                    disposable.set(nil)
                                }
                                disposable.set((signal
                                |> deliverOnMainQueue).start(completed: { [weak self] in
                                    if let strongSelf = self, let _ = strongSelf.validLayout {
                                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(selectedSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))", stringForDeviceType()).string), elevatedLayout: false, action: { _ in return false }), in: .current)
                                    }
                                }))

                                dismissAction()
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                            }))
                            
                            items.append(ActionSheetButtonItem(title: presentationData.strings.ClearCache_StorageUsage, action: { [weak self] in
                                dismissAction()
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                
                                if let strongSelf = self {
                                    let controller = storageUsageController(context: strongSelf.context, isModal: true)
                                    strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                }
                            }))
                            
                            controller.setItemGroups([
                                ActionSheetItemGroup(items: items),
                                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                            ])
                            strongSelf.chatDisplayNode.dismissInput()
                            strongSelf.present(controller, in: .window(.root))
                        }
                    })
                }))
            case .replyThread:
                break
            case .feed:
                break
            }
        case .toggleInfoPanel:
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedTitlePanelContext {
                    if let index = $0.firstIndex(where: {
                        switch $0 {
                            case .chatInfo:
                                return true
                            default:
                                return false
                        }
                    }) {
                        var updatedContexts = $0
                        updatedContexts.remove(at: index)
                        return updatedContexts
                    } else {
                        var updatedContexts = $0
                        updatedContexts.append(.chatInfo)
                        return updatedContexts.sorted()
                    }
                }
            })
        }
    }
    
    private func editMessageMediaWithMessages(_ messages: [EnqueueMessage]) {
        if let message = messages.first, case let .message(text, attributes, maybeMediaReference, _, _, _) = message, let mediaReference = maybeMediaReference {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                var entities: [MessageTextEntity] = []
                for attribute in attributes {
                    if let entitiesAttrbute = attribute as? TextEntitiesMessageAttribute {
                        entities = entitiesAttrbute.entities
                    }
                }
                let attributedText = chatInputStateStringWithAppliedEntities(text, entities: entities)
                
                var state = state
                if let editMessageState = state.editMessageState, case let .media(options) = editMessageState.content, !options.isEmpty {
                    state = state.updatedEditMessageState(ChatEditInterfaceMessageState(content: editMessageState.content, mediaReference: mediaReference))
                }
                if !text.isEmpty {
                    state = state.updatedInterfaceState { state in
                        if let editMessage = state.editMessage {
                            return state.withUpdatedEditMessage(editMessage.withUpdatedInputState(ChatTextInputState(inputText: attributedText)))
                        }
                        return state
                    }
                }
                return state
            })
            self.interfaceInteraction?.editMessage()
        }
    }
    
    private func editMessageMediaWithLegacySignals(_ signals: [Any]) {
        let _ = (legacyAssetPickerEnqueueMessages(account: self.context.account, signals: signals)
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            self?.editMessageMediaWithMessages(messages.map { $0.message })
        })
    }
    
    private func getCaptionPanelView() -> TGCaptionPanelView {
        let presentationData = self.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
        var presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: .builtin(WallpaperSettings()), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 }, fontSize: presentationData.chatFontSize, bubbleCorners: presentationData.chatBubbleCorners, accountPeerId: self.context.account.peerId, mode: .standard(previewing: false), chatLocation: self.presentationInterfaceState.chatLocation, subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil)
        
        var updateChatPresentationInterfaceStateImpl: (((ChatPresentationInterfaceState) -> ChatPresentationInterfaceState) -> Void)?
        var ensureFocusedImpl: (() -> Void)?
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(updateTextInputStateAndMode: { f in
            updateChatPresentationInterfaceStateImpl?({
                let (updatedState, updatedMode) = f($0.interfaceState.effectiveInputState, $0.inputMode)
                return $0.updatedInterfaceState { interfaceState in
                    return interfaceState.withUpdatedEffectiveInputState(updatedState)
                }.updatedInputMode({ _ in updatedMode })
            })
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { f in
            updateChatPresentationInterfaceStateImpl?({
                let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                return $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({
                    $0.withUpdatedMessageActionsState({ value in
                        var value = value
                        value.closedButtonKeyboardMessageId = updatedClosedButtonKeyboardMessageId
                        return value
                    })
                })
            })
        }, openLinkEditing: { [weak self] in
            if let strongSelf = self {
                var selectionRange: Range<Int>?
                var text: String?
                var inputMode: ChatInputMode?
                updateChatPresentationInterfaceStateImpl?({ state in
                    selectionRange = state.interfaceState.effectiveInputState.selectionRange
                    if let selectionRange = selectionRange {
                        text = state.interfaceState.effectiveInputState.inputText.attributedSubstring(from: NSRange(location: selectionRange.startIndex, length: selectionRange.count)).string
                    }
                    inputMode = state.inputMode
                    return state
                })
                
                let controller = chatTextLinkEditController(sharedContext: strongSelf.context.sharedContext, updatedPresentationData: (presentationData, .never()), account: strongSelf.context.account, text: text ?? "", link: nil, apply: { link in
                    if let inputMode = inputMode, let selectionRange = selectionRange {
                        if let link = link {
                            updateChatPresentationInterfaceStateImpl?({
                                return $0.updatedInterfaceState({
                                    $0.withUpdatedEffectiveInputState(chatTextInputAddLinkAttribute($0.effectiveInputState, selectionRange: selectionRange, url: link))
                                })
                            })
                        }
                        ensureFocusedImpl?()
                        updateChatPresentationInterfaceStateImpl?({
                            return $0.updatedInputMode({ _ in return inputMode }).updatedInterfaceState({
                                $0.withUpdatedEffectiveInputState(ChatTextInputState(inputText: $0.effectiveInputState.inputText, selectionRange: selectionRange.endIndex ..< selectionRange.endIndex))
                            })
                        })
                    }
                })
                strongSelf.present(controller, in: .window(.root))
            }
        })
        
        let inputPanelNode = AttachmentTextInputPanelNode(context: self.context, presentationInterfaceState: presentationInterfaceState, isCaption: true, presentController: { _ in })
        inputPanelNode.interfaceInteraction = interfaceInteraction
        inputPanelNode.effectivePresentationInterfaceState = {
            return presentationInterfaceState
        }
        
        updateChatPresentationInterfaceStateImpl = { [weak inputPanelNode] f in
            let updatedPresentationInterfaceState = f(presentationInterfaceState)
            let updateInputTextState = presentationInterfaceState.interfaceState.effectiveInputState != updatedPresentationInterfaceState.interfaceState.effectiveInputState
            
            presentationInterfaceState = updatedPresentationInterfaceState
            
            if let inputPanelNode = inputPanelNode, updateInputTextState {
                inputPanelNode.updateInputTextState(updatedPresentationInterfaceState.interfaceState.effectiveInputState, animated: true)
            }
        }
        
        ensureFocusedImpl =  { [weak inputPanelNode] in
            inputPanelNode?.ensureFocused()
        }
        
        return inputPanelNode
    }
    
    private func openCamera(cameraView: TGAttachmentCameraView? = nil) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).start(next: { [weak self] settings in
            guard let strongSelf = self else {
                return
            }
            
            var photoOnly = false
            if let callManager = strongSelf.context.sharedContext.callManager as? PresentationCallManagerImpl, callManager.hasActiveCall {
                photoOnly = true
            }
            
            let storeCapturedMedia = peer.id.namespace != Namespaces.Peer.SecretChat
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
            
            presentedLegacyCamera(context: strongSelf.context, peer: peer, chatLocation: strongSelf.chatLocation, cameraView: cameraView, menuController: nil, parentController: strongSelf, attachmentController: self?.attachmentController, editingMedia: false, saveCapturedPhotos: storeCapturedMedia, mediaGrouping: true, initialCaption: inputText, hasSchedule: strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, photoOnly: photoOnly, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime in
                if let strongSelf = self {
                    strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                    if !inputText.string.isEmpty {
                        strongSelf.clearInputText()
                    }
                }
            }, recognizedQRCode: { [weak self] code in
                if let strongSelf = self {
                    if let (host, port, username, password, secret) = parseProxyUrl(code) {
                        strongSelf.openResolved(result: ResolvedUrl.proxy(host: host, port: port, username: username, password: password, secret: secret), sourceMessageId: nil)
                    }
                }
            }, presentSchedulePicker: { [weak self] _, done in
                if let strongSelf = self {
                    strongSelf.presentScheduleTimePicker(style: .media, completion: { [weak self] time in
                        if let strongSelf = self {
                            done(time)
                            if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                strongSelf.openScheduledMessages()
                            }
                        }
                    })
                }
            }, presentTimerPicker: { [weak self] done in
                if let strongSelf = self {
                    strongSelf.presentTimerPicker(style: .media, completion: { time in
                        done(time)
                    })
                }
            }, presentStickers: { [weak self] completion in
                if let strongSelf = self {
                    let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                        completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                        return true
                    })
                    strongSelf.present(controller, in: .window(.root))
                    return controller
                } else {
                    return nil
                }
            }, getCaptionPanelView: { [weak self] in
                return self?.getCaptionPanelView()
            }, dismissedWithResult: { [weak self] in
                self?.attachmentController?.dismiss(animated: false, completion: nil)
            }, finishedTransitionIn: { [weak self] in
                self?.attachmentController?.scrollToTop?()
            })
        })
    }
    
    public func presentAttachmentBot(botId: PeerId, payload: String?) {
        self.attachmentController?.dismiss(animated: true, completion: nil)
        self.presentAttachmentMenu(editMediaOptions: nil, editMediaReference: nil, botId: botId, botPayload: payload)
    }
    
    private func presentAttachmentMenu(editMediaOptions: MessageMediaEditingOptions?, editMediaReference: AnyMediaReference?, botId: PeerId? = nil, botPayload: String? = nil) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
                
        let context = self.context
        
        let inputIsActive = self.presentationInterfaceState.inputMode == .text
        
        self.chatDisplayNode.dismissInput()
                
        var bannedSendMedia: (Int32, Bool)?
        var canSendPolls = true
        if let peer = peer as? TelegramUser, peer.botInfo == nil {
            canSendPolls = false
        } else if peer is TelegramSecretChat {
            canSendPolls = false
        } else if let channel = peer as? TelegramChannel {
            if let value = channel.hasBannedPermission(.banSendMedia) {
                bannedSendMedia = value
            }
            if channel.hasBannedPermission(.banSendPolls) != nil {
                canSendPolls = false
            }
        } else if let group = peer as? TelegramGroup {
            if group.hasBannedPermission(.banSendMedia) {
                bannedSendMedia = (Int32.max, false)
            }
            if group.hasBannedPermission(.banSendPolls) {
                canSendPolls = false
            }
        }
        
        var availableButtons: [AttachmentButtonType] = [.gallery, .file, .location, .contact]
        if canSendPolls {
            availableButtons.insert(.poll, at: availableButtons.count - 1)
        }
        
        let presentationData = self.presentationData
        
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }
        
        let buttons: Signal<([AttachmentButtonType], AttachmentButtonType?), NoError>
        if !isScheduledMessages {
            buttons = self.context.engine.messages.attachMenuBots()
            |> map { attachMenuBots in
                var buttons = availableButtons
                var initialButton: AttachmentButtonType?
                if botId == nil {
                    initialButton = .gallery
                }
                
                var peerType: AttachMenuBots.Bot.PeerFlags = []
                if let user = peer as? TelegramUser {
                    if let _ = user.botInfo {
                        peerType.insert(.bot)
                    } else {
                        peerType.insert(.user)
                    }
                } else if let _ = peer as? TelegramGroup {
                    peerType = .group
                } else if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        peerType = .channel
                    } else {
                        peerType = .group
                    }
                }
                 
                for bot in attachMenuBots.reversed() {
                    var peerType = peerType
                    if bot.peer.id == peer.id {
                        peerType.insert(.sameBot)
                        peerType.remove(.bot)
                    }
                    
                    if !bot.peerTypes.intersection(peerType).isEmpty {
                        let button: AttachmentButtonType = .app(bot.peer, bot.shortName, bot.icons)
                        buttons.insert(button, at: 1)
                        
                        if initialButton == nil && bot.peer.id == botId {
                            initialButton = button
                        }
                    }
                }
                return (buttons, initialButton)
            }
        } else {
            buttons = .single((availableButtons, .gallery))
        }
                    
        let dataSettings = self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        
        let _ = combineLatest(queue: Queue.mainQueue(), buttons, dataSettings).start(next: { [weak self] buttonsAndInitialButton, dataSettings in
            guard let strongSelf = self else {
                return
            }
            
            let (buttons, initialButton) = buttonsAndInitialButton
            
            guard let initialButton = initialButton else {
                if let botId = botId {
                    let _ = (context.engine.messages.getAttachMenuBot(botId: botId)
                    |> deliverOnMainQueue).start(next: { bot in
                        let peer = EnginePeer(bot.peer)
                        let controller = addWebAppToAttachmentController(context: context, peerName: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), icons: bot.icons, completion: {
                            let _ = (context.engine.messages.addBotToAttachMenu(botId: botId)
                            |> deliverOnMainQueue).start(error: { _ in
                                
                            }, completed: {
                                strongSelf.presentAttachmentBot(botId: botId, payload: botPayload)
                            })
                        })
                        strongSelf.present(controller, in: .window(.root))
                    }, error: { _ in
                        strongSelf.present(textAlertController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    })
                }
                return
            }
            
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
            
            let currentMediaController = Atomic<MediaPickerScreen?>(value: nil)
            let currentFilesController = Atomic<AttachmentContainable?>(value: nil)
            let currentLocationController = Atomic<AttachmentContainable?>(value: nil)
            
            let attachmentController = AttachmentController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, chatLocation: strongSelf.chatLocation, buttons: buttons, initialButton: initialButton)
            attachmentController.requestController = { [weak self, weak attachmentController] type, completion in
                guard let strongSelf = self else {
                    return
                }
                switch type {
                case .gallery:
                    strongSelf.controllerNavigationDisposable.set(nil)
                    let existingController = currentMediaController.with { $0 }
                    if let controller = existingController {
                        completion(controller, controller.mediaPickerContext)
                        controller.prepareForReuse()
                        return
                    }
                    strongSelf.presentMediaPicker(saveEditedPhotos: dataSettings.storeEditedPhotos, bannedSendMedia: bannedSendMedia, present: { controller, mediaPickerContext in
                        let _ = currentMediaController.swap(controller)
                        if !inputText.string.isEmpty {
                            mediaPickerContext?.setCaption(inputText)
                        }
                        completion(controller, mediaPickerContext)
                    }, updateMediaPickerContext: { [weak attachmentController] mediaPickerContext in
                        attachmentController?.mediaPickerContext = mediaPickerContext
                    }, completion: { [weak self] signals, silentPosting, scheduleTime, getAnimatedTransitionSource, completion in
                        if !inputText.string.isEmpty {
                            self?.clearInputText()
                        }
                        self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
                    })
                case .file:
                    strongSelf.controllerNavigationDisposable.set(nil)
                    let existingController = currentFilesController.with { $0 }
                    if let controller = existingController {
                        completion(controller, nil)
                        controller.prepareForReuse()
                        return
                    }
                    let controller = attachmentFileController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, bannedSendMedia: bannedSendMedia, presentGallery: { [weak self, weak attachmentController] in
                        attachmentController?.dismiss(animated: true)
                        self?.presentFileGallery()
                    }, presentFiles: { [weak self, weak attachmentController] in
                        attachmentController?.dismiss(animated: true)
                        self?.presentICloudFileGallery()
                    }, send: { [weak self] mediaReference in
                        guard let strongSelf = self, let peerId = strongSelf.chatLocation.peerId else {
                            return
                        }
                        let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: mediaReference, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)
                        let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: strongSelf.transformEnqueueMessages([message]))
                        |> deliverOnMainQueue).start(next: { [weak self] _ in
                            if let strongSelf = self, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                                strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                            }
                        })
                    })
                    let _ = currentFilesController.swap(controller)
                    completion(controller, nil)
                case .location:
                    strongSelf.controllerNavigationDisposable.set(nil)
                    let existingController = currentLocationController.with { $0 }
                    if let controller = existingController {
                        completion(controller, nil)
                        controller.prepareForReuse()
                        return
                    }
                    let selfPeerId: PeerId
                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                        selfPeerId = peer.id
                    } else if let peer = peer as? TelegramChannel, case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                        selfPeerId = peer.id
                    } else {
                        selfPeerId = strongSelf.context.account.peerId
                    }
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfPeerId))
                    |> deliverOnMainQueue).start(next: { [weak self] selfPeer in
                        guard let strongSelf = self, let selfPeer = selfPeer else {
                            return
                        }
                        let hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != strongSelf.context.account.peerId && strongSelf.presentationInterfaceState.subject != .scheduledMessages
                        let controller = LocationPickerController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, mode: .share(peer: peer, selfPeer: selfPeer._asPeer(), hasLiveLocation: hasLiveLocation), completion: { [weak self] location, _ in
                            guard let strongSelf = self else {
                                return
                            }
                            let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                            let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: location), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)
                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                if let strongSelf = self {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                    })
                                }
                            }, nil)
                            strongSelf.sendMessages([message])
                        })
                        completion(controller, nil)
                        
                        let _ = currentLocationController.swap(controller)
                    })
                case .contact:
                    let contactsController = ContactSelectionControllerImpl(ContactSelectionControllerParams(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: true))
                    contactsController.presentScheduleTimePicker = { [weak self] completion in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(completion: completion)
                        }
                    }
                    contactsController.navigationPresentation = .modal
                    completion(contactsController, contactsController.mediaPickerContext)
                    strongSelf.controllerNavigationDisposable.set((contactsController.result
                    |> deliverOnMainQueue).start(next: { [weak self] peers in
                        if let strongSelf = self, let (peers, _, silent, scheduleTime, text) = peers {
                            var textEnqueueMessage: EnqueueMessage?
                            if let text = text, text.length > 0 {
                                var attributes: [MessageAttribute] = []
                                let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                                if !entities.isEmpty {
                                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                                }
                                textEnqueueMessage = .message(text: text.string, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)
                            }
                            if peers.count > 1 {
                                var enqueueMessages: [EnqueueMessage] = []
                                if let textEnqueueMessage = textEnqueueMessage {
                                    enqueueMessages.append(textEnqueueMessage)
                                }
                                for peer in peers {
                                    var media: TelegramMediaContact?
                                    switch peer {
                                        case let .peer(contact, _, _):
                                            guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                                continue
                                            }
                                            let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                            
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: contact.id, vCardData: nil)
                                        case let .deviceContact(_, basicData):
                                            guard !basicData.phoneNumbers.isEmpty else {
                                                continue
                                            }
                                            let contactData = DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                            
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: nil)
                                    }

                                    if let media = media {
                                        let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                            if let strongSelf = self {
                                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                })
                                            }
                                        }, nil)
                                        let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)
                                        enqueueMessages.append(message)
                                    }
                                }
                                strongSelf.sendMessages(strongSelf.transformEnqueueMessages(enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                            } else if let peer = peers.first {
                                let dataSignal: Signal<(Peer?,  DeviceContactExtendedData?), NoError>
                                switch peer {
                                    case let .peer(contact, _, _):
                                        guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                            return
                                        }
                                        let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                        let context = strongSelf.context
                                        dataSignal = (strongSelf.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                                        |> take(1)
                                        |> mapToSignal { basicData -> Signal<(Peer?,  DeviceContactExtendedData?), NoError> in
                                            var stableId: String?
                                            let queryPhoneNumber = formatPhoneNumber(phoneNumber)
                                            outer: for (id, data) in basicData {
                                                for phoneNumber in data.phoneNumbers {
                                                    if formatPhoneNumber(phoneNumber.value) == queryPhoneNumber {
                                                        stableId = id
                                                        break outer
                                                    }
                                                }
                                            }
                                            
                                            if let stableId = stableId {
                                                return (context.sharedContext.contactDataManager?.extendedData(stableId: stableId) ?? .single(nil))
                                                |> take(1)
                                                |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                                                    return (contact, extendedData)
                                                }
                                            } else {
                                                return .single((contact, contactData))
                                            }
                                        }
                                    case let .deviceContact(id, _):
                                        dataSignal = (strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                                        |> take(1)
                                        |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                                            return (nil, extendedData)
                                        }
                                }
                                strongSelf.controllerNavigationDisposable.set((dataSignal
                                |> deliverOnMainQueue).start(next: { peerAndContactData in
                                    if let strongSelf = self, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 {
                                        if contactData.isPrimitive {
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                                            let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                    })
                                                }
                                            }, nil)
                                            
                                            var enqueueMessages: [EnqueueMessage] = []
                                            if let textEnqueueMessage = textEnqueueMessage {
                                                enqueueMessages.append(textEnqueueMessage)
                                            }
                                            enqueueMessages.append(.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil))
                                            strongSelf.sendMessages(strongSelf.transformEnqueueMessages(enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                        } else {
                                            let contactController = strongSelf.context.sharedContext.makeDeviceContactInfoController(context: strongSelf.context, subject: .filter(peer: peerAndContactData.0, contactId: nil, contactData: contactData, completion: { peer, contactData in
                                                guard let strongSelf = self, !contactData.basicData.phoneNumbers.isEmpty else {
                                                    return
                                                }
                                                let phone = contactData.basicData.phoneNumbers[0].value
                                                if let vCardData = contactData.serializedVCard() {
                                                    let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                        if let strongSelf = self {
                                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                            })
                                                        }
                                                    }, nil)
                                                    
                                                    var enqueueMessages: [EnqueueMessage] = []
                                                    if let textEnqueueMessage = textEnqueueMessage {
                                                        enqueueMessages.append(textEnqueueMessage)
                                                    }
                                                    enqueueMessages.append(.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil))
                                                    strongSelf.sendMessages(strongSelf.transformEnqueueMessages(enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                                }
                                            }), completed: nil, cancelled: nil)
                                            strongSelf.effectiveNavigationController?.pushViewController(contactController)
                                        }
                                    }
                                }))
                            }
                        }
                    }))
                case .poll:
                    let controller = strongSelf.configurePollCreation()
                    completion(controller, nil)
                    strongSelf.controllerNavigationDisposable.set(nil)
                case let .app(bot, botName, _):
                    let params = WebAppParameters(peerId: peer.id, botId: bot.id, botName: botName, url: nil, queryId: nil, payload: botPayload, buttonText: nil, keepAliveSignal: nil, fromMenu: false, isSimple: false)
                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                    let controller = WebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, replyToMessageId: replyMessageId)
                    controller.openUrl = { [weak self] url in
                        self?.openUrl(url, concealed: true, forceExternal: true)
                    }
                    controller.getNavigationController = { [weak self] in
                        return self?.effectiveNavigationController
                    }
                    controller.completion = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                            })
                            strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                        }
                    }
                    completion(controller, controller.mediaPickerContext)
                    strongSelf.controllerNavigationDisposable.set(nil)
                default:
                    break
                }
            }
            let present = {
                attachmentController.navigationPresentation = .flatModal
                strongSelf.push(attachmentController)
                strongSelf.attachmentController = attachmentController
            }
            
            if inputIsActive {
                Queue.mainQueue().after(0.15, {
                    present()
                })
            } else {
                present()
            }
        })
    }
    
    private func oldPresentAttachmentMenu(editMediaOptions: MessageMediaEditingOptions?, editMediaReference: AnyMediaReference?) {
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).start(next: { [weak self] settings in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            strongSelf.chatDisplayNode.dismissInput()

            var bannedSendMedia: (Int32, Bool)?
            var canSendPolls = true
            if let channel = peer as? TelegramChannel {
                if let value = channel.hasBannedPermission(.banSendMedia) {
                    bannedSendMedia = value
                }
                if channel.hasBannedPermission(.banSendPolls) != nil {
                    canSendPolls = false
                }
            } else if let group = peer as? TelegramGroup {
                if group.hasBannedPermission(.banSendMedia) {
                    bannedSendMedia = (Int32.max, false)
                }
                if group.hasBannedPermission(.banSendPolls) {
                    canSendPolls = false
                }
            }
        
            if editMediaOptions == nil, let (untilDate, personal) = bannedSendMedia {
                let banDescription: String
                if untilDate != 0 && untilDate != Int32.max {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).string
                } else if personal {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMedia
                } else {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_DefaultRestrictedMedia
                }
                
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                var items: [ActionSheetItem] = []
                items.append(ActionSheetTextItem(title: banDescription))
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_Location, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.presentLocationPicker()
                }))
                if canSendPolls {
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.AttachmentMenu_Poll, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let controller = self?.configurePollCreation() {
                            self?.effectiveNavigationController?.pushViewController(controller)
                        }
                    }))
                }
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_Contact, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.presentContactPicker()
                }))
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.present(actionSheet, in: .window(.root))
                
                return
            }
        
            let legacyController = LegacyController(presentation: .custom, theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
            legacyController.blocksBackgroundWhenInOverlay = true
            legacyController.acceptsFocusWhenInOverlay = true
            legacyController.statusBar.statusBarStyle = .Ignore
            legacyController.controllerLoaded = { [weak legacyController] in
                legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
            }
        
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            legacyController.bind(controller: navigationController)
        
            legacyController.enableSizeClassSignal = true
            
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
            let menuEditMediaOptions = editMediaOptions.flatMap { options -> LegacyAttachmentMenuMediaEditing in
                var result: LegacyAttachmentMenuMediaEditing = .none
                if options.contains(.imageOrVideo) {
                    result = .imageOrVideo(editMediaReference)
                }
                return result
            }
            
            var slowModeEnabled = false
            if let channel = peer as? TelegramChannel, channel.isRestrictedBySlowmode {
                slowModeEnabled = true
            }
            
            let controller = legacyAttachmentMenu(context: strongSelf.context, peer: peer, chatLocation: strongSelf.chatLocation, editMediaOptions: menuEditMediaOptions, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, hasSchedule: strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, canSendPolls: canSendPolls, updatedPresentationData: strongSelf.updatedPresentationData, parentController: legacyController, recentlyUsedInlineBots: strongSelf.recentlyUsedInlineBotsValue, initialCaption: inputText, openGallery: {
                self?.presentOldMediaPicker(fileMode: false, editingMedia: editMediaOptions != nil, present: { [weak self] c, _ in
                    self?.effectiveNavigationController?.pushViewController(c)
                }, completion: { signals, silentPosting, scheduleTime in
                    if !inputText.string.isEmpty {
                        strongSelf.clearInputText()
                    }
                    if editMediaOptions != nil {
                        self?.editMessageMediaWithLegacySignals(signals)
                    } else {
                        self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                    }
                })
            }, openCamera: { [weak self] cameraView, menuController in
                if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    var photoOnly = false
                    if let callManager = strongSelf.context.sharedContext.callManager as? PresentationCallManagerImpl, callManager.hasActiveCall {
                        photoOnly = true
                    }
                    
                    presentedLegacyCamera(context: strongSelf.context, peer: peer, chatLocation: strongSelf.chatLocation, cameraView: cameraView, menuController: menuController, parentController: strongSelf, editingMedia: editMediaOptions != nil, saveCapturedPhotos:  peer.id.namespace != Namespaces.Peer.SecretChat, mediaGrouping: true, initialCaption: inputText, hasSchedule: strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, photoOnly: photoOnly, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime in
                        if let strongSelf = self {
                            if editMediaOptions != nil {
                                strongSelf.editMessageMediaWithLegacySignals(signals!)
                            } else {
                                strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                            }
                            if !inputText.string.isEmpty {
                                strongSelf.clearInputText()
                            }
                        }
                    }, recognizedQRCode: { [weak self] code in
                        if let strongSelf = self {
                            if let (host, port, username, password, secret) = parseProxyUrl(code) {
                                strongSelf.openResolved(result: ResolvedUrl.proxy(host: host, port: port, username: username, password: password, secret: secret), sourceMessageId: nil)
                            }
                        }
                    }, presentSchedulePicker: { [weak self] _, done in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(style: .media, completion: { [weak self] time in
                                if let strongSelf = self {
                                    done(time)
                                    if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                        strongSelf.openScheduledMessages()
                                    }
                                }
                            })
                        }
                    }, presentTimerPicker: { [weak self] done in
                        if let strongSelf = self {
                            strongSelf.presentTimerPicker(style: .media, completion: { time in
                                done(time)
                            })
                        }
                    }, presentStickers: { [weak self] completion in
                        if let strongSelf = self {
                            let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                                completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                                return true
                            })
                            strongSelf.present(controller, in: .window(.root))
                            return controller
                        } else {
                            return nil
                        }
                    }, getCaptionPanelView: { [weak self] in
                        return self?.getCaptionPanelView()
                    })
                }
            }, openFileGallery: {
                self?.presentFileMediaPickerOptions(editingMessage: editMediaOptions != nil)
            }, openWebSearch: { [weak self] in
                self?.presentWebSearch(editingMessage: editMediaOptions != nil, attachment: false, present: { [weak self] c, a in
                    self?.present(c, in: .window(.root), with: a)
                })
            }, openMap: {
                self?.presentLocationPicker()
            }, openContacts: {
                self?.presentContactPicker()
            }, openPoll: {
                if let controller = self?.configurePollCreation() {
                    self?.effectiveNavigationController?.pushViewController(controller)
                }
            }, presentSelectionLimitExceeded: {
                guard let strongSelf = self else {
                    return
                }
                let text: String
                if slowModeEnabled {
                    text = strongSelf.presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                } else {
                    text = strongSelf.presentationData.strings.Chat_AttachmentLimitReached
                }
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }, presentCantSendMultipleFiles: {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.Chat_AttachmentMultipleFilesDisabled, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }, presentJpegConversionAlert: { completion in
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.MediaPicker_JpegConversionText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.MediaPicker_KeepHeic, action: {
                    completion(false)
                }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.MediaPicker_ConvertToJpeg, action: {
                    completion(true)
                })], actionLayout: .vertical), in: .window(.root))
            }, presentSchedulePicker: { [weak self] _, done in
                if let strongSelf = self {
                    strongSelf.presentScheduleTimePicker(style: .media, completion: { [weak self] time in
                        if let strongSelf = self {
                            done(time)
                            if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                strongSelf.openScheduledMessages()
                            }
                         }
                    })
                }
            }, presentTimerPicker: { [weak self] done in
                if let strongSelf = self {
                    strongSelf.presentTimerPicker(style: .media, completion: { time in
                        done(time)
                    })
                }
            }, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime, getAnimatedTransitionSource, completion in
                guard let strongSelf = self else {
                    completion()
                    return
                }
                if !inputText.string.isEmpty {
                    strongSelf.clearInputText()
                }
                if editMediaOptions != nil {
                    strongSelf.editMessageMediaWithLegacySignals(signals!)
                    completion()
                } else {
                    let immediateCompletion = getAnimatedTransitionSource == nil
                    strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: {
                        if !immediateCompletion {
                            completion()
                        }
                    })
                    if immediateCompletion {
                        completion()
                    }
                }
            }, selectRecentlyUsedInlineBot: { [weak self] peer in
                if let strongSelf = self, let addressName = peer.addressName {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState({ $0.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: "@" + addressName + " "))) }).updatedInputMode({ _ in
                            return .text
                        })
                    })
                }
            }, presentStickers: { [weak self] completion in
                if let strongSelf = self {
                    let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                        completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                        return true
                    })
                    strongSelf.present(controller, in: .window(.root))
                    return controller
                } else {
                    return nil
                }
            }, getCaptionPanelView: { [weak self] in
                return self?.getCaptionPanelView()
            }, present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            })
            controller.didDismiss = { [weak legacyController] _ in
                legacyController?.dismiss()
            }
            controller.customRemoveFromParentViewController = { [weak legacyController] in
                legacyController?.dismiss()
            }
        
            legacyController.blocksBackgroundWhenInOverlay = true
            strongSelf.present(legacyController, in: .window(.root))
            controller.present(in: emptyController, sourceView: nil, animated: true)
            
            let presentationDisposable = strongSelf.updatedPresentationData.1.start(next: { [weak controller] presentationData in
                if let controller = controller {
                    controller.pallete = legacyMenuPaletteFromTheme(presentationData.theme, forceDark: false)
                }
            })
            legacyController.disposables.add(presentationDisposable)
        })
    }
    
    private func presentFileGallery(editingMessage: Bool = false) {
        self.presentOldMediaPicker(fileMode: true, editingMedia: editingMessage, present: { [weak self] c, _ in
            self?.effectiveNavigationController?.pushViewController(c)
        }, completion: { [weak self] signals, silentPosting, scheduleTime in
            if editingMessage {
                self?.editMessageMediaWithLegacySignals(signals)
            } else {
                self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
            }
        })
    }
    
    private func presentICloudFileGallery(editingMessage: Bool = false) {
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        )
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let (accountPeer, limits, premiumLimits) = result
            let isPremium = accountPeer?.isPremium ?? false
            
            strongSelf.present(legacyICloudFilePicker(theme: strongSelf.presentationData.theme, completion: { [weak self] urls in
                if let strongSelf = self, !urls.isEmpty {
                    var signals: [Signal<ICloudFileDescription?, NoError>] = []
                    for url in urls {
                        signals.append(iCloudFileDescription(url))
                    }
                    strongSelf.enqueueMediaMessageDisposable.set((combineLatest(signals)
                    |> deliverOnMainQueue).start(next: { results in
                        if let strongSelf = self {
                            let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                            
                            for item in results {
                                if let item = item {
                                    if item.fileSize > Int64(premiumLimits.maxUploadFileParts) * 512 * 1024 {
                                        let controller = PremiumLimitScreen(context: strongSelf.context, subject: .files, count: 4, action: {
                                        })
                                        strongSelf.push(controller)
                                        return
                                    } else if item.fileSize > Int64(limits.maxUploadFileParts) * 512 * 1024 && !isPremium {
                                        let context = strongSelf.context
                                        var replaceImpl: ((ViewController) -> Void)?
                                        let controller = PremiumLimitScreen(context: context, subject: .files, count: 2, action: {
                                            replaceImpl?(PremiumIntroScreen(context: context, source: .upload))
                                        })
                                        replaceImpl = { [weak controller] c in
                                            controller?.replace(with: c)
                                        }
                                        strongSelf.push(controller)
                                        return
                                    }
                                }
                            }
                            
                            var groupingKey: Int64?
                            var fileTypes: (music: Bool, other: Bool) = (false, false)
                            if results.count > 1 {
                                for item in results {
                                    if let item = item {
                                        let pathExtension = (item.fileName as NSString).pathExtension.lowercased()
                                        if ["mp3", "m4a"].contains(pathExtension) {
                                            fileTypes.music = true
                                        } else {
                                            fileTypes.other = true
                                        }
                                    }
                                }
                            }
                            if fileTypes.music != fileTypes.other {
                                groupingKey = Int64.random(in: Int64.min ... Int64.max)
                            }
                            
                            var messages: [EnqueueMessage] = []
                            for item in results {
                                if let item = item {
                                    let fileId = Int64.random(in: Int64.min ... Int64.max)
                                    let mimeType = guessMimeTypeByFileExtension((item.fileName as NSString).pathExtension)
                                    var previewRepresentations: [TelegramMediaImageRepresentation] = []
                                    if mimeType.hasPrefix("image/") || mimeType == "application/pdf" {
                                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: ICloudFileResource(urlData: item.urlData, thumbnail: true), progressiveSizes: [], immediateThumbnailData: nil))
                                    }
                                    var attributes: [TelegramMediaFileAttribute] = []
                                    attributes.append(.FileName(fileName: item.fileName))
                                    if let audioMetadata = item.audioMetadata {
                                        attributes.append(.Audio(isVoice: false, duration: audioMetadata.duration, title: audioMetadata.title, performer: audioMetadata.performer, waveform: nil))
                                    }
                                    
                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes)
                                    let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: replyMessageId, localGroupingKey: groupingKey, correlationId: nil)
                                    messages.append(message)
                                }
                                if let _ = groupingKey, messages.count % 10 == 0 {
                                    groupingKey = Int64.random(in: Int64.min ... Int64.max)
                                }
                            }
                            
                            if !messages.isEmpty {
                                if editingMessage {
                                    strongSelf.editMessageMediaWithMessages(messages)
                                } else {
                                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                        if let strongSelf = self {
                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                            })
                                        }
                                    }, nil)
                                    strongSelf.sendMessages(messages)
                                }
                            }
                        }
                    }))
                }
            }), in: .window(.root))
        })
    }
    
    private func presentFileMediaPickerOptions(editingMessage: Bool) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FilePhotoOrVideo, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.presentFileGallery(editingMessage: editingMessage)
                }
            }),
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FileICloudDrive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.presentICloudFileGallery(editingMessage: editingMessage)
                }
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.chatDisplayNode.dismissInput()
        self.present(actionSheet, in: .window(.root))
    }
    
    private func presentMediaPicker(saveEditedPhotos: Bool, bannedSendMedia: (Int32, Bool)?, present: @escaping (MediaPickerScreen, AttachmentMediaPickerContext?) -> Void, updateMediaPickerContext: @escaping (AttachmentMediaPickerContext?) -> Void, completion: @escaping ([Any], Bool, Int32?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        let controller = MediaPickerScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: EnginePeer(peer), chatLocation: self.chatLocation, bannedSendMedia: bannedSendMedia, saveEditedPhotos: saveEditedPhotos)
        let mediaPickerContext = controller.mediaPickerContext
        controller.openCamera = { [weak self] cameraView in
            self?.openCamera(cameraView: cameraView)
        }
        controller.presentWebSearch = { [weak self, weak controller] mediaGroups in
            self?.presentWebSearch(editingMessage: false, attachment: true, present: { [weak controller] c, a in
                controller?.present(c, in: .current)
                if let webSearchController = c as? WebSearchController {
                    webSearchController.searchingUpdated = { [weak mediaGroups] searching in
                        if let mediaGroups = mediaGroups, mediaGroups.isNodeLoaded {
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                            transition.updateAlpha(node: mediaGroups.displayNode, alpha: searching ? 0.0 : 1.0)
                            mediaGroups.displayNode.isUserInteractionEnabled = !searching
                        }
                    }
                    webSearchController.present(mediaGroups, in: .current)
                    webSearchController.dismissed = {
                        updateMediaPickerContext(mediaPickerContext)
                    }
                    controller?.webSearchController = webSearchController
                    updateMediaPickerContext(webSearchController.mediaPickerContext)
                }
            })
        }
        controller.presentStickers = { [weak self] completion in
            if let strongSelf = self {
                let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                    completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                    return true
                })
                strongSelf.present(controller, in: .window(.root))
                return controller
            } else {
                return nil
            }
        }
        controller.presentSchedulePicker = { [weak self] media, done in
            if let strongSelf = self {
                strongSelf.presentScheduleTimePicker(style: media ? .media : .default, completion: { [weak self] time in
                    if let strongSelf = self {
                        done(time)
                        if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                            strongSelf.openScheduledMessages()
                        }
                    }
                })
            }
        }
        controller.presentTimerPicker = { [weak self] done in
            if let strongSelf = self {
                strongSelf.presentTimerPicker(style: .media, completion: { time in
                    done(time)
                })
            }
        }
        controller.getCaptionPanelView = { [weak self] in
            return self?.getCaptionPanelView()
        }
        controller.legacyCompletion = { signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion in
            completion(signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion)
        }
        present(controller, mediaPickerContext)
    }
    
    private func presentOldMediaPicker(fileMode: Bool, editingMedia: Bool, present: @escaping (AttachmentContainable, AttachmentMediaPickerContext) -> Void, completion: @escaping ([Any], Bool, Int32) -> Void) {
        let engine = self.context.engine
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> Signal<(GeneratedMediaStoreSettings, EngineConfiguration.SearchBots), NoError> in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            
            return engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
            |> map { configuration -> (GeneratedMediaStoreSettings, EngineConfiguration.SearchBots) in
                return (entry ?? GeneratedMediaStoreSettings.defaultSettings, configuration)
            }
        }
        |> switchToLatest
        |> deliverOnMainQueue).start(next: { [weak self] settings, searchBotsConfiguration in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
            var selectionLimit: Int = 100
            var slowModeEnabled = false
            if let channel = peer as? TelegramChannel, channel.isRestrictedBySlowmode {
                selectionLimit = 10
                slowModeEnabled = true
            }
            
            let _ = legacyAssetPicker(context: strongSelf.context, presentationData: strongSelf.presentationData, editingMedia: editingMedia, fileMode: fileMode, peer: peer, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, selectionLimit: selectionLimit).start(next: { generator in
                if let strongSelf = self {
                    let legacyController = LegacyController(presentation: fileMode ? .navigation : .custom, theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
                    legacyController.navigationPresentation = .modal
                    legacyController.statusBar.statusBarStyle = strongSelf.presentationData.theme.rootController.statusBarStyle.style
                    legacyController.controllerLoaded = { [weak legacyController] in
                        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
                        legacyController?.view.disablesInteractiveModalDismiss = true
                    }
                    let controller = generator(legacyController.context)
                    
                    legacyController.bind(controller: controller)
                    legacyController.deferScreenEdgeGestures = [.top]
                                        
                    configureLegacyAssetPicker(controller, context: strongSelf.context, peer: peer, chatLocation: strongSelf.chatLocation, initialCaption: inputText, hasSchedule: strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, presentWebSearch: editingMedia ? nil : { [weak self, weak legacyController] in
                        if let strongSelf = self {
                            let controller = WebSearchController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: EnginePeer(peer), chatLocation: strongSelf.chatLocation, configuration: searchBotsConfiguration, mode: .media(attachment: false, completion: { results, selectionState, editingState, silentPosting in
                                if let legacyController = legacyController {
                                    legacyController.dismiss()
                                }
                                legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { result in
                                    if let strongSelf = self {
                                        strongSelf.enqueueChatContextResult(results, result, hideVia: true)
                                    }
                                }, enqueueMediaMessages: { signals in
                                    if let strongSelf = self {
                                        if editingMedia {
                                            strongSelf.editMessageMediaWithLegacySignals(signals)
                                        } else {
                                            strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting)
                                        }
                                    }
                                })
                            }))
                            controller.presentStickers = { [weak self] completion in
                                if let strongSelf = self {
                                    let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                                        completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                                        return true
                                    })
                                    strongSelf.present(controller, in: .window(.root))
                                    return controller
                                } else {
                                    return nil
                                }
                            }
                            controller.getCaptionPanelView = { [weak self] in
                                return self?.getCaptionPanelView()
                            }
                            strongSelf.effectiveNavigationController?.pushViewController(controller)
                        }
                    }, presentSelectionLimitExceeded: {
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let text: String
                        if slowModeEnabled {
                            text = strongSelf.presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                        } else {
                            text = strongSelf.presentationData.strings.Chat_AttachmentLimitReached
                        }
                        
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }, presentSchedulePicker: { [weak self] media, done in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(style: media ? .media : .default, completion: { [weak self] time in
                                if let strongSelf = self {
                                     done(time)
                                     if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                         strongSelf.openScheduledMessages()
                                     }
                                 }
                            })
                        }
                    }, presentTimerPicker: { [weak self] done in
                        if let strongSelf = self {
                            strongSelf.presentTimerPicker(style: .media, completion: { time in
                                done(time)
                            })
                        }
                    }, presentStickers: { [weak self] completion in
                        if let strongSelf = self {
                            let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                                completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                                return true
                            })
                            strongSelf.present(controller, in: .window(.root))
                            return controller
                        } else {
                            return nil
                        }
                    }, getCaptionPanelView: { [weak self] in
                        return self?.getCaptionPanelView()
                    })
                    controller.descriptionGenerator = legacyAssetPickerItemGenerator()
                    controller.completionBlock = { [weak legacyController] signals, silentPosting, scheduleTime in
                        if let legacyController = legacyController {
                            legacyController.dismiss(animated: true)
                            completion(signals!, silentPosting, scheduleTime)
                        }
                    }
                    controller.dismissalBlock = { [weak legacyController] in
                        if let legacyController = legacyController {
                            legacyController.dismiss(animated: true)
                        }
                    }
                    strongSelf.chatDisplayNode.dismissInput()
                    present(legacyController, LegacyAssetPickerContext(controller: controller))
                }
            })
        })
    }
    
    private func presentWebSearch(editingMessage: Bool, attachment: Bool, present: @escaping (ViewController, Any?) -> Void) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
        |> deliverOnMainQueue).start(next: { [weak self] configuration in
            if let strongSelf = self {
                let controller = WebSearchController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: EnginePeer(peer), chatLocation: strongSelf.chatLocation, configuration: configuration, mode: .media(attachment: attachment, completion: { [weak self] results, selectionState, editingState, silentPosting in
                    self?.attachmentController?.dismiss(animated: true, completion: nil)
                    legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { [weak self] result in
                        if let strongSelf = self {
                            strongSelf.enqueueChatContextResult(results, result, hideVia: true)
                        }
                    }, enqueueMediaMessages: { [weak self] signals in
                        if let strongSelf = self, !signals.isEmpty {
                            if editingMessage {
                                strongSelf.editMessageMediaWithLegacySignals(signals)
                            } else {
                                strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting)
                            }
                        }
                    })
                }))
                controller.presentStickers = { [weak self] completion in
                    if let strongSelf = self {
                        let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                            completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                            return true
                        })
                        strongSelf.present(controller, in: .window(.root))
                        return controller
                    } else {
                        return nil
                    }
                }
                controller.getCaptionPanelView = { [weak self] in
                    return self?.getCaptionPanelView()
                }
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        })
    }
      
    private func presentLocationPicker() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        let selfPeerId: PeerId
        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
            selfPeerId = peer.id
        } else if let peer = peer as? TelegramChannel, case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
            selfPeerId = peer.id
        } else {
            selfPeerId = self.context.account.peerId
        }
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfPeerId))
        |> deliverOnMainQueue).start(next: { [weak self] selfPeer in
            guard let strongSelf = self, let selfPeer = selfPeer else {
                return
            }
            let hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != strongSelf.context.account.peerId && strongSelf.presentationInterfaceState.subject != .scheduledMessages
            let controller = LocationPickerController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, mode: .share(peer: peer, selfPeer: selfPeer._asPeer(), hasLiveLocation: hasLiveLocation), completion: { [weak self] location, _ in
                guard let strongSelf = self else {
                    return
                }
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: location), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                }, nil)
                strongSelf.sendMessages([message])
            })
            strongSelf.effectiveNavigationController?.pushViewController(controller)
            strongSelf.chatDisplayNode.dismissInput()
        })
    }
    
    private func presentContactPicker() {
        let contactsController = ContactSelectionControllerImpl(ContactSelectionControllerParams(context: self.context, updatedPresentationData: self.updatedPresentationData, title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: true))
        contactsController.navigationPresentation = .modal
        self.chatDisplayNode.dismissInput()
        self.effectiveNavigationController?.pushViewController(contactsController)
        self.controllerNavigationDisposable.set((contactsController.result
        |> deliverOnMainQueue).start(next: { [weak self] peers in
            if let strongSelf = self, let (peers, _, _, _, _) = peers {
                if peers.count > 1 {
                    var enqueueMessages: [EnqueueMessage] = []
                    for peer in peers {
                        var media: TelegramMediaContact?
                        switch peer {
                            case let .peer(contact, _, _):
                                guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                    continue
                                }
                                let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                
                                let phone = contactData.basicData.phoneNumbers[0].value
                                media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: contact.id, vCardData: nil)
                            case let .deviceContact(_, basicData):
                                guard !basicData.phoneNumbers.isEmpty else {
                                    continue
                                }
                                let contactData = DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                
                                let phone = contactData.basicData.phoneNumbers[0].value
                                media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: nil)
                        }

                        if let media = media {
                            let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                if let strongSelf = self {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                    })
                                }
                            }, nil)
                            let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)
                            enqueueMessages.append(message)
                        }
                    }
                    strongSelf.sendMessages(enqueueMessages)
                } else if let peer = peers.first {
                    let dataSignal: Signal<(Peer?,  DeviceContactExtendedData?), NoError>
                    switch peer {
                        case let .peer(contact, _, _):
                            guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                return
                            }
                            let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                            let context = strongSelf.context
                            dataSignal = (strongSelf.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                            |> take(1)
                            |> mapToSignal { basicData -> Signal<(Peer?,  DeviceContactExtendedData?), NoError> in
                                var stableId: String?
                                let queryPhoneNumber = formatPhoneNumber(phoneNumber)
                                outer: for (id, data) in basicData {
                                    for phoneNumber in data.phoneNumbers {
                                        if formatPhoneNumber(phoneNumber.value) == queryPhoneNumber {
                                            stableId = id
                                            break outer
                                        }
                                    }
                                }
                                
                                if let stableId = stableId {
                                    return (context.sharedContext.contactDataManager?.extendedData(stableId: stableId) ?? .single(nil))
                                    |> take(1)
                                    |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                                        return (contact, extendedData)
                                    }
                                } else {
                                    return .single((contact, contactData))
                                }
                            }
                        case let .deviceContact(id, _):
                            dataSignal = (strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                            |> take(1)
                            |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                                return (nil, extendedData)
                            }
                    }
                    strongSelf.controllerNavigationDisposable.set((dataSignal
                    |> deliverOnMainQueue).start(next: { peerAndContactData in
                        if let strongSelf = self, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 {
                            if contactData.isPrimitive {
                                let phone = contactData.basicData.phoneNumbers[0].value
                                let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                    if let strongSelf = self {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                        })
                                    }
                                }, nil)
                                let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)
                                strongSelf.sendMessages([message])
                            } else {
                                let contactController = strongSelf.context.sharedContext.makeDeviceContactInfoController(context: strongSelf.context, subject: .filter(peer: peerAndContactData.0, contactId: nil, contactData: contactData, completion: { peer, contactData in
                                    guard let strongSelf = self, !contactData.basicData.phoneNumbers.isEmpty else {
                                        return
                                    }
                                    let phone = contactData.basicData.phoneNumbers[0].value
                                    if let vCardData = contactData.serializedVCard() {
                                        let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                        let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                            if let strongSelf = self {
                                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                })
                                            }
                                        }, nil)
                                        let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil)
                                        strongSelf.sendMessages([message])
                                    }
                                }), completed: nil, cancelled: nil)
                                strongSelf.effectiveNavigationController?.pushViewController(contactController)
                            }
                        }
                    }))
                }
            }
        }))
    }
    
    private func displayPollSolution(solution: TelegramMediaPollResults.Solution, sourceNode: ASDisplayNode, isAutomatic: Bool) {
        var maybeFoundItemNode: ChatMessageItemView?
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if sourceNode.view.isDescendant(of: itemNode.view) {
                    maybeFoundItemNode = itemNode
                }
            }
        }
        guard let foundItemNode = maybeFoundItemNode, let item = foundItemNode.item else {
            return
        }
        
        var found = false
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                if controller.text == solution.text && controller.textEntities == solution.entities {
                    found = true
                    controller.dismiss()
                    return false
                }
            }
            return true
        })
        if found {
            return
        }
        
        let tooltipScreen = TooltipScreen(account: self.context.account, text: solution.text, textEntities: solution.entities, icon: .info, location: .top, shouldDismissOnTouch: { point in
            return .ignore
        }, openActiveTextItem: { [weak self] item, action in
            guard let strongSelf = self else {
                return
            }
            switch item {
            case let .url(url, concealed):
                switch action {
                case .tap:
                    strongSelf.openUrl(url, concealed: concealed)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.url(url), nil)
                }
            case let .mention(peerId, mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil, nil)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.peerMention(peerId, mention), nil)
                }
            case let .textMention(mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeerMention(mention)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.mention(mention), nil)
                }
            case let .botCommand(command):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.sendBotCommand(nil, command)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.command(command), nil)
                }
            case let .hashtag(hashtag):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openHashtag(nil, hashtag)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.hashtag(hashtag), nil)
                }
            }
        })
        
        let messageId = item.message.id
        self.controllerInteraction?.currentPollMessageWithTooltip = messageId
        self.updatePollTooltipMessageState(animated: !isAutomatic)
        
        tooltipScreen.willBecomeDismissed = { [weak self] tooltipScreen in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.controllerInteraction?.currentPollMessageWithTooltip == messageId {
                strongSelf.controllerInteraction?.currentPollMessageWithTooltip = nil
                strongSelf.updatePollTooltipMessageState(animated: true)
            }
        }
        
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
        
        self.present(tooltipScreen, in: .current)
    }
    
    public func displayPromoAnnouncement(text: String) {
        let psaText: String = text
        let psaEntities: [MessageTextEntity] = generateTextEntities(psaText, enabledTypes: .allUrl)
        
        var found = false
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                if controller.text == psaText {
                    found = true
                    controller.dismiss()
                    return false
                }
            }
            return true
        })
        if found {
            return
        }
        
        let tooltipScreen = TooltipScreen(account: self.context.account, text: psaText, textEntities: psaEntities, icon: .info, location: .top, displayDuration: .custom(10.0), shouldDismissOnTouch: { point in
            return .ignore
        }, openActiveTextItem: { [weak self] item, action in
            guard let strongSelf = self else {
                return
            }
            switch item {
            case let .url(url, concealed):
                switch action {
                case .tap:
                    strongSelf.openUrl(url, concealed: concealed)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.url(url), nil)
                }
            case let .mention(peerId, mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil, nil)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.peerMention(peerId, mention), nil)
                }
            case let .textMention(mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeerMention(mention)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.mention(mention), nil)
                }
            case let .botCommand(command):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.sendBotCommand(nil, command)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.command(command), nil)
                }
            case let .hashtag(hashtag):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openHashtag(nil, hashtag)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.hashtag(hashtag), nil)
                }
            }
        })
        
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
        
        self.present(tooltipScreen, in: .current)
    }
    
    private func displayPsa(type: String, sourceNode: ASDisplayNode, isAutomatic: Bool) {
        var maybeFoundItemNode: ChatMessageItemView?
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if sourceNode.view.isDescendant(of: itemNode.view) {
                    maybeFoundItemNode = itemNode
                }
            }
        }
        guard let foundItemNode = maybeFoundItemNode, let item = foundItemNode.item else {
            return
        }
        
        var psaText = self.presentationData.strings.Chat_GenericPsaTooltip
        let key = "Chat.PsaTooltip.\(type)"
        if let string = self.presentationData.strings.primaryComponent.dict[key] {
            psaText = string
        } else if let string = self.presentationData.strings.secondaryComponent?.dict[key] {
            psaText = string
        }
        
        let psaEntities: [MessageTextEntity] = generateTextEntities(psaText, enabledTypes: .allUrl)
        
        let messageId = item.message.id
        
        var found = false
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                if controller.text == psaText {
                    found = true
                    controller.resetDismissTimeout()
                    
                    controller.willBecomeDismissed = { [weak self] tooltipScreen in
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.controllerInteraction?.currentPsaMessageWithTooltip == messageId {
                            strongSelf.controllerInteraction?.currentPsaMessageWithTooltip = nil
                            strongSelf.updatePollTooltipMessageState(animated: true)
                        }
                    }
                    
                    return false
                }
            }
            return true
        })
        if found {
            self.controllerInteraction?.currentPsaMessageWithTooltip = messageId
            self.updatePollTooltipMessageState(animated: !isAutomatic)
            
            return
        }
        
        let tooltipScreen = TooltipScreen(account: self.context.account, text: psaText, textEntities: psaEntities, icon: .info, location: .top, displayDuration: .custom(10.0), shouldDismissOnTouch: { point in
            return .ignore
        }, openActiveTextItem: { [weak self] item, action in
            guard let strongSelf = self else {
                return
            }
            switch item {
            case let .url(url, concealed):
                switch action {
                case .tap:
                    strongSelf.openUrl(url, concealed: concealed)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.url(url), nil)
                }
            case let .mention(peerId, mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil, nil)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.peerMention(peerId, mention), nil)
                }
            case let .textMention(mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeerMention(mention)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.mention(mention), nil)
                }
            case let .botCommand(command):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.sendBotCommand(nil, command)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.command(command), nil)
                }
            case let .hashtag(hashtag):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openHashtag(nil, hashtag)
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.hashtag(hashtag), nil)
                }
            }
        })
        
        self.controllerInteraction?.currentPsaMessageWithTooltip = messageId
        self.updatePollTooltipMessageState(animated: !isAutomatic)
        
        tooltipScreen.willBecomeDismissed = { [weak self] tooltipScreen in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.controllerInteraction?.currentPsaMessageWithTooltip == messageId {
                strongSelf.controllerInteraction?.currentPsaMessageWithTooltip = nil
                strongSelf.updatePollTooltipMessageState(animated: true)
            }
        }
        
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
        
        self.present(tooltipScreen, in: .current)
    }
        
    private func configurePollCreation(isQuiz: Bool? = nil) -> AttachmentContainable? {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return nil
        }
        return createPollController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: EnginePeer(peer), isQuiz: isQuiz, completion: { [weak self] poll in
            guard let strongSelf = self else {
                return
            }
            let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            }, nil)
            let message: EnqueueMessage = .message(
                text: "",
                attributes: [],
                mediaReference: .standalone(media: TelegramMediaPoll(
                    pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: Int64.random(in: Int64.min ... Int64.max)),
                    publicity: poll.publicity,
                    kind: poll.kind,
                    text: poll.text,
                    options: poll.options,
                    correctAnswers: poll.correctAnswers,
                    results: poll.results,
                    isClosed: false,
                    deadlineTimeout: poll.deadlineTimeout
                )),
                replyToMessageId: nil,
                localGroupingKey: nil,
                correlationId: nil
            )
            strongSelf.sendMessages([message.withUpdatedReplyToMessageId(replyMessageId)])
        })
    }
    
    func transformEnqueueMessages(_ messages: [EnqueueMessage]) -> [EnqueueMessage] {
        let silentPosting = self.presentationInterfaceState.interfaceState.silentPosting
        return transformEnqueueMessages(messages, silentPosting: silentPosting)
    }
    
    private func displayPremiumStickerTooltip(file: TelegramMediaFile, message: Message) {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
        guard !premiumConfiguration.isPremiumDisabled else {
            return
        }
        
        var currentOverlayController: UndoOverlayController?
        
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                currentOverlayController = controller
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                currentOverlayController = controller
            }
            return true
        })
        
        if let currentOverlayController = currentOverlayController {
            if case .sticker = currentOverlayController.content {
                return
            }
            currentOverlayController.dismissWithCommitAction()
        }
        
        var stickerPackReference: StickerPackReference?
        for attribute in file.attributes {
            if case let .Sticker(_, packReference, _) = attribute, let packReference = packReference {
                stickerPackReference = packReference
                break
            }
        }
        
        if let stickerPackReference = stickerPackReference {
            let _ = (self.context.engine.stickers.loadedStickerPack(reference: stickerPackReference, forceActualized: false)
            |> deliverOnMainQueue).start(next: { [weak self] stickerPack in
                if let strongSelf = self, case let .result(info, _, _) = stickerPack {
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: file, title: info.title, text: strongSelf.presentationData.strings.Stickers_PremiumPackInfoText, undoText: strongSelf.presentationData.strings.Stickers_PremiumPackView), elevatedLayout: false, action: { [weak self] action in
                        if let strongSelf = self, action == .undo {
                            let _ = strongSelf.controllerInteraction?.openMessage(message, .default)
                        }
                        return false
                    }), in: .current)
                }
            })
        }
    }
    
    private func displayDiceTooltip(dice: TelegramMediaDice) {
        guard let _ = dice.value else {
            return
        }
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
        
        let value: String?
        let emoji = dice.emoji.strippedEmoji
        switch emoji {
            case "🎲":
                value = self.presentationData.strings.Conversation_Dice_u1F3B2
            case "🎯":
                value = self.presentationData.strings.Conversation_Dice_u1F3AF
            case "🏀":
                value = self.presentationData.strings.Conversation_Dice_u1F3C0
            case "⚽":
                value = self.presentationData.strings.Conversation_Dice_u26BD
            case "🎰":
                value = self.presentationData.strings.Conversation_Dice_u1F3B0
            case "🎳":
                value = self.presentationData.strings.Conversation_Dice_u1F3B3
            default:
                let emojiHex = emoji.unicodeScalars.map({ String(format:"%02x", $0.value) }).joined().uppercased()
                let key = "Conversation.Dice.u\(emojiHex)"
                if let string = self.presentationData.strings.primaryComponent.dict[key] {
                    value = string
                } else if let string = self.presentationData.strings.secondaryComponent?.dict[key] {
                    value = string
                } else {
                    value = nil
                }
        }
        if let value = value {
            self.present(UndoOverlayController(presentationData: self.presentationData, content: .dice(dice: dice, context: self.context, text: value, action: canSendMessagesToChat(self.presentationInterfaceState) ? self.presentationData.strings.Conversation_SendDice : nil), elevatedLayout: false, action: { [weak self] action in
                if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState), action == .undo {
                    strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: AnyMediaReference.standalone(media: TelegramMediaDice(emoji: dice.emoji)), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)])
                }
                return false
            }), in: .current)
        }
    }
    
    private func transformEnqueueMessages(_ messages: [EnqueueMessage], silentPosting: Bool, scheduleTime: Int32? = nil) -> [EnqueueMessage] {
        var defaultReplyMessageId: MessageId?
        switch self.chatLocation {
        case .peer:
            break
        case let .replyThread(replyThreadMessage):
            defaultReplyMessageId = replyThreadMessage.messageId
        case .feed:
            break
        }
        
        return messages.map { message in
            var message = message
            
            if let defaultReplyMessageId = defaultReplyMessageId {
                switch message {
                case let .message(text, attributes, mediaReference, replyToMessageId, localGroupingKey, correlationId):
                    if replyToMessageId == nil {
                        message = .message(text: text, attributes: attributes, mediaReference: mediaReference, replyToMessageId: defaultReplyMessageId, localGroupingKey: localGroupingKey, correlationId: correlationId)
                    }
                case .forward:
                    break
                }
            }
            
            return message.withUpdatedAttributes { attributes in
                var attributes = attributes
                if silentPosting || scheduleTime != nil {
                    for i in (0 ..< attributes.count).reversed() {
                        if attributes[i] is NotificationInfoMessageAttribute {
                            attributes.remove(at: i)
                        } else if let _ = scheduleTime, attributes[i] is OutgoingScheduleInfoMessageAttribute {
                            attributes.remove(at: i)
                        }
                    }
                    if silentPosting {
                        attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                    }
                    if let scheduleTime = scheduleTime {
                         attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime))
                    }
                }
                if let sendAsPeerId = self.presentationInterfaceState.currentSendAsPeerId {
                    if attributes.first(where: { $0 is SendAsMessageAttribute }) == nil {
                        attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
                    }
                }
                return attributes
            }
        }
    }
    
    private func sendMessages(_ messages: [EnqueueMessage], media: Bool = false, commit: Bool = false) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }
        
        if commit || !isScheduledMessages {
            self.commitPurposefulAction()
            
            let _ = (enqueueMessages(account: self.context.account, peerId: peerId, messages: self.transformEnqueueMessages(messages))
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                if let strongSelf = self, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }
            })
            
            donateSendMessageIntent(account: self.context.account, sharedContext: self.context.sharedContext, intentContext: .chat, peerIds: [peerId])
            
            self.updateChatPresentationInterfaceState(interactive: true, { $0.updatedShowCommands(false) })
        } else {
            self.presentScheduleTimePicker(style: media ? .media : .default, dismissByTapOutside: false, completion: { [weak self] time in
                if let strongSelf = self {
                    strongSelf.sendMessages(strongSelf.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: time), commit: true)
                }
            })
        }
    }
    
    private func enqueueMediaMessages(signals: [Any]?, silentPosting: Bool, scheduleTime: Int32? = nil, getAnimatedTransitionSource: ((String) -> UIView?)? = nil, completion: @escaping () -> Void = {}) {
        self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(account: self.context.account, signals: signals!)
        |> deliverOnMainQueue).start(next: { [weak self] items in
            if let strongSelf = self {
                var completionImpl: (() -> Void)? = completion

                var usedCorrelationId: Int64?

                var mappedMessages: [EnqueueMessage] = []
                var addedTransitions: [(Int64, [String], () -> Void)] = []
                
                var groupedCorrelationIds: [Int64: Int64] = [:]
                
                var skipAddingTransitions = false
                
                for item in items {
                    var message = item.message
                    if message.groupingKey != nil {
                        if items.count > 10 {
                            skipAddingTransitions = true
                        }
                    } else if items.count > 3 {
                        skipAddingTransitions = true
                    }
                    
                    if let uniqueId = item.uniqueId, !item.isFile && !skipAddingTransitions {
                        let correlationId: Int64
                        var addTransition = scheduleTime == nil
                        if let groupingKey = message.groupingKey {
                            if let existing = groupedCorrelationIds[groupingKey] {
                                correlationId = existing
                                addTransition = false
                            } else {
                                correlationId = Int64.random(in: 0 ..< Int64.max)
                                groupedCorrelationIds[groupingKey] = correlationId
                            }
                        } else {
                            correlationId = Int64.random(in: 0 ..< Int64.max)
                        }
                        message = message.withUpdatedCorrelationId(correlationId)

                        if addTransition {
                            addedTransitions.append((correlationId, [uniqueId], addedTransitions.isEmpty ? completion : {}))
                        } else {
                            if let index = addedTransitions.firstIndex(where: { $0.0 == correlationId }) {
                                var (correlationId, uniqueIds, completion) = addedTransitions[index]
                                uniqueIds.append(uniqueId)
                                addedTransitions[index] = (correlationId, uniqueIds, completion)
                            }
                        }
                        
                        usedCorrelationId = correlationId
                        completionImpl = nil
                    }
                    mappedMessages.append(message)
                }
                        
                if addedTransitions.count > 1 {
                    var transitions: [(Int64, ChatMessageTransitionNode.Source, () -> Void)] = []
                    for (correlationId, uniqueIds, initiated) in addedTransitions {
                        var source: ChatMessageTransitionNode.Source?
                        if uniqueIds.count > 1 {
                            source = .groupedMediaInput(ChatMessageTransitionNode.Source.GroupedMediaInput(extractSnapshots: {
                                return uniqueIds.compactMap({ getAnimatedTransitionSource?($0) })
                            }))
                        } else if let uniqueId = uniqueIds.first {
                            source = .mediaInput(ChatMessageTransitionNode.Source.MediaInput(extractSnapshot: {
                                return getAnimatedTransitionSource?(uniqueId)
                            }))
                        }
                        if let source = source {
                            transitions.append((correlationId, source, initiated))
                        }
                    }
                    strongSelf.chatDisplayNode.messageTransitionNode.add(grouped: transitions)
                } else if let (correlationId, uniqueIds, initiated) = addedTransitions.first {
                    var source: ChatMessageTransitionNode.Source?
                    if uniqueIds.count > 1 {
                        source = .groupedMediaInput(ChatMessageTransitionNode.Source.GroupedMediaInput(extractSnapshots: {
                            return uniqueIds.compactMap({ getAnimatedTransitionSource?($0) })
                        }))
                    } else if let uniqueId = uniqueIds.first {
                        source = .mediaInput(ChatMessageTransitionNode.Source.MediaInput(extractSnapshot: {
                            return getAnimatedTransitionSource?(uniqueId)
                        }))
                    }
                    if let source = source {
                        strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: source, initiated: {
                            initiated()
                        })
                    }
                }
                                                    
                let messages = strongSelf.transformEnqueueMessages(mappedMessages, silentPosting: silentPosting, scheduleTime: scheduleTime)
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                    completionImpl?()
                }, usedCorrelationId)

                strongSelf.sendMessages(messages.map { $0.withUpdatedReplyToMessageId(replyMessageId) }, media: true)
                
                if let _ = scheduleTime {
                    completion()
                }
            }
        }))
    }
    
    private func displayPasteMenu(_ images: [UIImage]) {
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).start(next: { [weak self] settings in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                strongSelf.chatDisplayNode.dismissInput()
                let _ = presentLegacyPasteMenu(context: strongSelf.context, peer: peer, chatLocation: strongSelf.chatLocation, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, hasSchedule: strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, updatedPresentationData: strongSelf.updatedPresentationData, images: images, presentSchedulePicker: { [weak self] done in
                    if let strongSelf = self {
                        strongSelf.presentScheduleTimePicker(style: .media, completion: { [weak self] time in
                            if let strongSelf = self {
                                done(time)
                                if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                    strongSelf.openScheduledMessages()
                                }
                            }
                        })
                    }
                }, presentTimerPicker: { [weak self] done in
                    if let strongSelf = self {
                        strongSelf.presentTimerPicker(style: .media, completion: { time in
                            done(time)
                        })
                    }
                }, sendMessagesWithSignals: { signals, silentPosting, scheduleTime in
                    self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                }, presentStickers: { [weak self] completion in
                    if let strongSelf = self {
                        let controller = DrawingStickersScreen(context: strongSelf.context, selectSticker: { fileReference, node, rect in
                            completion(fileReference.media, fileReference.media.isAnimatedSticker || fileReference.media.isVideoSticker, node.view, rect)
                            return true
                        })
                        strongSelf.present(controller, in: .window(.root))
                        return controller
                    } else {
                        return nil
                    }
                }, getCaptionPanelView: { [weak self] in
                    return self?.getCaptionPanelView()
                }, present: { [weak self] controller, arguments in
                    if let strongSelf = self {
                        strongSelf.present(controller, in: .window(.root), with: arguments)
                    }
                }, initialLayout: strongSelf.validLayout)
            }
        })
    }
    
    private func enqueueGifData(_ data: Data) {
        self.enqueueMediaMessageDisposable.set((legacyEnqueueGifMessage(account: self.context.account, data: data) |> deliverOnMainQueue).start(next: { [weak self] message in
            if let strongSelf = self {
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                }, nil)
                strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageId) })
            }
        }))
    }
    
    private func enqueueVideoData(_ data: Data) {
        self.enqueueMediaMessageDisposable.set((legacyEnqueueGifMessage(account: self.context.account, data: data) |> deliverOnMainQueue).start(next: { [weak self] message in
            if let strongSelf = self {
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                }, nil)
                strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageId) })
            }
        }))
    }
    
    private func enqueueStickerImage(_ image: UIImage, isMemoji: Bool) {
        let size = image.size.aspectFitted(CGSize(width: 512.0, height: 512.0))
        self.enqueueMediaMessageDisposable.set((convertToWebP(image: image, targetSize: size, targetBoundingSize: size, quality: 0.9) |> deliverOnMainQueue).start(next: { [weak self] data in
            if let strongSelf = self, !data.isEmpty {
                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                
                var fileAttributes: [TelegramMediaFileAttribute] = []
                fileAttributes.append(.FileName(fileName: "sticker.webp"))
                fileAttributes.append(.Sticker(displayText: "", packReference: nil, maskData: nil))
                fileAttributes.append(.ImageSize(size: PixelDimensions(size)))
                
                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: Int64(data.count), attributes: fileAttributes)
                let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)
                
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                }, nil)
                strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageId) })
            }
        }))
    }
    
    private func enqueueChatContextResult(_ results: ChatContextResultCollection, _ result: ChatContextResult, hideVia: Bool = false, closeMediaInput: Bool = false, silentPosting: Bool = false) {
        if !canSendMessagesToChat(self.presentationInterfaceState) {
            return
        }
        
        guard let peerId = self.chatLocation.peerId else {
            return
        }

        let replyMessageId = self.presentationInterfaceState.interfaceState.replyMessageId

        if self.context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: peerId, botId: results.botId, result: result, replyToMessageId: replyMessageId, hideVia: hideVia, silentPosting: silentPosting) {
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        var state = state
                        state = state.updatedInterfaceState { interfaceState in
                            var interfaceState = interfaceState
                            interfaceState = interfaceState.withUpdatedReplyMessageId(nil)
                            interfaceState = interfaceState.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: "")))
                            interfaceState = interfaceState.withUpdatedComposeDisableUrlPreview(nil)
                            return interfaceState
                        }
                        state = state.updatedInputMode { current in
                            if case let .media(mode, maybeExpanded, focused) = current, maybeExpanded != nil  {
                                return .media(mode: mode, expanded: nil, focused: focused)
                            }
                            return current
                        }
                        return state
                    })
                }
            }, nil)
        }
    }
    
    private func firstLoadedMessageToListen() -> Message? {
        var messageToListen: Message?
        self.chatDisplayNode.historyNode.forEachMessageInCurrentHistoryView { message in
            if message.flags.contains(.Incoming) && message.tags.contains(.voiceOrInstantVideo) {
                for attribute in message.attributes {
                    if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                        messageToListen = message
                        return false
                    }
                }
            }
            return true
        }
        return messageToListen
    }
    
    private var raiseToListenActivateRecordingTimer: SwiftSignalKit.Timer?
    
    private func activateRaiseGesture() {
        self.raiseToListenActivateRecordingTimer?.invalidate()
        self.raiseToListenActivateRecordingTimer = nil
        if let messageToListen = self.firstLoadedMessageToListen() {
            let _ = self.controllerInteraction?.openMessage(messageToListen, .default)
        } else {
            let timeout = (self.voicePlaylistDidEndTimestamp + 1.0) - CACurrentMediaTime()
            self.raiseToListenActivateRecordingTimer = SwiftSignalKit.Timer(timeout: max(0.0, timeout), repeat: false, completion: { [weak self] in
                self?.requestAudioRecorder(beginWithTone: true)
            }, queue: .mainQueue())
            self.raiseToListenActivateRecordingTimer?.start()
        }
    }
    
    private func deactivateRaiseGesture() {
        self.raiseToListenActivateRecordingTimer?.invalidate()
        self.raiseToListenActivateRecordingTimer = nil
        self.dismissMediaRecorder(.preview)
    }
    
    private func requestAudioRecorder(beginWithTone: Bool) {
        if self.audioRecorderValue == nil {
            if self.recorderFeedback == nil {
                self.recorderFeedback = HapticFeedback()
                self.recorderFeedback?.prepareImpact(.light)
            }
            
            self.audioRecorder.set(self.context.sharedContext.mediaManager.audioRecorder(beginWithTone: beginWithTone, applicationBindings: self.context.sharedContext.applicationBindings, beganWithTone: { _ in
            }))
        }
    }
    
    private func requestVideoRecorder() {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        
        if self.videoRecorderValue == nil {
            if let currentInputPanelFrame = self.chatDisplayNode.currentInputPanelFrame() {
                if self.recorderFeedback == nil {
                    self.recorderFeedback = HapticFeedback()
                    self.recorderFeedback?.prepareImpact(.light)
                }
                
                var isScheduledMessages = false
                if case .scheduledMessages = self.presentationInterfaceState.subject {
                    isScheduledMessages = true
                }
                
                self.videoRecorder.set(.single(legacyInstantVideoController(theme: self.presentationData.theme, panelFrame: self.view.convert(currentInputPanelFrame, to: nil), context: self.context, peerId: peerId, slowmodeState: !isScheduledMessages ? self.presentationInterfaceState.slowmodeState : nil, hasSchedule: !isScheduledMessages && peerId.namespace != Namespaces.Peer.SecretChat, send: { [weak self] videoController, message in
                    if let strongSelf = self {
                        guard let message = message else {
                            strongSelf.videoRecorder.set(.single(nil))
                            return
                        }

                        let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                        let correlationId = Int64.random(in: 0 ..< Int64.max)
                        let updatedMessage = message
                            .withUpdatedReplyToMessageId(replyMessageId)
                            .withUpdatedCorrelationId(correlationId)

                        var usedCorrelationId = false

                        if strongSelf.chatDisplayNode.shouldAnimateMessageTransition, let extractedView = videoController.extractVideoSnapshot() {
                            usedCorrelationId = true
                            strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source:  .videoMessage(ChatMessageTransitionNode.Source.VideoMessage(view: extractedView)), initiated: { [weak videoController] in
                                videoController?.hideVideoSnapshot()
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.videoRecorder.set(.single(nil))
                            })
                        } else {
                            strongSelf.videoRecorder.set(.single(nil))
                        }

                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                })
                            }
                        }, usedCorrelationId ? correlationId : nil)

                        strongSelf.sendMessages([updatedMessage])
                    }
                }, displaySlowmodeTooltip: { [weak self] node, rect in
                    self?.interfaceInteraction?.displaySlowmodeTooltip(node, rect)
                }, presentSchedulePicker: { [weak self] done in
                    if let strongSelf = self {
                        strongSelf.presentScheduleTimePicker(completion: { [weak self] time in
                            if let strongSelf = self {
                                done(time)
                                if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                    strongSelf.openScheduledMessages()
                                }
                            }
                        })
                    }
                })))
            }
        }
    }
    
    private func dismissMediaRecorder(_ action: ChatFinishMediaRecordingAction) {
        var updatedAction = action
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }
        
        if let _ = self.presentationInterfaceState.slowmodeState, !isScheduledMessages {
            updatedAction = .preview
        }
        
        if let audioRecorderValue = self.audioRecorderValue {
            audioRecorderValue.stop()
            
            switch updatedAction {
                case .dismiss:
                    self.chatDisplayNode.updateRecordedMediaDeleted(true)
                    self.audioRecorder.set(.single(nil))
                case .preview:
                    self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            return panelState.withUpdatedMediaRecordingState(.waitingForPreview)
                        }
                    })
                    let _ = (audioRecorderValue.takenRecordedData() |> deliverOnMainQueue).start(next: { [weak self] data in
                        if let strongSelf = self, let data = data {
                            if data.duration < 0.5 {
                                strongSelf.recorderFeedback?.error()
                                strongSelf.recorderFeedback = nil
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedInputTextPanelState { panelState in
                                        return panelState.withUpdatedMediaRecordingState(nil)
                                    }
                                })
                            } else if let waveform = data.waveform {
                                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(data.compressedData.count))
                                
                                strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                                
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedRecordedMediaPreview(ChatRecordedMediaPreview(resource: resource, duration: Int32(data.duration), fileSize: Int32(data.compressedData.count), waveform: AudioWaveform(bitstream: waveform, bitsPerSample: 5))).updatedInputTextPanelState { panelState in
                                        return panelState.withUpdatedMediaRecordingState(nil)
                                    }
                                })
                                strongSelf.recorderFeedback = nil
                            }
                        }
                    })
                    self.audioRecorder.set(.single(nil))
                case .send:
                    self.chatDisplayNode.updateRecordedMediaDeleted(false)
                    let _ = (audioRecorderValue.takenRecordedData()
                    |> deliverOnMainQueue).start(next: { [weak self] data in
                        if let strongSelf = self, let data = data {
                            if data.duration < 0.5 {
                                strongSelf.recorderFeedback?.error()
                                strongSelf.recorderFeedback = nil
                                strongSelf.audioRecorder.set(.single(nil))
                            } else {
                                let randomId = Int64.random(in: Int64.min ... Int64.max)
                                
                                let resource = LocalFileMediaResource(fileId: randomId)
                                strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                                
                                let waveformBuffer: Data? = data.waveform

                                let correlationId = Int64.random(in: 0 ..< Int64.max)
                                var usedCorrelationId = false

                                if strongSelf.chatDisplayNode.shouldAnimateMessageTransition, let textInputPanelNode = strongSelf.chatDisplayNode.textInputPanelNode, let micButton = textInputPanelNode.micButton {
                                    usedCorrelationId = true
                                    strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .audioMicInput(ChatMessageTransitionNode.Source.AudioMicInput(micButton: micButton)), initiated: {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.audioRecorder.set(.single(nil))
                                    })
                                } else {
                                    strongSelf.audioRecorder.set(.single(nil))
                                }

                                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                    if let strongSelf = self {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                        })
                                    }
                                }, usedCorrelationId ? correlationId : nil)
                                
                                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(data.compressedData.count), attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil, correlationId: correlationId)])
                                
                                strongSelf.recorderFeedback?.tap()
                                strongSelf.recorderFeedback = nil
                            }
                        }
                    })
            }
        } else if let videoRecorderValue = self.videoRecorderValue {
            if case .send = updatedAction {
                self.chatDisplayNode.updateRecordedMediaDeleted(false)
                videoRecorderValue.completeVideo()
            } else {
                if case .dismiss = updatedAction {
                    self.chatDisplayNode.updateRecordedMediaDeleted(true)
                }
                if case .preview = updatedAction, videoRecorderValue.stopVideo() {
                    self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                        }
                    })
                } else {
                    self.videoRecorder.set(.single(nil))
                }
            }
        }
    }
    
    private func stopMediaRecorder() {
        if let audioRecorderValue = self.audioRecorderValue {
            if let _ = self.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
                self.dismissMediaRecorder(.preview)
            } else {
                audioRecorderValue.stop()
                self.audioRecorder.set(.single(nil))
            }
        } else if let videoRecorderValue = self.videoRecorderValue {
            if videoRecorderValue.stopVideo() {
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    $0.updatedInputTextPanelState { panelState in
                        return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                    }
                })
            } else {
                self.videoRecorder.set(.single(nil))
            }
        }
    }
    
    private func lockMediaRecorder() {
        if self.presentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedInputTextPanelState { panelState in
                    return panelState.withUpdatedMediaRecordingState(panelState.mediaRecordingState?.withLocked(true))
                }
            })
        }
        
        self.videoRecorderValue?.lockVideo()
    }
    
    private func deleteMediaRecording() {
        self.chatDisplayNode.updateRecordedMediaDeleted(true)
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
            $0.updatedRecordedMediaPreview(nil)
        })
    }
    
    private func sendMediaRecording(silentPosting: Bool? = nil, scheduleTime: Int32? = nil) {
        self.chatDisplayNode.updateRecordedMediaDeleted(false)
        
        if let recordedMediaPreview = self.presentationInterfaceState.recordedMediaPreview {
            var isScheduledMessages = false
            if case .scheduledMessages = self.presentationInterfaceState.subject {
                isScheduledMessages = true
            }
            
            if let _ = self.presentationInterfaceState.slowmodeState, !isScheduledMessages {
                if let rect = self.chatDisplayNode.frameForInputActionButton() {
                    self.interfaceInteraction?.displaySlowmodeTooltip(self.chatDisplayNode, rect)
                }
                return
            }
            
            let waveformBuffer = recordedMediaPreview.waveform.makeBitstream()
            
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedRecordedMediaPreview(nil).updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            }, nil)
            
            let messages: [EnqueueMessage] = [.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: recordedMediaPreview.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(recordedMediaPreview.fileSize), attributes: [.Audio(isVoice: true, duration: Int(recordedMediaPreview.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: self.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil, correlationId: nil)]
            
            let transformedMessages: [EnqueueMessage]
            if let silentPosting = silentPosting {
                transformedMessages = self.transformEnqueueMessages(messages, silentPosting: silentPosting)
            } else if let scheduleTime = scheduleTime {
                transformedMessages = self.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: scheduleTime)
            } else {
                transformedMessages = self.transformEnqueueMessages(messages)
            }
            
            guard let peerId = self.chatLocation.peerId else {
                return
            }
            
            let _ = (enqueueMessages(account: self.context.account, peerId: peerId, messages: transformedMessages)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                if let strongSelf = self, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }
            })
            
            donateSendMessageIntent(account: self.context.account, sharedContext: self.context.sharedContext, intentContext: .chat, peerIds: [peerId])
        }
    }
    
    private func updateSearch(_ interfaceState: ChatPresentationInterfaceState) -> ChatPresentationInterfaceState? {
        guard let peerId = self.chatLocation.peerId else {
            return nil
        }
        
        let limit: Int32 = 100
        
        var derivedSearchState: ChatSearchState?
        if let search = interfaceState.search {
            func loadMoreStateFromResultsState(_ resultsState: ChatSearchResultsState?) -> SearchMessagesState? {
                guard let resultsState = resultsState, let currentId = resultsState.currentId else {
                    return nil
                }
                if let index = resultsState.messageIndices.firstIndex(where: { $0.id == currentId }) {
                    if index <= limit / 2 {
                        return resultsState.state
                    }
                }
                return nil
            }
            var searchTopMsgId: MessageId?
            switch self.chatLocation {
            case .peer:
                break
            case let .replyThread(replyThreadMessage):
                searchTopMsgId = replyThreadMessage.messageId
            case .feed:
                break
            }
            switch search.domain {
                case .everything:
                    derivedSearchState = ChatSearchState(query: search.query, location: .peer(peerId: peerId, fromId: nil, tags: nil, topMsgId: searchTopMsgId, minDate: nil, maxDate: nil), loadMoreState: loadMoreStateFromResultsState(search.resultsState))
                case .members:
                    derivedSearchState = nil
                case let .member(peer):
                    derivedSearchState = ChatSearchState(query: search.query, location: .peer(peerId: peerId, fromId: peer.id, tags: nil, topMsgId: searchTopMsgId, minDate: nil, maxDate: nil), loadMoreState: loadMoreStateFromResultsState(search.resultsState))
            }
        }
        
        if derivedSearchState != self.searchState {
            let previousSearchState = self.searchState
            self.searchState = derivedSearchState
            if let searchState = derivedSearchState {
                if previousSearchState?.query != searchState.query || previousSearchState?.location != searchState.location {
                    var queryIsEmpty = false
                    if searchState.query.isEmpty {
                        if case let .peer(_, fromId, _, _, _, _) = searchState.location {
                            if fromId == nil {
                                queryIsEmpty = true
                            }
                        } else {
                            queryIsEmpty = true
                        }
                    }
                    
                    if queryIsEmpty {
                        self.searching.set(false)
                        self.searchDisposable?.set(nil)
                        self.searchResult.set(.single(nil))
                        if let data = interfaceState.search {
                            return interfaceState.updatedSearch(data.withUpdatedResultsState(nil))
                        }
                    } else {
                        self.searching.set(true)
                        let searchDisposable: MetaDisposable
                        if let current = self.searchDisposable {
                            searchDisposable = current
                        } else {
                            searchDisposable = MetaDisposable()
                            self.searchDisposable = searchDisposable
                        }

                        let search = self.context.engine.messages.searchMessages(location: searchState.location, query: searchState.query, state: nil, limit: limit)
                        |> delay(0.2, queue: Queue.mainQueue())
                        self.searchResult.set(search
                        |> map { (result, state) -> (SearchMessagesResult, SearchMessagesState, SearchMessagesLocation)? in
                            return (result, state, searchState.location)
                        })
                        
                        searchDisposable.set((search
                        |> deliverOnMainQueue).start(next: { [weak self] results, updatedState in
                            guard let strongSelf = self else {
                                return
                            }
                            var navigateIndex: MessageIndex?
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                if let data = current.search {
                                    let messageIndices = results.messages.map({ $0.index }).sorted()
                                    var currentIndex = messageIndices.last
                                    if let previousResultId = data.resultsState?.currentId {
                                        for index in messageIndices {
                                            if index.id >= previousResultId {
                                                currentIndex = index
                                                break
                                            }
                                        }
                                    }
                                    navigateIndex = currentIndex
                                    return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: currentIndex?.id, state: updatedState, totalCount: results.totalCount, completed: results.completed)))
                                } else {
                                    return current
                                }
                            })
                            if let navigateIndex = navigateIndex {
                                switch strongSelf.chatLocation {
                                case .peer, .replyThread, .feed:
                                    strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex), forceInCurrentChat: true)
                                }
                            }
                            strongSelf.updateItemNodesSearchTextHighlightStates()
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.searching.set(false)
                            }
                        }))
                    }
                } else if previousSearchState?.loadMoreState != searchState.loadMoreState {
                    if let loadMoreState = searchState.loadMoreState {
                        self.searching.set(true)
                        let searchDisposable: MetaDisposable
                        if let current = self.searchDisposable {
                            searchDisposable = current
                        } else {
                            searchDisposable = MetaDisposable()
                            self.searchDisposable = searchDisposable
                        }
                        searchDisposable.set((self.context.engine.messages.searchMessages(location: searchState.location, query: searchState.query, state: loadMoreState, limit: limit)
                        |> delay(0.2, queue: Queue.mainQueue())
                        |> deliverOnMainQueue).start(next: { [weak self] results, updatedState in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { current in
                                if let data = current.search, let previousResultsState = data.resultsState {
                                    let messageIndices = results.messages.map({ $0.index }).sorted()
                                    return current.updatedSearch(data.withUpdatedResultsState(ChatSearchResultsState(messageIndices: messageIndices, currentId: previousResultsState.currentId, state: updatedState, totalCount: results.totalCount, completed: results.completed)))
                                } else {
                                    return current
                                }
                            })
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.searching.set(false)
                            }
                        }))
                    } else {
                        self.searching.set(false)
                        self.searchDisposable?.set(nil)
                    }
                }
            } else {
                self.searching.set(false)
                self.searchDisposable?.set(nil)
                
                if let data = interfaceState.search {
                    return interfaceState.updatedSearch(data.withUpdatedResultsState(nil))
                }
            }
        }
        self.updateItemNodesSearchTextHighlightStates()
        return nil
    }
    
    func scrollToEndOfHistory() {
        let locationInput = ChatHistoryLocationInput(content: .Scroll(index: .upperBound, anchorIndex: .upperBound, sourceIndex: .lowerBound, scrollPosition: .top(0.0), animated: true, highlight: false), id: 0)
        
        let historyView = preloadedChatHistoryViewForLocation(locationInput, context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
        let signal = historyView
        |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
            switch historyView {
            case .Loading:
                return .single((nil, true))
            case .HistoryView:
                return .single((nil, false))
            }
        }
        |> take(until: { index in
            return SignalTakeAction(passthrough: true, complete: !index.1)
        })
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
        let displayTime = CACurrentMediaTime()
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                if CACurrentMediaTime() - displayTime > 1.5 {
                    cancelImpl?()
                }
            }))
            self?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.05, queue: Queue.mainQueue())
        let progressDisposable = MetaDisposable()
        var progressStarted = false
        self.messageIndexDisposable.set((signal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(next: { index in
            if index.1 {
                if !progressStarted {
                    progressStarted = true
                    progressDisposable.set(progressSignal.start())
                }
            }
        }, completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
            }
        }))
        cancelImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.messageIndexDisposable.set(nil)
            }
        }
    }
    
    func scrollToStartOfHistory() {
        let locationInput = ChatHistoryLocationInput(content: .Scroll(index: .lowerBound, anchorIndex: .lowerBound, sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false), id: 0)
        
        let historyView = preloadedChatHistoryViewForLocation(locationInput, context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
        let signal = historyView
        |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
            switch historyView {
            case .Loading:
                return .single((nil, true))
            case .HistoryView:
                return .single((nil, false))
            }
        }
        |> take(until: { index in
            return SignalTakeAction(passthrough: true, complete: !index.1)
        })
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
        let displayTime = CACurrentMediaTime()
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                if CACurrentMediaTime() - displayTime > 1.5 {
                    cancelImpl?()
                }
            }))
            self?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.05, queue: Queue.mainQueue())
        let progressDisposable = MetaDisposable()
        var progressStarted = false
        self.messageIndexDisposable.set((signal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).start(next: { index in
            if index.1 {
                if !progressStarted {
                    progressStarted = true
                    progressDisposable.set(progressSignal.start())
                }
            }
        }, completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.chatDisplayNode.historyNode.scrollToStartOfHistory()
            }
        }))
        cancelImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.messageIndexDisposable.set(nil)
            }
        }
    }
    
    func updateDownButtonVisibility() {
        let recordingMediaMessage = self.audioRecorderValue != nil || self.videoRecorderValue != nil
        self.chatDisplayNode.navigateButtons.displayDownButton = self.shouldDisplayDownButton && !recordingMediaMessage
    }
    
    func updateTextInputState(_ textInputState: ChatTextInputState) {
        self.updateChatPresentationInterfaceState(interactive: false, { state in
            state.updatedInterfaceState({ state in
                state.withUpdatedComposeInputState(textInputState)
            })
        })
    }

    private func openCalendarSearch(timestamp: Int32) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        self.chatDisplayNode.dismissInput()

        let initialTimestamp = timestamp
        var dismissCalendarScreen: (() -> Void)?
        var selectDay: ((Int32) -> Void)?
        var openClearHistory: ((Int32) -> Void)?

        let enableMessageRangeDeletion: Bool = peerId.namespace == Namespaces.Peer.CloudUser

        let calendarScreen = CalendarMessageScreen(
            context: self.context,
            peerId: peerId,
            calendarSource: self.context.engine.messages.sparseMessageCalendar(peerId: peerId, tag: .photoOrVideo),
            initialTimestamp: initialTimestamp,
            enableMessageRangeDeletion: enableMessageRangeDeletion,
            canNavigateToEmptyDays: true,
            navigateToDay: { [weak self] c, index, timestamp in
                guard let strongSelf = self else {
                    c.dismiss()
                    return
                }

                c.dismiss()

                strongSelf.loadingMessage.set(.single(.generic))

                let peerId: PeerId
                let threadId: Int64?
                switch strongSelf.chatLocation {
                case let .peer(peerIdValue):
                    peerId = peerIdValue
                    threadId = nil
                case let .replyThread(replyThreadMessage):
                    peerId = replyThreadMessage.messageId.peerId
                    threadId = makeMessageThreadId(replyThreadMessage.messageId)
                case .feed:
                    return
                }

                strongSelf.messageIndexDisposable.set((strongSelf.context.engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: threadId, timestamp: timestamp) |> deliverOnMainQueue).start(next: { messageId in
                    if let strongSelf = self {
                        strongSelf.loadingMessage.set(.single(nil))
                        if let messageId = messageId {
                            strongSelf.navigateToMessage(from: nil, to: .id(messageId, nil), forceInCurrentChat: true)
                        }
                    }
                }))
            },
            previewDay: { [weak self] timestamp, _, sourceNode, sourceRect, gesture in
                guard let strongSelf = self else {
                    return
                }

                var items: [ContextMenuItem] = []

                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_JumpToDate, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    dismissCalendarScreen?()

                    strongSelf.loadingMessage.set(.single(.generic))

                    let peerId: PeerId
                    let threadId: Int64?
                    switch strongSelf.chatLocation {
                    case let .peer(peerIdValue):
                        peerId = peerIdValue
                        threadId = nil
                    case let .replyThread(replyThreadMessage):
                        peerId = replyThreadMessage.messageId.peerId
                        threadId = makeMessageThreadId(replyThreadMessage.messageId)
                    case .feed:
                        return
                    }

                    strongSelf.messageIndexDisposable.set((strongSelf.context.engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: threadId, timestamp: timestamp) |> deliverOnMainQueue).start(next: { messageId in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(.single(nil))
                            if let messageId = messageId {
                                strongSelf.navigateToMessage(from: nil, to: .id(messageId, nil), forceInCurrentChat: true)
                            }
                        }
                    }))
                })))

                if enableMessageRangeDeletion && (peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat) {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.DialogList_ClearHistoryConfirmation, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        openClearHistory?(timestamp)
                    })))

                    items.append(.separator)

                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Select, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        selectDay?(timestamp)
                    })))
                }

                let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: .message(id: .timestamp(timestamp), highlight: false, timecode: nil), botStart: nil, mode: .standard(previewing: true))
                chatController.canReadHistory.set(false)
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, sourceRect: sourceRect, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                strongSelf.presentInGlobalOverlay(contextController)
            }
        )
        
        calendarScreen.completedWithRemoveMessagesInRange = { [weak self] range, type, dayCount, calendarSource in
            guard let strongSelf = self else {
                return
            }
            
            let statusText: String
            switch type {
            case .forEveryone:
                statusText = strongSelf.presentationData.strings.Chat_MessageRangeDeleted_ForBothSides(Int32(dayCount))
            default:
                statusText = strongSelf.presentationData.strings.Chat_MessageRangeDeleted_ForMe(Int32(dayCount))
            }
            
            strongSelf.chatDisplayNode.historyNode.ignoreMessagesInTimestampRange = range
            
            strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: statusText), elevatedLayout: false, action: { value in
                guard let strongSelf = self else {
                    return false
                }
                
                if value == .commit {
                    let _ = calendarSource.removeMessagesInRange(minTimestamp: range.lowerBound, maxTimestamp: range.upperBound, type: type, completion: {
                        Queue.mainQueue().after(1.0, {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.chatDisplayNode.historyNode.ignoreMessagesInTimestampRange = nil
                        })
                    })
                    return true
                } else if value == .undo {
                    strongSelf.chatDisplayNode.historyNode.ignoreMessagesInTimestampRange = nil
                    return true
                }
                return false
            }), in: .current)
        }

        self.push(calendarScreen)
        dismissCalendarScreen = { [weak calendarScreen] in
            calendarScreen?.dismiss(completion: nil)
        }
        selectDay = { [weak calendarScreen] timestamp in
            calendarScreen?.selectDay(timestamp: timestamp)
        }
        openClearHistory = { [weak calendarScreen] timestamp in
            calendarScreen?.openClearHistory(timestamp: timestamp)
        }
    }
    
    private func openMessageReplies(messageId: MessageId, displayProgressInMessage: MessageId?, isChannelPost: Bool, atMessage atMessageId: MessageId?, displayModalProgress: Bool) {
        guard let navigationController = self.effectiveNavigationController else {
            return
        }
        
        if let displayProgressInMessage = displayProgressInMessage, self.controllerInteraction?.currentMessageWithLoadingReplyThread == displayProgressInMessage {
            return
        }
        
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            let progressSignal: Signal<Never, NoError> = Signal { [weak self] _ in
                guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                    return EmptyDisposable
                }
                
                if let displayProgressInMessage = displayProgressInMessage, controllerInteraction.currentMessageWithLoadingReplyThread != displayProgressInMessage {
                    let previousId = controllerInteraction.currentMessageWithLoadingReplyThread
                    controllerInteraction.currentMessageWithLoadingReplyThread = displayProgressInMessage
                    strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(displayProgressInMessage)
                    if let previousId = previousId {
                        strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(previousId)
                    }
                }
                
                return ActionDisposable {
                    Queue.mainQueue().async {
                        guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                            return
                        }
                        if let displayProgressInMessage = displayProgressInMessage, controllerInteraction.currentMessageWithLoadingReplyThread == displayProgressInMessage {
                            controllerInteraction.currentMessageWithLoadingReplyThread = nil
                            strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(displayProgressInMessage)
                        }
                    }
                }
            }
            |> runOn(.mainQueue())
            
            let progress = (progressSignal
            |> delay(0.15, queue: .mainQueue())).start()
            
            self.navigationActionDisposable.set((ChatControllerImpl.openMessageReplies(context: self.context, updatedPresentationData: self.updatedPresentationData, navigationController: navigationController, present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            }, messageId: messageId, isChannelPost: isChannelPost, atMessage: atMessageId, displayModalProgress: displayModalProgress)
            |> afterDisposed {
                progress.dispose()
            }).start())
        })
    }
    
    static func openMessageReplies(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, navigationController: NavigationController, present: @escaping (ViewController, Any?) -> Void, messageId: MessageId, isChannelPost: Bool, atMessage atMessageId: MessageId?, displayModalProgress: Bool) -> Signal<Never, NoError> {
        return Signal { subscriber in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var cancelImpl: (() -> Void)?
            let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))
            
            if displayModalProgress {
                present(statusController, nil)
            }
            
            let disposable = (fetchAndPreloadReplyThreadInfo(context: context, subject: isChannelPost ? .channelPost(messageId) : .groupMessage(messageId), atMessageId: atMessageId)
            |> deliverOnMainQueue).start(next: { [weak statusController] result in
                if displayModalProgress {
                    statusController?.dismiss()
                }
                
                let chatLocation: ChatLocation = .replyThread(message: result.message)
                
                let subject: ChatControllerSubject?
                if let atMessageId = atMessageId {
                    subject = .message(id: .id(atMessageId), highlight: true, timecode: nil)
                } else if let index = result.scrollToLowerBoundMessage {
                    subject = .message(id: .id(index.id), highlight: false, timecode: nil)
                } else {
                    subject = nil
                }
                
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: chatLocation, chatLocationContextHolder: result.contextHolder, subject: subject, activateInput: result.isEmpty, keepStack: .always))
                subscriber.putCompletion()
            }, error: { _ in
                let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_DiscussionMessageUnavailable, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })
            
            cancelImpl = { [weak statusController] in
                disposable.dispose()
                statusController?.dismiss()
                subscriber.putCompletion()
            }
            
            return ActionDisposable {
                cancelImpl?()
            }
        }
        |> runOn(.mainQueue())
    }
    
    public func navigateToMessage(messageLocation: NavigateToMessageLocation, animated: Bool, forceInCurrentChat: Bool = false, dropStack: Bool = false, completion: (() -> Void)? = nil, customPresentProgress: ((ViewController, Any?) -> Void)? = nil) {
        let scrollPosition: ListViewScrollPosition
        if case .upperBound = messageLocation {
            scrollPosition = .top(0.0)
        } else {
            scrollPosition = .center(.bottom)
        }
        self.navigateToMessage(from: nil, to: messageLocation, scrollPosition: scrollPosition, rememberInStack: false, forceInCurrentChat: forceInCurrentChat, dropStack: dropStack, animated: animated, completion: completion, customPresentProgress: customPresentProgress)
    }
    
    private func navigateToMessage(from fromId: MessageId?, to messageLocation: NavigateToMessageLocation, scrollPosition: ListViewScrollPosition = .center(.bottom), rememberInStack: Bool = true, forceInCurrentChat: Bool = false, dropStack: Bool = false, animated: Bool = true, completion: (() -> Void)? = nil, customPresentProgress: ((ViewController, Any?) -> Void)? = nil, statusSubject: ChatLoadingMessageSubject = .generic) {
        if self.isNodeLoaded {
            var fromIndex: MessageIndex?
            
            if let fromId = fromId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
                fromIndex = message.index
            } else {
                if let message = self.chatDisplayNode.historyNode.anchorMessageInCurrentHistoryView() {
                    fromIndex = message.index
                }
            }
            
            var isScheduledMessages = false
            var isPinnedMessages = false
            if case .scheduledMessages = self.presentationInterfaceState.subject {
                isScheduledMessages = true
            } else if case .pinnedMessages = self.presentationInterfaceState.subject {
                isPinnedMessages = true
            }
            
            var forceInCurrentChat = forceInCurrentChat
            if case let .peer(peerId) = self.chatLocation, messageLocation.peerId == peerId, !isPinnedMessages, !isScheduledMessages {
                forceInCurrentChat = true
            }
            
            if isPinnedMessages, let messageId = messageLocation.messageId {
                if let navigationController = self.effectiveNavigationController {
                    self.dismiss()
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: messageId.peerId), subject: .message(id: .id(messageId), highlight: true, timecode: nil), keepStack: .always))
                }
            } else if case let .peer(peerId) = self.chatLocation, let messageId = messageLocation.messageId, (messageId.peerId != peerId && !forceInCurrentChat) || (isScheduledMessages && messageId.id != 0 && !Namespaces.Message.allScheduled.contains(messageId.namespace)) {
                if let navigationController = self.effectiveNavigationController {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: messageId.peerId), subject: .message(id: .id(messageId), highlight: true, timecode: nil), keepStack: .always))
                }
            } else if forceInCurrentChat {
                if let _ = fromId, let fromIndex = fromIndex, rememberInStack {
                    self.historyNavigationStack.add(fromIndex)
                }
                
                let scrollFromIndex: MessageIndex?
                if let fromIndex = fromIndex {
                    scrollFromIndex = fromIndex
                } else if let message = self.chatDisplayNode.historyNode.lastVisbleMesssage() {
                    scrollFromIndex = message.index
                } else {
                    scrollFromIndex = nil
                }
                
                if let scrollFromIndex = scrollFromIndex {
                    if let messageId = messageLocation.messageId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                        self.loadingMessage.set(.single(nil))
                        self.messageIndexDisposable.set(nil)
                        
                        var delayCompletion = true
                        if self.chatDisplayNode.historyNode.isMessageVisible(id: messageId) {
                            delayCompletion = false
                        }
                        
                        self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: message.index, animated: animated, scrollPosition: scrollPosition)
                        
                        if delayCompletion {
                            Queue.mainQueue().after(0.25, {
                                completion?()
                            })
                        } else {
                            Queue.mainQueue().justDispatch({
                                completion?()
                            })
                        }
                        
                        if case let .id(_, maybeTimecode) = messageLocation, let timecode = maybeTimecode {
                            let _ = self.controllerInteraction?.openMessage(message, .timecode(timecode))
                        }
                    } else if case let .index(index) = messageLocation, index.id.id == 0, index.timestamp > 0, case .scheduledMessages = self.presentationInterfaceState.subject {
                        self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                    } else {
                        if case let .id(messageId, maybeTimecode) = messageLocation, let timecode = maybeTimecode {
                            self.scheduledScrollToMessageId = (messageId, timecode)
                        }
                        self.loadingMessage.set(.single(statusSubject) |> delay(0.1, queue: .mainQueue()))
                        let searchLocation: ChatHistoryInitialSearchLocation
                        switch messageLocation {
                        case let .id(id, _):
                            searchLocation = .id(id)
                        case let .index(index):
                            searchLocation = .index(index)
                        case .upperBound:
                            if let peerId = self.chatLocation.peerId {
                                searchLocation = .index(MessageIndex.upperBound(peerId: peerId))
                            } else {
                                searchLocation = .index(.absoluteUpperBound())
                            }
                        }
                        let historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(location: searchLocation, count: 50, highlight: true), id: 0), context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                        
                        let signal = historyView
                        |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
                            switch historyView {
                                case .Loading:
                                    return .single((nil, true))
                                case let .HistoryView(view, _, _, _, _, _, _):
                                    for entry in view.entries {
                                        if entry.message.id == messageLocation.messageId {
                                            return .single((entry.message.index, false))
                                        }
                                    }
                                    if case let .index(index) = searchLocation {
                                        return .single((index, false))
                                    }
                                    return .single((nil, false))
                            }
                        }
                        |> take(until: { index in
                            return SignalTakeAction(passthrough: true, complete: !index.1)
                        })
                        
                        var cancelImpl: (() -> Void)?
                        let presentationData = self.presentationData
                        let displayTime = CACurrentMediaTime()
                        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                            if case .generic = statusSubject {
                                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                    if CACurrentMediaTime() - displayTime > 1.5 {
                                        cancelImpl?()
                                    }
                                }))
                                if let customPresentProgress = customPresentProgress {
                                    customPresentProgress(controller, nil)
                                } else {
                                    self?.present(controller, in: .window(.root))
                                }
                                return ActionDisposable { [weak controller] in
                                    Queue.mainQueue().async() {
                                        controller?.dismiss()
                                    }
                                }
                            } else {
                                return EmptyDisposable
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.05, queue: Queue.mainQueue())
                        let progressDisposable = MetaDisposable()
                        var progressStarted = false
                        self.messageIndexDisposable.set((signal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        |> deliverOnMainQueue).start(next: { [weak self] index in
                            if let strongSelf = self, let index = index.0 {
                                strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                                completion?()
                            } else if index.1 {
                                if !progressStarted {
                                    progressStarted = true
                                    progressDisposable.set(progressSignal.start())
                                }
                            }
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.loadingMessage.set(.single(nil))
                            }
                        }))
                        cancelImpl = { [weak self] in
                            if let strongSelf = self {
                                strongSelf.loadingMessage.set(.single(nil))
                                strongSelf.messageIndexDisposable.set(nil)
                            }
                        }
                    }
                } else {
                    completion?()
                }
            } else {
                if let fromIndex = fromIndex {
                    let searchLocation: ChatHistoryInitialSearchLocation
                    switch messageLocation {
                        case let .id(id, _):
                            searchLocation = .id(id)
                        case let .index(index):
                            searchLocation = .index(index)
                        case .upperBound:
                            return
                    }
                    if let _ = fromId, rememberInStack {
                        self.historyNavigationStack.add(fromIndex)
                    }
                    self.loadingMessage.set(.single(statusSubject) |> delay(0.1, queue: .mainQueue()))
                    let historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(location: searchLocation, count: 50, highlight: true), id: 0), context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
                    let signal = historyView
                        |> mapToSignal { historyView -> Signal<MessageIndex?, NoError> in
                            switch historyView {
                                case .Loading:
                                    return .complete()
                                case let .HistoryView(view, _, _, _, _, _, _):
                                    for entry in view.entries {
                                        if entry.message.id == messageLocation.messageId {
                                            return .single(entry.message.index)
                                        }
                                    }
                                    return .single(nil)
                            }
                        }
                        |> take(1)
                    self.messageIndexDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] index in
                        if let strongSelf = self {
                            if let index = index {
                                strongSelf.chatDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                                completion?()
                            } else {
                                if let navigationController = strongSelf.effectiveNavigationController {
                                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: messageLocation.peerId), subject: messageLocation.messageId.flatMap { .message(id: .id($0), highlight: true, timecode: nil) }))
                                }
                                completion?()
                            }
                        }
                    }, completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(.single(nil))
                        }
                    }))
                } else {
                    if let navigationController = self.effectiveNavigationController {
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: messageLocation.peerId), subject: messageLocation.messageId.flatMap { .message(id: .id($0), highlight: true, timecode: nil) }))
                    }
                    completion?()
                }
            }
        } else {
            completion?()
        }
    }
    
    private func forwardMessages(messageIds: [MessageId], options: ChatInterfaceForwardOptionsState? = nil, resetCurrent: Bool = false) {
        let _ = (self.context.engine.data.get(EngineDataMap(
            messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init)
        ))
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            self?.forwardMessages(messages: messages.values.compactMap { $0?._asMessage() }, options: options, resetCurrent: resetCurrent)
        })
    }
    
    private func forwardMessages(messages: [Message], options: ChatInterfaceForwardOptionsState? = nil, resetCurrent: Bool) {
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            var filter: ChatListNodePeersFilter = [.onlyWriteable, .includeSavedMessages, .excludeDisabled, .doNotSearchMessages]
            var hasPublicPolls = false
            var hasPublicQuiz = false
            for message in messages {
                for media in message.media {
                    if let poll = media as? TelegramMediaPoll, case .public = poll.publicity {
                        hasPublicPolls = true
                        if case .quiz = poll.kind {
                            hasPublicQuiz = true
                        }
                        filter.insert(.excludeChannels)
                        break
                    }
                }
            }
            var attemptSelectionImpl: ((Peer) -> Void)?
            let controller = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, updatedPresentationData: self.updatedPresentationData, filter: filter, attemptSelection: { peer in
                attemptSelectionImpl?(peer)
            }, multipleSelection: true, forwardedMessageIds: messages.map { $0.id }))
            let context = self.context
            attemptSelectionImpl = { [weak self, weak controller] peer in
                guard let strongSelf = self, let controller = controller else {
                    return
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                if hasPublicPolls {
                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        controller.present(textAlertController(context: context, title: nil, text: hasPublicQuiz ? presentationData.strings.Forward_ErrorPublicQuizDisabledInChannels : presentationData.strings.Forward_ErrorPublicPollDisabledInChannels, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        return
                    }
                }
                controller.present(textAlertController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: presentationData.strings.Forward_ErrorDisabledForChat, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
            controller.multiplePeersSelected = { [weak self, weak controller] peers, peerMap, messageText, mode, forwardOptions in
                guard let strongSelf = self, let strongController = controller else {
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
                
                result.append(contentsOf: messages.map { message -> EnqueueMessage in
                    return .forward(source: message.id, grouping: .auto, attributes: attributes, correlationId: nil)
                })
                
                let commit: ([EnqueueMessage]) -> Void = { result in
                    strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }).updatedSearch(nil) })
                    
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
                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
                        savedMessages = true
                    } else {
                        if displayPeers.count == 1, let peer = displayPeers.first {
                            let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                        } else if displayPeers.count == 2, let firstPeer = displayPeers.first, let secondPeer = displayPeers.last {
                            let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(firstPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : EnginePeer(secondPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                        } else if let peer = displayPeers.first {
                            let peerName = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(displayPeers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(displayPeers.count - 1)").string
                        } else {
                            text = ""
                        }
                    }
                    
                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                }
                
                switch mode {
                    case .generic:
                        commit(result)
                    case .silent:
                        let transformedMessages = strongSelf.transformEnqueueMessages(result, silentPosting: true)
                        commit(transformedMessages)
                    case .schedule:
                        strongSelf.presentScheduleTimePicker(completion: { [weak self] scheduleTime in
                            if let strongSelf = self {
                                let transformedMessages = strongSelf.transformEnqueueMessages(result, silentPosting: false, scheduleTime: scheduleTime)
                                commit(transformedMessages)
                            }
                        })
                }
            }
            controller.peerSelected = { [weak self, weak controller] peer in
                guard let strongSelf = self, let strongController = controller else {
                    return
                }
                let peerId = peer.id
                let accountPeerId = strongSelf.context.account.peerId
                
                if resetCurrent {
                    strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(nil).withUpdatedForwardOptionsState(nil) }) })
                }
                
                var isPinnedMessages = false
                if case .pinnedMessages = strongSelf.presentationInterfaceState.subject {
                    isPinnedMessages = true
                }
                
                var hasNotOwnMessages = false
                for message in messages {
                    if message.id.peerId == accountPeerId && message.forwardInfo == nil {
                    } else {
                        hasNotOwnMessages = true
                    }
                }
                
                if case .peer(peerId) = strongSelf.chatLocation, strongSelf.parentController == nil, !isPinnedMessages {
                    strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(messages.map { $0.id }).withUpdatedForwardOptionsState(ChatInterfaceForwardOptionsState(hideNames: !hasNotOwnMessages, hideCaptions: false, unhideNamesOnCaptionChange: false)).withoutSelectionState() }).updatedSearch(nil) })
                    strongSelf.updateItemNodesSearchTextHighlightStates()
                    strongSelf.searchResultsController = nil
                    strongController.dismiss()
                } else if peerId == strongSelf.context.account.peerId {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: true, text: messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
                        if case .info = value, let strongSelf = self, let navigationController = strongSelf.effectiveNavigationController {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: context.account.peerId), keepStack: .always, purposefulAction: {}, peekData: nil))
                            return true
                        }
                        return false
                    }), in: .current)
                    
                    let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messages.map { message -> EnqueueMessage in
                        return .forward(source: message.id, grouping: .auto, attributes: [], correlationId: nil)
                    })
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
                    strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                    strongController.dismiss()
                } else {
                    if let navigationController = strongSelf.navigationController as? NavigationController {
                        for controller in navigationController.viewControllers {
                            if let maybeChat = controller as? ChatControllerImpl {
                                if case .peer(peerId) = maybeChat.chatLocation {
                                    var isChatPinnedMessages = false
                                    if case .pinnedMessages = maybeChat.presentationInterfaceState.subject {
                                        isChatPinnedMessages = true
                                    }
                                    if !isChatPinnedMessages {
                                        maybeChat.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(messages.map { $0.id }).withoutSelectionState() }) })
                                        strongSelf.dismiss()
                                        strongController.dismiss()
                                        return
                                    }
                                }
                            }
                        }
                    }

                    let _ = (ChatInterfaceState.update(engine: strongSelf.context.engine, peerId: peerId, threadId: nil, { currentState in
                        return currentState.withUpdatedForwardMessageIds(messages.map { $0.id }).withUpdatedForwardOptionsState(ChatInterfaceForwardOptionsState(hideNames: !hasNotOwnMessages, hideCaptions: false, unhideNamesOnCaptionChange: false))
                    })
                    |> deliverOnMainQueue).start(completed: {
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                            
                            let navigationController: NavigationController?
                            if let parentController = strongSelf.parentController {
                                navigationController = (parentController.navigationController as? NavigationController)
                            } else {
                                navigationController = strongSelf.effectiveNavigationController
                            }
                            
                            if let navigationController = navigationController {
                                let chatController = ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: peerId))
                                var viewControllers = navigationController.viewControllers
                                viewControllers.insert(chatController, at: viewControllers.count - 1)
                                navigationController.setViewControllers(viewControllers, animated: false)
                                
                                strongSelf.controllerNavigationDisposable.set((chatController.ready.get()
                                |> SwiftSignalKit.filter { $0 }
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { _ in
                                    if let strongController = controller {
                                        strongController.dismiss()
                                    }
                                }))
                            }
                        }
                    })
                }
            }
            self.chatDisplayNode.dismissInput()
            self.effectiveNavigationController?.pushViewController(controller)
        })
    }
    
    private func openPeer(peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer, fromMessage: MessageReference?, expandAvatar: Bool = false) {
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            if case let .peer(currentPeerId) = self.chatLocation, peerId == currentPeerId {
                switch navigation {
                    case .info:
                        self.navigationButtonAction(.openChatInfo(expandAvatar: expandAvatar))
                    case let .chat(textInputState, _, _):
                        if let textInputState = textInputState {
                            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return ($0.updatedInterfaceState {
                                    return $0.withUpdatedComposeInputState(textInputState)
                                }).updatedInputMode({ _ in
                                    return .text
                                })
                            })
                        }
                    case let .withBotStartPayload(botStart):
                        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            $0.updatedBotStartPayload(botStart.payload)
                        })
                    case .withAttachBot:
                        self.presentAttachmentMenu(editMediaOptions: nil, editMediaReference: nil)
                    default:
                        break
                }
            } else {
                if let peerId = peerId {
                    do {
                        var chatPeerId: PeerId?
                        if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramGroup {
                            chatPeerId = peer.id
                        } else if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case .group = peer.info, case .member = peer.participationStatus {
                            chatPeerId = peer.id
                        }
                        
                        switch navigation {
                            case .info, .default:
                                let peerSignal: Signal<Peer?, NoError>
                                if let messageId = fromMessage?.id {
                                    peerSignal = loadedPeerFromMessage(account: self.context.account, peerId: peerId, messageId: messageId)
                                } else {
                                    peerSignal = self.context.account.postbox.loadedPeerWithId(peerId) |> map(Optional.init)
                                }
                                self.navigationActionDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    if let strongSelf = self, let peer = peer {
                                        var mode: PeerInfoControllerMode = .generic
                                        if let _ = fromMessage, let chatPeerId = chatPeerId {
                                            mode = .group(chatPeerId)
                                        }
                                        var expandAvatar = expandAvatar
                                        if peer.smallProfileImage == nil {
                                            expandAvatar = false
                                        }
                                        if let validLayout = strongSelf.validLayout, validLayout.deviceMetrics.type == .tablet {
                                            expandAvatar = false
                                        }
                                        if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: peer, mode: mode, avatarInitiallyExpanded: expandAvatar, fromChat: false, requestsContext: nil) {
                                            strongSelf.effectiveNavigationController?.pushViewController(infoController)
                                        }
                                    }
                                }))
                            case let .chat(textInputState, subject, peekData):
                                if let textInputState = textInputState {
                                    let _ = (ChatInterfaceState.update(engine: self.context.engine, peerId: peerId, threadId: nil, { currentState in
                                        return currentState.withUpdatedComposeInputState(textInputState)
                                    })
                                    |> deliverOnMainQueue).start(completed: { [weak self] in
                                        if let strongSelf = self, let navigationController = strongSelf.effectiveNavigationController {
                                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), subject: subject, updateTextInputState: textInputState, peekData: peekData))
                                        }
                                    })
                                } else {
                                    self.effectiveNavigationController?.pushViewController(ChatControllerImpl(context: self.context, chatLocation: .peer(id: peerId), subject: subject))
                                }
                            case let .withBotStartPayload(botStart):
                                self.effectiveNavigationController?.pushViewController(ChatControllerImpl(context: self.context, chatLocation: .peer(id: peerId), botStart: botStart))
                            case let .withAttachBot(attachBotStart):
                                if let navigationController = self.effectiveNavigationController {
                                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(id: peerId), attachBotStart: attachBotStart))
                                }
                        }
                    }
                } else {
                    switch navigation {
                        case .info:
                            break
                        case let .chat(textInputState, _, _):
                            if let textInputState = textInputState {
                                let controller = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, updatedPresentationData: self.updatedPresentationData))
                                controller.peerSelected = { [weak self, weak controller] peer in
                                    let peerId = peer.id
                                    
                                    if let strongSelf = self, let strongController = controller {
                                        if case let .peer(currentPeerId) = strongSelf.chatLocation, peerId == currentPeerId {
                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                                return ($0.updatedInterfaceState {
                                                    return $0.withUpdatedComposeInputState(textInputState)
                                                }).updatedInputMode({ _ in
                                                    return .text
                                                })
                                            })
                                            strongController.dismiss()
                                        } else {
                                            let _ = (ChatInterfaceState.update(engine: strongSelf.context.engine, peerId: peerId, threadId: nil, { currentState in
                                                return currentState.withUpdatedComposeInputState(textInputState)
                                            })
                                            |> deliverOnMainQueue).start(completed: {
                                                if let strongSelf = self {
                                                    strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                                                                                        
                                                    if let navigationController = strongSelf.effectiveNavigationController {
                                                        let chatController = ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: peerId))
                                                        var viewControllers = navigationController.viewControllers
                                                        viewControllers.insert(chatController, at: viewControllers.count - 1)
                                                        navigationController.setViewControllers(viewControllers, animated: false)
                                                        
                                                        strongSelf.controllerNavigationDisposable.set((chatController.ready.get()
                                                        |> filter { $0 }
                                                        |> take(1)
                                                        |> deliverOnMainQueue).start(next: { _ in
                                                            if let strongController = controller {
                                                                strongController.dismiss()
                                                            }
                                                        }))
                                                    }
                                                }
                                            })
                                        }
                                    }
                                }
                                self.chatDisplayNode.dismissInput()
                                self.effectiveNavigationController?.pushViewController(controller)
                            }
                        default:
                            break
                    }
                }
            }
        })
    }
    
    private func openPeerMention(_ name: String, navigation: ChatControllerInteractionNavigateToPeer = .default, sourceMessageId: MessageId? = nil) {
        let _ = self.presentVoiceMessageDiscardAlert(action: {
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
                self?.present(controller, in: .window(.root))
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
                        strongSelf.openResolved(result: .peer(peer.id, navigation), sourceMessageId: sourceMessageId)
                    } else {
                        strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                }
            }))
        })
    }
    
    private func openHashtag(_ hashtag: String, peerName: String?) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            if self.resolvePeerByNameDisposable == nil {
                self.resolvePeerByNameDisposable = MetaDisposable()
            }
            var resolveSignal: Signal<Peer?, NoError>
            if let peerName = peerName {
                resolveSignal = self.context.engine.peers.resolvePeerByName(name: peerName)
                |> mapToSignal { peer -> Signal<Peer?, NoError> in
                    if let peer = peer {
                        return .single(peer._asPeer())
                    } else {
                        return .single(nil)
                    }
                }
            } else {
                resolveSignal = self.context.account.postbox.loadedPeerWithId(peerId)
                |> map(Optional.init)
            }
            var cancelImpl: (() -> Void)?
            let presentationData = self.presentationData
            let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                    cancelImpl?()
                }))
                self?.present(controller, in: .window(.root))
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
                    strongSelf.effectiveNavigationController?.pushViewController(searchController)
                }
            }))
        })
    }
    
    private func unblockPeer() {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        let unblockingPeer = self.unblockingPeer
        unblockingPeer.set(true)
        
        var restartBot = false
        if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
            restartBot = true
        }
        self.editMessageDisposable.set((self.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peerId, isBlocked: false)
        |> afterDisposed({ [weak self] in
            Queue.mainQueue().async {
                unblockingPeer.set(false)
                if let strongSelf = self, restartBot {
                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)]).start()
                }
            }
        })).start())
    }
    
    private func reportPeer() {
        guard let renderedPeer = self.presentationInterfaceState.renderedPeer, let peer = renderedPeer.chatMainPeer, let chatPeer = renderedPeer.peer else {
            return
        }
        self.chatDisplayNode.dismissInput()
        
        if let peer = peer as? TelegramChannel, let username = peer.username, !username.isEmpty {
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            
            var items: [ActionSheetItem] = []
            items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ReportSpamAndLeave, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.deleteChat(reportChatSpam: true)
                }
            }))
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            
            self.present(actionSheet, in: .window(.root))
        } else if let _ = peer as? TelegramUser {
            let presentationData = self.presentationData
            let controller = ActionSheetController(presentationData: presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                controller?.dismissAnimated()
            }
            var reportSpam = true
            var deleteChat = true
            var items: [ActionSheetItem] = []
            if !peer.isDeleted {
                items.append(ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(EnginePeer(peer).compactDisplayTitle).string))
            }
            items.append(contentsOf: [
                ActionSheetCheckboxItem(title: presentationData.strings.Conversation_Moderate_Report, label: "", value: reportSpam, action: { [weak controller] checkValue in
                    reportSpam = checkValue
                    controller?.updateItem(groupIndex: 0, itemIndex: 1, { item in
                        if let item = item as? ActionSheetCheckboxItem {
                            return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                        }
                        return item
                    })
                }),
                ActionSheetCheckboxItem(title: presentationData.strings.ReportSpam_DeleteThisChat, label: "", value: deleteChat, action: { [weak controller] checkValue in
                    deleteChat = checkValue
                    controller?.updateItem(groupIndex: 0, itemIndex: 2, { item in
                        if let item = item as? ActionSheetCheckboxItem {
                            return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                        }
                        return item
                    })
                }),
                ActionSheetButtonItem(title: presentationData.strings.UserInfo_BlockActionTitle(EnginePeer(peer).compactDisplayTitle).string, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = strongSelf.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peer.id, isBlocked: true).start()
                    if let _ = chatPeer as? TelegramSecretChat {
                        let _ = strongSelf.context.engine.peers.terminateSecretChat(peerId: chatPeer.id, requestRemoteHistoryRemoval: true).start()
                    }
                    if deleteChat {
                        let _ = strongSelf.context.engine.peers.removePeerChat(peerId: chatPeer.id, reportChatSpam: reportSpam).start()
                        strongSelf.effectiveNavigationController?.filterController(strongSelf, animated: true)
                    } else if reportSpam {
                        let _ = strongSelf.context.engine.peers.reportPeer(peerId: peer.id, reason: .spam, message: "").start()
                    }
                })
            ] as [ActionSheetItem])
            
            controller.setItemGroups([
                ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            self.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        } else {
            let title: String
            var infoString: String?
            if let _ = peer as? TelegramGroup {
                title = self.presentationData.strings.Conversation_ReportSpamAndLeave
                infoString = self.presentationData.strings.Conversation_ReportSpamGroupConfirmation
            } else if let channel = peer as? TelegramChannel {
                title = self.presentationData.strings.Conversation_ReportSpamAndLeave
                if case .group = channel.info {
                    infoString = self.presentationData.strings.Conversation_ReportSpamGroupConfirmation
                } else {
                    infoString = self.presentationData.strings.Conversation_ReportSpamChannelConfirmation
                }
            } else {
                title = self.presentationData.strings.Conversation_ReportSpam
                infoString = self.presentationData.strings.Conversation_ReportSpamConfirmation
            }
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            
            var items: [ActionSheetItem] = []
            if let infoString = infoString {
                items.append(ActionSheetTextItem(title: infoString))
            }
            items.append(ActionSheetButtonItem(title: title, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.deleteChat(reportChatSpam: true)
                }
            }))
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            
            self.present(actionSheet, in: .window(.root))
        }
    }
    
    private func shareAccountContact() {
        let _ = (self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] accountPeer in
            guard let strongSelf = self else {
                return
            }
            guard let user = accountPeer as? TelegramUser, let phoneNumber = user.phone else {
                return
            }
            guard let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramUser else {
                return
            }
            
            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
            var items: [ActionSheetItem] = []
            items.append(ActionSheetTextItem(title: strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumberConfirmation(formatPhoneNumber(phoneNumber), EnginePeer(peer).compactDisplayTitle).string))
            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumber, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                guard let strongSelf = self else {
                    return
                }
                let _ = (strongSelf.context.engine.contacts.acceptAndShareContact(peerId: peer.id)
                |> deliverOnMainQueue).start(error: { _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }, completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .genericSuccess(strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumber_StatusSuccess(EnginePeer(peer).compactDisplayTitle).string, true)), in: .window(.root))
                })
            }))
            
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(actionSheet, in: .window(.root))
        })
    }
    
    private func addPeerContact() {
        if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramUser, let peerStatusSettings = self.presentationInterfaceState.contactStatus?.peerStatusSettings, let contactData = DeviceContactExtendedData(peer: peer) {
            self.present(context.sharedContext.makeDeviceContactInfoController(context: context, subject: .create(peer: peer, contactData: contactData, isSharing: true, shareViaException: peerStatusSettings.contains(.addExceptionWhenAddingContact), completion: { [weak self] peer, stableId, contactData in
                guard let strongSelf = self else {
                    return
                }
                if let peer = peer as? TelegramUser {
                    if let phone = peer.phone, !phone.isEmpty {
                    }
                    
                    self?.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .genericSuccess(strongSelf.presentationData.strings.AddContact_StatusSuccess(EnginePeer(peer).compactDisplayTitle).string, true)), in: .window(.root))
                }
            }), completed: nil, cancelled: nil), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }
    }
    
    private func dismissPeerContactOptions() {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        let dismissPeerId: PeerId
        if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramUser {
            dismissPeerId = peer.id
        } else {
            dismissPeerId = peerId
        }
        self.editMessageDisposable.set((self.context.engine.peers.dismissPeerStatusOptions(peerId: dismissPeerId)
        |> afterDisposed({
            Queue.mainQueue().async {
            }
        })).start())
    }
    
    private func deleteChat(reportChatSpam: Bool) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        self.commitPurposefulAction()
        self.chatDisplayNode.historyNode.disconnect()
        let _ = self.context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: reportChatSpam).start()
        self.effectiveNavigationController?.popToRoot(animated: true)
        
        let _ = self.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peerId, isBlocked: true).start()
    }
    
    private func startBot(_ payload: String?) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        
        let startingBot = self.startingBot
        startingBot.set(true)
        self.editMessageDisposable.set((self.context.engine.messages.requestStartBot(botPeerId: peerId, payload: payload) |> deliverOnMainQueue |> afterDisposed({
            startingBot.set(false)
        })).start(completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedBotStartPayload(nil) })
            }
        }))
    }
    
    private func openResolved(result: ResolvedUrl, sourceMessageId: MessageId?, forceExternal: Bool = false) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        self.context.sharedContext.openResolvedUrl(result, context: self.context, urlContext: .chat(peerId: peerId, updatedPresentationData: self.updatedPresentationData), navigationController: self.effectiveNavigationController, forceExternal: forceExternal, openPeer: { [weak self] peerId, navigation in
            guard let strongSelf = self else {
                return
            }
            
            if let currentWebAppController = strongSelf.currentWebAppController {
                strongSelf.currentWebAppController = nil
                currentWebAppController.dismiss(animated: true, completion: nil)
            } else if let currentWebAppController = strongSelf.currentMenuWebAppController {
                strongSelf.currentMenuWebAppController = nil
                currentWebAppController.dismiss(animated: true, completion: nil)
            }
            
            switch navigation {
                case let .chat(_, subject, peekData):
                    if case .peer(peerId) = strongSelf.chatLocation {
                        if let subject = subject, case let .message(messageSubject, _, timecode) = subject {
                            if case let .id(messageId) = messageSubject {
                                strongSelf.navigateToMessage(from: sourceMessageId, to: .id(messageId, timecode))
                            }
                        }
                    } else if let navigationController = strongSelf.effectiveNavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), subject: subject, keepStack: .always, peekData: peekData))
                    }
                case .info:
                    strongSelf.navigationActionDisposable.set((strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                            if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                                if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                    strongSelf.effectiveNavigationController?.pushViewController(infoController)
                                }
                            }
                        }))
                case let .withBotStartPayload(startPayload):
                    if case .peer(peerId) = strongSelf.chatLocation {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            $0.updatedBotStartPayload(startPayload.payload)
                        })
                    } else if let navigationController = strongSelf.effectiveNavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), botStart: startPayload, keepStack: .always))
                    }
                case let .withAttachBot(attachBotStart):
                    if let navigationController = strongSelf.effectiveNavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peerId), attachBotStart: attachBotStart))
                    }
                default:
                    break
                }
        }, sendFile: nil, sendSticker: { [weak self] f, sourceNode, sourceRect in
            return self?.interfaceInteraction?.sendSticker(f, true, sourceNode, sourceRect) ?? false
        }, requestMessageActionUrlAuth: { [weak self] subject in
            if case let .url(url) = subject {
                self?.controllerInteraction?.requestMessageActionUrlAuth(url, subject)
            }
        }, joinVoiceChat: { [weak self] peerId, invite, call in
            self?.joinGroupCall(peerId: peerId, invite: invite, activeCall: EngineGroupCallDescription(call))
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak self] in
            self?.chatDisplayNode.dismissInput()
        }, contentContext: nil)
    }
    
    private func openUrl(_ url: String, concealed: Bool, forceExternal: Bool = false, skipUrlAuth: Bool = false, skipConcealedAlert: Bool = false, message: Message? = nil) {
        self.commitPurposefulAction()
        
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            if self.context.sharedContext.immediateExperimentalUISettings.playlistPlayback {
                if url.hasSuffix(".m3u8") {
                    let navigationController = self.navigationController as? NavigationController
                    
                    let webPage = TelegramMediaWebpage(
                        webpageId: MediaId(namespace: 0, id: 0),
                        content: .Loaded(TelegramMediaWebpageLoadedContent(
                            url: url,
                            displayUrl: url,
                            hash: 0,
                            type: "video",
                            websiteName: nil,
                            title: nil,
                            text: nil,
                            embedUrl: url,
                            embedType: "video",
                            embedSize: nil,
                            duration: nil,
                            author: nil,
                            image: nil,
                            file: nil,
                            attributes: [],
                            instantPage: nil
                        ))
                    )
                    let entry = InstantPageGalleryEntry(
                        index: 0,
                        pageId: webPage.webpageId,
                        media: InstantPageMedia(
                            index: 0,
                            media: webPage,
                            url: nil,
                            caption: nil,
                            credit: nil
                        ),
                        caption: nil,
                        credit: nil,
                        location: nil
                    )
                    
                    let gallery = InstantPageGalleryController(context: self.context, webPage: webPage, entries: [entry], centralIndex: 0, replaceRootController: { [weak navigationController] controller, ready in
                        if let navigationController = navigationController {
                            navigationController.replaceTopController(controller, animated: false, ready: ready)
                        }
                    }, baseNavigationController: navigationController)
                    self.present(gallery, in: .window(.root), with: InstantPageGalleryControllerPresentationArguments(transitionArguments: { entry -> GalleryTransitionArguments? in
                        return nil
                    }))
                    return;
                }
            }
            
            openUserGeneratedUrl(context: self.context, peerId: self.peerView?.peerId, url: url, concealed: concealed, skipUrlAuth: skipUrlAuth, skipConcealedAlert: skipConcealedAlert, present: { [weak self] c in
                self?.present(c, in: .window(.root))
            }, openResolved: { [weak self] resolved in
                self?.openResolved(result: resolved, sourceMessageId: message?.id, forceExternal: forceExternal)
            })
        }, performAction: true)
    }
    
    private func openUrlIn(_ url: String) {
        let actionSheet = OpenInActionSheetController(context: self.context, updatedPresentationData: self.updatedPresentationData, item: .url(url: url), openUrl: { [weak self] url in
            if let strongSelf = self, let navigationController = strongSelf.effectiveNavigationController {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.presentationData, navigationController: navigationController, dismissInput: {
                    self?.chatDisplayNode.dismissInput()
                })
            }
        })
        self.chatDisplayNode.dismissInput()
        self.present(actionSheet, in: .window(.root))
    }
    
    func avatarPreviewingController(from sourceView: UIView) -> (UIViewController, CGRect)? {
        guard let layout = self.validLayout else {
            return nil
        }
        guard let buttonView = (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.avatarNode.view else {
            return nil
        }
        if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer, peer.smallProfileImage != nil {
            let galleryController = AvatarGalleryController(context: self.context, peer: peer, remoteEntries: nil, replaceRootController: { controller, ready in
            }, synchronousLoad: true)
            galleryController.setHintWillBePresentedInPreviewingContext(true)
            galleryController.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height), metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
            return (galleryController, buttonView.convert(buttonView.bounds, to: sourceView))
        }
        return nil
    }
    
    func previewingController(from sourceView: UIView, for location: CGPoint) -> (UIViewController, CGRect)? {
        guard let layout = self.validLayout, case .phone = layout.deviceMetrics.type, let view = self.chatDisplayNode.view.hitTest(location, with: nil), view.isDescendant(of: self.chatDisplayNode.historyNode.view) else {
            return nil
        }
        
        let historyPoint = sourceView.convert(location, to: self.chatDisplayNode.historyNode.view)
        var result: (Message, ChatMessagePeekPreviewContent)?
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if itemNode.frame.contains(historyPoint) {
                    if let value = itemNode.peekPreviewContent(at: self.chatDisplayNode.historyNode.view.convert(historyPoint, to: itemNode.view)) {
                        result = value
                    }
                }
            }
        }
        if let (message, content) = result {
            switch content {
                case let .media(media):
                    var selectedTransitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                    self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            if let result = itemNode.transitionNode(id: message.id, media: media) {
                                selectedTransitionNode = result
                            }
                        }
                    }
                    
                    if let selectedTransitionNode = selectedTransitionNode {
                        if let previewData = chatMessagePreviewControllerData(context: self.context, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: self.effectiveNavigationController) {
                            switch previewData {
                                case let .gallery(gallery):
                                    gallery.setHintWillBePresentedInPreviewingContext(true)
                                    let rect = selectedTransitionNode.0.view.convert(selectedTransitionNode.0.bounds, to: sourceView)
                                    let sourceRect = rect.insetBy(dx: -2.0, dy: -2.0)
                                    gallery.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height), metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                                    return (gallery, sourceRect)
                                case .instantPage:
                                    break
                            }
                        }
                    }
                case let .url(node, rect, string, concealed):
                    var parsedUrlValue: URL?
                    if let parsed = URL(string: string) {
                        parsedUrlValue = parsed
                    } else if let encoded = (string as NSString).addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed), let parsed = URL(string: encoded) {
                        parsedUrlValue = parsed
                    }
                    
                    if let parsedUrlValue = parsedUrlValue {
                        if concealed, (parsedUrlValue.scheme == "http" || parsedUrlValue.scheme == "https"), !isConcealedUrlWhitelisted(parsedUrlValue) {
                            return nil
                        }
                    } else {
                        return nil
                    }
                    
                    let targetRect = node.view.convert(rect, to: sourceView)
                    let sourceRect = CGRect(origin: CGPoint(x: floor(targetRect.midX), y: floor(targetRect.midY)), size: CGSize(width: 1.0, height: 1.0))
                    if let parsedUrl = parsedUrlValue {
                        if parsedUrl.scheme == "http" || parsedUrl.scheme == "https" {
                            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                                let controller = SFSafariViewController(url: parsedUrl)
                                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                                    controller.preferredBarTintColor = self.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
                                    controller.preferredControlTintColor = self.presentationData.theme.rootController.navigationBar.accentTextColor
                                }
                                return (controller, sourceRect)
                            }
                        }
                    }
            }
        }
        return nil
    }
    
    private func presentBanMessageOptions(accountPeerId: PeerId, author: Peer, messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        do {
            self.navigationActionDisposable.set((self.context.engine.peers.fetchChannelParticipant(peerId: peerId, participantId: author.id)
            |> deliverOnMainQueue).start(next: { [weak self] participant in
                if let strongSelf = self {
                    let canBan = participant?.canBeBannedBy(peerId: accountPeerId) ?? true
                    
                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                    var items: [ActionSheetItem] = []
                    
                    var actions = Set<Int>([0])
                    
                    let toggleCheck: (Int, Int) -> Void = { [weak actionSheet] category, itemIndex in
                        if actions.contains(category) {
                            actions.remove(category)
                        } else {
                            actions.insert(category)
                        }
                        actionSheet?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                            if let item = item as? ActionSheetCheckboxItem {
                                return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                            }
                            return item
                        })
                    }
                    
                    var itemIndex = 0
                    var categories: [Int] = [0]
                    if canBan {
                        categories.append(1)
                    }
                    categories.append(contentsOf: [2, 3])
                    
                    for categoryId in categories as [Int] {
                        var title = ""
                        if categoryId == 0 {
                            title = strongSelf.presentationData.strings.Conversation_Moderate_Delete
                        } else if categoryId == 1 {
                            title = strongSelf.presentationData.strings.Conversation_Moderate_Ban
                        } else if categoryId == 2 {
                            title = strongSelf.presentationData.strings.Conversation_Moderate_Report
                        } else if categoryId == 3 {
                            title = strongSelf.presentationData.strings.Conversation_Moderate_DeleteAllMessages(EnginePeer(author).displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).string
                        }
                        let index = itemIndex
                        items.append(ActionSheetCheckboxItem(title: title, label: "", value: actions.contains(categoryId), action: { value in
                            toggleCheck(categoryId, index)
                        }))
                        itemIndex += 1
                    }
                    
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Done, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                            if actions.contains(3) {
                                let context = strongSelf.context
                                let _ = context.engine.messages.deleteAllMessagesWithAuthor(peerId: peerId, authorId: author.id, namespace: Namespaces.Message.Cloud).start()
                                let _ = strongSelf.context.engine.messages.clearAuthorHistory(peerId: peerId, memberId: author.id).start()
                            } else if actions.contains(0) {
                                let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
                            }
                            if actions.contains(1) {
                                let _ = strongSelf.context.engine.peers.removePeerMember(peerId: peerId, memberId: author.id).start()
                            }
                        }
                    }))
                    
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(actionSheet, in: .window(.root))
                }
            }))
        }
    }
    
    private func presentDeleteMessageOptions(messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions, contextController: ContextControllerProtocol?, completion: @escaping (ContextMenuActionResult) -> Void) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        var personalPeerName: String?
        var isChannel = false
        if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser {
            personalPeerName = EnginePeer(user).compactDisplayTitle
        } else if let peer = self.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, let associatedPeerId = peer.associatedPeerId, let user = self.presentationInterfaceState.renderedPeer?.peers[associatedPeerId] as? TelegramUser {
            personalPeerName = EnginePeer(user).compactDisplayTitle
        } else if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
            isChannel = true
        }
        
        if options.contains(.cancelSending) {
            items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ContextMenuCancelSending, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
                }
            }))
        }
        
        var contextItems: [ContextMenuItem] = []
        var canDisplayContextMenu = true
        
        var unsendPersonalMessages = false
        if options.contains(.unsendPersonal) {
            canDisplayContextMenu = false
            items.append(ActionSheetTextItem(title: self.presentationData.strings.Chat_UnsendMyMessagesAlertTitle(personalPeerName ?? "").string))
            items.append(ActionSheetSwitchItem(title: self.presentationData.strings.Chat_UnsendMyMessages, isOn: false, action: { value in
                unsendPersonalMessages = value
            }))
        } else if options.contains(.deleteGlobally) {
            let globalTitle: String
            if isChannel {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
            } else if let personalPeerName = personalPeerName {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
            } else {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
            }
            contextItems.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { [weak self] _, f in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
                    f(.dismissWithoutContent)
                }
            })))
            items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).start()
                }
            }))
        }
        if options.contains(.deleteLocally) {
            var localOptionText = self.presentationData.strings.Conversation_DeleteMessagesForMe
            if case .scheduledMessages = self.presentationInterfaceState.subject {
                localOptionText = messageIds.count > 1 ? self.presentationData.strings.ScheduledMessages_DeleteMany : self.presentationData.strings.ScheduledMessages_Delete
            } else {
                if options.contains(.unsendPersonal) {
                    localOptionText = self.presentationData.strings.Chat_DeleteMessagesConfirmation(Int32(messageIds.count))
                } else if case .peer(self.context.account.peerId) = self.chatLocation {
                    if messageIds.count == 1 {
                        localOptionText = self.presentationData.strings.Conversation_Moderate_Delete
                    } else {
                        localOptionText = self.presentationData.strings.Conversation_DeleteManyMessages
                    }
                }
            }
            contextItems.append(.action(ContextMenuActionItem(text: localOptionText, textColor: .destructive, icon: { _ in nil }, action: { [weak self] _, f in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: unsendPersonalMessages ? .forEveryone : .forLocalPeer).start()
                    f(.dismissWithoutContent)
                }
            })))
            items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: unsendPersonalMessages ? .forEveryone : .forLocalPeer).start()
                }
            }))
        }
        
        if canDisplayContextMenu, let contextController = contextController {
            contextController.setItems(.single(ContextController.Items(content: .list(contextItems))), minHeight: nil)
        } else {
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            
            if let contextController = contextController {
                contextController.dismiss(completion: { [weak self] in
                    self?.present(actionSheet, in: .window(.root))
                })
            } else {
                self.chatDisplayNode.dismissInput()
                self.present(actionSheet, in: .window(.root))
                completion(.default)
            }
        }
    }
    
    private func presentClearCacheSuggestion() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
        
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        
        items.append(DeleteChatPeerActionSheetItem(context: self.context, peer: EnginePeer(peer), chatPeer: EnginePeer(peer), action: .clearCacheSuggestion, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder))
        
        var presented = false
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.ClearCache_FreeSpace, color: .accent, action: { [weak self, weak actionSheet] in
           actionSheet?.dismissAnimated()
            if let strongSelf = self, !presented {
                presented = true
                strongSelf.push(storageUsageController(context: strongSelf.context, isModal: true))
           }
        }))
    
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.chatDisplayNode.dismissInput()
        self.presentInGlobalOverlay(actionSheet)
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [kUTTypeImage as String])
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        if !canSendMessagesToChat(self.presentationInterfaceState) {
            return UIDropProposal(operation: .cancel)
        }
        
        //let dropLocation = session.location(in: self.chatDisplayNode.view)
        self.chatDisplayNode.updateDropInteraction(isActive: true)
        
        let operation: UIDropOperation
        operation = .copy
        return UIDropProposal(operation: operation)
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] imageItems in
            guard let strongSelf = self else {
                return
            }
            let images = imageItems as! [UIImage]
            
            strongSelf.chatDisplayNode.updateDropInteraction(isActive: false)
            if images.count == 1, let image = images.first, let cgImage = image.cgImage {
                let maxSide = max(image.size.width, image.size.height)
                if maxSide.isZero {
                    return
                }
                let aspectRatio = min(image.size.width, image.size.height) / maxSide
                if (imageHasTransparency(cgImage) && aspectRatio > 0.2) {
                    strongSelf.enqueueStickerImage(image, isMemoji: false)
                    return
                }
            }
            strongSelf.chatDisplayNode.updateDropInteraction(isActive: false)
            strongSelf.displayPasteMenu(images)
        }
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        self.chatDisplayNode.updateDropInteraction(isActive: false)
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        self.chatDisplayNode.updateDropInteraction(isActive: false)
    }
    
    public func beginMessageSearch(_ query: String) {
        self.interfaceInteraction?.beginMessageSearch(.everything, query)
    }
    
    public func beginReportSelection(reason: ReportReason) {
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedReportReason(reason).updatedInterfaceState { $0.withUpdatedSelectedMessages([]) } })
    }
    
    private func displayMediaRecordingTooltip() {
        let rect: CGRect? = self.chatDisplayNode.frameForInputActionButton()
        
        let updatedMode: ChatTextInputMediaRecordingButtonMode = self.presentationInterfaceState.interfaceState.mediaRecordingMode
        
        let text: String
        if updatedMode == .audio {
            text = self.presentationData.strings.Conversation_HoldForAudio
        } else {
            text = self.presentationData.strings.Conversation_HoldForVideo
        }
        
        self.silentPostTooltipController?.dismiss()
        
        if let tooltipController = self.mediaRecordingModeTooltipController {
            tooltipController.updateContent(.text(text), animated: true, extendTimer: true)
        } else if let rect = rect {
            let tooltipController = TooltipController(content: .text(text), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize)
            self.mediaRecordingModeTooltipController = tooltipController
            tooltipController.dismissed = { [weak self, weak tooltipController] _ in
                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.mediaRecordingModeTooltipController === tooltipController {
                    strongSelf.mediaRecordingModeTooltipController = nil
                }
            }
            self.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (strongSelf.chatDisplayNode, rect)
                }
                return nil
            }))
        }
    }
    
    private func displaySendingOptionsTooltip() {
        guard let rect = self.chatDisplayNode.frameForInputActionButton(), self.effectiveNavigationController?.topViewController === self else {
            return
        }
        self.sendingOptionsTooltipController?.dismiss()
        let tooltipController = TooltipController(content: .text(self.presentationData.strings.Conversation_SendingOptionsTooltip), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize, timeout: 3.0, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
        self.sendingOptionsTooltipController = tooltipController
        tooltipController.dismissed = { [weak self, weak tooltipController] _ in
            if let strongSelf = self, let tooltipController = tooltipController, strongSelf.sendingOptionsTooltipController === tooltipController {
                strongSelf.sendingOptionsTooltipController = nil
            }
        }
        self.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
            if let strongSelf = self {
                return (strongSelf.chatDisplayNode, rect)
            }
            return nil
        }))
    }
    
    private func displayChecksTooltip() {
        self.checksTooltipController?.dismiss()
        
        var latestNode: (Int32, ASDisplayNode)?
        self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, let statusNode = itemNode.getStatusNode() {
                if !item.content.effectivelyIncoming(self.context.account.peerId) {
                    if let (latestTimestamp, _) = latestNode {
                        if item.message.timestamp > latestTimestamp {
                            latestNode = (item.message.timestamp, statusNode)
                        }
                    } else {
                        latestNode = (item.message.timestamp, statusNode)
                    }
                }
            }
        }
        
        if let (_, latestStatusNode) = latestNode {
            let bounds = latestStatusNode.view.convert(latestStatusNode.view.bounds, to: self.chatDisplayNode.view)
            let location = CGPoint(x: bounds.maxX - 7.0, y: bounds.minY - 11.0)
            
            let contentNode = ChatStatusChecksTooltipContentNode(presentationData: self.presentationData)
            let tooltipController = TooltipController(content: .custom(contentNode), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize, timeout: 3.5, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
            self.checksTooltipController = tooltipController
            tooltipController.dismissed = { [weak self, weak tooltipController] _ in
                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.checksTooltipController === tooltipController {
                    strongSelf.checksTooltipController = nil
                }
            }
            self.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (strongSelf.chatDisplayNode, CGRect(origin: location, size: CGSize()))
                }
                return nil
            }))
        }
    }
    
    private func dismissAllTooltips() {
        self.sendingOptionsTooltipController?.dismiss()
        self.searchResultsTooltipController?.dismiss()
        self.messageTooltipController?.dismiss()
        self.videoUnmuteTooltipController?.dismiss()
        self.silentPostTooltipController?.dismiss()
        self.mediaRecordingModeTooltipController?.dismiss()
        self.mediaRestrictedTooltipController?.dismiss()
        self.checksTooltipController?.dismiss()
        self.copyProtectionTooltipController?.dismiss()
        
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
    }
    
    private func commitPurposefulAction() {
        if let purposefulAction = self.purposefulAction {
            self.purposefulAction = nil
            purposefulAction()
        }
    }
    
    public override var keyShortcuts: [KeyShortcut] {
        if !self.traceVisibility() || !isTopmostChatController(self) {
            return []
        }
        
        let strings = self.presentationData.strings
        
        var inputShortcuts: [KeyShortcut]
        if self.chatDisplayNode.isInputViewFocused {
            inputShortcuts = [
                KeyShortcut(title: strings.KeyCommand_SendMessage, input: "\r", action: {}),
                KeyShortcut(input: "B", modifiers: [.command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.bold), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "I", modifiers: [.command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.italic), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "M", modifiers: [.shift, .command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.monospace), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "K", modifiers: [.command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.openLinkEditing()
                    }
                }),
                KeyShortcut(input: "N", modifiers: [.shift, .command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputClearFormattingAttributes(current), inputMode)
                        }
                    }
                })
            ]
        } else if UIResponder.currentFirst() == nil {
            inputShortcuts = [
                KeyShortcut(title: strings.KeyCommand_FocusOnInputField, input: "\r", action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            return state.updatedInterfaceState { interfaceState in
                                return interfaceState.withUpdatedEffectiveInputState(interfaceState.effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            })
                    }
                }),
                KeyShortcut(input: "/", modifiers: [], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            if state.interfaceState.effectiveInputState.inputText.length == 0 {
                                return state.updatedInterfaceState { interfaceState in
                                    let effectiveInputState = ChatTextInputState(inputText: NSAttributedString(string: "/"))
                                    return interfaceState.withUpdatedEffectiveInputState(effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            } else {
                                return state
                            }
                        })
                    }
                }),
                KeyShortcut(input: "2", modifiers: [.shift], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            if state.interfaceState.effectiveInputState.inputText.length == 0 {
                                return state.updatedInterfaceState { interfaceState in
                                    let effectiveInputState = ChatTextInputState(inputText: NSAttributedString(string: "@"))
                                    return interfaceState.withUpdatedEffectiveInputState(effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            } else {
                                return state
                            }
                        })
                    }
                }),
                KeyShortcut(input: "3", modifiers: [.shift], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            if state.interfaceState.effectiveInputState.inputText.length == 0 {
                                return state.updatedInterfaceState { interfaceState in
                                    let effectiveInputState = ChatTextInputState(inputText: NSAttributedString(string: "#"))
                                    return interfaceState.withUpdatedEffectiveInputState(effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            } else {
                                return state
                            }
                        })
                    }
                })
            ]
        } else {
            inputShortcuts = []
        }
        
        var canEdit = false
        if self.presentationInterfaceState.interfaceState.effectiveInputState.inputText.length == 0 && self.presentationInterfaceState.interfaceState.editMessage == nil {
            canEdit = true
        }
        
        if canEdit, let message = self.chatDisplayNode.historyNode.firstMessageForEditInCurrentHistoryView() {
            inputShortcuts.append(KeyShortcut(input: UIKeyCommand.inputUpArrow, action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interfaceInteraction?.setupEditMessage(message.id, { _ in })
                }
            }))
        }
        
        let otherShortcuts: [KeyShortcut] = [
            KeyShortcut(title: strings.KeyCommand_ChatInfo, input: "I", modifiers: [.command, .control], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interfaceInteraction?.openPeerInfo()
                }
            }),
            KeyShortcut(input: "/", modifiers: [.command], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        return state.updatedInterfaceState { interfaceState in
                            return interfaceState.withUpdatedEffectiveInputState(interfaceState.effectiveInputState)
                        }.updatedInputMode({ _ in ChatInputMode.media(mode: .other, expanded: nil, focused: false) })
                    })
                }
            }),
            KeyShortcut(title: strings.KeyCommand_SearchInChat, input: "F", modifiers: [.command], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.beginMessageSearch("")
                }
            })
        ]
        
        return inputShortcuts + otherShortcuts
    }
    
    public override func joinGroupCall(peerId: PeerId, invite: String?, activeCall: EngineGroupCallDescription) {
        let proceed = {
            super.joinGroupCall(peerId: peerId, invite: invite, activeCall: activeCall)
        }
        
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            proceed()
        })
    }
    
    public func getTransitionInfo(messageId: MessageId, media: Media) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))? {
        var selectedNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    selectedNode = result
                }
            }
        }
        if let (node, _, get) = selectedNode {
            return ({ [weak self] view in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.chatDisplayNode.historyNode.view)
            }, node, get)
        } else {
            return nil
        }
    }
    
    func activateInput() {
        if self.didAppear {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                return state.updatedInputMode({ _ in .text })
            })
        } else {
            self.scheduledActivateInput = true
        }
    }
    
    private func clearInputText() {
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
            if !state.interfaceState.effectiveInputState.inputText.string.isEmpty {
                return state.updatedInterfaceState { interfaceState in
                    let effectiveInputState = ChatTextInputState(inputText: NSAttributedString(string: ""))
                    return interfaceState.withUpdatedEffectiveInputState(effectiveInputState)
                }
            } else {
                return state
            }
        })
    }
    
    private func updateReminderActivity() {
        if self.isReminderActivityEnabled && false {
            if #available(iOS 9.0, *) {
                if self.reminderActivity == nil, case let .peer(peerId) = self.chatLocation, let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer {
                    let reminderActivity = NSUserActivity(activityType: "RemindAboutChatIntent")
                    self.reminderActivity = reminderActivity
                    if peer is TelegramGroup {
                        reminderActivity.title = self.presentationData.strings.Activity_RemindAboutGroup(EnginePeer(peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).string
                    } else if let channel = peer as? TelegramChannel {
                        if case .broadcast = channel.info {
                            reminderActivity.title = self.presentationData.strings.Activity_RemindAboutChannel(EnginePeer(peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).string
                        } else {
                            reminderActivity.title = self.presentationData.strings.Activity_RemindAboutGroup(EnginePeer(peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).string
                        }
                    } else {
                        reminderActivity.title = self.presentationData.strings.Activity_RemindAboutUser(EnginePeer(peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).string
                    }
                    reminderActivity.userInfo = ["peerId": peerId.toInt64(), "peerTitle": EnginePeer(peer).displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)]
                    reminderActivity.isEligibleForHandoff = true
                    reminderActivity.becomeCurrent()
                }
            }
        } else if let reminderActivity = self.reminderActivity {
            self.reminderActivity = nil
            reminderActivity.invalidate()
        }
    }
    
    private func updateSlowmodeStatus() {
        if let slowmodeState = self.presentationInterfaceState.slowmodeState, case let .timestamp(slowmodeActiveUntilTimestamp) = slowmodeState.variant {
            let timestamp = Int32(Date().timeIntervalSince1970)
            let remainingTime = max(0, slowmodeActiveUntilTimestamp - timestamp)
            if remainingTime == 0 {
                self.updateSlowmodeStatusTimerValue = nil
                self.updateSlowmodeStatusDisposable.set(nil)
                self.updateChatPresentationInterfaceState(interactive: false, {
                    $0.updatedSlowmodeState(nil)
                })
            } else {
                if self.updateSlowmodeStatusTimerValue != slowmodeActiveUntilTimestamp {
                    self.updateSlowmodeStatusTimerValue = slowmodeActiveUntilTimestamp
                    self.updateSlowmodeStatusDisposable.set((Signal<Never, NoError>.complete()
                    |> suspendAwareDelay(Double(remainingTime), granularity: 1.0, queue: .mainQueue())
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateSlowmodeStatusTimerValue = nil
                        strongSelf.updateSlowmodeStatus()
                    }))
                }
            }
        } else if let _ = self.updateSlowmodeStatusTimerValue {
            self.updateSlowmodeStatusTimerValue = nil
            self.updateSlowmodeStatusDisposable.set(nil)
        }
    }
    
    private func openScheduledMessages() {
        guard let navigationController = self.effectiveNavigationController, navigationController.topViewController == self else {
            return
        }
        let controller = ChatControllerImpl(context: self.context, chatLocation: self.chatLocation, subject: .scheduledMessages)
        controller.navigationPresentation = .modal
        navigationController.pushViewController(controller)
    }
    
    private func openPinnedMessages(at messageId: MessageId?) {
        guard let navigationController = self.effectiveNavigationController, navigationController.topViewController == self else {
            return
        }
        let controller = ChatControllerImpl(context: self.context, chatLocation: self.chatLocation, subject: .pinnedMessages(id: messageId))
        controller.navigationPresentation = .modal
        controller.updatedClosedPinnedMessageId = { [weak self] pinnedMessageId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.performUpdatedClosedPinnedMessageId(pinnedMessageId: pinnedMessageId)
        }
        controller.requestedUnpinAllMessages = { [weak self] count, pinnedMessageId in
            guard let strongSelf = self else {
                return
            }
            strongSelf.performRequestedUnpinAllMessages(count: count, pinnedMessageId: pinnedMessageId)
        }
        navigationController.pushViewController(controller)
    }
    
    private func performUpdatedClosedPinnedMessageId(pinnedMessageId: MessageId) {
        let previousClosedPinnedMessageId = self.presentationInterfaceState.interfaceState.messageActionsState.closedPinnedMessageId
        
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
            return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                var value = value
                value.closedPinnedMessageId = pinnedMessageId
                return value
            }) })
        })
        
        self.present(
            UndoOverlayController(
                presentationData: self.presentationData,
                content: .messagesUnpinned(
                    title: self.presentationData.strings.Chat_PinnedMessagesHiddenTitle,
                    text: self.presentationData.strings.Chat_PinnedMessagesHiddenText,
                    undo: true,
                    isHidden: true
                ),
                elevatedLayout: false,
                action: { [weak self] action in
                    guard let strongSelf = self else {
                        return true
                    }
                    
                    switch action {
                    case .commit:
                        break
                    case .undo:
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                var value = value
                                value.closedPinnedMessageId = previousClosedPinnedMessageId
                                return value
                            }) })
                        })
                    default:
                        break
                    }
                    return true
                }
            ),
            in: .current
        )
    }
    
    private func performRequestedUnpinAllMessages(count: Int, pinnedMessageId: MessageId) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        self.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = true
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
            return $0.updatedPendingUnpinnedAllMessages(true)
        })
        
        self.present(
            UndoOverlayController(
                presentationData: self.presentationData,
                content: .messagesUnpinned(
                    title: self.presentationData.strings.Chat_MessagesUnpinned(Int32(count)),
                    text: "",
                    undo: true,
                    isHidden: false
                ),
                elevatedLayout: false,
                action: { [weak self] action in
                    guard let strongSelf = self else {
                        return true
                    }
                    
                    switch action {
                    case .commit:
                        let _ = (strongSelf.context.engine.messages.requestUnpinAllMessages(peerId: peerId)
                        |> deliverOnMainQueue).start(error: { _ in
                        }, completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedPendingUnpinnedAllMessages(false)
                            })
                        })
                    case .undo:
                        strongSelf.chatDisplayNode.historyNode.pendingUnpinnedAllMessages = false
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                            return $0.updatedPendingUnpinnedAllMessages(false)
                        })
                    default:
                        break
                    }
                    return true
                }
            ),
            in: .current
        )
    }
    
    private func presentScheduleTimePicker(style: ChatScheduleTimeControllerStyle = .default, selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        let _ = (self.context.account.viewTracker.peerView(peerId)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] peerView in
            guard let strongSelf = self, let peer = peerViewMainPeer(peerView) else {
                return
            }
            var sendWhenOnlineAvailable = false
            if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case .present = presence.status {
                sendWhenOnlineAvailable = true
            }
            
            let mode: ChatScheduleTimeControllerMode
            if peerId == strongSelf.context.account.peerId {
                mode = .reminders
            } else {
                mode = .scheduledMessages(sendWhenOnlineAvailable: sendWhenOnlineAvailable)
            }
            let controller = ChatScheduleTimeController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peerId: peerId, mode: mode, style: style, currentTime: selectedTime, minimalTime: strongSelf.presentationInterfaceState.slowmodeState?.timeout, dismissByTapOutside: dismissByTapOutside, completion: { time in
                completion(time)
            })
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(controller, in: .window(.root))
        })
    }
    
    private func presentTimerPicker(style: ChatTimerScreenStyle = .default, selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: peerId, style: style, currentTime: selectedTime, dismissByTapOutside: dismissByTapOutside, completion: { time in
            completion(time)
        })
        self.chatDisplayNode.dismissInput()
        self.present(controller, in: .window(.root))
    }
    
    private func presentVoiceMessageDiscardAlert(action: @escaping () -> Void = {}, alertAction: (() -> Void)? = nil, delay: Bool = false, performAction: Bool = true) -> Bool {
        if let _ = self.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
            alertAction?()
            Queue.mainQueue().after(delay ? 0.2 : 0.0) {
                self.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: self.presentationData.strings.Conversation_DiscardVoiceMessageDescription, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Conversation_DiscardVoiceMessageAction, action: { [weak self] in
                    self?.stopMediaRecorder()
                    action()
                })]), in: .window(.root))
            }
            
            return true
        } else if performAction {
            action()
        }
        return false
    }
    
    private func presentAutoremoveSetup() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: peer.id, style: .default, mode: .autoremove, currentTime: self.presentationInterfaceState.autoremoveTimeout, dismissByTapOutside: true, completion: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peer.id, timeout: value == 0 ? nil : value)
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
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
            })
        })
        self.chatDisplayNode.dismissInput()
        self.present(controller, in: .window(.root))
    }
    
    private func presentChatRequestAdminInfo() {
        if let requestChatTitle = self.presentationInterfaceState.contactStatus?.peerStatusSettings?.requestChatTitle, let requestDate = self.presentationInterfaceState.contactStatus?.peerStatusSettings?.requestChatDate {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            let controller = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            
            let text = presentationData.strings.Conversation_InviteRequestInfo(requestChatTitle, stringForDate(timestamp: requestDate, strings: presentationData.strings))
            
            items.append(ActionSheetTextItem(title: text.string))
            items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_InviteRequestInfoConfirm, color: .accent, action: { [weak self, weak controller] in
                controller?.dismissAnimated()
                self?.interfaceInteraction?.dismissReportPeer()
            }))
            controller.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak controller] in
                    controller?.dismissAnimated()
                })
            ])])
            self.chatDisplayNode.dismissInput()
            self.present(controller, in: .window(.root))
        }
    }
    
    private var crossfading = false
    private func presentCrossfadeSnapshot() {
        guard !self.crossfading, let snapshotView = self.view.snapshotView(afterScreenUpdates: false) else {
            return
        }
        self.crossfading = true
        self.view.addSubview(snapshotView)

        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: ChatThemeScreen.themeCrossfadeDuration, delay: ChatThemeScreen.themeCrossfadeDelay, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak self, weak snapshotView] _ in
            self?.crossfading = false
            snapshotView?.removeFromSuperview()
        })
    }
    
    public func presentThemeSelection() {
        let context = self.context
        let peerId = self.chatLocation.peerId
        
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
            var updated = state
            updated = updated.updatedInputMode({ _ in
                return .none
            })
            updated = updated.updatedShowCommands(false)
            return updated
        })
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let _ = (combineLatest(queue: Queue.mainQueue(), self.themeEmoticonPromise.get(), animatedEmojiStickers)
        |> take(1)).start(next: { [weak self] themeEmoticon, animatedEmojiStickers in
            guard let strongSelf = self else {
                return
            }
                
            let selectedEmoticon: String? = themeEmoticon
            
            let controller = ChatThemeScreen(context: context, updatedPresentationData: strongSelf.updatedPresentationData, animatedEmojiStickers: animatedEmojiStickers, initiallySelectedEmoticon: selectedEmoticon, peerName: strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer.flatMap(EnginePeer.init)?.compactDisplayTitle ?? "", previewTheme: { [weak self] emoticon, dark in
                if let strongSelf = self {
                    strongSelf.presentCrossfadeSnapshot()
                    strongSelf.themeEmoticonAndDarkAppearancePreviewPromise.set(.single((emoticon, dark)))
                }
            }, completion: { [weak self] emoticon in
                guard let strongSelf = self, let peerId = peerId else {
                    return
                }
                strongSelf.themeEmoticonAndDarkAppearancePreviewPromise.set(.single((emoticon ?? "", nil)))
                let _ = context.engine.themes.setChatTheme(peerId: peerId, emoticon: emoticon).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.themeEmoticonAndDarkAppearancePreviewPromise.set(.single((nil, nil)))
                    }
                })
            })
            controller.passthroughHitTestImpl = { [weak self] _ in
                if let strongSelf = self {
                    return strongSelf.chatDisplayNode.historyNode.view
                } else {
                    return nil
                }
            }
            controller.dismissed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatDisplayNode.historyNode.tapped = nil
                }
            }
            strongSelf.chatDisplayNode.historyNode.tapped = { [weak controller] in
                controller?.dimTapped()
            }
            strongSelf.present(controller, in: .window(.root))
            strongSelf.themeSceen = controller
        })
    }
    
    private var effectiveNavigationController: NavigationController? {
        if let navigationController = self.navigationController as? NavigationController {
            return navigationController
        } else if case let .inline(navigationController) = self.presentationInterfaceState.mode {
            return navigationController
        } else if case let .overlay(navigationController) = self.presentationInterfaceState.mode {
            return navigationController
        } else {
            return nil
        }
    }
    
    func activateSearch(domain: ChatSearchDomain = .everything, query: String = "") {
        self.focusOnSearchAfterAppearance = (domain, query)
        self.interfaceInteraction?.beginMessageSearch(domain, query)
    }
    
    override public func updatePossibleControllerDropContent(content: NavigationControllerDropContent?) {
        //self.chatDisplayNode.updateEmbeddedTitlePeekContent(content: content)
    }
    
    override public func acceptPossibleControllerDropContent(content: NavigationControllerDropContent) -> Bool {
        //return self.chatDisplayNode.acceptEmbeddedTitlePeekContent(content: content)
        return false
    }
    
    public var isSendButtonVisible: Bool {
        if self.presentationInterfaceState.interfaceState.editMessage != nil || self.presentationInterfaceState.interfaceState.forwardMessageIds != nil || self.presentationInterfaceState.interfaceState.composeInputState.inputText.string.count > 0 {
            return true
        } else {
            return false
        }
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    let sourceRect: CGRect?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, sourceRect: CGRect? = nil, passthroughTouches: Bool) {
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
                return (sourceNode, sourceRect ?? sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

final class ChatControllerContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    private let insets: UIEdgeInsets
    private let contentInsets: UIEdgeInsets
    
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


extension Peer {
    func canSetupAutoremoveTimeout(accountPeerId: PeerId) -> Bool {
        if let _ = self as? TelegramSecretChat {
            return false
        } else if let group = self as? TelegramGroup {
            if case .creator = group.role {
                return true
            } else if case let .admin(rights, _) = group.role {
                if rights.rights.contains(.canDeleteMessages) {
                    return true
                }
            }
        } else if let user = self as? TelegramUser {
            if user.id != accountPeerId && user.botInfo == nil {
                return true
            }
        } else if let channel = self as? TelegramChannel {
            if channel.hasPermission(.deleteAllMessages) {
                return true
            }
        }
        
        return false
    }
}

func canAddMessageReactions(message: Message) -> Bool {
    if message.id.namespace != Namespaces.Message.Cloud {
        return false
    }
    if let peer = message.peers[message.id.peerId] {
        if let _ = peer as? TelegramSecretChat {
            return false
        }
    } else {
        return false
    }
    for media in message.media {
        if let _ = media as? TelegramMediaAction {
            return false
        }
    }
    return true
}

enum AllowedReactions {
    case set(Set<String>)
    case all
}

func peerAllowedReactions(context: AccountContext, peerId: PeerId) -> Signal<AllowedReactions?, NoError> {
    return context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
        TelegramEngine.EngineData.Item.Peer.AllowedReactions(id: peerId)
    )
    |> map { peer, allowedReactions -> AllowedReactions? in
        if let allowedReactions = allowedReactions {
            return .set(Set(allowedReactions))
        } else if case .user = peer {
            return .all
        } else {
            return nil
        }
    }
}

final class ChatControllerNavigationData: CustomViewControllerNavigationData {
    let peerId: PeerId
    
    init(peerId: PeerId) {
        self.peerId = peerId
    }
    
    func combine(summary: CustomViewControllerNavigationDataSummary?) -> CustomViewControllerNavigationDataSummary? {
        if let summary = summary as? ChatControllerNavigationDataSummary {
            return summary.adding(peerId: self.peerId)
        } else {
            return ChatControllerNavigationDataSummary(peerIds: [self.peerId])
        }
    }
}

final class ChatControllerNavigationDataSummary: CustomViewControllerNavigationDataSummary {
    let peerIds: [PeerId]
    
    init(peerIds: [PeerId]) {
        self.peerIds = peerIds
    }
    
    func adding(peerId: PeerId) -> ChatControllerNavigationDataSummary {
        var peerIds = self.peerIds
        if let index = peerIds.firstIndex(of: peerId) {
            peerIds.removeSubrange(0 ... index)
        }
        peerIds.insert(peerId, at: 0)
        return ChatControllerNavigationDataSummary(peerIds: peerIds)
    }
}
