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
import StickerPackPreviewUI
import TextNodeWithEntities
import EntityKeyboard
import ChatTitleView
import EmojiStatusComponent
import ChatTimerScreen
import MediaPasteboardUI
import ChatListHeaderComponent
import ChatControllerInteraction
import FeaturedStickersScreen
import ChatEntityKeyboardInputNode
import StorageUsageScreen
import AvatarEditorScreen
import ChatScheduleTimeController
import ICloudResources
import StoryContainerScreen
import MoreHeaderButton
import VolumeButtons
import ChatAvatarNavigationNode
import ChatContextQuery
import PeerReportScreen
import PeerSelectionController
import SaveToCameraRoll
import ChatMessageDateAndStatusNode
import ReplyAccessoryPanelNode
import TextSelectionNode
import ChatMessagePollBubbleContentNode
import ChatMessageItem
import ChatMessageItemImpl
import ChatMessageItemView
import ChatMessageItemCommon
import ChatMessageAnimatedStickerItemNode
import ChatMessageBubbleItemNode
import ChatNavigationButton
import WebsiteType
import ChatQrCodeScreen
import PeerInfoScreen
import MediaEditor
import MediaEditorScreen
import WallpaperGalleryScreen
import WallpaperGridScreen
import VideoMessageCameraScreen
import TopMessageReactions
import AudioWaveform
import PeerNameColorScreen
import ChatEmptyNode
import ChatMediaInputStickerGridItem
import AdsInfoScreen
import MessageUI
import PhoneNumberFormat
import OwnershipTransferController
import OldChannelsController
import BrowserUI
import NotificationPeerExceptionController
import AdsReportScreen
import AdUI
import ChatMessagePaymentAlertController
import TelegramCallsUI
import QuickShareScreen
import PostSuggestionsSettingsScreen

public final class ChatControllerOverlayPresentationData {
    public let expandData: (ASDisplayNode?, () -> Void)
    public init(expandData: (ASDisplayNode?, () -> Void)) {
        self.expandData = expandData
    }
}

enum ChatLocationInfoData {
    case peer(Promise<PeerView>)
    case replyThread(Promise<Message?>)
    case customChatContents
}

enum ChatRecordingActivity {
    case voice
    case instantVideo
    case none
}

public enum NavigateToMessageLocation {
    case id(MessageId, NavigateToMessageParams)
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

func isTopmostChatController(_ controller: ChatControllerImpl) -> Bool {
    if let _ = controller.navigationController {
        var hasOther = false
        controller.window?.forEachController({ c in
            if c is ChatControllerImpl {
                if controller !== c {
                    hasOther = true
                } else {
                    hasOther = false
                }
            }
        })
        if hasOther {
            return false
        }
    }
    return true
}

func calculateSlowmodeActiveUntilTimestamp(account: Account, untilTimestamp: Int32?) -> Int32? {
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

struct ScrolledToMessageId: Equatable {
    struct AllowedReplacementDirections: OptionSet {
        var rawValue: Int32
        
        static let up = AllowedReplacementDirections(rawValue: 1 << 0)
        static let down = AllowedReplacementDirections(rawValue: 1 << 1)
    }
    
    var id: MessageId
    var allowedReplacementDirection: AllowedReplacementDirections
}

public final class ChatControllerImpl: TelegramBaseController, ChatController, GalleryHiddenMediaTarget, UIDropInteractionDelegate {    
    var validLayout: ContainerViewLayout?
    
    public weak var parentController: ViewController?
    public weak var customNavigationController: NavigationController?

    let currentChatListFilter: Int32?
    let chatNavigationStack: [ChatNavigationStackItem]
    let customChatNavigationStack: [EnginePeer.Id]?
    
    var didSetupDropToPaste: Bool = false
    
    let context: AccountContext
    public internal(set) var chatLocation: ChatLocation
    public let subject: ChatControllerSubject?
    
    var botStart: ChatControllerInitialBotStart?
    var attachBotStart: ChatControllerInitialAttachBotStart?
    var botAppStart: ChatControllerInitialBotAppStart?
    var mode: ChatControllerPresentationMode
    
    var pendingContentData: (contentData: ChatControllerImpl.ContentData, historyNode: ChatHistoryListNodeImpl)?
    var contentData: ChatControllerImpl.ContentData?
    let contentDataReady = ValuePromise<Bool>(false, ignoreRepeated: true)
    var contentDataDisposable: Disposable?
    var didHandlePerformDismissAction: Bool = false
    var didInitializePersistentPeerInterfaceData: Bool = false
    
    var accountPeerDisposable: Disposable?
    
    let cachedDataReady = Promise<Bool>()
    var didSetCachedDataReady = false
    
    let navigationActionDisposable = MetaDisposable()
    let messageIndexDisposable = MetaDisposable()
    var networkStateDisposable: Disposable?

    let wallpaperReady = Promise<Bool>()
    let presentationReady = Promise<Bool>()
    
    var presentationInterfaceState: ChatPresentationInterfaceState
    let presentationInterfaceStatePromise: ValuePromise<ChatPresentationInterfaceState>
    public var presentationInterfaceStateSignal: Signal<Any, NoError> {
        return self.presentationInterfaceStatePromise.get() |> map { $0 }
    }
    
    public var selectedMessageIds: Set<EngineMessage.Id>? {
        return self.presentationInterfaceState.interfaceState.selectionState?.selectedIds
    }
    
    let chatThemeEmoticonPromise = Promise<String?>()
    let chatWallpaperPromise = Promise<TelegramWallpaper?>()
    
    var chatTitleView: ChatTitleView?
    var leftNavigationButton: ChatNavigationButton?
    var rightNavigationButton: ChatNavigationButton?
    var secondaryRightNavigationButton: ChatNavigationButton?
    var chatInfoNavigationButton: ChatNavigationButton?
    
    var moreBarButton: MoreHeaderButton
    var moreInfoNavigationButton: ChatNavigationButton?
    
    var historyStateDisposable: Disposable?
    
    let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    let temporaryHiddenGalleryMediaDisposable = MetaDisposable()
    
    let galleryPresentationContext = PresentationContext()

    let chatBackgroundNode: WallpaperBackgroundNode
    public private(set) var controllerInteraction: ChatControllerInteraction?
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    let messageContextDisposable = MetaDisposable()
    let controllerNavigationDisposable = MetaDisposable()
    let sentMessageEventsDisposable = MetaDisposable()
    let failedMessageEventsDisposable = MetaDisposable()
    let sentPeerMediaMessageEventsDisposable = MetaDisposable()
    weak var currentFailedMessagesAlertController: ViewController?
    let messageActionCallbackDisposable = MetaDisposable()
    let messageActionUrlAuthDisposable = MetaDisposable()
    let editMessageDisposable = MetaDisposable()
    let editMessageErrorsDisposable = MetaDisposable()
    let enqueueMediaMessageDisposable = MetaDisposable()
    var resolvePeerByNameDisposable: MetaDisposable?
    var shareStatusDisposable: MetaDisposable?
    var clearCacheDisposable: MetaDisposable?
    var bankCardDisposable: MetaDisposable?
    var hasActiveGroupCallDisposable: Disposable?
    var sendAsPeersDisposable: Disposable?
    var preloadAttachBotIconsDisposables: DisposableSet?
    var keepMessageCountersSyncrhonizedDisposable: Disposable?
    var keepSavedMessagesSyncrhonizedDisposable: Disposable?
    var saveMediaDisposable: MetaDisposable?
    var giveawayStatusDisposable: MetaDisposable?
    var nameColorDisposable: Disposable?
    
    let editingMessage = ValuePromise<Float?>(nil, ignoreRepeated: true)
    let startingBot = ValuePromise<Bool>(false, ignoreRepeated: true)
    let unblockingPeer = ValuePromise<Bool>(false, ignoreRepeated: true)
    public let searching = ValuePromise<Bool>(false, ignoreRepeated: true)
    public let searchResultsCount = ValuePromise<Int32>(0, ignoreRepeated: true)
    let searchResult = Promise<(SearchMessagesResult, SearchMessagesState, SearchMessagesLocation)?>()
    let loadingMessage = Promise<ChatLoadingMessageSubject?>(nil)
    let performingInlineSearch = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    var stateServiceTasks: [AnyHashable: Disposable] = [:]
    
    let botCallbackAlertMessage = Promise<String?>(nil)
    var botCallbackAlertMessageDisposable: Disposable?
    
    var selectMessagePollOptionDisposables: DisposableDict<MessageId>?
    var selectPollOptionFeedback: HapticFeedback?
    
    var resolveUrlDisposable: MetaDisposable?
    
    var contextQueryStates: [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)] = [:]
    var searchQuerySuggestionState: (ChatPresentationInputQuery?, Disposable)?
    var urlPreviewQueryState: (UrlPreviewState?, Disposable)?
    var editingUrlPreviewQueryState: (UrlPreviewState?, Disposable)?
    var replyMessageState: (EngineMessage.Id, Disposable)?
    var searchState: ChatSearchState?
    
    var shakeFeedback: HapticFeedback?
    
    var recordingModeFeedback: HapticFeedback?
    var recorderFeedback: HapticFeedback?
    var audioRecorderValue: ManagedAudioRecorder?
    var audioRecorder = Promise<ManagedAudioRecorder?>()
    var audioRecorderDisposable: Disposable?
    var audioRecorderStatusDisposable: Disposable?
    
    var videoRecorderValue: VideoMessageCameraScreen?
    var videoRecorder = Promise<VideoMessageCameraScreen?>()
    var videoRecorderDisposable: Disposable?
    
    var recorderDataDisposable = MetaDisposable()
    
    var chatUnreadCountDisposable: Disposable?
    var buttonUnreadCountDisposable: Disposable?
    var chatUnreadMentionCountDisposable: Disposable?
    var peerInputActivitiesDisposable: Disposable?
    
    var peerInputActivitiesPromise = Promise<[(Peer, PeerInputActivity)]>()
    var interactiveEmojiSyncDisposable = MetaDisposable()
    
    var recentlyUsedInlineBotsValue: [Peer] = []
    var recentlyUsedInlineBotsDisposable: Disposable?
    
    var unpinMessageDisposable: MetaDisposable?
        
    let typingActivityPromise = Promise<Bool>(false)
    var inputActivityDisposable: Disposable?
    var recordingActivityValue: ChatRecordingActivity = .none
    let recordingActivityPromise = ValuePromise<ChatRecordingActivity>(.none, ignoreRepeated: true)
    var recordingActivityDisposable: Disposable?
    var acquiredRecordingActivityDisposable: Disposable?
    let choosingStickerActivityPromise = ValuePromise<Bool>(false)
    var choosingStickerActivityDisposable: Disposable?
    
    var searchDisposable: MetaDisposable?
    
    public let canReadHistory = ValuePromise<Bool>(true, ignoreRepeated: true)
    public let hasBrowserOrAppInFront = Promise<Bool>(false)
    
    var canReadHistoryValue = false {
        didSet {
            self.computedCanReadHistoryPromise.set(self.canReadHistoryValue)
        }
    }
    var canReadHistoryDisposable: Disposable?
    var computedCanReadHistoryPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    var themeEmoticonAndDarkAppearancePreviewPromise = Promise<(String?, Bool?)>((nil, nil))
    var didSetPresentationData = false
    var presentationData: PresentationData
    var presentationDataPromise = Promise<PresentationData>()
    override public var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) {
        return (self.presentationData, self.presentationDataPromise.get())
    }
    var presentationDataDisposable: Disposable?
    var forcedTheme: PresentationTheme?
    var forcedNavigationBarTheme: PresentationTheme?
    var forcedWallpaper: TelegramWallpaper?
    
    var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    var automaticMediaDownloadSettingsDisposable: Disposable?
    
    var disableStickerAnimationsPromise = ValuePromise<Bool>(false)
    var disableStickerAnimationsValue = false
    var disableStickerAnimations: Bool {
        get {
            return self.disableStickerAnimationsValue
        } set {
            self.disableStickerAnimationsPromise.set(newValue)
        }
    }
    var stickerSettings: ChatInterfaceStickerSettings
    var stickerSettingsDisposable: Disposable?
    
    var applicationInForegroundDisposable: Disposable?
    var applicationInFocusDisposable: Disposable?
    
    let checksTooltipDisposable = MetaDisposable()
    var shouldDisplayChecksTooltip = false
    var shouldDisplayProcessingVideoTooltip: EngineMessage.Id?
    
    let peerSuggestionsDisposable = MetaDisposable()
    let peerSuggestionsDismissDisposable = MetaDisposable()
    var displayedConvertToGigagroupSuggestion = false
    
    var checkedPeerChatServiceActions = false
    
    var willAppear = false
    var didAppear = false
    var scheduledActivateInput: ChatControllerActivateInput?
    
    var raiseToListen: RaiseToListenManager?
    var voicePlaylistDidEndTimestamp: Double = 0.0

    weak var emojiTooltipController: TooltipController?
    weak var sendingOptionsTooltipController: TooltipController?
    weak var searchResultsTooltipController: TooltipController?
    weak var messageTooltipController: TooltipController?
    weak var videoUnmuteTooltipController: TooltipController?
    var didDisplayVideoUnmuteTooltip = false
    var didDisplayGroupEmojiTip = false
    var didDisplaySendWhenOnlineTip = false
    let displaySendWhenOnlineTipDisposable = MetaDisposable()
    
    weak var silentPostTooltipController: TooltipController?
    weak var mediaRecordingModeTooltipController: TooltipController?
    weak var mediaRestrictedTooltipController: TooltipController?
    var mediaRestrictedTooltipControllerMode = true
    weak var checksTooltipController: TooltipController?
    weak var copyProtectionTooltipController: TooltipController?
    weak var emojiPackTooltipController: TooltipScreen?
    weak var birthdayTooltipController: TooltipScreen?
    weak var scheduledVideoProcessingTooltipController: TooltipScreen?
    
    weak var slowmodeTooltipController: ChatSlowmodeHintController?
    
    weak var currentContextController: ContextController?
    public var visibleContextController: ViewController? {
        return self.currentContextController
    }
    
    weak var sendMessageActionsController: ChatSendMessageActionSheetController?
    var searchResultsController: ChatSearchResultsController?

    weak var themeScreen: ChatThemeScreen?
    
    weak var currentPinchController: PinchController?
    weak var currentPinchSourceItemNode: ListViewItemNode?
    
    var screenCaptureManager: ScreenCaptureDetectionManager?
    
    var volumeButtonsListener: VolumeButtonsListener?
    
    var beginMediaRecordingRequestId: Int = 0
    var lockMediaRecordingRequestId: Int?
    
    var updateSlowmodeStatusDisposable = MetaDisposable()
    var updateSlowmodeStatusTimerValue: Int32?
    
    var isDismissed = false
    
    var focusOnSearchAfterAppearance: (ChatSearchDomain, String)?
    
    let keepPeerInfoScreenDataHotDisposable = MetaDisposable()
    let preloadAvatarDisposable = MetaDisposable()
    
    let peekData: ChatPeekTimeout?
    let peekTimerDisposable = MetaDisposable()
    
    let createVoiceChatDisposable = MetaDisposable()
    
    let selectAddMemberDisposable = MetaDisposable()
    let addMemberDisposable = MetaDisposable()
    let joinChannelDisposable = MetaDisposable()
    
    var shouldDisplayDownButton = false

    var hasEmbeddedTitleContent = false
    var isEmbeddedTitleContentHidden = false
    
    var chatLocationContextHolder: Atomic<ChatLocationContextHolder?>
    
    weak var attachmentController: AttachmentController?
    
    weak var currentImportMessageTooltip: UndoOverlayController?
    
    public var customNavigationBarContentNode: NavigationBarContentNode?
    public var customNavigationPanelNode: ChatControllerCustomNavigationPanelNode?
    public var stateUpdated: ((ContainedViewLayoutTransition) -> Void)?

    public var customDismissSearch: (() -> Void)?

    public override var customData: Any? {
        return self.chatLocation
    }
    
    override public var customNavigationData: CustomViewControllerNavigationData? {
        get {
            if let peerId = self.chatLocation.peerId {
                return ChatControllerNavigationData(peerId: peerId, threadId: self.chatLocation.threadId)
            } else {
                return nil
            }
        }
    }
    
    override public var interactiveNavivationGestureEdgeWidth: InteractiveTransitionGestureRecognizerEdgeWidth? {
        return .widthMultiplier(factor: 0.35, min: 16.0, max: 200.0)
    }
    
    var scheduledScrollToMessageId: (MessageId, NavigateToMessageParams)?
    
    public var purposefulAction: (() -> Void)?
    public var dismissPreviewing: ((Bool) -> (() -> Void))?
    
    var updatedClosedPinnedMessageId: ((MessageId) -> Void)?
    var requestedUnpinAllMessages: ((Int, MessageId) -> Void)?
    
    public var isSelectingMessagesUpdated: ((Bool) -> Void)?
    
    var translationStateDisposable: Disposable?
    var premiumGiftSuggestionDisposable: Disposable?
    
    var currentSpeechHolder: SpeechSynthesizerHolder?
    
    var powerSavingMonitoringDisposable: Disposable?
    
    var avatarNode: ChatAvatarNavigationNode?
    
    var performTextSelectionAction: ((Message?, Bool, NSAttributedString, TextSelectionAction) -> Void)?
    var performOpenURL: ((Message?, String, Promise<Bool>?) -> Void)?
    
    var networkSpeedEventsDisposable: Disposable?
    
    var stickerVideoExport: MediaEditorVideoExport?
    
    var messageComposeController: MFMessageComposeViewController?
    
    weak var currentSendStarsUndoController: UndoOverlayController?
    var currentSendStarsUndoMessageId: EngineMessage.Id?
    var currentSendStarsUndoCount: Int = 0
    
    weak var currentPaidMessageUndoController: UndoOverlayController?
    
    let initTimestamp: Double
    
    public var alwaysShowSearchResultsAsList: Bool = false {
        didSet {
            self.presentationInterfaceState = self.presentationInterfaceState.updatedDisplayHistoryFilterAsList(self.alwaysShowSearchResultsAsList)
            self.chatDisplayNode.alwaysShowSearchResultsAsList = self.alwaysShowSearchResultsAsList
        }
    }
    
    public var externalSearchResultsCount: Int32? {
        didSet {
            if let panelNode = self.chatDisplayNode.inputPanelNode as? ChatTagSearchInputPanelNode {
                panelNode.externalSearchResultsCount = self.externalSearchResultsCount
            }
        }
    }
    
    public var includeSavedPeersInSearchResults: Bool = false {
        didSet {
            self.chatDisplayNode.includeSavedPeersInSearchResults = self.includeSavedPeersInSearchResults
        }
    }
    
    public var showListEmptyResults: Bool = false {
        didSet {
            self.chatDisplayNode.showListEmptyResults = self.showListEmptyResults
        }
    }
    
    var layoutActionOnViewTransitionAction: (() -> Void)?
    
    var lastPostedScheduledMessagesToastTimestamp: Double = 0.0
    var postedScheduledMessagesEventsDisposable: Disposable?
    
    public init(
        context: AccountContext,
        chatLocation: ChatLocation,
        chatLocationContextHolder: Atomic<ChatLocationContextHolder?> = Atomic<ChatLocationContextHolder?>(value: nil),
        subject: ChatControllerSubject? = nil,
        botStart: ChatControllerInitialBotStart? = nil,
        attachBotStart: ChatControllerInitialAttachBotStart? = nil,
        botAppStart: ChatControllerInitialBotAppStart? = nil,
        mode: ChatControllerPresentationMode = .standard(.default),
        peekData: ChatPeekTimeout? = nil,
        peerNearbyData: ChatPeerNearbyData? = nil,
        chatListFilter: Int32? = nil,
        chatNavigationStack: [ChatNavigationStackItem] = [],
        customChatNavigationStack: [EnginePeer.Id]? = nil,
        params: ChatControllerParams? = nil
    ) {
        self.initTimestamp = CFAbsoluteTimeGetCurrent()
        
        let _ = ChatControllerCount.modify { value in
            return value + 1
        }
        
        self.context = context
        self.chatLocation = chatLocation
        self.chatLocationContextHolder = chatLocationContextHolder
        self.subject = subject
        self.botStart = botStart
        self.attachBotStart = attachBotStart
        self.botAppStart = botAppStart
        self.mode = mode
        self.peekData = peekData
        self.currentChatListFilter = chatListFilter
        self.chatNavigationStack = chatNavigationStack
        self.customChatNavigationStack = customChatNavigationStack
        
        self.forcedTheme = params?.forcedTheme
        self.forcedNavigationBarTheme = params?.forcedNavigationBarTheme
        self.forcedWallpaper = params?.forcedWallpaper

        var useSharedAnimationPhase = false
        switch mode {
        case .standard(.default):
            useSharedAnimationPhase = true
        default:
            break
        }
        self.chatBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: useSharedAnimationPhase)
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
        case .replyThread:
            locationBroadcastPanelSource = .none
            groupCallPanelSource = .none
        case .customChatContents:
            locationBroadcastPanelSource = .none
            groupCallPanelSource = .none
        }
        
        var presentationData = context.sharedContext.currentPresentationData.with { $0 }
        if let forcedTheme = self.forcedTheme {
            presentationData = presentationData.withUpdated(theme: forcedTheme)
        }
        if let forcedWallpaper = self.forcedWallpaper {
            presentationData = presentationData.withUpdated(chatWallpaper: forcedWallpaper)
        }
        self.presentationData = presentationData
        self.automaticMediaDownloadSettings = context.sharedContext.currentAutomaticMediaDownloadSettings
        
        self.stickerSettings = ChatInterfaceStickerSettings()
        
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: context.account.peerId, mode: mode, chatLocation: chatLocation, subject: subject, peerNearbyData: peerNearbyData, greetingData: context.prefetchManager?.preloadedGreetingSticker, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil, threadData: nil, isGeneralThreadClosed: nil, replyMessage: nil, accountPeerColor: nil, businessIntro: nil)
        
        if case let .customChatContents(customChatContents) = subject {
            switch customChatContents.kind {
            case .quickReplyMessageInput:
                break
            case let .businessLinkSetup(link):
                if !link.message.isEmpty {
                    self.presentationInterfaceState = self.presentationInterfaceState.updatedInterfaceState({ interfaceState in
                        return interfaceState.withUpdatedEffectiveInputState(ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(link.message, entities: link.entities)))
                    })
                }
            case .hashTagSearch:
                break
            }
        }
        
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
        case .inline, .standard(.embedded):
            navigationBarPresentationData = nil
        default:
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData, hideBackground: self.context.sharedContext.immediateExperimentalUISettings.playerEmbedding ? true : false, hideBadge: false)
        }
        
        self.moreBarButton = MoreHeaderButton(color: self.presentationData.theme.rootController.navigationBar.buttonColor)
        self.moreBarButton.isUserInteractionEnabled = true
        
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
            
            if let _ = strongSelf.videoRecorderValue {
                return false
            }
            
            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            if strongSelf.presentVoiceMessageDiscardAlert(action: action, performAction: false) {
                return false
            }
                        
            if case let .customChatContents(customChatContents) = strongSelf.presentationInterfaceState.subject {
                switch customChatContents.kind {
                case .hashTagSearch:
                    return true
                case let .quickReplyMessageInput(_, shortcutType):
                    if let historyView = strongSelf.chatDisplayNode.historyNode.originalHistoryView, historyView.entries.isEmpty {
                        let titleString: String
                        let textString: String
                        switch shortcutType {
                        case .generic:
                            titleString = strongSelf.presentationData.strings.QuickReply_ChatRemoveGeneric_Title
                            textString = strongSelf.presentationData.strings.QuickReply_ChatRemoveGeneric_Text
                        case .greeting:
                            titleString = strongSelf.presentationData.strings.QuickReply_ChatRemoveGreetingMessage_Title
                            textString = strongSelf.presentationData.strings.QuickReply_ChatRemoveGreetingMessage_Text
                        case .away:
                            titleString = strongSelf.presentationData.strings.QuickReply_ChatRemoveAwayMessage_Title
                            textString = strongSelf.presentationData.strings.QuickReply_ChatRemoveAwayMessage_Text
                        }
                        
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: titleString, text: textString, actions: [
                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}),
                            TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.QuickReply_ChatRemoveGeneric_DeleteAction, action: { [weak strongSelf] in
                                strongSelf?.dismiss()
                            })
                        ]), in: .window(.root))
                        
                        return false
                    }
                case let .businessLinkSetup(link):
                    var inputText = convertMarkdownToAttributes(strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText)
                    inputText = trimChatInputText(inputText)
                    let entities = generateChatInputTextEntities(inputText, generateLinks: false)
                    
                    let message = inputText.string
                    
                    if message != link.message || entities != link.entities {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.Business_Links_AlertUnsavedText, actions: [
                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}),
                            TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.Business_Links_AlertUnsavedAction, action: { [weak strongSelf] in
                                strongSelf?.dismiss()
                            })
                        ]), in: .window(.root))
                        
                        return false
                    }
                }
            }
            
            return true
        }
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] message, params in
            guard let self, self.isNodeLoaded, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) else {
                return false
            }
            
            if let contextController = self.currentContextController {
                self.present(contextController, in: .window(.root))
                Queue.mainQueue().after(0.15) {
                    contextController.dismiss(result: .dismissWithoutContent, completion: nil)
                }
            }
            
            let mode = params.mode
            
            let displayVoiceMessageDiscardAlert: () -> Bool = { [weak self] in
                guard let self else {
                    return true
                }
                if self.presentVoiceMessageDiscardAlert(action: { [weak self] in
                    Queue.mainQueue().after(0.1, {
                        guard let self else {
                            return
                        }
                        let _ = self.controllerInteraction?.openMessage(message, params)
                    })
                }, performAction: false) {
                    return false
                }
                return true
            }
            
            self.commitPurposefulAction()
            self.dismissAllTooltips()
            
            self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            var openMessageByAction = false
            var isLocation = false
                        
            for media in message.media {
                if media is TelegramMediaMap {
                    if !displayVoiceMessageDiscardAlert() {
                        return false
                    }
                    isLocation = true
                }
                if let file = media as? TelegramMediaFile {
                    if file.isInstantVideo {
                        if self.chatDisplayNode.isInputViewFocused {
                            self.returnInputViewFocus = true
                            self.chatDisplayNode.dismissInput()
                        }
                    }
                    if file.isMusic || file.isVoice || file.isInstantVideo {
                        if !displayVoiceMessageDiscardAlert() {
                            return false
                        }
                        
                        if (file.isVoice || file.isInstantVideo) && message.minAutoremoveOrClearTimeout == viewOnceTimeout {
                            self.openViewOnceMediaMessage(message)
                            return false
                        }
                    } else if file.isVideo {
                        if !displayVoiceMessageDiscardAlert() {
                            return false
                        }
                    }
                }
                if let paidContent = media as? TelegramMediaPaidContent, let extendedMedia = paidContent.extendedMedia.first {
                    switch extendedMedia {
                        case .preview:
                            if displayVoiceMessageDiscardAlert() {
                                self.controllerInteraction?.openCheckoutOrReceipt(message.id, params)
                                return true
                            } else {
                                return false
                            }
                        case .full:
                            break
                    }
                } else if let invoice = media as? TelegramMediaInvoice, let extendedMedia = invoice.extendedMedia {
                    switch extendedMedia {
                        case .preview:
                            if displayVoiceMessageDiscardAlert() {
                                self.controllerInteraction?.openCheckoutOrReceipt(message.id, nil)
                                return true
                            } else {
                                return false
                            }
                        case .full:
                            break
                    }
                } else if media is TelegramMediaGiveaway || media is TelegramMediaGiveawayResults {
                    let progress = params.progress
                    let presentationData = self.presentationData
                    
                    var signal = self.context.engine.payments.premiumGiveawayInfo(peerId: message.id.peerId, messageId: message.id)
                    let disposable: MetaDisposable
                    if let current = self.giveawayStatusDisposable {
                        disposable = current
                    } else {
                        disposable = MetaDisposable()
                        self.giveawayStatusDisposable = disposable
                    }
                    
                    let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                        if let progress {
                            progress.set(.single(true))
                            return ActionDisposable {
                                Queue.mainQueue().async() {
                                    progress.set(.single(false))
                                }
                            }
                        } else {
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                            self?.present(controller, in: .window(.root))
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                    }
                    |> runOn(Queue.mainQueue())
                    |> delay(0.25, queue: Queue.mainQueue())
                    let progressDisposable = progressSignal.startStrict()
                    
                    signal = signal
                    |> afterDisposed {
                        Queue.mainQueue().async {
                            progressDisposable.dispose()
                        }
                    }
                    disposable.set((signal
                    |> deliverOnMainQueue).startStrict(next: { [weak self] info in
                        if let self, let info {
                            self.displayGiveawayStatusInfo(messageId: message.id, giveawayInfo: info)
                        }
                    }))
                    
                    return true
                } else if let action = media as? TelegramMediaAction {
                    if !displayVoiceMessageDiscardAlert() {
                        return false
                    }
                    switch action.action {
                        case .pinnedMessageUpdated, .gameScore, .setSameChatWallpaper, .giveawayResults, .customText:
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    self.navigateToMessage(from: message.id, to: .id(attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: attribute.isQuote ? attribute.quote.flatMap { quote in NavigateToMessageParams.Quote(string: quote.text, offset: quote.offset) } : nil)))
                                    break
                                }
                            }
                        case let .photoUpdated(image):
                            openMessageByAction = image != nil
                        case .groupPhoneCall, .inviteToGroupPhoneCall:
                            if let activeCall = self.presentationInterfaceState.activeGroupCallInfo?.activeCall {
                                self.joinGroupCall(peerId: message.id.peerId, invite: nil, activeCall: EngineGroupCallDescription(id: activeCall.id, accessHash: activeCall.accessHash, title: activeCall.title, scheduleTimestamp: activeCall.scheduleTimestamp, subscribedToScheduled: activeCall.subscribedToScheduled, isStream: activeCall.isStream))
                            } else {
                                var canManageGroupCalls = false
                                if let channel = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel {
                                    if channel.flags.contains(.isCreator) || channel.hasPermission(.manageCalls) {
                                        canManageGroupCalls = true
                                    }
                                } else if let group = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramGroup {
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
                                    if let channel = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case .broadcast = channel.info {
                                        text = self.presentationData.strings.LiveStream_CreateNewVoiceChatText
                                    } else {
                                        text = self.presentationData.strings.VoiceChat_CreateNewVoiceChatText
                                    }
                                    self.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.VoiceChat_CreateNewVoiceChatStartNow, action: { [weak self] in
                                        if let self {
                                            var dismissStatus: (() -> Void)?
                                            let statusController = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: {
                                                dismissStatus?()
                                            }))
                                            dismissStatus = { [weak self, weak statusController] in
                                                self?.createVoiceChatDisposable.set(nil)
                                                statusController?.dismiss()
                                            }
                                            self.present(statusController, in: .window(.root))
                                            self.createVoiceChatDisposable.set((self.context.engine.calls.createGroupCall(peerId: message.id.peerId, title: nil, scheduleDate: nil, isExternalStream: false)
                                            |> deliverOnMainQueue).startStrict(next: { [weak self] info in
                                                guard let self else {
                                                    return
                                                }
                                                self.joinGroupCall(peerId: message.id.peerId, invite: nil, activeCall: EngineGroupCallDescription(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: info.scheduleTimestamp, subscribedToScheduled: info.subscribedToScheduled, isStream: info.isStream))
                                            }, error: { [weak self] error in
                                                dismissStatus?()
                                                
                                                guard let self else {
                                                    return
                                                }
                                            
                                                let text: String
                                                switch error {
                                                case .generic, .scheduledTooLate:
                                                    text = self.presentationData.strings.Login_UnknownError
                                                case .anonymousNotAllowed:
                                                    if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                                                        text = self.presentationData.strings.LiveStream_AnonymousDisabledAlertText
                                                    } else {
                                                        text = self.presentationData.strings.VoiceChat_AnonymousDisabledAlertText
                                                    }
                                                }
                                                self.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                            }, completed: {
                                                dismissStatus?()
                                            }))
                                        }
                                    }), TextAlertAction(type: .genericAction, title: self.presentationData.strings.VoiceChat_CreateNewVoiceChatSchedule, action: { [weak self] in
                                        if let self {
                                            self.context.scheduleGroupCall(peerId: message.id.peerId, parentController: self)
                                        }
                                    }), TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {})], actionLayout: .vertical), in: .window(.root))
                                }
                            }
                            return true
                        case .messageAutoremoveTimeoutUpdated:
                            var canSetupAutoremoveTimeout = false
                            
                            if let _ = self.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat {
                                canSetupAutoremoveTimeout = false
                            } else if let group = self.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                                if !group.hasBannedPermission(.banChangeInfo) {
                                    canSetupAutoremoveTimeout = true
                                }
                            } else if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser {
                                if user.id != self.context.account.peerId && user.botInfo == nil {
                                    canSetupAutoremoveTimeout = true
                                }
                            } else if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
                                if channel.hasPermission(.changeInfo) {
                                    canSetupAutoremoveTimeout = true
                                }
                            }
                            
                            if canSetupAutoremoveTimeout {
                                self.presentAutoremoveSetup()
                            }
                        case let .paymentSent(currency, _, _, _, _):
                            if currency == "XTR" {
                                let _ = (context.engine.payments.requestBotPaymentReceipt(messageId: message.id)
                                |> deliverOnMainQueue).start(next: { [weak self] receipt in
                                    guard let self else {
                                        return
                                    }
                                    self.push(self.context.sharedContext.makeStarsReceiptScreen(context: self.context, receipt: receipt))
                                })
                            } else {
                                self.present(BotReceiptController(context: self.context, messageId: message.id), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            }
                            return true
                        case .setChatTheme:
                            self.presentThemeSelection()
                            return true
                        case let .setChatWallpaper(wallpaper, _):
                            guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
                                return true
                            }
                            if let peer = peer as? TelegramChannel {
                                if peer.flags.contains(.isCreator) || peer.adminRights?.rights.contains(.canChangeInfo) == true {
                                    let _ = (context.engine.peers.getChannelBoostStatus(peerId: peer.id)
                                    |> deliverOnMainQueue).start(next: { [weak self] boostStatus in
                                        guard let self else {
                                            return
                                        }
                                        self.push(ChannelAppearanceScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, peerId: peer.id, boostStatus: boostStatus))
                                    })
                                }
                                return true
                            }
                            guard message.effectivelyIncoming(self.context.account.peerId), let peer = self.presentationInterfaceState.renderedPeer?.peer else {
                                self.presentThemeSelection()
                                return true
                            }
                            self.chatDisplayNode.dismissInput()
                            var options = WallpaperPresentationOptions()
                            var intensity: Int32?
                            if let settings = wallpaper.settings {
                                if settings.blur {
                                    options.insert(.blur)
                                }
                                if settings.motion {
                                    options.insert(.motion)
                                }
                                if case let .file(file) = wallpaper, !file.isPattern {
                                    intensity = settings.intensity
                                }
                            }
                            let wallpaperPreviewController = WallpaperGalleryController(context: self.context, source: .wallpaper(wallpaper, options, [], intensity, nil, nil), mode: .peer(EnginePeer(peer), true))
                            wallpaperPreviewController.apply = { [weak wallpaperPreviewController] entry, options, _, _, brightness, forBoth in
                                var settings: WallpaperSettings?
                                if case let .wallpaper(wallpaper, _) = entry {
                                    let baseSettings = wallpaper.settings
                                    var intensity: Int32? = baseSettings?.intensity
                                    if case let .file(file) = wallpaper, !file.isPattern {
                                        if let brightness {
                                            intensity = max(0, min(100, Int32(brightness * 100.0)))
                                        }
                                    }
                                    settings = WallpaperSettings(blur: options.contains(.blur), motion: options.contains(.motion), colors: baseSettings?.colors ?? [], intensity: intensity, rotation: baseSettings?.rotation)
                                }
                                let _ = (self.context.engine.themes.setExistingChatWallpaper(messageId: message.id, settings: settings, forBoth: forBoth)
                                |> deliverOnMainQueue).startStandalone()
                                Queue.mainQueue().after(0.1) {
                                    wallpaperPreviewController?.dismiss()
                                }
                            }
                            self.push(wallpaperPreviewController)
                            return true
                        case let .giftPremium(_, _, duration, _, _, _, _):
                            self.chatDisplayNode.dismissInput()
                            let fromPeerId: PeerId = message.author?.id == self.context.account.peerId ? self.context.account.peerId : message.id.peerId
                            let toPeerId: PeerId = message.author?.id == self.context.account.peerId ? message.id.peerId : self.context.account.peerId
                            let controller = PremiumIntroScreen(context: self.context, source: .gift(from: fromPeerId, to: toPeerId, duration: duration, giftCode: nil))
                            self.push(controller)
                            return true
                        case .starGift, .starGiftUnique:
                            let controller = self.context.sharedContext.makeGiftViewScreen(context: self.context, message: EngineMessage(message), shareStory: { [weak self] uniqueGift in
                                Queue.mainQueue().after(0.15) {
                                    if let self {
                                        let controller = self.context.sharedContext.makeStorySharingScreen(context: self.context, subject: .gift(uniqueGift), parentController: self)
                                        self.push(controller)
                                    }
                                }
                            })
                            self.push(controller)
                            return true
                        case .giftStars:
                            let controller = self.context.sharedContext.makeStarsGiftScreen(context: self.context, message: EngineMessage(message))
                            self.push(controller)
                            return true
                        case let .giftCode(slug, _, _, _, _, _, _, _, _, _, _):
                            self.openResolved(result: .premiumGiftCode(slug: slug), sourceMessageId: message.id, progress: params.progress)
                            return true
                        case .prizeStars:
                            let controller = self.context.sharedContext.makeStarsGiftScreen(context: self.context, message: EngineMessage(message))
                            self.push(controller)
                            return true
                        case let .suggestedProfilePhoto(image):
                            self.chatDisplayNode.dismissInput()
                            if let image = image {
                                if message.effectivelyIncoming(self.context.account.peerId) {
                                    if let emojiMarkup = image.emojiMarkup {
                                        let controller = AvatarEditorScreen(context: self.context, inputData: AvatarEditorScreen.inputData(context: self.context, isGroup: false), peerType: .user, markup: emojiMarkup)
                                        controller.imageCompletion = { [weak self] image, commit in
                                            if let self {
                                                if let rootController = self.effectiveNavigationController as? TelegramRootController, let settingsController = rootController.accountSettingsController as? PeerInfoScreenImpl {
                                                    settingsController.updateProfilePhoto(image, mode: .accept, uploadStatus: nil)
                                                    commit()
                                                }
                                            }
                                        }
                                        controller.videoCompletion = { [weak self] image, url, values, markup, commit in
                                            if let self {
                                                if let rootController = self.effectiveNavigationController as? TelegramRootController, let settingsController = rootController.accountSettingsController as? PeerInfoScreenImpl {
                                                    settingsController.updateProfileVideo(image, video: nil, values: nil, markup: markup, mode: .accept, uploadStatus: nil)
                                                    commit()
                                                }
                                            }
                                        }
                                        self.push(controller)
                                    } else {
                                        var selectedNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                                        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                            if let itemNode = itemNode as? ChatMessageItemView {
                                                if let result = itemNode.transitionNode(id: message.id, media: image, adjustRect: false) {
                                                    selectedNode = result
                                                }
                                            }
                                        }
                                        let transitionView = selectedNode?.0.view
                                        
                                        let senderName: String?
                                        if let peer = message.peers[message.id.peerId] {
                                            senderName = EnginePeer(peer).compactDisplayTitle
                                        } else {
                                            senderName = nil
                                        }
                                        
                                        legacyAvatarEditor(context: self.context, media: .message(message: MessageReference(message), media: image), transitionView: transitionView, senderName: senderName, present: { [weak self] c, a in
                                            self?.present(c, in: .window(.root), with: a)
                                        }, imageCompletion: { [weak self] image in
                                            if let self {
                                                if let rootController = self.effectiveNavigationController as? TelegramRootController, let settingsController = rootController.accountSettingsController as? PeerInfoScreenImpl {
                                                    settingsController.updateProfilePhoto(image, mode: .accept, uploadStatus: nil)
                                                }
                                            }
                                        }, videoCompletion: { [weak self] image, url, adjustments in
                                            if let self {
                                                if let rootController = self.effectiveNavigationController as? TelegramRootController, let settingsController = rootController.accountSettingsController as? PeerInfoScreenImpl {
                                                    settingsController.oldUpdateProfileVideo(image, asset: AVURLAsset(url: url), adjustments: adjustments, mode: .accept)
                                                }
                                            }
                                        })
                                    }
                                } else {
                                    openMessageByAction = true
                                }
                            }
                        case .boostsApplied:
                            self.controllerInteraction?.openGroupBoostInfo(nil, 0)
                            return true
                        default:
                            break
                    }
                    if !openMessageByAction {
                        return true
                    }
                }
            }
            
            let openChatLocation = self.chatLocation
            var chatFilterTag: MemoryBuffer?
            if case let .customTag(value, _) = self.chatDisplayNode.historyNode.tag {
                chatFilterTag = value
            }
            
            var standalone = false
            if case .customChatContents = self.chatLocation {
                standalone = true
            }
            
            if let adAttribute = message.attributes.first(where: { $0 is AdMessageAttribute }) as? AdMessageAttribute {
                if let file = message.media.first(where: { $0 is TelegramMediaFile}) as? TelegramMediaFile, file.isVideo && !file.isAnimated {
                    self.chatDisplayNode.adMessagesContext?.markAction(opaqueId: adAttribute.opaqueId, media: true, fullscreen: false)
                } else {
                    self.controllerInteraction?.activateAdAction(message.id, nil, true, false)
                    return true
                }
            }
            
            let openChatMessageParams = OpenChatMessageParams(context: context, updatedPresentationData: self.updatedPresentationData, chatLocation: openChatLocation, chatFilterTag: chatFilterTag, chatLocationContextHolder: self.chatLocationContextHolder, message: message, mediaIndex: params.mediaIndex, standalone: standalone, reverseMessageGalleryOrder: false, mode: mode, navigationController: self.effectiveNavigationController, dismissInput: { [weak self] in
                self?.chatDisplayNode.dismissInput()
            }, present: { [weak self] c, a, i in
                guard let self else {
                    return
                }
                
                if case .current = i {
                    c.presentationArguments = a
                    c.statusBar.alphaUpdated = { [weak self] transition in
                        guard let self else {
                            return
                        }
                        self.updateStatusBarPresentation(animated: transition.isAnimated)
                    }
                    self.galleryPresentationContext.present(c, on: PresentationSurfaceLevel(rawValue: 0), blockInteraction: true, completion: {})
                } else {
                    self.present(c, in: .window(.root), with: a, blockInteraction: true)
                }
            }, transitionNode: { [weak self] messageId, media, adjustRect in
                var selectedNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                if let self {
                    self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            if let result = itemNode.transitionNode(id: messageId, media: media, adjustRect: adjustRect) {
                                selectedNode = result
                            }
                        }
                    }
                }
                return selectedNode
            }, addToTransitionSurface: { [weak self] view in
                guard let self else {
                    return
                }
                if let contextController = self.currentContextController {
                    contextController.view.addSubview(view)
                } else {
                    self.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: self.chatDisplayNode.historyNode.view)
                }
            }, openUrl: { [weak self] url in
                self?.openUrl(url, concealed: false, skipConcealedAlert: isLocation, message: nil)
            }, openPeer: { [weak self] peer, navigation in
                self?.openPeer(peer: EnginePeer(peer), navigation: navigation, fromMessage: nil)
            }, callPeer: { [weak self] peerId, isVideo in
                self?.controllerInteraction?.callPeer(peerId, isVideo)
            }, openConferenceCall: { [weak self] message in
                self?.controllerInteraction?.openConferenceCall(message)
            }, enqueueMessage: { [weak self] message in
                self?.sendMessages([message])
            }, sendSticker: canSendMessagesToChat(self.presentationInterfaceState) ? { [weak self] fileReference, sourceNode, sourceRect in
                return self?.controllerInteraction?.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect, nil, []) ?? false
            } : nil, sendEmoji: canSendMessagesToChat(self.presentationInterfaceState) ? { [weak self] text, attribute in
                self?.controllerInteraction?.sendEmoji(text, attribute, false)
            } : nil, setupTemporaryHiddenMedia: { [weak self] signal, centralIndex, galleryMedia in
                if let self {
                    self.temporaryHiddenGalleryMediaDisposable.set((signal |> deliverOnMainQueue).startStrict(next: { [weak self] entry in
                        if let self, let controllerInteraction = self.controllerInteraction {
                            var messageIdAndMedia: [MessageId: [Media]] = [:]
                            
                            if let entry = entry as? InstantPageGalleryEntry, entry.index == centralIndex {
                                messageIdAndMedia[message.id] = [galleryMedia]
                            }
                            
                            controllerInteraction.hiddenMedia = messageIdAndMedia
                            
                            self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMessageItemView {
                                    itemNode.updateHiddenMedia()
                                }
                            }
                        }
                    }))
                }
            }, chatAvatarHiddenMedia: { [weak self] signal, media in
                if let self {
                    self.temporaryHiddenGalleryMediaDisposable.set((signal |> deliverOnMainQueue).startStrict(next: { [weak self] messageId in
                        if let self, let controllerInteraction = self.controllerInteraction {
                            var messageIdAndMedia: [MessageId: [Media]] = [:]
                            
                            if let messageId = messageId {
                                messageIdAndMedia[messageId] = [media]
                            }
                            
                            controllerInteraction.hiddenMedia = messageIdAndMedia
                            
                            self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMessageItemView {
                                    itemNode.updateHiddenMedia()
                                }
                            }
                        }
                    }))
                }
            }, actionInteraction: GalleryControllerActionInteraction(
                openUrl: { [weak self] url, concealed in
                    if let self {
                        self.openUrl(url, concealed: concealed, message: nil)
                    }
                }, openUrlIn: { [weak self] url in
                    if let self {
                        self.openUrlIn(url)
                    }
                }, openPeerMention: { [weak self] mention in
                    if let self {
                        self.controllerInteraction?.openPeerMention(mention, nil)
                    }
                }, openPeer: { [weak self] peer in
                    if let self {
                        self.controllerInteraction?.openPeer(peer, .default, nil, .default)
                    }
                }, openHashtag: { [weak self] peerName, hashtag in
                    if let self {
                        self.controllerInteraction?.openHashtag(peerName, hashtag)
                    }
                }, openBotCommand: { [weak self] command in
                    if let self {
                        self.controllerInteraction?.sendBotCommand(nil, command)
                    }
                }, openAd: { [weak self] messageId in
                    if let self {
                        self.controllerInteraction?.activateAdAction(messageId, nil, true, true)
                    }
                }, addContact: { [weak self] phoneNumber in
                    if let self {
                        self.controllerInteraction?.addContact(phoneNumber)
                    }
                }, storeMediaPlaybackState: { [weak self] messageId, timestamp, playbackRate in
                    guard let self else {
                        return
                    }
                    var storedState: MediaPlaybackStoredState?
                    if let timestamp = timestamp {
                        storedState = MediaPlaybackStoredState(timestamp: timestamp, playbackRate: AudioPlaybackRate(playbackRate))
                    }
                    let _ = updateMediaPlaybackStoredStateInteractively(engine: self.context.engine, messageId: messageId, state: storedState).startStandalone()
                }, editMedia: { [weak self] messageId, snapshots, transitionCompletion in
                    guard let self else {
                        return
                    }
                    
                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] message in
                        guard let self, let message = message else {
                            return
                        }
                        
                        var mediaReference: AnyMediaReference?
                        for media in message.media {
                            if let image = media as? TelegramMediaImage {
                                mediaReference = AnyMediaReference.standalone(media: image)
                            } else if let file = media as? TelegramMediaFile {
                                mediaReference = AnyMediaReference.standalone(media: file)
                            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                                if let image = content.image {
                                    mediaReference = AnyMediaReference.standalone(media: image)
                                } else if let file = content.file {
                                    mediaReference = AnyMediaReference.standalone(media: file)
                                }
                            }
                        }
                        
                        if let mediaReference = mediaReference, let peer = message.peers[message.id.peerId] {
                            legacyMediaEditor(context: self.context, peer: peer, threadTitle: self.contentData?.state.threadInfo?.title, media: mediaReference, mode: .draw, initialCaption: NSAttributedString(), snapshots: snapshots, transitionCompletion: {
                                transitionCompletion()
                            }, getCaptionPanelView: { [weak self] in
                                return self?.getCaptionPanelView(isFile: false)
                            }, sendMessagesWithSignals: { [weak self] signals, _, _, isCaptionAbove in
                                if let self {
                                    var parameters: ChatSendMessageActionSheetController.SendParameters?
                                    if isCaptionAbove {
                                        parameters = ChatSendMessageActionSheetController.SendParameters(effect: nil, textIsAboveMedia: true)
                                    }
                                    self.enqueueMediaMessages(signals: signals, silentPosting: false, parameters: parameters)
                                }
                            }, present: { [weak self] c, a in
                                self?.present(c, in: .window(.root), with: a)
                            })
                        }
                    })
                }, updateCanReadHistory: { [weak self] canReadHistory in
                    self?.canReadHistory.set(canReadHistory)
                }),
                getSourceRect: { [weak self] in
                    guard let self else {
                        return nil
                    }
                    var rect: CGRect?
                    self.chatDisplayNode.historyNode.forEachVisibleMessageItemNode({ itemNode in
                        if itemNode.item?.message.id == message.id {
                            rect = itemNode.view.convert(itemNode.contentFrame(), to: nil)
                        }
                    })
                    return rect
                }
            )
            
            self.controllerInteraction?.isOpeningMediaSignal = openChatMessageParams.blockInteraction.get()
            
            return context.sharedContext.openChatMessage(openChatMessageParams)
        }, openPeer: { [weak self] peer, navigation, fromMessage, source in
            var expandAvatar = false
            if case let .groupParticipant(storyStats, avatarHeaderNode) = source {
                if let storyStats, storyStats.totalCount != 0, let avatarHeaderNode = avatarHeaderNode as? ChatMessageAvatarHeaderNodeImpl {
                    self?.openStories(peerId: peer.id, avatarHeaderNode: avatarHeaderNode, avatarNode: nil)
                    return
                } else {
                    expandAvatar = true
                }
            }
            var fromReactionMessageId: MessageId?
            if case .reaction = source {
                fromReactionMessageId = fromMessage?.id
            }
            self?.openPeer(peer: peer, navigation: navigation, fromMessage: fromMessage, fromReactionMessageId: fromReactionMessageId, expandAvatar: expandAvatar)
        }, openPeerMention: { [weak self] name, progress in
            self?.openPeerMention(name, progress: progress)
        }, openMessageContextMenu: { [weak self] message, selectAll, node, frame, anyRecognizer, location in
            guard let self, self.isNodeLoaded else {
                return
            }
            self.openMessageContextMenu(message: message, selectAll: selectAll, node: node, frame: frame, anyRecognizer: anyRecognizer, location: location)
        }, openMessageReactionContextMenu: { [weak self] message, sourceView, gesture, value in
            guard let self else {
                return
            }
            
            self.openMessageReactionContextMenu(message: message, sourceView: sourceView, gesture: gesture, value: value)
        }, updateMessageReaction: { [weak self] initialMessage, reaction, force, sourceView in
            guard let strongSelf = self else {
                return
            }
            guard !strongSelf.presentAccountFrozenInfoIfNeeded() else {
                return
            }
            guard let messages = strongSelf.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(initialMessage.id) else {
                return
            }
            guard let message = messages.first else {
                return
            }
            if case .default = reaction, strongSelf.chatLocation.peerId == strongSelf.context.account.peerId {
                return
            }
            if case let .customChatContents(customChatContents) = strongSelf.presentationInterfaceState.subject {
                if case let .hashTagSearch(publicPosts) = customChatContents.kind, publicPosts {
                    return
                }
            }
            
            if !force && message.areReactionsTags(accountPeerId: strongSelf.context.account.peerId) {
                if case .pinnedMessages = strongSelf.subject {
                    return
                }
                
                if !strongSelf.presentationInterfaceState.isPremium {
                    strongSelf.presentTagPremiumPaywall()
                    return
                }
                
                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                    guard let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item else {
                        return
                    }
                    guard item.message.id == message.id else {
                        return
                    }
                    
                    let chosenReaction: MessageReaction.Reaction?
                    
                    switch reaction {
                    case .default:
                        switch item.associatedData.defaultReaction {
                        case .none:
                            chosenReaction = nil
                        case let .builtin(value):
                            chosenReaction = .builtin(value)
                        case let .custom(fileId):
                            chosenReaction = .custom(fileId)
                        case .stars:
                            chosenReaction = .stars
                        }
                    case let .reaction(value):
                        switch value {
                        case let .builtin(value):
                            chosenReaction = .builtin(value)
                        case let .custom(fileId):
                            chosenReaction = .custom(fileId)
                        case .stars:
                            chosenReaction = .stars
                        }
                    }
                    
                    guard let chosenReaction = chosenReaction else {
                        return
                    }
                    
                    let tag = ReactionsMessageAttribute.messageTag(reaction: chosenReaction)
                    if strongSelf.presentationInterfaceState.historyFilter?.customTag == tag {
                        if let sourceView {
                            strongSelf.openMessageReactionContextMenu(message: message, sourceView: sourceView, gesture: nil, value: chosenReaction)
                        }
                    } else {
                        strongSelf.chatDisplayNode.historyNode.frozenMessageForScrollingReset = message.id
                        strongSelf.interfaceInteraction?.updateHistoryFilter { _ in
                            return ChatPresentationInterfaceState.HistoryFilter(customTag: tag, isActive: true)
                        }
                    }
                }
                return
            }
            
            let _ = (peerMessageAllowedReactions(context: strongSelf.context, message: message)
            |> deliverOnMainQueue).startStandalone(next: { allowedReactions, _ in
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
                    
                    let chosenReaction: MessageReaction.Reaction?
                    
                    switch reaction {
                    case .default:
                        switch item.associatedData.defaultReaction {
                        case .none:
                            chosenReaction = nil
                        case let .builtin(value):
                            chosenReaction = .builtin(value)
                        case let .custom(fileId):
                            chosenReaction = .custom(fileId)
                        case .stars:
                            chosenReaction = .stars
                        }
                    case let .reaction(value):
                        switch value {
                        case let .builtin(value):
                            chosenReaction = .builtin(value)
                        case let .custom(fileId):
                            chosenReaction = .custom(fileId)
                        case .stars:
                            chosenReaction = .stars
                        }
                    }
                    
                    guard let chosenReaction = chosenReaction else {
                        return
                    }
                    
                    if case .stars = chosenReaction {
                        if strongSelf.selectPollOptionFeedback == nil {
                            strongSelf.selectPollOptionFeedback = HapticFeedback()
                        }
                        strongSelf.selectPollOptionFeedback?.tap()
                        
                        itemNode.awaitingAppliedReaction = (chosenReaction, { [weak itemNode] in
                            guard let strongSelf = self else {
                                return
                            }
                            if let itemNode = itemNode, let item = itemNode.item, let availableReactions = item.associatedData.availableReactions, let targetView = itemNode.targetReactionView(value: chosenReaction) {
                                var reactionItem: ReactionItem?
                                
                                switch chosenReaction {
                                case .builtin, .stars:
                                    for reaction in availableReactions.reactions {
                                        guard let centerAnimation = reaction.centerAnimation else {
                                            continue
                                        }
                                        guard let aroundAnimation = reaction.aroundAnimation else {
                                            continue
                                        }
                                        if reaction.value == chosenReaction {
                                            reactionItem = ReactionItem(
                                                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                                appearAnimation: reaction.appearAnimation,
                                                stillAnimation: reaction.selectAnimation,
                                                listAnimation: centerAnimation,
                                                largeListAnimation: reaction.activateAnimation,
                                                applicationAnimation: aroundAnimation,
                                                largeApplicationAnimation: reaction.effectAnimation,
                                                isCustom: false
                                            )
                                            break
                                        }
                                    }
                                case let .custom(fileId):
                                    if let itemFile = item.message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile {
                                        let itemFile = TelegramMediaFile.Accessor(itemFile)
                                        reactionItem = ReactionItem(
                                            reaction: ReactionItem.Reaction(rawValue: chosenReaction),
                                            appearAnimation: itemFile,
                                            stillAnimation: itemFile,
                                            listAnimation: itemFile,
                                            largeListAnimation: itemFile,
                                            applicationAnimation: nil,
                                            largeApplicationAnimation: nil,
                                            isCustom: true
                                        )
                                    }
                                }
                                
                                if let reactionItem = reactionItem {
                                    let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: strongSelf.chatDisplayNode.historyNode.takeGenericReactionEffect())
                                    
                                    strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                    
                                    strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                    standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                    standaloneReactionAnimation.animateReactionSelection(
                                        context: strongSelf.context,
                                        theme: strongSelf.presentationData.theme,
                                        animationCache: strongSelf.controllerInteraction!.presentationContext.animationCache,
                                        reaction: reactionItem,
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
                                        onHit: { [weak itemNode] in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            if let itemNode = itemNode, let targetView = itemNode.targetReactionView(value: chosenReaction), strongSelf.context.sharedContext.energyUsageSettings.fullTranslucency {
                                                strongSelf.chatDisplayNode.wrappingNode.triggerRipple(at: targetView.convert(targetView.bounds.center, to: strongSelf.chatDisplayNode.view))
                                            }
                                        },
                                        completion: { [weak standaloneReactionAnimation] in
                                            standaloneReactionAnimation?.removeFromSupernode()
                                        }
                                    )
                                }
                            }
                        })
                        
                        guard let starsContext = strongSelf.context.starsContext else {
                            return
                        }
                        guard let peerId = strongSelf.chatLocation.peerId else {
                            return
                        }
                        let _ = (combineLatest(
                            starsContext.state,
                            strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ReactionSettings(id: peerId))
                        )
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak strongSelf] state, reactionSettings in
                            guard let strongSelf, let balance = state?.balance else {
                                return
                            }
                            
                            if case let .known(reactionSettings) = reactionSettings, let starsAllowed = reactionSettings.starsAllowed, !starsAllowed {
                                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer {
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.Chat_ToastStarsReactionsDisabled(peer.debugDisplayTitle).string, actions: [
                                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {})
                                    ]), in: .window(.root))
                                }
                                return
                            }
                            
                            if balance < StarsAmount(value: 1, nanos: 0) {
                                let _ = (strongSelf.context.engine.payments.starsTopUpOptions()
                                |> take(1)
                                |> deliverOnMainQueue).startStandalone(next: { [weak strongSelf] options in
                                    guard let strongSelf, let peerId = strongSelf.chatLocation.peerId else {
                                        return
                                    }
                                    guard let starsContext = strongSelf.context.starsContext else {
                                        return
                                    }
                                    
                                    let purchaseScreen = strongSelf.context.sharedContext.makeStarsPurchaseScreen(context: strongSelf.context, starsContext: starsContext, options: options, purpose: .reactions(peerId: peerId, requiredStars: 1), completion: { result in
                                        let _ = result
                                    })
                                    strongSelf.push(purchaseScreen)
                                })
                                
                                return
                            }
                            
                            let _ = (strongSelf.context.engine.messages.sendStarsReaction(id: message.id, count: 1, privacy: nil)
                            |> deliverOnMainQueue).startStandalone(next: { privacy in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.displayOrUpdateSendStarsUndo(messageId: message.id, count: 1, privacy: privacy)
                            })
                        })
                    } else {
                        var removedReaction: MessageReaction.Reaction?
                        var messageAlreadyHasThisReaction = false
                        
                        let currentReactions = mergedMessageReactions(attributes: message.attributes, isTags: message.areReactionsTags(accountPeerId: context.account.peerId))?.reactions ?? []
                        var updatedReactions: [MessageReaction.Reaction] = currentReactions.filter(\.isSelected).map(\.value)
                        
                        if let index = updatedReactions.firstIndex(where: { $0 == chosenReaction }) {
                            removedReaction = chosenReaction
                            updatedReactions.remove(at: index)
                        } else {
                            updatedReactions.append(chosenReaction)
                            messageAlreadyHasThisReaction = currentReactions.contains(where: { $0.value == chosenReaction })
                        }
                        
                        if removedReaction == nil {
                            if !canAddMessageReactions(message: message) {
                                itemNode.openMessageContextMenu()
                                return
                            }
                            
                            if strongSelf.context.sharedContext.immediateExperimentalUISettings.disableQuickReaction {
                                itemNode.openMessageContextMenu()
                                return
                            }
                            
                            guard let allowedReactions = allowedReactions else {
                                itemNode.openMessageContextMenu()
                                return
                            }
                            
                            switch allowedReactions {
                            case let .set(set):
                                if !messageAlreadyHasThisReaction && updatedReactions.contains(where: { !set.contains($0) }) {
                                    itemNode.openMessageContextMenu()
                                    return
                                }
                            case .all:
                                break
                            }
                        }
                        
                        if removedReaction == nil && !updatedReactions.isEmpty {
                            if strongSelf.selectPollOptionFeedback == nil {
                                strongSelf.selectPollOptionFeedback = HapticFeedback()
                            }
                            strongSelf.selectPollOptionFeedback?.tap()
                            
                            itemNode.awaitingAppliedReaction = (chosenReaction, { [weak itemNode] in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let itemNode = itemNode, let item = itemNode.item, let availableReactions = item.associatedData.availableReactions, let targetView = itemNode.targetReactionView(value: chosenReaction) {
                                    var reactionItem: ReactionItem?
                                    
                                    switch chosenReaction {
                                    case .builtin, .stars:
                                        for reaction in availableReactions.reactions {
                                            guard let centerAnimation = reaction.centerAnimation else {
                                                continue
                                            }
                                            guard let aroundAnimation = reaction.aroundAnimation else {
                                                continue
                                            }
                                            if reaction.value == chosenReaction {
                                                reactionItem = ReactionItem(
                                                    reaction: ReactionItem.Reaction(rawValue: reaction.value),
                                                    appearAnimation: reaction.appearAnimation,
                                                    stillAnimation: reaction.selectAnimation,
                                                    listAnimation: centerAnimation,
                                                    largeListAnimation: reaction.activateAnimation,
                                                    applicationAnimation: aroundAnimation,
                                                    largeApplicationAnimation: reaction.effectAnimation,
                                                    isCustom: false
                                                )
                                                break
                                            }
                                        }
                                    case let .custom(fileId):
                                        if let itemFile = item.message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile {
                                            let itemFile = TelegramMediaFile.Accessor(itemFile)
                                            reactionItem = ReactionItem(
                                                reaction: ReactionItem.Reaction(rawValue: chosenReaction),
                                                appearAnimation: itemFile,
                                                stillAnimation: itemFile,
                                                listAnimation: itemFile,
                                                largeListAnimation: itemFile,
                                                applicationAnimation: nil,
                                                largeApplicationAnimation: nil,
                                                isCustom: true
                                            )
                                        }
                                    }
                                    
                                    if let reactionItem = reactionItem {
                                        let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: strongSelf.chatDisplayNode.historyNode.takeGenericReactionEffect())
                                        
                                        strongSelf.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                        
                                        strongSelf.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                        standaloneReactionAnimation.frame = strongSelf.chatDisplayNode.bounds
                                        standaloneReactionAnimation.animateReactionSelection(
                                            context: strongSelf.context,
                                            theme: strongSelf.presentationData.theme,
                                            animationCache: strongSelf.controllerInteraction!.presentationContext.animationCache,
                                            reaction: reactionItem,
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
                                    }
                                }
                            })
                        } else {
                            strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts(itemNode: itemNode)
                            
                            if let removedReaction = removedReaction, let targetView = itemNode.targetReactionView(value: removedReaction), shouldDisplayInlineDateReactions(message: message, isPremium: strongSelf.presentationInterfaceState.isPremium, forceInline: false) {
                                var hideRemovedReaction: Bool = false
                                if let reactions = mergedMessageReactions(attributes: message.attributes, isTags: message.areReactionsTags(accountPeerId: context.account.peerId)) {
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
                        
                        let mappedUpdatedReactions = updatedReactions.map { reaction -> UpdateMessageReaction in
                            switch reaction {
                            case let .builtin(value):
                                return .builtin(value)
                            case let .custom(fileId):
                                return .custom(fileId: fileId, file: nil)
                            case .stars:
                                return .stars
                            }
                        }
                        
                        if !strongSelf.presentationInterfaceState.isPremium && mappedUpdatedReactions.count > strongSelf.context.userLimits.maxReactionsPerMessage {
                            let _ = (ApplicationSpecificNotice.incrementMultipleReactionsSuggestion(accountManager: strongSelf.context.sharedContext.accountManager)
                                     |> deliverOnMainQueue).startStandalone(next: { [weak self] count in
                                guard let self else {
                                    return
                                }
                                if count < 1 {
                                    let context = self.context
                                    let controller = UndoOverlayController(
                                        presentationData: self.presentationData,
                                        content: .premiumPaywall(title: nil, text: self.presentationData.strings.Chat_Reactions_MultiplePremiumTooltip, customUndoText: nil, timeout: nil, linkAction: nil),
                                        elevatedLayout: false,
                                        action: { [weak self] action in
                                            if case .info = action {
                                                if let self {
                                                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .reactions, forceDark: false, dismissed: nil)
                                                    self.push(controller)
                                                }
                                            }
                                            return true
                                        }
                                    )
                                    self.present(controller, in: .current)
                                }
                            })
                        }
                        
                        let _ = updateMessageReactionsInteractively(account: strongSelf.context.account, messageIds: [message.id], reactions: mappedUpdatedReactions, isLarge: false, storeAsRecentlyUsed: false).startStandalone()
                    }
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

            let isSecret = strongSelf.presentationInterfaceState.copyProtectionEnabled || strongSelf.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
            let pinchController = PinchController(sourceNode: sourceNode, disableScreenshots: isSecret, getContentAreaInScreenSpace: {
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
        }, navigateToMessage: { [weak self] fromId, id, params in
            guard let self else {
                return
            }
            self.navigateToMessage(fromId: fromId, id: id, params: params)
        }, navigateToMessageStandalone: { [weak self] id in
            self?.navigateToMessage(from: nil, to: .id(id, NavigateToMessageParams(timestamp: nil, quote: nil)), forceInCurrentChat: false)
        }, navigateToThreadMessage: { [weak self] peerId, threadId, messageId in
            if let context = self?.context, let navigationController = self?.effectiveNavigationController {
                let _ = context.sharedContext.navigateToForumThread(context: context, peerId: peerId, threadId: threadId, messageId: messageId, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .always, animated: true).startStandalone()
            }
        }, tapMessage: nil, clickThroughMessage: { [weak self] view, location in
            self?.chatDisplayNode.dismissInput(view: view, location: location)
        }, toggleMessagesSelection: { [weak self] ids, value in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            
            if let subject = strongSelf.subject, case .messageOptions = subject, !value {
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
        }, sendCurrentMessage: { [weak self] silentPosting, messageEffect in
            if let self {
                if let _ = self.presentationInterfaceState.interfaceState.mediaDraftState {
                    self.sendMediaRecording(silentPosting: silentPosting, messageEffect: messageEffect)
                } else {
                    self.presentPaidMessageAlertIfNeeded(count: 1, completion: { [weak self] postpone in
                        if let self {
                            self.chatDisplayNode.sendCurrentMessage(silentPosting: silentPosting, postpone: postpone, messageEffect: messageEffect)
                        }
                    })
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
                    strongSelf.chatDisplayNode.collapseInput()
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil) }
                    })
                }
            }, nil)
            var attributes: [MessageAttribute] = []
            let entities = generateTextEntities(text, enabledTypes: .all)
            if !entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: entities))
            }
            
            let peerId = strongSelf.chatLocation.peerId
            if peerId?.namespace != Namespaces.Peer.SecretChat, let interactiveEmojis = strongSelf.chatDisplayNode.interactiveEmojis, interactiveEmojis.emojis.contains(text) {
                strongSelf.sendMessages([.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaDice(emoji: text)), threadId: strongSelf.chatLocation.threadId, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
            } else {
                strongSelf.sendMessages([.message(text: text, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
            }
        }, sendSticker: { [weak self] fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer, bubbleUpEmojiOrStickersets in
            guard let strongSelf = self else {
                return false
            }
            
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceView, sourceRect)
                return false
            }
            
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, peer.hasBannedPermission(.banSendStickers) != nil {
                if !canBypassRestrictions(chatPresentationInterfaceState: strongSelf.presentationInterfaceState) {
                    strongSelf.interfaceInteraction?.openBoostToUnrestrict()
                    return false
                }
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
            if let _ = sourceView.asyncdisplaykit_node as? ChatEmptyNodeStickerContentNode {
                shouldAnimateMessageTransition = true
            }
            
            strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.collapseInput()
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, { current in
                            var current = current
                            current = current.updatedInterfaceState { interfaceState in
                                var interfaceState = interfaceState
                                interfaceState = interfaceState.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil)
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
                    if let sourceNode = sourceView.asyncdisplaykit_node as? ChatMediaInputStickerGridItemNode {
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
                    } else if let sourceNode = sourceView.asyncdisplaykit_node as? HorizontalStickerGridItemNode {
                        strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .stickerMediaInput(input: .mediaPanel(itemNode: sourceNode), replyPanel: replyPanel), initiated: {})
                    } else if let sourceNode = sourceView.asyncdisplaykit_node as? ChatEmptyNodeStickerContentNode {
                        strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .stickerMediaInput(input: .emptyPanel(itemNode: sourceNode), replyPanel: nil), initiated: {})
                    } else if let sourceLayer = sourceLayer {
                        strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .stickerMediaInput(input: .universal(sourceContainerView: sourceView, sourceRect: sourceRect, sourceLayer: sourceLayer), replyPanel: replyPanel), initiated: {
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
                    }
                }
                
                let messages: [EnqueueMessage]  = [.message(text: "", attributes: attributes, inlineStickers: [:], mediaReference: fileReference.abstract, threadId: strongSelf.chatLocation.threadId, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)]
                if silentPosting {
                    let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: silentPosting, postpone: postpone)
                    strongSelf.sendMessages(transformedMessages)
                } else if schedule {
                    strongSelf.presentScheduleTimePicker(completion: { [weak self] scheduleTime in
                        if let strongSelf = self {
                            let transformedMessages = strongSelf.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: scheduleTime, postpone: postpone)
                            strongSelf.sendMessages(transformedMessages)
                        }
                    })
                } else {
                    let transformedMessages = strongSelf.transformEnqueueMessages(messages, postpone: postpone)
                    strongSelf.sendMessages(transformedMessages)
                }
            })
            return true
        }, sendEmoji: { [weak self] text, attribute, immediately in
            if let strongSelf = self {
                if immediately {
                    if let file = attribute.file {
                        var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                                if case let .id(id, _) = packReference {
                                    bubbleUpEmojiOrStickersets.append(ItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: id))
                                }
                            }
                        }
                        
                        strongSelf.sendMessages([.message(text: text, attributes: [TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< (text as NSString).length, type: .CustomEmoji(stickerPack: nil, fileId: file.fileId.id))])], inlineStickers: [file.fileId : file], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)], commit: false)
                    }
                } else {
                    strongSelf.interfaceInteraction?.insertText(NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: attribute]))
                    strongSelf.updateChatPresentationInterfaceState(interactive: true, { state in
                        return state.updatedInputMode({ _ in
                            return .text
                        })
                    })
                    
                    let _ = (ApplicationSpecificNotice.getEmojiTooltip(accountManager: strongSelf.context.sharedContext.accountManager)
                    |> deliverOnMainQueue).startStandalone(next: { count in
                        guard let strongSelf = self else {
                            return
                        }
                        if count < 2 {
                            let _ = ApplicationSpecificNotice.incrementEmojiTooltip(accountManager: strongSelf.context.sharedContext.accountManager).startStandalone()
                            
                            Queue.mainQueue().after(0.5, {
                                strongSelf.displayEmojiTooltip()
                            })
                        }
                    })
                }
            }
        }, sendGif: { [weak self] fileReference, sourceView, sourceRect, silentPosting, schedule in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                    strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceView, sourceRect)
                    return false
                }
                
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, peer.hasBannedPermission(.banSendGifs) != nil {
                    if !canBypassRestrictions(chatPresentationInterfaceState: strongSelf.presentationInterfaceState) {
                        strongSelf.interfaceInteraction?.openBoostToUnrestrict()
                        return false
                    }
                }
                
                strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.collapseInput()
                            
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil) }.updatedInputMode { current in
                                    if case let .media(mode, maybeExpanded, focused) = current, maybeExpanded != nil  {
                                        return .media(mode: mode, expanded: nil, focused: focused)
                                    }
                                    return current
                                }
                            })
                        }
                    }, nil)
                    
                    var messages = [EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: fileReference.abstract, threadId: strongSelf.chatLocation.threadId, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]
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
                })
            }
            return true
        }, sendBotContextResultAsGif: { [weak self] collection, result, sourceView, sourceRect, silentPosting, resetTextInputState in
            guard let strongSelf = self else {
                return false
            }
            if case .pinnedMessages = strongSelf.presentationInterfaceState.subject {
                return false
            }
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceView, sourceRect)
                return false
            }
            
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, peer.hasBannedPermission(.banSendGifs) != nil {
                if !canBypassRestrictions(chatPresentationInterfaceState: strongSelf.presentationInterfaceState) {
                    strongSelf.interfaceInteraction?.openBoostToUnrestrict()
                    return false
                }
            }
            
            strongSelf.enqueueChatContextResult(collection, result, hideVia: true, closeMediaInput: true, silentPosting: silentPosting, resetTextInputState: resetTextInputState)
            
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
            |> deliverOnMainQueue).startStandalone(next: { message in
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
                                    |> deliverOnMainQueue).startStandalone(next: { [weak self] value in
                                        guard let strongSelf = self else {
                                            return
                                        }

                                        if value {
                                            openBot()
                                        } else {
                                            let controller = webAppLaunchConfirmationController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: EnginePeer(botPeer), completion: { [weak self] _ in
                                                if let strongSelf = self {
                                                    let _ = ApplicationSpecificNotice.setBotGameNotice(accountManager: strongSelf.context.sharedContext.accountManager, peerId: botPeer.id).startStandalone()
                                                }
                                                openBot()
                                            }, showMore: nil, openTerms: { [weak self] in
                                                if let self, let navigationController = self.effectiveNavigationController {
                                                    context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.WebApp_LaunchTermsConfirmation_URL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                                                }
                                            })
                                            strongSelf.present(controller, in: .window(.root))
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
                    |> deliverOnMainQueue).startStrict(error: { error in
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
                    |> deliverOnMainQueue).startStrict(next: { result in
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
                })) |> deliverOnMainQueue).startStrict(next: { peer, result in
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
                                            }) |> deliverOnMainQueue).startStrict(next: { [weak self] result in
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
                                strongSelf.openUrl(url, concealed: false, forceExternal: true, skipUrlAuth: true)
                        }
                    }
                }))
            }
        }, activateSwitchInline: { [weak self] peerId, inputString, peerTypes in
            guard let strongSelf = self else {
                return
            }
            guard strongSelf.presentationInterfaceState.subject != .scheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            if let botStart = strongSelf.botStart, case let .automatic(returnToPeerId, scheduled) = botStart.behavior {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: returnToPeerId))
                |> deliverOnMainQueue).startStandalone(next: { peer in
                    if let strongSelf = self, let peer = peer {
                        strongSelf.openPeer(peer: peer, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), subject: scheduled ? .scheduledMessages : nil, peekData: nil), fromMessage: nil)
                    }
                })
            } else {
                if let peerId = peerId {
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        if let strongSelf = self, let peer = peer {
                            strongSelf.openPeer(peer: peer, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), subject: nil, peekData: nil), fromMessage: nil)
                        }
                    })
                } else {
                    strongSelf.openPeer(peer: nil, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), subject: nil, peekData: nil), fromMessage: nil, peerTypes: peerTypes)
                }
            }
        }, openUrl: { [weak self] urlData in
            guard let strongSelf = self else {
                return
            }
            let url = urlData.url
            let concealed = urlData.concealed
            let message = urlData.message
            let progress = urlData.progress
            let forceExternal = urlData.external ?? false
            
            var skipConcealedAlert = false
            if let author = message?.author, author.isVerified {
                skipConcealedAlert = true
            }
            
            if let message, let adAttribute = message.attributes.first(where: { $0 is AdMessageAttribute }) as? AdMessageAttribute {
                strongSelf.chatDisplayNode.adMessagesContext?.markAction(opaqueId: adAttribute.opaqueId, media: false, fullscreen: false)
            }
            
            if let performOpenURL = strongSelf.performOpenURL {
                performOpenURL(message, url, progress)
            } else {
                strongSelf.openUrl(url, concealed: concealed, forceExternal: forceExternal, skipConcealedAlert: skipConcealedAlert, message: message, allowInlineWebpageResolution: urlData.allowInlineWebpageResolution, progress: progress)
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
                        |> deliverOnMainQueue).startStandalone(next: { coordinate in
                            if let strongSelf = self {
                                if let coordinate = coordinate {
                                    strongSelf.sendMessages([.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, heading: nil, accuracyRadius: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil)), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
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
                        |> deliverOnMainQueue).startStandalone(next: { peer in
                            if let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
                                strongSelf.sendMessages([.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)), threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
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
                        case .customChatContents:
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
                        strongSelf.chatDisplayNode.collapseInput()
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreviews([]) }
                        })
                    }
                }, nil)
                var attributes: [MessageAttribute] = []
                let entities = generateTextEntities(command, enabledTypes: .all)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                var replyToMessageId: EngineMessageReplySubject?
                if postAsReply, let messageId {
                    replyToMessageId = EngineMessageReplySubject(messageId: messageId, quote: nil)
                }
                strongSelf.sendMessages([.message(text: command, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyToMessageId, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
            }
        }, openInstantPage: { [weak self] message, associatedData in
            if let strongSelf = self, strongSelf.isNodeLoaded, let navigationController = strongSelf.effectiveNavigationController, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    strongSelf.chatDisplayNode.dismissInput()
                    if let controller = strongSelf.context.sharedContext.makeInstantPageController(context: strongSelf.context, message: message, sourcePeerType: associatedData?.automaticDownloadPeerType) {
                        navigationController.pushViewController(controller)
                    }
                    if case .overlay = strongSelf.presentationInterfaceState.mode {
                        strongSelf.chatDisplayNode.dismissAsOverlay()
                    }
                })
            }
        }, openWallpaper: { [weak self] message in
            if let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.context.sharedContext.openChatWallpaper(context: strongSelf.context, message: message, present: { [weak self] c, a in
                        self?.push(c)
                    })
                })
            }
        }, openTheme: { [weak self] message in
            if let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    strongSelf.chatDisplayNode.dismissInput()
                    openChatTheme(context: strongSelf.context, message: message, pushController: { [weak self] c in
                        self?.effectiveNavigationController?.pushViewController(c)
                    }, present: { [weak self] c, a in
                        self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                    })
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
            guard let self else {
                return
            }
            self.openMessageShareMenu(id: id)
        }, presentController: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }, presentControllerInCurrent: { [weak self] controller, arguments in
            if controller is UndoOverlayController {
                self?.dismissAllTooltips()
            }
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
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        
                        if let cachedUserData = strongSelf.contentData?.state.peerView?.cachedData as? CachedUserData, cachedUserData.callsPrivate {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            
                            strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: presentationData.strings.Call_ConnectionErrorTitle, text: presentationData.strings.Call_PrivacyErrorMessage(EnginePeer(peer).compactDisplayTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            return
                        }
                        
                        context.requestCall(peerId: peer.id, isVideo: isVideo, completion: {})
                    })
                })
            }
        }, openConferenceCall: { [weak self] message in
            guard let self else {
                return
            }
            
            self.joinConferenceCall(message: EngineMessage(message))
        }, longTap: { [weak self] action, params in
            if let self {
                self.openLinkLongTap(action, params: params)
            }
        }, openCheckoutOrReceipt: { [weak self] messageId, params in
            guard let strongSelf = self else {
                return
            }
            strongSelf.commitPurposefulAction()
            
            var isScheduledMessages = false
            if case .scheduledMessages = strongSelf.presentationInterfaceState.subject {
                isScheduledMessages = true
            }
            
            guard !isScheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            
            let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).startStandalone(next: { message in
                guard let strongSelf = self, let message else {
                    return
                }
                
                for media in message.media {
                    if let paidContent = media as? TelegramMediaPaidContent {
                        let progressSignal = Signal<Never, NoError> { _ in
                            params?.progress?.set(.single(true))
                            return ActionDisposable {
                                params?.progress?.set(.single(false))
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.25, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.startStrict()
                        
                        strongSelf.chatDisplayNode.dismissInput()
                        let inputData = Promise<BotCheckoutController.InputData?>()
                        inputData.set(BotCheckoutController.InputData.fetch(context: strongSelf.context, source: .message(message.id))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                            return .single(nil)
                        })
                        if let starsContext = strongSelf.context.starsContext {
                            let starsInputData = combineLatest(
                                inputData.get(),
                                starsContext.state
                            )
                            |> map { data, state -> (StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)? in
                                if let data, let state {
                                    return (state, data.form, data.botPeer, message.forwardInfo?.sourceMessageId == nil ? message.author : nil)
                                } else {
                                    return nil
                                }
                            }
                            let _ = (starsInputData |> filter { $0 != nil } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                                guard let strongSelf = self, let extendedMedia = paidContent.extendedMedia.first, case let .preview(dimensions, immediateThumbnailData, _) = extendedMedia else {
                                    return
                                }
                                var messageId = messageId
                                if let sourceMessageId = message.forwardInfo?.sourceMessageId {
                                    messageId = sourceMessageId
                                }
                                let invoice = TelegramMediaInvoice(title: "", description: "", photo: nil, receiptMessageId: nil, currency: "XTR", totalAmount: paidContent.amount, startParam: "", extendedMedia: .preview(dimensions: dimensions, immediateThumbnailData: immediateThumbnailData, videoDuration: nil), subscriptionPeriod: nil, flags: [], version: 0)
                                let controller = strongSelf.context.sharedContext.makeStarsTransferScreen(context: strongSelf.context, starsContext: starsContext, invoice: invoice, source: .message(messageId), extendedMedia: paidContent.extendedMedia, inputData: starsInputData, completion: { _ in })
                                strongSelf.push(controller)
                                
                                progressDisposable.dispose()
                            })
                        }
                    } else if let invoice = media as? TelegramMediaInvoice {
                        strongSelf.chatDisplayNode.dismissInput()
                        if let receiptMessageId = invoice.receiptMessageId {
                            if invoice.currency == "XTR" {
                                let _ = (strongSelf.context.engine.payments.requestBotPaymentReceipt(messageId: receiptMessageId)
                                |> deliverOnMainQueue).start(next: { [weak self] receipt in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.push(strongSelf.context.sharedContext.makeStarsReceiptScreen(context: strongSelf.context, receipt: receipt))
                                })
                            } else {
                                strongSelf.present(BotReceiptController(context: strongSelf.context, messageId: receiptMessageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            }
                        } else {
                            let inputData = Promise<BotCheckoutController.InputData?>()
                            inputData.set(BotCheckoutController.InputData.fetch(context: strongSelf.context, source: .message(message.id))
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                                return .single(nil)
                            })
                            if invoice.currency == "XTR", let starsContext = strongSelf.context.starsContext {
                                let starsInputData = combineLatest(
                                    inputData.get(),
                                    starsContext.state
                                )
                                |> map { data, state -> (StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)? in
                                    if let data, let state {
                                        return (state, data.form, data.botPeer, nil)
                                    } else {
                                        return nil
                                    }
                                }
                                let _ = (starsInputData |> filter { $0 != nil } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let controller = strongSelf.context.sharedContext.makeStarsTransferScreen(context: strongSelf.context, starsContext: starsContext, invoice: invoice, source: .message(messageId), extendedMedia: [], inputData: starsInputData, completion: { _ in })
                                    strongSelf.push(controller)
                                })
                            } else {
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
                }
            })
        }, openSearch: {
        }, setupReply: { [weak self] messageId in
            self?.interfaceInteraction?.setupReplyMessage(messageId, { _, f in f() })
        }, canSetupReply: { [weak self] message in
            if message.adAttribute != nil {
                return .none
            }
            if !message.flags.contains(.Incoming) {
                if !message.flags.intersection([.Failed, .Sending, .Unsent]).isEmpty {
                    return .none
                }
            }
            if let strongSelf = self {
                if case let .replyThread(replyThreadMessage) = strongSelf.chatLocation, replyThreadMessage.effectiveMessageId == message.id {
                    return .none
                }
                if case let .replyThread(replyThreadMessage) = strongSelf.chatLocation, replyThreadMessage.peerId == strongSelf.context.account.peerId {
                    if replyThreadMessage.threadId != strongSelf.context.account.peerId.toInt64() {
                        return .none
                    }
                }
                if case .peer = strongSelf.chatLocation, let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum {
                    if message.threadId == nil {
                        return .none
                    }
                }
                
                if canReplyInChat(strongSelf.presentationInterfaceState, accountPeerId: strongSelf.context.account.peerId) {
                    return .reply
                } else if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                }
            }
            return .none
        }, canSendMessages: { [weak self] in
            guard let self else {
                return false
            }
            return canSendMessagesToChat(self.presentationInterfaceState)
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
                let peerId = replyThreadMessage.peerId
                strongSelf.navigateToMessage(from: nil, to: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp - Int32(NSTimeZone.local.secondsFromGMT()))), scrollPosition: .bottom(0.0), rememberInStack: false, forceInCurrentChat: true, animated: true, completion: nil)
            case .customChatContents:
                break
            }
        }, requestRedeliveryOfFailedMessages: { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            if id.namespace == Namespaces.Message.ScheduledCloud {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.MessageGroup(id: id))
                |> deliverOnMainQueue).startStandalone(next: { messages in
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
                    
                    let controller = ContextController(presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatController: strongSelf, chatNode: strongSelf.chatDisplayNode, engine: strongSelf.context.engine, message: message._asMessage(), selectAll: true)), items: .single(ContextController.Items(content: .list(actions))), recognizer: nil)
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
                |> deliverOnMainQueue).startStandalone(next: { messages in
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
                        if let self {
                            self.presentPaidMessageAlertIfNeeded(count: Int32(selectedGroup.count), alwaysAsk: true, completion: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                let _ = resendMessages(account: self.context.account, messageIds: selectedGroup.map({ $0.id })).startStandalone()
                            })
                            f(self.presentationInterfaceState.sendPaidMessageStars == nil ? .dismissWithoutContent : .default)
                        }
                    })))
                    if totalGroupCount != 1 {
                        actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_MessageDialogRetryAll(totalGroupCount).string, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
                        }, action: { [weak self] _, f in
                            if let self {
                                self.presentPaidMessageAlertIfNeeded(count: Int32(messages.count), alwaysAsk: true, completion: { [weak self] _ in
                                    guard let self else {
                                        return
                                    }
                                    let _ = resendMessages(account: self.context.account, messageIds: messages.map({ $0.id })).startStandalone()
                                })
                                f(self.presentationInterfaceState.sendPaidMessageStars == nil ? .dismissWithoutContent : .default)
                            }
                        })))
                    }
                    actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { [weak self] controller, f in
                        if let strongSelf = self {
                            let _ = strongSelf.context.engine.messages.deleteMessagesInteractively(messageIds: [id], type: .forLocalPeer).startStandalone()
                        }
                        f(.dismissWithoutContent)
                    })))
                    
                    strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                    
                    let controller = ContextController(presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatController: strongSelf, chatNode: strongSelf.chatDisplayNode, engine: strongSelf.context.engine, message: topMessage, selectAll: true)), items: .single(ContextController.Items(content: .list(actions))), recognizer: nil)
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
                |> deliverOnMainQueue).startStrict(next: { resultPoll in
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
                                        
                                        strongSelf.chatDisplayNode.playConfettiAnimation()
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
                |> deliverOnMainQueue).startStandalone(next: { message in
                    guard let message = message else {
                        return
                    }
                    for media in message.media {
                        if let poll = media as? TelegramMediaPoll, poll.pollId == pollId {
                            strongSelf.push(pollResultsController(context: strongSelf.context, messageId: messageId, message: message, poll: poll))
                            break
                        }
                    }
                })
            }, delay: true)
        }, openAppStorePage: { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.applicationBindings.openAppStorePage()
            }
        }, displayMessageTooltip: { [weak self] messageId, text, isFactCheck, node, nodeRect in
            if let strongSelf = self {
                if let node = node {
                    strongSelf.messageTooltipController?.dismiss()
                    
                    let padding: CGFloat
                    let timeout: Double
                    let balancedTextLayout: Bool
                    let alignment: TooltipController.Alignment
                    let innerPadding: UIEdgeInsets
                    if isFactCheck {
                        timeout = 5.0
                        padding = 20.0
                        balancedTextLayout = true
                        alignment = .natural
                        innerPadding = UIEdgeInsets(top: 0.0, left: 4.0, bottom: 0.0, right: 4.0)
                    } else {
                        timeout = 2.0
                        padding = 8.0
                        balancedTextLayout = false
                        alignment = .center
                        innerPadding = .zero
                    }
                    
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, balancedTextLayout: balancedTextLayout, alignment: alignment, isBlurred: true, timeout: timeout, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true, padding: padding, innerPadding: innerPadding)
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
                                let _ = strongSelf.controllerInteraction?.openMessage(message, OpenMessageParams(mode: .timecode(Double(timestamp))))
                            }
                            found = true
                        }
                    }
                }
                if !found {
                    var messageId = message.id
                    if let forwardInfo = message.forwardInfo, let sourceMessageId = forwardInfo.sourceMessageId, case let .replyThread(threadMessage) = strongSelf.chatLocation, threadMessage.isChannelPost {
                        messageId = sourceMessageId
                    }
                    if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                        let _ = strongSelf.controllerInteraction?.openMessage(message, OpenMessageParams(mode: .timecode(Double(timestamp))))
                    } else {
                        strongSelf.navigateToMessage(messageLocation: .id(messageId, NavigateToMessageParams(timestamp: Double(timestamp), quote: nil)), animated: true, forceInCurrentChat: true)
                    }
                }
            }
        }, scheduleCurrentMessage: { [weak self] params in
            guard let self else {
                return
            }
            guard !self.presentAccountFrozenInfoIfNeeded(delay: true) else {
                return
            }
            self.presentScheduleTimePicker(completion: { [weak self] time in
                if let strongSelf = self {
                    if let _ = strongSelf.presentationInterfaceState.interfaceState.mediaDraftState {
                        strongSelf.sendMediaRecording(scheduleTime: time, messageEffect: (params?.effect).flatMap {
                            return ChatSendMessageEffect(id: $0.id)
                        })
                    } else {
                        let silentPosting = strongSelf.presentationInterfaceState.interfaceState.silentPosting
                        strongSelf.chatDisplayNode.sendCurrentMessage(silentPosting: silentPosting, scheduleTime: time, messageEffect: (params?.effect).flatMap {
                            return ChatSendMessageEffect(id: $0.id)
                        }) { [weak self] in
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, saveInterfaceState: strongSelf.presentationInterfaceState.subject != .scheduledMessages, {
                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedForwardMessageIds(nil).withUpdatedForwardOptionsState(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))) }
                                })
                                
                                if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
                                    strongSelf.openScheduledMessages()
                                }
                            }
                        }
                    }
                }
            })
        }, sendScheduledMessagesNow: { [weak self] messageIds in
            guard let self else {
                return
            }
            guard !self.presentAccountFrozenInfoIfNeeded(delay: true) else {
                return
            }
            
            if let _ = self.presentationInterfaceState.slowmodeState {
                if let rect = self.chatDisplayNode.frameForInputActionButton() {
                    self.interfaceInteraction?.displaySlowmodeTooltip(self.chatDisplayNode.view, rect)
                }
                return
            } else {
                let _ = self.context.engine.messages.sendScheduledMessageNowInteractively(messageId: messageIds.first!).startStandalone()
            }
        }, editScheduledMessagesTime: { [weak self] messageIds in
            if let strongSelf = self, let messageId = messageIds.first {
                let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] message in
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
                                
                                let inlineStickers: [MediaId: TelegramMediaFile] = [:]
                                strongSelf.editMessageDisposable.set((strongSelf.context.engine.messages.requestEditMessage(messageId: messageId, text: message.text, media: .keep, entities: entities, inlineStickers: inlineStickers, webpagePreviewAttribute: nil, disableUrlPreview: false, scheduleTime: time) |> deliverOnMainQueue).startStrict(next: { result in
                                }, error: { error in
                                }))
                            }
                        })
                    })
                }, delay: true)
            }
        }, performTextSelectionAction: { [weak self] message, canCopy, text, action in
            guard let strongSelf = self else {
                return
            }
            
            if let performTextSelectionAction = strongSelf.performTextSelectionAction {
                performTextSelectionAction(message, canCopy, text, action)
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
                if let speechHolder = speakText(context: strongSelf.context, text: text.string) {
                    speechHolder.completion = { [weak self, weak speechHolder] in
                        if let strongSelf = self, strongSelf.currentSpeechHolder == speechHolder {
                            strongSelf.currentSpeechHolder = nil
                        }
                    }
                    strongSelf.currentSpeechHolder = speechHolder
                }
            case .translate:
                strongSelf.chatDisplayNode.dismissInput()
                let f = {
                    let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] sharedData in
                        guard let strongSelf = self else {
                            return
                        }
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
                        
                        let _ = ApplicationSpecificNotice.incrementTranslationSuggestion(accountManager: context.sharedContext.accountManager, timestamp: Int32(Date().timeIntervalSince1970)).startStandalone()
                        
                        let controller = TranslateScreen(context: context, text: text.string, canCopy: canCopy, fromLanguage: language, ignoredLanguages: translationSettings.ignoredLanguages)
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
            case let .quote(range):
                let completion: (ContainedViewLayoutTransition?) -> Void = { transition in
                    guard let self else {
                        return
                    }
                    if let currentContextController = self.currentContextController {
                        self.currentContextController = nil
                        
                        if let transition {
                            currentContextController.dismissWithCustomTransition(transition: transition)
                        } else {
                            currentContextController.dismiss(completion: {})
                        }
                    }
                }
                if let messageId = message?.id, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) ?? message {
                    var quoteData: EngineMessageReplyQuote?
                    
                    let nsRange = NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound)
                    let quoteText = (message.text as NSString).substring(with: nsRange)
                    
                    let trimmedText = trimStringWithEntities(string: quoteText, entities: messageTextEntitiesInRange(entities: message.textEntitiesAttribute?.entities ?? [], range: nsRange, onlyQuoteable: true), maxLength: quoteMaxLength(appConfig: strongSelf.context.currentAppConfiguration.with({ $0 })))
                    if !trimmedText.string.isEmpty {
                        quoteData = EngineMessageReplyQuote(text: trimmedText.string, offset: nsRange.location, entities: trimmedText.entities, media: nil)
                    }
                    
                    let replySubject = ChatInterfaceState.ReplyMessageSubject(
                        messageId: message.id,
                        quote: quoteData
                    )
                    
                    if canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                        let _ = strongSelf.presentVoiceMessageDiscardAlert(action: {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(replySubject) }).updatedSearch(nil).updatedShowCommands(false) }, completion: completion)
                            strongSelf.updateItemNodesSearchTextHighlightStates()
                            strongSelf.chatDisplayNode.ensureInputViewFocused()
                        }, alertAction: {
                            completion(nil)
                        }, delay: true)
                    } else {
                        moveReplyMessageToAnotherChat(selfController: strongSelf, replySubject: replySubject)
                        completion(nil)
                    }
                } else {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil) }) }, completion: completion)
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
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .swipeToReply(title: strongSelf.presentationData.strings.Conversation_SwipeToReplyHintTitle, text: strongSelf.presentationData.strings.Conversation_SwipeToReplyHintText), elevatedLayout: false, position: .top, action: { _ in return false }), in: .current)
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
                |> deliverOnMainQueue).startStandalone(next: { message in
                    guard let message = message else {
                        return
                    }
                    for media in message.media {
                        if let poll = media as? TelegramMediaPoll, poll.pollId.namespace == Namespaces.Media.CloudPoll {
                            strongSelf.push(pollResultsController(context: strongSelf.context, messageId: messageId, message: message, poll: poll, focusOnOptionWithOpaqueIdentifier: optionOpaqueIdentifier))
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
        }, animateDiceSuccess: { [weak self] haptic, confetti in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            if strongSelf.selectPollOptionFeedback == nil {
                strongSelf.selectPollOptionFeedback = HapticFeedback()
            }
            if haptic {
                strongSelf.selectPollOptionFeedback?.success()
            }
            if confetti {
                strongSelf.chatDisplayNode.playConfettiAnimation()
            }
        }, displayPremiumStickerTooltip: { [weak self] file, message in
            self?.displayPremiumStickerTooltip(file: file, message: message)
        }, displayEmojiPackTooltip: { [weak self] file, message in
            self?.displayEmojiPackTooltip(file: file, message: message)
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
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, message in
                guard let strongSelf = self, let peer = peer else {
                    return
                }
                
                var isChannel = false
                if case let .channel(peer) = peer, case .broadcast = peer.info {
                    isChannel = true
                }
                var items: [ContextMenuItem] = [
                    .action(ContextMenuActionItem(text: isChannel ? strongSelf.presentationData.strings.Conversation_ContextMenuOpenChannelProfile : strongSelf.presentationData.strings.Conversation_ContextMenuOpenProfile, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        self?.openPeer(peer: peer, navigation: .info(nil), fromMessage: nil)
                    }))
                ]
                items.append(.action(ContextMenuActionItem(text: isChannel ? strongSelf.presentationData.strings.Conversation_ContextMenuOpenChannel : strongSelf.presentationData.strings.Conversation_ContextMenuSendMessage, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: isChannel ? "Chat/Context Menu/Channels" : "Chat/Context Menu/Message"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    self?.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
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
                                return (chatTextInputAddMentionAttribute(current, peer: peer), inputMode)
                            }
                        }, delay: true)
                    })))
                }
                if !isChannel {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_ContextMenuSearchMessages, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Search"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.activateSearch(domain: .member(peer._asPeer()))
                    })))
                }
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                strongSelf.canReadHistory.set(false)
                
                let source: ContextContentSource
                if let _ = peer.smallProfileImage {
                    let galleryController = AvatarGalleryController(context: context, peer: peer, remoteEntries: nil, replaceRootController: { controller, ready in
                    }, synchronousLoad: true)
                    galleryController.setHintWillBePresentedInPreviewingContext(true)
                    source = .controller(ChatContextControllerContentSourceImpl(controller: galleryController, sourceNode: node, passthroughTouches: false))
                } else {
                    source = .reference(ChatControllerContextReferenceContentSource(controller: strongSelf, sourceView: node.view, insets: .zero))
                }
                
                let contextController = ContextController(presentationData: strongSelf.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                contextController.dismissed = { [weak self] in
                    self?.canReadHistory.set(true)
                }
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
                        strongSelf.navigateToMessage(from: nil, to: .id(attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: nil)))
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
                |> mapToSignal { message -> Signal<EngineMessage.Id?, NoError> in
                    if let message {
                        return .single(message.id)
                    } else {
                        return .complete()
                    }
                }
                |> deliverOnMainQueue).startStandalone(next: { [weak self] messageId in
                    guard let strongSelf = self, let messageId else {
                        return
                    }
                    strongSelf.push(messageStatsController(context: context, subject: .message(id: messageId)))
                })
            }, delay: true)
        }, editMessageMedia: { [weak self] messageId, draw in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.chatDisplayNode.dismissInput()
            
            if draw {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                |> deliverOnMainQueue).startStandalone(next: { [weak self] message in
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
                        let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
                        legacyMediaEditor(context: strongSelf.context, peer: peer, threadTitle: strongSelf.contentData?.state.threadInfo?.title, media: mediaReference, mode: .draw, initialCaption: inputText, snapshots: [], transitionCompletion: nil, getCaptionPanelView: { [weak self] in
                            return self?.getCaptionPanelView(isFile: true)
                        }, sendMessagesWithSignals: { [weak self] signals, _, _, _ in
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
                strongSelf.presentOldMediaPicker(fileMode: false, editingMedia: true, completion: { signals, _, _ in
                    self?.interfaceInteraction?.setupEditMessage(messageId, { _ in })
                    self?.editMessageMediaWithLegacySignals(signals)
                })
            }
        }, copyText: { [weak self] text in
            if let strongSelf = self {
                storeMessageTextInPasteboard(text, entities: nil)
                
                var infoText = presentationData.strings.Conversation_TextCopied
                if let peerId = strongSelf.chatLocation.peerId, peerId.isVerificationCodes && text.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
                    infoText = presentationData.strings.Conversation_CodeCopied
                }
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: infoText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                        return true
                }), in: .current)
            }
        }, displayUndo: { [weak self] content in
            if let strongSelf = self {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                strongSelf.window?.forEachController({ controller in
                    if let controller = controller as? UndoOverlayController {
                        controller.dismiss()
                    }
                })
                strongSelf.forEachController({ controller in
                    if let controller = controller as? UndoOverlayController {
                        controller.dismiss()
                    }
                    return true
                })
                
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
            |> deliverOnMainQueue).startStandalone(next: { [weak self] count, timestamp in
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
                        |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(false))).startStrict(next: { [weak self] responded in
                            if let strongSelf = self {
                                if !responded {
                                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: file, loop: true, title: nil, text: strongSelf.presentationData.strings.Conversation_InteractiveEmojiSyncTip(EnginePeer(peer).compactDisplayTitle).string, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                                    
                                    let _ = ApplicationSpecificNotice.incrementInteractiveEmojiSyncTip(accountManager: strongSelf.context.sharedContext.accountManager, timestamp: currentTimestamp).startStandalone()
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
                    }).startStandalone()
                    
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
        }, openWebView: { [weak self] buttonText, url, simple, source in
            guard let self else {
                return
            }
            self.openWebApp(buttonText: buttonText, url: url, simple: simple, source: source)
        }, activateAdAction: { [weak self] messageId, progress, media, fullscreen in
            guard let self else {
                return
            }
            
            var message: Message?
            if let historyMessage = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                message = historyMessage
            } else if let panelMessage = self.chatDisplayNode.adPanelNode?.message, panelMessage.id == messageId {
                message = panelMessage
            }
                
            guard let message, let adAttribute = message.adAttribute else {
                return
            }
            
            var progress = progress
            if progress == nil {
                self.chatDisplayNode.historyNode.forEachVisibleMessageItemNode { itemView in
                    if itemView.item?.message.id == messageId {
                        progress = itemView.makeProgress()
                    }
                }
            }
            
            self.chatDisplayNode.adMessagesContext?.markAction(opaqueId: adAttribute.opaqueId, media: media, fullscreen: fullscreen)
            self.controllerInteraction?.openUrl(ChatControllerInteraction.OpenUrl(url: adAttribute.url, concealed: false, external: true, progress: progress))
        }, adContextAction: { [weak self] message, sourceNode, gesture in
            guard let self else {
                return
            }
            var isBot = false
            if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
                isBot = true
            }
            let controller = AdsInfoScreen(
                context: context,
                mode: isBot ? .bot : .channel,
                message: message
            )
            controller.removeAd = { [weak self] opaqueId in
                self?.removeAd(opaqueId: opaqueId)
            }
            self.effectiveNavigationController?.pushViewController(controller)
        }, removeAd: { [weak self] opaqueId in
            guard let self else {
                return
            }
            self.removeAd(opaqueId: opaqueId)
        }, openRequestedPeerSelection: { [weak self] messageId, peerType, buttonId, maxQuantity in
            guard let self else {
                return
            }
            let botName = self.presentationInterfaceState.renderedPeer?.peer.flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
            let context = self.context
            let peerId = self.chatLocation.peerId
            
            let presentConfirmation: (String, Bool, @escaping () -> Void) -> Void = { [weak self] peerName, isChannel, completion in
                guard let strongSelf = self else {
                    return
                }
                
                var attributedTitle: NSAttributedString?
                let attributedText: NSAttributedString
                
                let theme = AlertControllerTheme(presentationData: strongSelf.presentationData)
                if case .user = peerType {
                    attributedTitle = nil
                    attributedText = NSAttributedString(string: strongSelf.presentationData.strings.RequestPeer_SelectionConfirmationTitle(peerName, botName).string, font: Font.medium(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
                } else {
                    attributedTitle = NSAttributedString(string: strongSelf.presentationData.strings.RequestPeer_SelectionConfirmationTitle(peerName, botName).string, font: Font.semibold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
                    
                    var botAdminRights: TelegramChatAdminRights?
                    switch peerType {
                    case let .group(group):
                        botAdminRights = group.botAdminRights
                    case let .channel(channel):
                        botAdminRights = channel.botAdminRights
                    default:
                        break
                    }
                    if let botAdminRights {
                        if botAdminRights.rights.isEmpty {
                            let stringWithRanges = strongSelf.presentationData.strings.RequestPeer_SelectionConfirmationInviteAdminText(botName, peerName)
                            let formattedString = NSMutableAttributedString(string: stringWithRanges.string, font: Font.regular(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
                            for range in stringWithRanges.ranges.prefix(2) {
                                formattedString.addAttribute(.font, value: Font.semibold(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), range: range.range)
                            }
                            attributedText = formattedString
                        } else {
                            let stringWithRanges = strongSelf.presentationData.strings.RequestPeer_SelectionConfirmationInviteWithRightsText(botName, peerName, stringForAdminRights(strings: strongSelf.presentationData.strings, adminRights: botAdminRights, isChannel: isChannel))
                            let formattedString = NSMutableAttributedString(string: stringWithRanges.string, font: Font.regular(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
                            for range in stringWithRanges.ranges.prefix(2) {
                                formattedString.addAttribute(.font, value: Font.semibold(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), range: range.range)
                            }
                            attributedText = formattedString
                        }
                    } else {
                        if case let .group(group) = peerType, group.botParticipant {
                            let stringWithRanges = strongSelf.presentationData.strings.RequestPeer_SelectionConfirmationInviteText(botName, peerName)
                            let formattedString = NSMutableAttributedString(string: stringWithRanges.string, font: Font.regular(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: theme.primaryColor, paragraphAlignment: .center)
                            for range in stringWithRanges.ranges.prefix(2) {
                                formattedString.addAttribute(.font, value: Font.semibold(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), range: range.range)
                            }
                            attributedText = formattedString
                        } else {
                            attributedTitle = nil
                            attributedText = NSAttributedString(string: strongSelf.presentationData.strings.RequestPeer_SelectionConfirmationTitle(peerName, botName).string, font: Font.semibold(strongSelf.presentationData.listsFontSize.baseDisplaySize), textColor: theme.primaryColor, paragraphAlignment: .center)
                        }
                    }
                }
                
                let controller = richTextAlertController(context: context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.RequestPeer_SelectionConfirmationSend, action: {
                    completion()
                })])
                strongSelf.present(controller, in: .window(.root))
            }
            
            if case let .user(requestUser) = peerType, maxQuantity > 1, requestUser.isBot == nil && requestUser.isPremium == nil {
                let presentationData = self.presentationData
                var reachedLimitImpl: ((Int32) -> Void)?
                let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .requestedUsersSelection(isBot: requestUser.isBot, isPremium: requestUser.isPremium), isPeerEnabled: { peer in
                    if case let .user(user) = peer, user.botInfo == nil {
                        return true
                    } else {
                        return false
                    }
                }, limit: maxQuantity, reachedLimit: { limit in
                    reachedLimitImpl?(limit)
                }))
                controller.navigationPresentation = .modal
                reachedLimitImpl = { [weak controller] limit in
                    guard let controller else {
                        return
                    }
                    HapticFeedback().error()
                    controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.RequestPeer_ReachedMaximum(limit), timeout: nil, customUndoText: nil), elevatedLayout: true, position: .bottom, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
                
                let _ = (controller.result
                |> deliverOnMainQueue).startStandalone(next: { [weak controller] result in
                    guard let controller else {
                        return
                    }
                    var peerIds: [PeerId] = []
                    if case let .result(peerIdsValue, _) = result {
                        peerIds = peerIdsValue.compactMap({ peerId in
                            if case let .peer(peerId) = peerId {
                                return peerId
                            } else {
                                return nil
                            }
                        })
                    }
                    let _ = context.engine.peers.sendBotRequestedPeer(messageId: messageId, buttonId: buttonId, requestedPeerIds: peerIds).startStandalone()
                    controller.dismiss()
                })
                
                self.push(controller)
            } else {
                var createNewGroupImpl: (() -> Void)?
                let controller = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, filter: [.excludeRecent, .doNotSearchMessages], requestPeerType: [peerType], hasContactSelector: false, createNewGroup: {
                    createNewGroupImpl?()
                }, multipleSelection: maxQuantity > 1, multipleSelectionLimit: maxQuantity > 1 ? maxQuantity : nil, hasCreation: true, immediatelyActivateMultipleSelection: maxQuantity > 1))
                   
                controller.peerSelected = { [weak self, weak controller] peer, _ in
                    guard let strongSelf = self else {
                        return
                    }
                    if case .user = peerType {
                        let _ = context.engine.peers.sendBotRequestedPeer(messageId: messageId, buttonId: buttonId, requestedPeerIds: [peer.id]).startStandalone()
                        controller?.dismiss()
                    } else {
                        var isChannel = false
                        if case let .channel(channel) = peer, case .broadcast = channel.info {
                            isChannel = true
                        }
                        let peerName = peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)
                        presentConfirmation(peerName, isChannel, {
                            let _ = context.engine.peers.sendBotRequestedPeer(messageId: messageId, buttonId: buttonId, requestedPeerIds: [peer.id]).startStandalone()
                            controller?.dismiss()
                        })
                    }
                }
                controller.multiplePeersSelected = { [weak controller] peers, _, _, _, _, _ in
                    let peerIds = peers.map { $0.id }
                    let _ = context.engine.peers.sendBotRequestedPeer(messageId: messageId, buttonId: buttonId, requestedPeerIds: peerIds).startStandalone()
                    controller?.dismiss()
                }
                createNewGroupImpl = { [weak controller] in
                    switch peerType {
                    case .user:
                        break
                    case let .group(group):
                        let createGroupController = createGroupControllerImpl(context: context, peerIds: group.botParticipant || group.botAdminRights != nil ? (peerId.flatMap { [$0] } ?? []) : [], mode: .requestPeer(group), willComplete: { peerName, complete in
                            presentConfirmation(peerName, false, {
                                complete()
                            })
                        }, completion: { peerId, dismiss in
                            let _ = context.engine.peers.sendBotRequestedPeer(messageId: messageId, buttonId: buttonId, requestedPeerIds: [peerId]).startStandalone()
                            dismiss()
                        })
                        createGroupController.navigationPresentation = .modal
                        controller?.replace(with: createGroupController)
                    case let .channel(channel):
                        let createChannelController = createChannelController(context: context, mode: .requestPeer(channel), willComplete: { peerName, complete in
                            presentConfirmation(peerName, true, {
                                complete()
                            })
                        }, completion: { peerId, dismiss in
                            let _ = context.engine.peers.sendBotRequestedPeer(messageId: messageId, buttonId: buttonId, requestedPeerIds: [peerId]).startStandalone()
                            dismiss()
                        })
                        createChannelController.navigationPresentation = .modal
                        controller?.replace(with: createChannelController)
                    }
                }
                self.push(controller)
            }
        }, saveMediaToFiles: { [weak self] messageId in
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).startStandalone(next: { message in
                guard let self, let message else {
                    return
                }
                var file: TelegramMediaFile?
                var title: String?
                var performer: String?
                for media in message.media {
                    if let mediaFile = media as? TelegramMediaFile, mediaFile.isMusic {
                        file = mediaFile
                        for attribute in mediaFile.attributes {
                            if case let .Audio(_, _, titleValue, performerValue, _) = attribute {
                                if let titleValue, !titleValue.isEmpty {
                                    title = titleValue
                                }
                                if let performerValue, !performerValue.isEmpty {
                                    performer = performerValue
                                }
                            }
                        }
                    }
                }
                guard let file else {
                    return
                }
                
                var signal = fetchMediaData(context: context, postbox: context.account.postbox, userLocation: .other, mediaReference: .message(message: MessageReference(message._asMessage()), media: file))
                
                let disposable: MetaDisposable
                if let current = self.saveMediaDisposable {
                    disposable = current
                } else {
                    disposable = MetaDisposable()
                    self.saveMediaDisposable = disposable
                }
                
                var cancelImpl: (() -> Void)?
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                    guard let self else {
                        return EmptyDisposable
                    }
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    self.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.startStrict()
                
                signal = signal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = { [weak disposable] in
                    disposable?.set(nil)
                }
                disposable.set((signal
                |> deliverOnMainQueue).startStrict(next: { [weak self] state, _ in
                    guard let self else {
                        return
                    }
                    switch state {
                    case .progress:
                        break
                    case let .data(data):
                        if data.complete {
                            var symlinkPath = data.path + ".mp3"
                            if fileSize(symlinkPath) != nil {
                                try? FileManager.default.removeItem(atPath: symlinkPath)
                            }
                            let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                            
                            let audioUrl = URL(fileURLWithPath: symlinkPath)
                            let audioAsset = AVURLAsset(url: audioUrl)
                            
                            var fileExtension = "mp3"
                            if let filename = file.fileName {
                                if let dotIndex = filename.lastIndex(of: ".") {
                                    fileExtension = String(filename[filename.index(after: dotIndex)...])
                                }
                            }
                            
                            var nameComponents: [String] = []
                            if let title {
                                if let performer {
                                    nameComponents.append(performer)
                                }
                                nameComponents.append(title)
                            } else {
                                var artist: String?
                                var title: String?
                                for data in audioAsset.commonMetadata {
                                    if data.commonKey == .commonKeyArtist {
                                        artist = data.stringValue
                                    }
                                    if data.commonKey == .commonKeyTitle {
                                        title = data.stringValue
                                    }
                                }
                                if let artist, !artist.isEmpty {
                                    nameComponents.append(artist)
                                }
                                if let title, !title.isEmpty {
                                    nameComponents.append(title)
                                }
                                if nameComponents.isEmpty, var filename = file.fileName {
                                    if let dotIndex = filename.lastIndex(of: ".") {
                                        filename = String(filename[..<dotIndex])
                                    }
                                    nameComponents.append(filename)
                                }
                            }
                            if !nameComponents.isEmpty {
                                try? FileManager.default.removeItem(atPath: symlinkPath)
                                
                                let fileName = "\(nameComponents.joined(separator: " – ")).\(fileExtension)"
                                symlinkPath = symlinkPath.replacingOccurrences(of: audioUrl.lastPathComponent, with: fileName)
                                let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                            }
                            
                            let url = URL(fileURLWithPath: symlinkPath)
                            let controller = legacyICloudFilePicker(theme: self.presentationData.theme, mode: .export, url: url, documentTypes: [], forceDarkTheme: false, dismissed: {}, completion: { _ in
                                
                            })
                            self.present(controller, in: .window(.root))
                        }
                    }
                }))
            })
        }, openNoAdsDemo: { [weak self] in
            guard let self else {
                return
            }
            if self.context.isPremium {
                self.present(UndoOverlayController(presentationData: self.presentationData, content: .actionSucceeded(title: nil, text: self.presentationData.strings.ReportAd_Hidden, cancel: nil, destructive: false), elevatedLayout: false, action: { _ in
                    return true
                }), in: .current)
                
                var adOpaqueId: Data?
                self.chatDisplayNode.historyNode.forEachVisibleMessageItemNode { itemView in
                    if let adAttribute = itemView.item?.message.adAttribute {
                        adOpaqueId = adAttribute.opaqueId
                    }
                }
                if adOpaqueId == nil, let panelMessage = self.chatDisplayNode.adPanelNode?.message, let adAttribute = panelMessage.adAttribute {
                    adOpaqueId = adAttribute.opaqueId
                }
                let _ = self.context.engine.accountData.updateAdMessagesEnabled(enabled: false).start()
                if let adOpaqueId {
                    self.removeAd(opaqueId: adOpaqueId)
                }
            } else {
                let context = self.context
                var replaceImpl: ((ViewController) -> Void)?
                let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .noAds, forceDark: false, action: {
                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .ads, forceDark: false, dismissed: nil)
                    replaceImpl?(controller)
                }, dismissed: nil)
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                self.push(controller)
            }
        }, openAdsInfo: { [weak self] in
            guard let self else {
                return
            }
            self.push(AdsInfoScreen(context: self.context, mode: .channel))
        }, displayGiveawayParticipationStatus: { [weak self] messageId in
            guard let self else {
                return
            }
            let disposable: MetaDisposable
            if let current = self.giveawayStatusDisposable {
                disposable = current
            } else {
                disposable = MetaDisposable()
                self.giveawayStatusDisposable = disposable
            }
            disposable.set((self.context.engine.payments.premiumGiveawayInfo(peerId: messageId.peerId, messageId: messageId)
            |> deliverOnMainQueue).start(next: { [weak self] info in
                guard let self, let info else {
                    return
                }
                let content: UndoOverlayContent
                switch info {
                case let .ongoing(_, status):
                    switch status {
                    case .notAllowed:
                        content = .info(title: nil, text: self.presentationData.strings.Chat_Giveaway_Toast_NotAllowed, timeout: nil, customUndoText: self.presentationData.strings.Chat_Giveaway_Toast_LearnMore)
                    case .participating:
                        content = .succeed(text: self.presentationData.strings.Chat_Giveaway_Toast_Participating, timeout: nil, customUndoText: self.presentationData.strings.Chat_Giveaway_Toast_LearnMore)
                    case .notQualified:
                        content = .info(title: nil, text: self.presentationData.strings.Chat_Giveaway_Toast_NotQualified, timeout: nil, customUndoText: self.presentationData.strings.Chat_Giveaway_Toast_LearnMore)
                    case .almostOver:
                        content = .info(title: nil, text: self.presentationData.strings.Chat_Giveaway_Toast_AlmostOver, timeout: nil, customUndoText: self.presentationData.strings.Chat_Giveaway_Toast_LearnMore)
                    }
                    case .finished:
                        content = .info(title: nil, text: self.presentationData.strings.Chat_Giveaway_Toast_Ended, timeout: nil, customUndoText: self.presentationData.strings.Chat_Giveaway_Toast_LearnMore)
                }
                let controller = UndoOverlayController(presentationData: self.presentationData, content: content, elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { [weak self] action in
                    if case .undo = action, let self {
                        self.displayGiveawayStatusInfo(messageId: messageId, giveawayInfo: info)
                        return true
                    }
                    return false
                })
                self.present(controller, in: .current)
                
            }))
        }, openPremiumStatusInfo: { [weak self] peerId, sourceView, peerStatus, nameColor in
            guard let self else {
                return
            }
            
            let context = self.context
            let source: Signal<PremiumSource, NoError>
            if let peerStatus {
                source = context.engine.stickers.resolveInlineStickers(fileIds: [peerStatus])
                |> mapToSignal { files in
                    if let file = files[peerStatus] {
                        var reference: StickerPackReference?
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute, let packReference = packReference {
                                reference = packReference
                                break
                            }
                        }
                        
                        if let reference {
                            return context.engine.stickers.loadedStickerPack(reference: reference, forceActualized: false)
                            |> filter { result in
                                if case .result = result {
                                    return true
                                } else {
                                    return false
                                }
                            }
                            |> take(1)
                            |> mapToSignal { result -> Signal<PremiumSource, NoError> in
                                if case let .result(_, items, _) = result {
                                    return .single(.emojiStatus(peerId, peerStatus, items.first?.file._parse(), result))
                                } else {
                                    return .single(.emojiStatus(peerId, peerStatus, nil, nil))
                                }
                            }
                        } else {
                            return .single(.emojiStatus(peerId, peerStatus, nil, nil))
                        }
                    } else {
                        return .single(.emojiStatus(peerId, peerStatus, nil, nil))
                    }
                }
            } else {
                source = .single(.profile(peerId))
            }
            
            let _ = (source
            |> deliverOnMainQueue).startStandalone(next: { [weak self] source in
                guard let self else {
                    return
                }
                let controller = PremiumIntroScreen(context: self.context, source: source)
                controller.sourceView = sourceView
                controller.containerView = self.navigationController?.view
                controller.animationColor = self.context.peerNameColors.get(nameColor, dark: self.presentationData.theme.overallDarkAppearance).main
                self.push(controller)
            })
            
        }, openRecommendedChannelContextMenu: { [weak self] peer, sourceView, gesture in
            guard let self else {
                return
            }
            
            let chatController = self.context.sharedContext.makeChatController(context: self.context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(.previewing), params: nil)
            chatController.canReadHistory.set(false)
            
            var items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_LinkDialogOpen, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ImageEnlarge"), color: theme.actionSheet.primaryTextColor) }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                    self?.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                })),
            ]
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_SimilarChannels_Join, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.actionSheet.primaryTextColor) }, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                
                guard let self else {
                    return
                }
                let presentationData = self.presentationData
                self.joinChannelDisposable.set((
                    self.context.peerChannelMemberCategoriesContextsManager.join(engine: self.context.engine, peerId: peer.id, hash: nil)
                    |> deliverOnMainQueue
                    |> afterCompleted { [weak self] in
                        Queue.mainQueue().async {
                            if let self {
                                self.present(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.Chat_SimilarChannels_JoinedChannel(peer.compactDisplayTitle).string, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { _ in return false }), in: .current)
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
                        self.present(UndoOverlayController(presentationData: presentationData, content: .inviteRequestSent(title: presentationData.strings.Group_RequestToJoinSent, text: presentationData.strings.Group_RequestToJoinSentDescriptionGroup), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        return
                    case .tooMuchJoined:
                        self.push(oldChannelsController(context: context, intent: .join))
                        return
                    case .tooMuchUsers:
                        text = self.presentationData.strings.Conversation_UsersTooMuchError
                    case .generic:
                        text = self.presentationData.strings.Channel_ErrorAccessDenied
                    }
                    self.present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }))
            })))
                      
            self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
            
            self.canReadHistory.set(false)
            
            let contextController = ContextController(presentationData: self.presentationData, source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceView: sourceView, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            contextController.dismissed = { [weak self] in
                self?.canReadHistory.set(true)
            }
            self.presentInGlobalOverlay(contextController)
        }, openGroupBoostInfo: { [weak self] userId, count in
            guard let self, let peerId = self.chatLocation.peerId else {
                return
            }
            let _ = combineLatest(queue: Queue.mainQueue(),
                context.engine.peers.getChannelBoostStatus(peerId: peerId),
                context.engine.peers.getMyBoostStatus()
            ).startStandalone(next: { [weak self] boostStatus, myBoostStatus in
                guard let self, let boostStatus, let myBoostStatus else {
                    return
                }
                let boostController = PremiumBoostLevelsScreen(
                    context: self.context,
                    peerId: peerId,
                    mode: userId.flatMap { .user(mode: .groupPeer($0, count)) } ?? .user(mode: .current),
                    status: boostStatus,
                    myBoostStatus: myBoostStatus
                )
                self.push(boostController)
            })
        }, openStickerEditor: { [weak self] in
            guard let self else {
                return
            }
            self.openStickerEditor()
        }, openAgeRestrictedMessageMedia: { [weak self] message, reveal in
            guard let self else {
                return
            }
            let controller = chatAgeRestrictionAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, completion: { _ in
                reveal()
            })
            self.present(controller, in: .window(.root))
        }, playMessageEffect: { [weak self] message in
            guard let self else {
                return
            }
            self.playMessageEffect(message: message)
        }, editMessageFactCheck: { [weak self] messageId in
            guard let self else {
                return
            }
            self.openEditMessageFactCheck(messageId: messageId)
        }, sendGift: { [weak self] peerId in
            guard let self else {
                return
            }
            let _ = (self.context.engine.payments.premiumGiftCodeOptions(peerId: nil, onlyCached: true)
            |> filter { !$0.isEmpty }
            |> deliverOnMainQueue).start(next: { [weak self] giftOptions in
                guard let self else {
                    return
                }
                let premiumOptions = giftOptions.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                
                var hasBirthday = false
                if let cachedUserData = self.contentData?.state.peerView?.cachedData as? CachedUserData {
                    hasBirthday = hasBirthdayToday(cachedData: cachedUserData)
                }
                let controller = self.context.sharedContext.makeGiftOptionsController(context: context, peerId: peerId, premiumOptions: premiumOptions, hasBirthday: hasBirthday, completion: nil)
                self.push(controller)
            })
        }, openUniqueGift: { [weak self] slug in
            guard let self else {
                return
            }
            self.openUrl("https://t.me/nft/\(slug)", concealed: false)
        }, openMessageFeeException: { [weak self] in
            guard let self, let peer = self.presentationInterfaceState.renderedPeer?.peer.flatMap(EnginePeer.init) else {
                return
            }
            
            let _ = (self.context.engine.peers.getPaidMessagesRevenue(peerId: peer.id)
            |> deliverOnMainQueue).start(next: { [weak self] revenue in
                guard let self else {
                    return
                }
                let controller = chatMessageRemovePaymentAlertController(
                    context: self.context,
                    presentationData: self.presentationData,
                    updatedPresentationData: self.updatedPresentationData,
                    peer: peer,
                    amount: (revenue?.value ?? 0) > 0 ? revenue : nil,
                    navigationController: self.navigationController as? NavigationController,
                    completion: { [weak self] refund in
                        guard let self else {
                            return
                        }
                        let _ = self.context.engine.peers.addNoPaidMessagesException(peerId: peer.id, refundCharged: refund).start()
                    }
                )
                self.present(controller, in: .window(.root))
            })
        }, requestMessageUpdate: { [weak self] id, scroll in
            if let self {
                self.chatDisplayNode.historyNode.requestMessageUpdate(id, andScrollToItem: scroll)
            }
        }, cancelInteractiveKeyboardGestures: { [weak self] in
            if let self {
                (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
                self.chatDisplayNode.cancelInteractiveKeyboardGestures()
            }
        }, dismissTextInput: { [weak self] in
            self?.chatDisplayNode.dismissTextInput()
        }, scrollToMessageId: { [weak self] index in
            self?.chatDisplayNode.historyNode.scrollToMessage(index: index)
        }, navigateToStory: { [weak self] message, storyId in
            guard let self else {
                return
            }
            if let story = message.associatedStories[storyId], story.data.isEmpty {
                self.present(UndoOverlayController(presentationData: self.presentationData, content:  .universal(animation: "story_expired", scale: 0.066, colors: [:], title: nil, text: self.presentationData.strings.Story_TooltipExpired, customUndoText: nil, timeout: nil), elevatedLayout: false, action: { _ in return true }), in: .current)
                return
            }
            
            let storyContent = SingleStoryContentContextImpl(context: self.context, storyId: storyId, readGlobally: true)
            let _ = (storyContent.state
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                guard let self else {
                    return
                }
                
                var transitionIn: StoryContainerScreen.TransitionIn?
                for i in 0 ..< 2 {
                    if transitionIn != nil {
                        break
                    }
                    self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            if i == 0 {
                                if itemNode.item?.message.id != message.id {
                                    return
                                }
                            }
                            
                            if let result = itemNode.targetForStoryTransition(id: storyId) {
                                transitionIn = StoryContainerScreen.TransitionIn(
                                    sourceView: result,
                                    sourceRect: result.bounds,
                                    sourceCornerRadius: 6.0,
                                    sourceIsAvatar: false
                                )
                            }
                        }
                    }
                }
                
                let storyContainerScreen = StoryContainerScreen(
                    context: self.context,
                    content: storyContent,
                    transitionIn: transitionIn,
                    transitionOut: { [weak self] peerId, storyIdValue in
                        guard let self, let storyIdId = storyIdValue.base as? Int32 else {
                            return nil
                        }
                        let storyId = StoryId(peerId: peerId, id: storyIdId)
                        
                        var transitionOut: StoryContainerScreen.TransitionOut?
                        for i in 0 ..< 2 {
                            if transitionOut != nil {
                                break
                            }
                            self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? ChatMessageItemView {
                                    if i == 0 {
                                        if itemNode.item?.message.id != message.id {
                                            return
                                        }
                                    }
                                    
                                    if let result = itemNode.targetForStoryTransition(id: storyId) {
                                        result.isHidden = true
                                        transitionOut = StoryContainerScreen.TransitionOut(
                                            destinationView: result,
                                            transitionView: StoryContainerScreen.TransitionView(
                                                makeView: { [weak result] in
                                                    let parentView = UIView()
                                                    if let copyView = result?.snapshotContentTree(unhide: true) {
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
                                            destinationRect: result.bounds,
                                            destinationCornerRadius: 2.0,
                                            destinationIsAvatar: false,
                                            completed: { [weak result] in
                                                result?.isHidden = false
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        return transitionOut
                    }
                )
                self.push(storyContainerScreen)
            })
        }, attemptedNavigationToPrivateQuote: { [weak self] peer in
            guard let self else {
                return
            }
            let text: String
            if let peer = peer as? TelegramChannel {
                if case .broadcast = peer.info {
                    text = self.presentationData.strings.Chat_ToastQuoteChatUnavailbalePrivateChannel
                } else {
                    text = self.presentationData.strings.Chat_ToastQuoteChatUnavailbalePrivateGroup
                }
            } else if peer is TelegramGroup {
                text = self.presentationData.strings.Chat_ToastQuoteChatUnavailbalePrivateGroup
            } else {
                text = self.presentationData.strings.Chat_ToastQuoteChatUnavailbalePrivateChat
            }
            self.controllerInteraction?.displayUndo(.info(title: nil, text: text, timeout: nil, customUndoText: nil))
        }, forceUpdateWarpContents: { [weak self] in
            guard let self else {
                return
            }
            self.chatDisplayNode.forceUpdateWarpContents()
        }, playShakeAnimation: { [weak self] in
            guard let self else {
                return
            }
            self.playShakeAnimation()
        }, displayQuickShare: { [weak self] messageId, node, gesture in
            guard let self else {
                return
            }
            self.displayQuickShare(id: messageId, node: node, gesture: gesture)
        }, updateChatLocationThread: { [weak self] threadId, animationDirection in
            guard let self else {
                return
            }
            let defaultDirection: ChatControllerAnimateInnerChatSwitchDirection? = self.chatDisplayNode.chatLocationTabSwitchDirection(from: self.chatLocation.threadId, to: threadId).flatMap { direction -> ChatControllerAnimateInnerChatSwitchDirection in
                return direction ? .right : .left
            }
            self.updateChatLocationThread(threadId: threadId, animationDirection: animationDirection ?? defaultDirection)
        }, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings, pollActionState: ChatInterfacePollActionState(), stickerSettings: self.stickerSettings, presentationContext: ChatPresentationContext(context: context, backgroundNode: self.chatBackgroundNode))
        controllerInteraction.enableFullTranslucency = context.sharedContext.energyUsageSettings.fullTranslucency
        
        self.controllerInteraction = controllerInteraction
        
        self.navigationBar?.allowsCustomTransition = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            if strongSelf.navigationBar?.userInfo == nil {
                return false
            }
            if strongSelf.navigationBar?.contentNode != nil {
                return false
            }
            return true
        }
        
        self.chatTitleView = ChatTitleView(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, animationCache: controllerInteraction.presentationContext.animationCache, animationRenderer: controllerInteraction.presentationContext.animationRenderer)
        
        if case .messageOptions = self.subject {
            self.chatTitleView?.disableAnimations = true
        }
        
        self.navigationItem.titleView = self.chatTitleView
        self.chatTitleView?.longPressed = { [weak self] in
            if let strongSelf = self, let peerView = strongSelf.contentData?.state.peerView, let peer = peerView.peers[peerView.peerId], peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil && !strongSelf.presentationInterfaceState.isNotAccessible {
                if case .standard(.previewing) = strongSelf.mode {
                } else {
                    strongSelf.interfaceInteraction?.beginMessageSearch(.everything, "")
                }
            }
        }
        
        let chatInfoButtonItem: UIBarButtonItem
        switch chatLocation {
        case .peer, .replyThread:
            let avatarNode = ChatAvatarNavigationNode()
            avatarNode.contextAction = { [weak self] node, gesture in
                guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer else {
                    return
                }
                
                let items: Signal<[ContextMenuItem], NoError>
                switch chatLocation {
                case .peer:
                    items = context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.CanViewStats(id: peer.id)
                    )
                    |> map { canViewStats -> [ContextMenuItem] in
                        var items: [ContextMenuItem] = []
                        
                        let openText = strongSelf.presentationData.strings.Conversation_ContextMenuOpenProfile
                        items.append(.action(ContextMenuActionItem(text: openText, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            self?.navigationButtonAction(.openChatInfo(expandAvatar: true, section: nil))
                        })))
                        
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
                                    statsController = groupStatsController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, peerId: peer.id)
                                } else {
                                    statsController = channelStatsController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, peerId: peer.id)
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
                case let .replyThread(message):
                    let peerId = peer.id
                    let threadId = message.threadId
                    
                    items = context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId),
                        TelegramEngine.EngineData.Item.Peer.ThreadData(id: peer.id, threadId: threadId),
                        TelegramEngine.EngineData.Item.NotificationSettings.Global()
                    )
                    |> map { peerNotificationSettings, threadData, globalNotificationSettings -> [ContextMenuItem] in
                        guard let channel = peer as? TelegramChannel else {
                            return []
                        }
                        guard let threadData = threadData else {
                            return []
                        }
                        
                        var items: [ContextMenuItem] = []
                        
                        var isMuted = false
                        switch threadData.notificationSettings.muteState {
                        case .muted:
                            isMuted = true
                        case .unmuted:
                            isMuted = false
                        case .default:
                            var peerIsMuted = false
                            if case let .muted(until) = peerNotificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                peerIsMuted = true
                            } else if case .default = peerNotificationSettings.muteState {
                                if case .group = channel.info {
                                    peerIsMuted = !globalNotificationSettings.groupChats.enabled
                                }
                            }
                            isMuted = peerIsMuted
                        }
                        
                        if !"".isEmpty {
                            items.append(.action(ContextMenuActionItem(text: isMuted ? presentationData.strings.ChatList_Context_Unmute : presentationData.strings.ChatList_Context_Mute, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: isMuted ? "Chat/Context Menu/Unmute" : "Chat/Context Menu/Muted"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                                if isMuted {
                                    let _ = (context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: 0)
                                             |> deliverOnMainQueue).startStandalone(completed: {
                                        f(.default)
                                    })
                                } else {
                                    var items: [ContextMenuItem] = []
                                    
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_MuteFor, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Mute2d"), color: theme.contextMenu.primaryColor)
                                    }, action: { c, _ in
                                        var subItems: [ContextMenuItem] = []
                                        
                                        let presetValues: [Int32] = [
                                            1 * 60 * 60,
                                            8 * 60 * 60,
                                            1 * 24 * 60 * 60,
                                            7 * 24 * 60 * 60
                                        ]
                                        
                                        for value in presetValues {
                                            subItems.append(.action(ContextMenuActionItem(text: muteForIntervalString(strings: presentationData.strings, value: value), icon: { _ in
                                                return nil
                                            }, action: { _, f in
                                                f(.default)
                                                
                                                let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: value).startStandalone()
                                                
                                                self?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_mute_for", scale: 0.066, colors: [:], title: nil, text: presentationData.strings.PeerInfo_TooltipMutedFor(mutedForTimeIntervalString(strings: presentationData.strings, value: value)).string, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                            })))
                                        }
                                        
                                        subItems.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_MuteForCustom, icon: { _ in
                                            return nil
                                        }, action: { _, f in
                                            f(.default)
                                            
                                            //                                        if let chatListController = chatListController {
                                            //                                            openCustomMute(context: context, peerId: peerId, threadId: threadId, baseController: chatListController)
                                            //                                        }
                                        })))
                                        
                                        c?.setItems(.single(ContextController.Items(content: .list(subItems))), minHeight: nil, animated: true)
                                    })))
                                    
                                    items.append(.separator)
                                    
                                    var isSoundEnabled = true
                                    switch threadData.notificationSettings.messageSound {
                                    case .none:
                                        isSoundEnabled = false
                                    default:
                                        break
                                    }
                                    
                                    if case .muted = threadData.notificationSettings.muteState {
                                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_ButtonUnmute, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOn"), color: theme.contextMenu.primaryColor)
                                        }, action: { _, f in
                                            f(.default)
                                            
                                            let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: nil).startStandalone()
                                            
                                            let iconColor: UIColor = .white
                                            self?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_profileunmute", scale: 0.075, colors: [
                                                "Middle.Group 1.Fill 1": iconColor,
                                                "Top.Group 1.Fill 1": iconColor,
                                                "Bottom.Group 1.Fill 1": iconColor,
                                                "EXAMPLE.Group 1.Fill 1": iconColor,
                                                "Line.Group 1.Stroke 1": iconColor
                                            ], title: nil, text: presentationData.strings.PeerInfo_TooltipUnmuted, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                        })))
                                    } else if !isSoundEnabled {
                                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_EnableSound, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOn"), color: theme.contextMenu.primaryColor)
                                        }, action: { _, f in
                                            f(.default)
                                            
                                            let _ = context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: .default).startStandalone()
                                            
                                            self?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_sound_on", scale: 0.056, colors: [:], title: nil, text: presentationData.strings.PeerInfo_TooltipSoundEnabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                        })))
                                    } else {
                                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_DisableSound, icon: { theme in
                                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/SoundOff"), color: theme.contextMenu.primaryColor)
                                        }, action: { _, f in
                                            f(.default)
                                            
                                            let _ = context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: threadId, sound: .none).startStandalone()
                                            
                                            self?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_sound_off", scale: 0.056, colors: [:], title: nil, text: presentationData.strings.PeerInfo_TooltipSoundDisabled, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                        })))
                                    }
                                    
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_NotificationsCustomize, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Customize"), color: theme.contextMenu.primaryColor)
                                    }, action: { _, f in
                                        f(.dismissWithoutContent)
                                        
                                        let _ = (context.engine.data.get(
                                            TelegramEngine.EngineData.Item.NotificationSettings.Global()
                                        )
                                                 |> deliverOnMainQueue).startStandalone(next: { globalSettings in
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
                                            
                                            let defaultSound: PeerMessageSound
                                            
                                            if case .broadcast = channel.info {
                                                defaultSound = globalSettings.channels.sound._asMessageSound()
                                            } else {
                                                defaultSound = globalSettings.groupChats.sound._asMessageSound()
                                            }
                                            
                                            let canRemove = false
                                            
                                            let exceptionController = notificationPeerExceptionController(context: context, updatedPresentationData: nil, peer: .channel(channel), threadId: threadId, isStories: nil, canRemove: canRemove, defaultSound: defaultSound, defaultStoriesSound: defaultSound, edit: true, updatePeerSound: { peerId, sound in
                                                let _ = (updatePeerSound(peerId, sound)
                                                         |> deliverOnMainQueue).startStandalone(next: { _ in
                                                })
                                            }, updatePeerNotificationInterval: { [weak self] peerId, muteInterval in
                                                let _ = (updatePeerNotificationInterval(peerId, muteInterval)
                                                         |> deliverOnMainQueue).startStandalone(next: { _ in
                                                    if let muteInterval = muteInterval, muteInterval == Int32.max {
                                                        let iconColor: UIColor = .white
                                                        self?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                                                            "Middle.Group 1.Fill 1": iconColor,
                                                            "Top.Group 1.Fill 1": iconColor,
                                                            "Bottom.Group 1.Fill 1": iconColor,
                                                            "EXAMPLE.Group 1.Fill 1": iconColor,
                                                            "Line.Group 1.Stroke 1": iconColor
                                                        ], title: nil, text: presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
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
                                                let _ = (updatePeerStorySound(peerId, sound)
                                                         |> deliverOnMainQueue).startStandalone()
                                            }, removePeerFromExceptions: {
                                            }, modifiedPeer: {
                                            })
                                            exceptionController.navigationPresentation = .modal
                                            self?.push(exceptionController)
                                        })
                                    })))
                                    
                                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.PeerInfo_MuteForever, textColor: .destructive, icon: { theme in
                                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Muted"), color: theme.contextMenu.destructiveColor)
                                    }, action: { _, f in
                                        f(.default)
                                        
                                        let _ = context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: threadId, muteInterval: Int32.max).startStandalone()
                                        
                                        let iconColor: UIColor = .white
                                        self?.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_profilemute", scale: 0.075, colors: [
                                            "Middle.Group 1.Fill 1": iconColor,
                                            "Top.Group 1.Fill 1": iconColor,
                                            "Bottom.Group 1.Fill 1": iconColor,
                                            "EXAMPLE.Group 1.Fill 1": iconColor,
                                            "Line.Group 1.Stroke 1": iconColor
                                        ], title: nil, text: presentationData.strings.PeerInfo_TooltipMutedForever, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                    })))
                                    
                                    c?.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil, animated: true)
                                }
                            })))
                        }
                        
                        items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_Search, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Search"), color: theme.actionSheet.primaryTextColor)
                        }, action: { _, f in
                            f(.dismissWithoutContent)
                            self?.interfaceInteraction?.beginMessageSearch(.everything, "")
                        })))
                        
                        if threadId != 1 {
                            var canOpenClose = false
                            if channel.flags.contains(.isCreator) {
                                canOpenClose = true
                            } else if channel.hasPermission(.manageTopics) {
                                canOpenClose = true
                            } else if threadData.isOwnedByMe {
                                canOpenClose = true
                            }
                            if canOpenClose {
                                items.append(.action(ContextMenuActionItem(text: threadData.isClosed ? presentationData.strings.ChatList_Context_ReopenTopic : presentationData.strings.ChatList_Context_CloseTopic, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: threadData.isClosed ? "Chat/Context Menu/Play": "Chat/Context Menu/Pause"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                                    f(.default)
                                    
                                    let _ = context.engine.peers.setForumChannelTopicClosed(id: peer.id, threadId: threadId, isClosed: !threadData.isClosed).startStandalone()
                                })))
                            }
                        }

                        return items
                    }
                default:
                    items = .single([])
                }
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                strongSelf.canReadHistory.set(false)
                
                let source: ContextContentSource
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, peer.smallProfileImage != nil {
                    let galleryController = AvatarGalleryController(context: strongSelf.context, peer: EnginePeer(peer), remoteEntries: nil, replaceRootController: { controller, ready in
                    }, synchronousLoad: true)
                    galleryController.setHintWillBePresentedInPreviewingContext(true)
                    source = .controller(ChatContextControllerContentSourceImpl(controller: galleryController, sourceNode: node, passthroughTouches: false))
                } else {
                    source = .reference(ChatControllerContextReferenceContentSource(controller: strongSelf, sourceView: node.view, insets: .zero))
                }
                
                let contextController = ContextController(presentationData: strongSelf.presentationData, source: source, items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
                contextController.dismissed = { [weak self] in
                    self?.canReadHistory.set(true)
                }
                strongSelf.presentInGlobalOverlay(contextController)
            }
            
            chatInfoButtonItem = UIBarButtonItem(customDisplayNode: avatarNode)!
            self.avatarNode = avatarNode
        case .customChatContents:
            chatInfoButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }
        chatInfoButtonItem.target = self
        chatInfoButtonItem.action = #selector(self.rightNavigationButtonAction)
        self.chatInfoNavigationButton = ChatNavigationButton(action: .openChatInfo(expandAvatar: true, section: nil), buttonItem: chatInfoButtonItem)
        
        self.moreBarButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: self.presentationData.theme.rootController.navigationBar.buttonColor)))
        self.moreInfoNavigationButton = ChatNavigationButton(action: .toggleInfoPanel, buttonItem: UIBarButtonItem(customDisplayNode: self.moreBarButton)!)
        self.moreBarButton.contextAction = { [weak self] sourceNode, gesture in
            guard let self else {
                return
            }
            guard case let .peer(peerId) = self.chatLocation else {
                return
            }
            
            if peerId == self.context.account.peerId {
                PeerInfoScreenImpl.openSavedMessagesMoreMenu(context: self.context, sourceController: self, isViewingAsTopics: false, sourceView: sourceNode.view, gesture: gesture)
            } else {
                ChatListControllerImpl.openMoreMenu(context: self.context, peerId: peerId, sourceController: self, isViewingAsTopics: false, sourceView: sourceNode.view, gesture: gesture)
            }
        }
        self.moreBarButton.addTarget(self, action: #selector(self.moreButtonPressed), forControlEvents: .touchUpInside)
        
        self.navigationItem.titleView = self.chatTitleView
        self.chatTitleView?.pressed = { [weak self] in
            self?.navigationButtonAction(.openChatInfo(expandAvatar: false, section: nil))
        }
        
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
            if let botStart = botStart, case .interactive = botStart.behavior {
                return state.updatedBotStartPayload(botStart.payload)
            } else {
                return state
            }
        })
        
        self.accountPeerDisposable = (context.account.postbox.peerView(id: context.account.peerId)
        |> deliverOnMainQueue).startStrict(next: { [weak self] peerView in
            if let strongSelf = self {
                let isPremium = peerView.peers[peerView.peerId]?.isPremium ?? false
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
                    return state.updatedIsPremium(isPremium)
                })
            }
        })
        
        if let chatPeerId = chatLocation.peerId {
            self.nameColorDisposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                TelegramEngine.EngineData.Item.Peer.Peer(id: chatPeerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] accountPeer, chatPeer in
                guard let self, let accountPeer, let chatPeer else {
                    return
                }
                var nameColor: PeerNameColor?
                if case let .channel(channel) = chatPeer, case .broadcast = channel.info {
                    nameColor = chatPeer.nameColor
                } else {
                    nameColor = accountPeer.nameColor
                }
                var accountPeerColor: ChatPresentationInterfaceState.AccountPeerColor?
                if let nameColor {
                    let colors = self.context.peerNameColors.get(nameColor)
                    var style: ChatPresentationInterfaceState.AccountPeerColor.Style = .solid
                    if colors.tertiary != nil {
                        style = .tripleDashed
                    } else if colors.secondary != nil {
                        style = .doubleDashed
                    }
                    accountPeerColor = ChatPresentationInterfaceState.AccountPeerColor(style: style)
                }
                self.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
                    return state.updatedAccountPeerColor(accountPeerColor)
                })
            })
        }
        
        self.reloadChatLocation(chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder, historyNode: self.chatDisplayNode.historyNode, apply: { $0(false) })
        
        self.botCallbackAlertMessageDisposable = (self.botCallbackAlertMessage.get()
        |> deliverOnMainQueue).startStrict(next: { [weak self] message in
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
        |> deliverOnMainQueue).startStrict(next: { [weak self] audioRecorder in
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
                        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                            if let self, case .stopped = value {
                                if self.presentationInterfaceState.interfaceState.mediaDraftState != nil {
                                    
                                } else {
                                    self.stopMediaRecorder()
                                }
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
        |> deliverOnMainQueue).startStrict(next: { [weak self] videoRecorder in
            if let strongSelf = self {
                if strongSelf.videoRecorderValue !== videoRecorder {
                    let previousVideoRecorderValue = strongSelf.videoRecorderValue
                    strongSelf.videoRecorderValue = videoRecorder
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            if let videoRecorder = videoRecorder {
                                if panelState.mediaRecordingState == nil {
                                    let recordingStatus = videoRecorder.recordingStatus
                                    return panelState.withUpdatedMediaRecordingState(.video(status: .recording(InstantVideoControllerRecordingStatus(micLevel: recordingStatus.micLevel, duration: recordingStatus.duration)), isLocked: strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId))
                                }
                            } else {
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })
                    
                    if let videoRecorder = videoRecorder {
                        strongSelf.recorderFeedback?.impact(.light)
                        
                        videoRecorder.onStop = {
                            if let strongSelf = self {
                                strongSelf.dismissMediaRecorder(.pause)
                            }
                        }
                        strongSelf.present(videoRecorder, in: .window(.root))
                        
                        if strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId {
                            videoRecorder.lockVideoRecording()
                        }
                    }
                    strongSelf.updateDownButtonVisibility()
                    
                    if let previousVideoRecorderValue = previousVideoRecorderValue {
                        previousVideoRecorderValue.discardVideo()
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
            activitySpace = PeerActivitySpace(peerId: replyThreadMessage.peerId, category: .thread(replyThreadMessage.threadId))
        case .customChatContents:
            activitySpace = nil
        }
        
        if let activitySpace = activitySpace {
            self.inputActivityDisposable = (self.typingActivityPromise.get()
            |> deliverOnMainQueue).startStrict(next: { [weak self] value in
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
            |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                if let strongSelf = self, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil && strongSelf.presentationInterfaceState.subject != .scheduledMessages && strongSelf.presentationInterfaceState.currentSendAsPeerId == nil {
                    if value {
                        strongSelf.context.account.updateLocalInputActivity(peerId: activitySpace, activity: .typingText, isPresent: false)
                    }
                    strongSelf.context.account.updateLocalInputActivity(peerId: activitySpace, activity: .choosingSticker, isPresent: value)
                }
            })
            
            self.recordingActivityDisposable = (self.recordingActivityPromise.get()
            |> deliverOnMainQueue).startStrict(next: { [weak self] value in
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
        
        let themeEmoticon: Signal<String?, NoError> = self.chatThemeEmoticonPromise.get()
        |> distinctUntilChanged
    
        let uploadingChatWallpaper: Signal<TelegramWallpaper?, NoError>
        if let peerId = self.chatLocation.peerId {
            uploadingChatWallpaper = self.context.account.pendingPeerMediaUploadManager.uploadingPeerMedia
            |> map { uploadingPeerMedia -> TelegramWallpaper? in
                if let item = uploadingPeerMedia[peerId], case let .wallpaper(wallpaper, _) = item.content {
                    return wallpaper
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged
        } else {
            uploadingChatWallpaper = .single(nil)
        }
        
        let chatWallpaper: Signal<TelegramWallpaper?, NoError> = combineLatest(self.chatWallpaperPromise.get(), uploadingChatWallpaper)
        |> map { chatWallpaper, uploadingChatWallpaper in
            return uploadingChatWallpaper ?? chatWallpaper
        }
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
        self.presentationDataDisposable = combineLatest(
            queue: Queue.mainQueue(),
            context.sharedContext.presentationData,
            themeSettings,
            context.engine.themes.getChatThemes(accountManager: accountManager, onlyCached: true),
            themeEmoticon,
            self.themeEmoticonAndDarkAppearancePreviewPromise.get(),
            chatWallpaper
        ).startStrict(next: { [weak self] presentationData, themeSettings, chatThemes, themeEmoticon, themeEmoticonAndDarkAppearance, chatWallpaper in
            if let strongSelf = self {
                let (themeEmoticonPreview, darkAppearancePreview) = themeEmoticonAndDarkAppearance
                
                var chatWallpaper = chatWallpaper
                
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                let previousChatWallpaper = strongSelf.presentationData.chatWallpaper
                
                var themeEmoticon = themeEmoticon
                if let themeEmoticonPreview = themeEmoticonPreview {
                    if !themeEmoticonPreview.isEmpty {
                        if themeEmoticon?.strippedEmoji != themeEmoticonPreview.strippedEmoji {
                            chatWallpaper = nil
                            themeEmoticon = themeEmoticonPreview
                        }
                    } else {
                        themeEmoticon = nil
                    }
                }
                if strongSelf.chatLocation.peerId == strongSelf.context.account.peerId {
                    themeEmoticon = nil
                }
                                
                var presentationData = presentationData
                var useDarkAppearance = presentationData.theme.overallDarkAppearance

                if let forcedTheme = strongSelf.forcedTheme {
                    presentationData = presentationData.withUpdated(theme: forcedTheme)
                } else {
                    if let wallpaper = chatWallpaper, case let .emoticon(wallpaperEmoticon) = wallpaper, let theme = chatThemes.first(where: { $0.emoticon?.strippedEmoji == wallpaperEmoticon.strippedEmoji }) {
                        let themeSettings: TelegramThemeSettings?
                        if let matching = theme.settings?.first(where: { $0.baseTheme == presentationData.theme.referenceTheme.baseTheme }) {
                            themeSettings = matching
                        } else {
                            themeSettings = theme.settings?.first
                        }
                        if let themeWallpaper = themeSettings?.wallpaper {
                            chatWallpaper = themeWallpaper
                        }
                    }
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
                            
                            var preferredBaseTheme: TelegramBaseTheme?
                            if let baseTheme = themeSettings.themePreferredBaseTheme[themeSettings.theme.index], [.classic, .day].contains(baseTheme) {
                                preferredBaseTheme = baseTheme
                            }
                            
                            lightTheme = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: themeSettings.theme, baseTheme: preferredBaseTheme, accentColor: currentColors?.color, bubbleColors: currentColors?.customBubbleColors ?? [], wallpaper: currentColors?.wallpaper, baseColor: currentColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
                        } else {
                            lightTheme = presentationData.theme
                            lightWallpaper = presentationData.chatWallpaper
                            
                            let automaticTheme = themeSettings.automaticThemeSwitchSetting.theme
                            let effectiveColors = themeSettings.themeSpecificAccentColors[automaticTheme.index]
                            let themeSpecificWallpaper = (themeSettings.themeSpecificChatWallpapers[coloredThemeIndex(reference: automaticTheme, accentColor: effectiveColors)] ?? themeSettings.themeSpecificChatWallpapers[automaticTheme.index])
                            
                            var preferredBaseTheme: TelegramBaseTheme?
                            if let baseTheme = themeSettings.themePreferredBaseTheme[automaticTheme.index], [.night, .tinted].contains(baseTheme) {
                                preferredBaseTheme = baseTheme
                            } else {
                                preferredBaseTheme = .night
                            }
                            
                            darkTheme = makePresentationTheme(mediaBox: accountManager.mediaBox, themeReference: automaticTheme, baseTheme: preferredBaseTheme, accentColor: effectiveColors?.color, bubbleColors: effectiveColors?.customBubbleColors ?? [], wallpaper: effectiveColors?.wallpaper, baseColor: effectiveColors?.baseColor, serviceBackgroundColor: defaultServiceBackgroundColor) ?? defaultPresentationTheme
                            
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
                }
                
                if let forcedWallpaper = strongSelf.forcedWallpaper {
                    presentationData = presentationData.withUpdated(chatWallpaper: forcedWallpaper)
                } else if let chatWallpaper {
                    presentationData = presentationData.withUpdated(chatWallpaper: chatWallpaper)
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
        |> deliverOnMainQueue).startStrict(next: { [weak self] downloadSettings in
            if let strongSelf = self, strongSelf.automaticMediaDownloadSettings != downloadSettings {
                strongSelf.automaticMediaDownloadSettings = downloadSettings
                strongSelf.controllerInteraction?.automaticMediaDownloadSettings = downloadSettings
                if strongSelf.isNodeLoaded {
                    strongSelf.chatDisplayNode.updateAutomaticMediaDownloadSettings(downloadSettings)
                }
            }
        })
        
        self.stickerSettingsDisposable = combineLatest(queue: Queue.mainQueue(),
            context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings]),
            self.disableStickerAnimationsPromise.get(),
            context.sharedContext.hasGroupCallOnScreen
        ).startStrict(next: { [weak self] sharedData, disableStickerAnimations, hasGroupCallOnScreen in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
                stickerSettings = value
            }
            
            var disableStickerAnimations = disableStickerAnimations
            if hasGroupCallOnScreen {
                disableStickerAnimations = true
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
        |> deliverOn(Queue.mainQueue())).startStrict(next: { [weak self] value in
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
            |> deliverOn(Queue.mainQueue())).startStrict(next: { [weak self] value in
                guard let strongSelf = self, strongSelf.isNodeLoaded else {
                    return
                }
                strongSelf.chatDisplayNode.updateIsBlurred(!value)
            })
        }
        

        
        self.canReadHistoryDisposable = (combineLatest(
            context.sharedContext.applicationBindings.applicationInForeground,
            self.canReadHistory.get(),
            self.hasBrowserOrAppInFront.get()
        ) |> map { inForeground, globallyEnabled, hasBrowserOrWebAppInFront in
            return inForeground && globallyEnabled && !hasBrowserOrWebAppInFront
        } |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            if let strongSelf = self, strongSelf.canReadHistoryValue != value {
                strongSelf.canReadHistoryValue = value
                strongSelf.raiseToListen?.enabled = value
            }
        })
        
        self.networkStateDisposable = (context.account.networkState |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            if let strongSelf = self, case .standard(.default) = strongSelf.presentationInterfaceState.mode {
                strongSelf.chatTitleView?.networkState = state
            }
        })
        
        if case let .messageOptions(_, messageIds, _) = self.subject, messageIds.count > 1 {
            self.updateChatPresentationInterfaceState(interactive: false, { state in
                return state.updatedInterfaceState({ $0.withUpdatedSelectedMessages(messageIds) })
            })
        }
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
        self.messageContextDisposable.dispose()
        self.controllerNavigationDisposable.dispose()
        self.sentMessageEventsDisposable.dispose()
        self.failedMessageEventsDisposable.dispose()
        self.sentPeerMediaMessageEventsDisposable.dispose()
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
        self.editingUrlPreviewQueryState?.1.dispose()
        self.replyMessageState?.1.dispose()
        self.audioRecorderDisposable?.dispose()
        self.audioRecorderStatusDisposable?.dispose()
        self.videoRecorderDisposable?.dispose()
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
        self.shareStatusDisposable?.dispose()
        self.context.sharedContext.mediaManager.galleryHiddenMediaManager.removeTarget(self)
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
        self.joinChannelDisposable.dispose()
        self.sendAsPeersDisposable?.dispose()
        self.preloadAttachBotIconsDisposables?.dispose()
        self.keepMessageCountersSyncrhonizedDisposable?.dispose()
        self.keepSavedMessagesSyncrhonizedDisposable?.dispose()
        self.translationStateDisposable?.dispose()
        self.premiumGiftSuggestionDisposable?.dispose()
        self.powerSavingMonitoringDisposable?.dispose()
        self.saveMediaDisposable?.dispose()
        self.giveawayStatusDisposable?.dispose()
        self.nameColorDisposable?.dispose()
        self.choosingStickerActivityDisposable?.dispose()
        self.automaticMediaDownloadSettingsDisposable?.dispose()
        self.stickerSettingsDisposable?.dispose()
        self.searchQuerySuggestionState?.1.dispose()
        self.recorderDataDisposable.dispose()
        self.displaySendWhenOnlineTipDisposable.dispose()
        self.networkSpeedEventsDisposable?.dispose()
        self.postedScheduledMessagesEventsDisposable?.dispose()
        self.updateChatLocationThreadDisposable?.dispose()
        self.accountPeerDisposable?.dispose()
        self.contentDataDisposable?.dispose()
    }
    
    public func updatePresentationMode(_ mode: ChatControllerPresentationMode) {
        self.mode = mode
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, {
            return $0.updatedMode(mode)
        })
    }
    
    func animateFromPreviewing(transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)) {
        guard let navigationController = self.effectiveNavigationController else {
            return
        }
        self.mode = .standard(.default)
        let completion = self.dismissPreviewing?(true)
        
        let initialLayout = self.validLayout
        let initialFrame = self.view.convert(self.view.bounds, to: navigationController.view)
                                                
        navigationController.pushViewController(self, animated: false)
        
        let updatedLayout = self.validLayout
        
        if let initialLayout, let updatedLayout, transition.isAnimated {
            let initialView = self.view.superview
            let updatedFrame = self.view.convert(self.view.bounds, to: navigationController.view)
            navigationController.view.addSubview(self.view)
            
            self.view.clipsToBounds = true
            self.view.frame = initialFrame
            self.containerLayoutUpdated(initialLayout, transition: .immediate)
            self.containerLayoutUpdated(updatedLayout, transition: transition)
            if !updatedLayout.metrics.isTablet {
                self.chatDisplayNode.historyNode.layer.animateScaleX(from: initialLayout.size.width / updatedLayout.size.width, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                self.chatDisplayNode.historyNode.layer.animatePosition(from: CGPoint(x: (updatedLayout.size.width - initialLayout.size.width) / 2.0, y: 0.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            self.chatDisplayNode.inputPanelBackgroundNode.layer.removeAllAnimations()
            self.chatDisplayNode.inputPanelBackgroundNode.layer.animatePosition(from: CGPoint(x: 0.0, y: self.chatDisplayNode.inputPanelNode?.frame.height ?? 45.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.view.layer.animate(from: 14.0, to: updatedLayout.deviceMetrics.screenCornerRadius, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4)
            
            transition.updateFrame(view: self.view, frame: updatedFrame, completion: { _ in
                initialView?.addSubview(self.view)
                self.view.clipsToBounds = false
                
                completion?()
            })
            transition.updateCornerRadius(layer: self.view.layer, cornerRadius: 0.0)
        }
        
        if let navigationBar = self.navigationBar {
            let nodes = [
                navigationBar.backButtonNode,
                navigationBar.backButtonArrow,
                navigationBar.badgeNode
            ]
            for node in nodes {
                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
        }
        
        self.canReadHistory.set(true)
        
        self.updateChatPresentationInterfaceState(transition: transition, interactive: false) { state in
            return state.updatedMode(self.mode)
        }
    }
    
    var chatDisplayNode: ChatControllerNode {
        get {
            return super.displayNode as! ChatControllerNode
        }
    }
    
    func updateStatusBarPresentation(animated: Bool = false) {
        if !self.galleryPresentationContext.controllers.isEmpty, let statusBarStyle = (self.galleryPresentationContext.controllers.last?.0 as? ViewController)?.statusBar.statusBarStyle {
            self.statusBar.updateStatusBarStyle(statusBarStyle, animated: animated)
        } else {
            switch self.presentationInterfaceState.mode {
            case let .standard(standardMode):
                switch standardMode {
                case .embedded:
                    self.statusBar.statusBarStyle = .Ignore
                default:
                    self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
                    self.deferScreenEdgeGestures = []
                }
            case .overlay:
                self.statusBar.statusBarStyle = .Hide
                self.deferScreenEdgeGestures = [.top]
            case .inline:
                self.statusBar.statusBarStyle = .Ignore
            }
        }
    }
    
    func themeAndStringsUpdated() {
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.updateStatusBarPresentation()
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
    
    func updateNavigationBarPresentation() {
        let navigationBarTheme: NavigationBarTheme
        
        let presentationTheme: PresentationTheme
        if let forcedNavigationBarTheme = self.forcedNavigationBarTheme {
            presentationTheme = forcedNavigationBarTheme
            navigationBarTheme = NavigationBarTheme(rootControllerTheme: forcedNavigationBarTheme, hideBackground: false, hideBadge: true)
        } else if self.hasEmbeddedTitleContent {
            presentationTheme = self.presentationData.theme
            navigationBarTheme = NavigationBarTheme(rootControllerTheme: defaultDarkPresentationTheme, hideBackground: self.context.sharedContext.immediateExperimentalUISettings.playerEmbedding ? true : false, hideBadge: true)
        } else {
            presentationTheme = self.presentationData.theme
            navigationBarTheme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme, hideBackground: self.context.sharedContext.immediateExperimentalUISettings.playerEmbedding ? true : false, hideBadge: false)
        }
        
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.chatTitleView?.updateThemeAndStrings(theme: presentationTheme, strings: self.presentationData.strings, hasEmbeddedTitleContent: self.hasEmbeddedTitleContent)
    }
    
    enum PinnedReferenceMessage {
        struct Loaded {
            var id: MessageId
            var minId: MessageId
            var isScrolled: Bool
        }
        
        case ready(Loaded)
        case loading
    }
    
    static func topPinnedScrollReferenceMessage(historyNode: ChatHistoryListNodeImpl, scrolledToMessageId: Signal<ScrolledToMessageId?, NoError>) -> Signal<PinnedReferenceMessage?, NoError> {
        return combineLatest(queue: Queue.mainQueue(),
            scrolledToMessageId,
            historyNode.topVisibleMessageRange.get()
        )
        |> map { scrolledToMessageId, topVisibleMessageRange -> PinnedReferenceMessage? in
            if let topVisibleMessageRange, topVisibleMessageRange.isLoading {
                return .loading
            }
            
            let bottomVisibleMessage = topVisibleMessageRange?.lowerBound.id
            let topVisibleMessage = topVisibleMessageRange?.upperBound.id
            
            if let scrolledToMessageId = scrolledToMessageId {
                if let topVisibleMessage, let bottomVisibleMessage {
                    if scrolledToMessageId.allowedReplacementDirection.contains(.up) && topVisibleMessage < scrolledToMessageId.id {
                        return .ready(PinnedReferenceMessage.Loaded(id: topVisibleMessage, minId: bottomVisibleMessage, isScrolled: false))
                    }
                }
                return .ready(PinnedReferenceMessage.Loaded(id: scrolledToMessageId.id, minId: scrolledToMessageId.id, isScrolled: true))
            } else if let topVisibleMessage, let bottomVisibleMessage {
                return .ready(PinnedReferenceMessage.Loaded(id: topVisibleMessage, minId: bottomVisibleMessage, isScrolled: false))
            } else {
                return nil
            }
        }
    }
    
    static func topPinnedScrollMessage(context: AccountContext, chatLocation: ChatLocation, historyNode: ChatHistoryListNodeImpl, scrolledToMessageId: Signal<ScrolledToMessageId?, NoError>) -> Signal<ChatPinnedMessage?, NoError> {
        //TODO:release move to ContentData
        let loadState: Signal<Bool, NoError> = historyNode.historyState.get()
        |> map { state -> Bool in
            switch state {
            case .loading:
                return false
            default:
                return true
            }
        }
        |> distinctUntilChanged
        
        let referenceMessage = self.topPinnedScrollReferenceMessage(historyNode: historyNode, scrolledToMessageId: scrolledToMessageId)
        
        return loadState
        |> mapToSignal { loadState in
            if !loadState {
                return .single(nil)
            } else {
                return ChatControllerImpl.topPinnedMessageSignal(context: context, chatLocation: chatLocation, referenceMessage: referenceMessage)
            }
        }
    }
    
    static func topPinnedMessageSignal(context: AccountContext, chatLocation: ChatLocation, referenceMessage: Signal<PinnedReferenceMessage?, NoError>?) -> Signal<ChatPinnedMessage?, NoError> {
        var pinnedPeerId: EnginePeer.Id?
        let threadId = chatLocation.threadId
        
        switch chatLocation {
        case let .peer(id):
            pinnedPeerId = id
        case let .replyThread(message):
            if message.isForumPost {
                pinnedPeerId = chatLocation.peerId
            }
        default:
            break
        }
        
        if let peerId = pinnedPeerId {
            let topPinnedMessage: Signal<ChatPinnedMessage?, NoError>
            
            func pinnedHistorySignal(anchorMessageId: MessageId?, count: Int) -> Signal<ChatHistoryViewUpdate, NoError> {
                let location: ChatHistoryLocation
                if let anchorMessageId = anchorMessageId {
                    location = .InitialSearch(subject: MessageHistoryInitialSearchSubject(location: .id(anchorMessageId), quote: nil), count: count, highlight: false, setupReply: false)
                } else {
                    location = .Initial(count: count)
                }
                
                let chatLocation: ChatLocation
                if let threadId {
                    chatLocation = .replyThread(message: ChatReplyThreadMessage(peerId: peerId, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, isMonoforumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false))
                } else {
                    chatLocation = .peer(id: peerId)
                }
                
                return (chatHistoryViewForLocation(ChatHistoryLocationInput(content: location, id: 0), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), context: context, chatLocation: chatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), scheduled: false, fixedCombinedReadStates: nil, tag: .tag(MessageTags.pinned), appendMessagesFromTheSameGroup: false, additionalData: [], orderStatistics: .combinedLocation)
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
            
            let topMessage = pinnedHistorySignal(anchorMessageId: nil, count: 10)
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
            
            let loadCount = 10
            
            struct PinnedHistory {
                struct PinnedMessage {
                    var message: Message
                    var index: Int
                }
                
                var messages: [PinnedMessage]
                var totalCount: Int
            }
            
            let adjustedReplyHistory: Signal<PinnedHistory, NoError>
            if let referenceMessage {
                adjustedReplyHistory = (Signal<PinnedHistory, NoError> { subscriber in
                    var referenceMessageValue: PinnedReferenceMessage?
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
                        
                        if case let .ready(loaded) = referenceMessageValue {
                            let referenceId = loaded.id
                            
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
                    |> deliverOnMainQueue).startStrict(next: { referenceMessage in
                        referenceMessageValue = referenceMessage
                        if !initializedView {
                            initializedView = true
                            //print("reload at \(String(describing: referenceMessage?.id)) disposable \(unsafeBitCast(viewDisposable, to: UInt64.self))")
                            var referenceId: MessageId?
                            if case let .ready(loaded) = referenceMessage {
                                referenceId = loaded.id
                            }
                            viewDisposable.set((pinnedHistorySignal(anchorMessageId: referenceId, count: loadCount)
                            |> deliverOnMainQueue).startStrict(next: { next in
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
            } else {
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
            }
            
            topPinnedMessage = combineLatest(queue: .mainQueue(),
                adjustedReplyHistory,
                topMessage,
                referenceMessage ?? .single(nil)
            )
            |> map { pinnedMessages, topMessage, referenceMessage -> ChatPinnedMessage? in
                var message: ChatPinnedMessage?
                
                let topMessageId: MessageId
                if pinnedMessages.messages.isEmpty {
                    return nil
                }
                topMessageId = topMessage?.message.id ?? pinnedMessages.messages[pinnedMessages.messages.count - 1].message.id
                
                if case let .ready(referenceMessage) = referenceMessage, referenceMessage.isScrolled, !pinnedMessages.messages.isEmpty, referenceMessage.id == pinnedMessages.messages[0].message.id, let topMessage = topMessage {
                    var index = topMessage.index
                    for message in pinnedMessages.messages {
                        if message.message.id == topMessage.message.id {
                            index = message.index
                            break
                        }
                    }
                    
                    if threadId != nil {
                        if referenceMessage.minId <= topMessage.message.id {
                            return nil
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
                    } else if case let .ready(referenceMessage) = referenceMessage {
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
                        if threadId != nil, case let .ready(referenceMessage) = referenceMessage {
                            if referenceMessage.minId <= entry.message.id {
                                continue
                            }
                        }
                        message = ChatPinnedMessage(message: entry.message, index: entry.index, totalCount: pinnedMessages.totalCount, topMessageId: topMessageId)
                    }
                }

                return message
            }
            |> distinctUntilChanged
            
            return topPinnedMessage
        } else {
            return .single(nil)
        }
    }

    var storedAnimateFromSnapshotState: ChatControllerNode.SnapshotState?

    func animateFromPreviousController(snapshotState: ChatControllerNode.SnapshotState) {
        self.storedAnimateFromSnapshotState = snapshotState
    }
    
    override public func loadDisplayNode() {
        self.loadDisplayNodeImpl()
        self.galleryPresentationContext.view = self.view
        self.galleryPresentationContext.controllersUpdated = { [weak self] _ in
            guard let self else {
                return
            }
            self.updateStatusBarPresentation()
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
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
        
        if case let .replyThread(message) = self.chatLocation, message.isForumPost {
            if self.keepMessageCountersSyncrhonizedDisposable == nil {
                self.keepMessageCountersSyncrhonizedDisposable = self.context.engine.messages.keepMessageCountersSyncrhonized(peerId: message.peerId, threadId: message.threadId).startStrict()
            }
        } else if self.chatLocation.peerId == self.context.account.peerId {
            if self.keepMessageCountersSyncrhonizedDisposable == nil {
                if let threadId = self.chatLocation.threadId {
                    self.keepMessageCountersSyncrhonizedDisposable = self.context.engine.messages.keepMessageCountersSyncrhonized(peerId: self.context.account.peerId, threadId: threadId).startStrict()
                } else {
                    self.keepMessageCountersSyncrhonizedDisposable = self.context.engine.messages.keepMessageCountersSyncrhonized(peerId: self.context.account.peerId).startStrict()
                }
            }
            if self.keepSavedMessagesSyncrhonizedDisposable == nil {
                self.keepSavedMessagesSyncrhonizedDisposable = self.context.engine.stickers.refreshSavedMessageTags(subPeerId: self.chatLocation.threadId.flatMap(PeerId.init)).startStrict()
            }
        }
        
        if let scheduledActivateInput = scheduledActivateInput, case .text = scheduledActivateInput {
            self.scheduledActivateInput = nil
            
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                return state.updatedInputMode({ _ in
                    switch scheduledActivateInput {
                    case .text:
                        return .text
                    case .entityInput:
                        return .media(mode: .other, expanded: nil, focused: false)
                    }
                })
            })
        }
        
        var chatNavigationStack: [ChatNavigationStackItem] = self.chatNavigationStack
        if let peerId = self.chatLocation.peerId {
            if let summary = self.customNavigationDataSummary as? ChatControllerNavigationDataSummary {
                chatNavigationStack.removeAll()
                chatNavigationStack = summary.peerNavigationItems.filter({ $0 != ChatNavigationStackItem(peerId: peerId, threadId: self.chatLocation.threadId) })
            }
            if let _ = self.chatLocation.threadId {
                if !chatNavigationStack.contains(ChatNavigationStackItem(peerId: peerId, threadId: nil)) {
                    chatNavigationStack.append(ChatNavigationStackItem(peerId: peerId, threadId: nil))
                }
            }
        }
        
        if !chatNavigationStack.isEmpty {
            self.chatDisplayNode.navigationBar?.backButtonNode.isGestureEnabled = true
            self.chatDisplayNode.navigationBar?.backButtonNode.activated = { [weak self] gesture, _ in
                guard let strongSelf = self, let backButtonNode = strongSelf.chatDisplayNode.navigationBar?.backButtonNode, let navigationController = strongSelf.effectiveNavigationController else {
                    gesture.cancel()
                    return
                }
                let nextFolderId: Int32? = strongSelf.currentChatListFilter
                PeerInfoScreenImpl.displayChatNavigationMenu(
                    context: strongSelf.context,
                    chatNavigationStack: chatNavigationStack,
                    nextFolderId: nextFolderId,
                    parentController: strongSelf,
                    backButtonView: backButtonNode.view,
                    navigationController: navigationController,
                    gesture: gesture
                )
            }
        }
        
        if case .standard(.default) = self.mode, !"".isEmpty {
            let hasBrowserOrWebAppInFront: Signal<Bool, NoError> = .single([])
            |> then(
                self.effectiveNavigationController?.viewControllersSignal ?? .single([])
            )
            |> map { controllers in
                if controllers.last is BrowserScreen || controllers.last is AttachmentController {
                    return true
                } else {
                    return false
                }
            }
            self.hasBrowserOrAppInFront.set(hasBrowserOrWebAppInFront)
        }
    }
    
    var returnInputViewFocus = false
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.didAppear = true
        
        self.chatDisplayNode.historyNode.experimentalSnapScrollToItem = false
        self.chatDisplayNode.historyNode.canReadHistory.set(self.computedCanReadHistoryPromise.get())
        
        if !self.alwaysShowSearchResultsAsList {
            self.chatDisplayNode.loadInputPanels(theme: self.presentationInterfaceState.theme, strings: self.presentationInterfaceState.strings, fontSize: self.presentationInterfaceState.fontSize)
        }
        
        if self.recentlyUsedInlineBotsDisposable == nil {
            self.recentlyUsedInlineBotsDisposable = (self.context.engine.peers.recentlyUsedInlineBots() |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                self?.recentlyUsedInlineBotsValue = peers.filter({ $0.1 >= 0.14 }).map({ $0.0._asPeer() })
            })
        }
        
        if case .standard(.default) = self.presentationInterfaceState.mode, self.raiseToListen == nil {
            self.raiseToListen = RaiseToListenManager(shouldActivate: { [weak self] in
                if let strongSelf = self, strongSelf.isNodeLoaded && strongSelf.canReadHistoryValue, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil, strongSelf.playlistStateAndType == nil {
                    if !strongSelf.context.sharedContext.currentMediaInputSettings.with({ $0.enableRaiseToSpeak }) {
                        return false
                    }
                    
                    if strongSelf.effectiveNavigationController?.topViewController !== strongSelf {
                        return false
                    }
                    
                    if strongSelf.presentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
                        return false
                    }
                    
                    if !strongSelf.traceVisibility() {
                        return false
                    }
                    if strongSelf.currentContextController != nil {
                        return false
                    }
                    if !isTopmostChatController(strongSelf) {
                        return false
                    }
                    
                    if strongSelf.firstLoadedMessageToListen() != nil || strongSelf.chatDisplayNode.isTextInputPanelActive {
                        if strongSelf.context.sharedContext.immediateHasOngoingCall {
                            return false
                        }
                        
                        if case .media = strongSelf.presentationInterfaceState.inputMode {
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
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.chatDisplayNode.historyNode.voicePlaylistItemChanged(previousItem, currentItem)
            }
        }
        
        if let arguments = self.presentationArguments as? ChatControllerOverlayPresentationData {
            //TODO clear arguments
            self.chatDisplayNode.animateInAsOverlay(from: arguments.expandData.0, completion: {
                arguments.expandData.1()
            })
        }
        
        if !self.didSetupDropToPaste {
            self.didSetupDropToPaste = true
            let dropInteraction = UIDropInteraction(delegate: self)
            self.chatDisplayNode.view.addInteraction(dropInteraction)
        }
        
        if !self.checkedPeerChatServiceActions {
            self.checkedPeerChatServiceActions = true
            
            if case let .peer(peerId) = self.chatLocation, self.screenCaptureManager == nil {
                if peerId.namespace == Namespaces.Peer.SecretChat {
                    self.screenCaptureManager = ScreenCaptureDetectionManager(check: { [weak self] in
                        if let strongSelf = self, strongSelf.traceVisibility() {
                            if strongSelf.canReadHistoryValue {
                                let _ = strongSelf.context.engine.messages.addSecretChatMessageScreenshot(peerId: peerId).startStandalone()
                            }
                            return true
                        } else {
                            return false
                        }
                    })
                } else if peerId.isTelegramNotifications {
                    self.screenCaptureManager = ScreenCaptureDetectionManager(check: { [weak self] in
                        if let strongSelf = self, strongSelf.traceVisibility() {
                            let loginCodeRegex = try? NSRegularExpression(pattern: "\\b\\d{5,7}\\b", options: [])
                            var loginCodesToInvalidate: [String] = []
                            strongSelf.chatDisplayNode.historyNode.forEachVisibleMessageItemNode({ itemNode in
                                if let text = itemNode.item?.message.text, let matches = loginCodeRegex?.matches(in: text, options: [], range: NSMakeRange(0, (text as NSString).length)), let match = matches.first {
                                    loginCodesToInvalidate.append((text as NSString).substring(with: match.range))
                                }
                            })
                            if !loginCodesToInvalidate.isEmpty {
                                let _ = strongSelf.context.engine.auth.invalidateLoginCodes(codes: loginCodesToInvalidate).startStandalone()
                            }
                            return true
                        } else {
                            return false
                        }
                    })
                } else if peerId.namespace == Namespaces.Peer.CloudUser {
                    self.screenCaptureManager = ScreenCaptureDetectionManager(check: { [weak self] in
                        guard let self else {
                            return false
                        }
                        
                        let _ = (self.context.sharedContext.mediaManager.globalMediaPlayerState
                        |> take(1)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] playlistStateAndType in
                            if let self, let (_, playbackState, _) = playlistStateAndType, case let .state(state) = playbackState {
                                if let source = state.item.playbackData?.source, case let .telegramFile(_, _, isViewOnce) = source, isViewOnce {
                                    self.context.sharedContext.mediaManager.setPlaylist(nil, type: .voice, control: .playback(.pause))
                                }
                            }
                        })
                        return true
                    })
                }
            }
            
            if case let .peer(peerId) = self.chatLocation {
                let _ = self.context.engine.peers.checkPeerChatServiceActions(peerId: peerId).startStandalone()
            }
            
            if self.chatLocation.peerId != nil && self.chatDisplayNode.frameForInputActionButton() != nil {
                let inputText = self.presentationInterfaceState.interfaceState.effectiveInputState.inputText.string
                if !inputText.isEmpty {
                    if inputText.count > 4 {
                        let _ = (ApplicationSpecificNotice.getChatMessageOptionsTip(accountManager: self.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
                            if let strongSelf = self, counter < 3 {
                                let _ = ApplicationSpecificNotice.incrementChatMessageOptionsTip(accountManager: strongSelf.context.sharedContext.accountManager).startStandalone()
                                strongSelf.displaySendingOptionsTooltip()
                            }
                        })
                    }
                } else if self.presentationInterfaceState.interfaceState.mediaRecordingMode == .audio {
                    var canSendMedia = false
                    if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel {
                        if channel.hasBannedPermission(.banSendMedia) == nil && channel.hasBannedPermission(.banSendVoice) == nil {
                            canSendMedia = true
                        }
                    } else if let group = self.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup {
                        if !group.hasBannedPermission(.banSendMedia) && !group.hasBannedPermission(.banSendVoice) {
                            canSendMedia = true
                        }
                    } else {
                        canSendMedia = true
                    }
                    if canSendMedia && self.presentationInterfaceState.voiceMessagesAvailable {
                        let _ = (ApplicationSpecificNotice.getChatMediaMediaRecordingTips(accountManager: self.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
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
                                let _ = ApplicationSpecificNotice.incrementChatMediaMediaRecordingTips(accountManager: strongSelf.context.sharedContext.accountManager).startStandalone()
                                strongSelf.displayMediaRecordingTooltip()
                            }
                        })
                    }
                }
            }
            
            self.editMessageErrorsDisposable.set((self.context.account.pendingUpdateMessageManager.errors
            |> deliverOnMainQueue).startStrict(next: { [weak self] (_, error) in
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
                self.keepPeerInfoScreenDataHotDisposable.set(keepPeerInfoScreenDataHot(context: context, peerId: peerId, chatLocation: self.chatLocation, chatLocationContextHolder: self.chatLocationContextHolder).startStrict())
                
                if peerId.namespace == Namespaces.Peer.CloudUser {
                    self.preloadAvatarDisposable.set((peerInfoProfilePhotosWithCache(context: context, peerId: peerId)
                    |> mapToSignal { (complete, result) -> Signal<Never, NoError> in
                        var signals: [Signal<Never, NoError>] = [.complete()]
                        for i in 0 ..< min(1, result.count) {
                            if let video = result[i].videoRepresentations.first {
                                let duration: Double = (video.representation.startTimestamp ?? 0.0) + (i == 0 ? 4.0 : 2.0)
                                signals.append(preloadVideoResource(postbox: context.account.postbox, userLocation: .other, userContentType: .video, resourceReference: video.reference, duration: duration))
                            }
                        }
                        return combineLatest(signals) |> mapToSignal { _ in
                            return .never()
                        }
                    }).startStrict())
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
            ).startStrict(next: { [weak self] peerView, _ in
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
                                |> deliverOnMainQueue).startStrict(next: { peerId in
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
        
        self.checksTooltipDisposable.set((self.context.engine.notices.getServerProvidedSuggestions()
        |> deliverOnMainQueue).startStrict(next: { [weak self] values in
            guard let strongSelf = self, strongSelf.chatLocation.peerId != strongSelf.context.account.peerId else {
                return
            }
            if !values.contains(.newcomerTicks) {
                return
            }
            strongSelf.shouldDisplayChecksTooltip = true
        }))
        
        if case let .peer(peerId) = self.chatLocation {
            self.peerSuggestionsDisposable.set((self.context.engine.notices.getPeerSpecificServerProvidedSuggestions(peerId: peerId)
            |> deliverOnMainQueue).startStrict(next: { [weak self] values in
                guard let strongSelf = self else {
                    return
                }
                
                if !strongSelf.traceVisibility() || strongSelf.navigationController?.topViewController != strongSelf {
                    return
                }
                
                if values.contains(.convertToGigagroup) && !strongSelf.displayedConvertToGigagroupSuggestion {
                    strongSelf.displayedConvertToGigagroupSuggestion = true
                    
                    let attributedTitle = NSAttributedString(string: strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_Title, font: Font.semibold(strongSelf.presentationData.listsFontSize.baseDisplaySize), textColor: strongSelf.presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                    let body = MarkdownAttributeSet(font: Font.regular(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: strongSelf.presentationData.theme.actionSheet.primaryTextColor)
                    let bold = MarkdownAttributeSet(font: Font.semibold(strongSelf.presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: strongSelf.presentationData.theme.actionSheet.primaryTextColor)
                    
                    let participantsLimit = strongSelf.context.currentLimitsConfiguration.with { $0 }.maxSupergroupMemberCount
                    let text = strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_Text(presentationStringsFormattedNumber(participantsLimit, strongSelf.presentationData.dateTimeFormat.groupingSeparator)).string
                    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
                    
                    let controller = richTextAlertController(context: strongSelf.context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                        strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(title: nil, text: strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_SettingsTip, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                    }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.BroadcastGroups_LimitAlert_LearnMore, action: {
                        
                        let context = strongSelf.context
                        let presentationData = strongSelf.presentationData
                        let controller = PermissionController(context: context, splashScreen: true)
                        controller.navigationPresentation = .modal
                        controller.setState(.custom(icon: .animation("BroadcastGroup"), title: presentationData.strings.BroadcastGroups_IntroTitle, subtitle: nil, text: presentationData.strings.BroadcastGroups_IntroText, buttonTitle: presentationData.strings.BroadcastGroups_Convert, secondaryButtonTitle: presentationData.strings.BroadcastGroups_Cancel, footerText: nil), animated: false)
                        controller.proceed = { [weak controller] result in
                            let attributedTitle = NSAttributedString(string: presentationData.strings.BroadcastGroups_ConfirmationAlert_Title, font: Font.semibold(presentationData.listsFontSize.baseDisplaySize), textColor: presentationData.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                            let body = MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
                            let bold = MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
                            let attributedText = parseMarkdownIntoAttributedString(presentationData.strings.BroadcastGroups_ConfirmationAlert_Text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
                            
                            let alertController = richTextAlertController(context: context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                let _ = context.engine.notices.dismissPeerSpecificServerProvidedSuggestion(peerId: peerId, suggestion: .convertToGigagroup).startStandalone()
                            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.BroadcastGroups_ConfirmationAlert_Convert, action: { [weak controller] in
                                controller?.dismiss()
                                
                                let _ = context.engine.notices.dismissPeerSpecificServerProvidedSuggestion(peerId: peerId, suggestion: .convertToGigagroup).startStandalone()
                                
                                let _ = (convertGroupToGigagroup(account: context.account, peerId: peerId)
                                |> deliverOnMainQueue).startStandalone(completed: {
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
        
        if let scheduledActivateInput = self.scheduledActivateInput {
            self.scheduledActivateInput = nil
            
            switch scheduledActivateInput {
            case .text:
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    return state.updatedInputMode({ _ in
                        return .text
                    })
                })
            case .entityInput:
                self.chatDisplayNode.openStickers(beginWithEmoji: true)
            }
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
            self.presentAttachmentBot(botId: attachBotStart.botId, payload: attachBotStart.payload, justInstalled: attachBotStart.justInstalled)
        }
        
        if self.powerSavingMonitoringDisposable == nil {
            self.powerSavingMonitoringDisposable = (self.context.sharedContext.automaticMediaDownloadSettings
            |> mapToSignal { settings -> Signal<Bool, NoError> in
                return automaticEnergyUsageShouldBeOn(settings: settings)
            }
            |> distinctUntilChanged).startStrict(next: { [weak self] isPowerSavingEnabled in
                guard let self else {
                    return
                }
                var previousValueValue: Bool?
                
                previousValueValue = ChatListControllerImpl.sharedPreviousPowerSavingEnabled
                ChatListControllerImpl.sharedPreviousPowerSavingEnabled = isPowerSavingEnabled
                
                /*#if DEBUG
                previousValueValue = false
                #endif*/
                
                if isPowerSavingEnabled != previousValueValue && previousValueValue != nil && isPowerSavingEnabled {
                    let batteryLevel = UIDevice.current.batteryLevel
                    if batteryLevel > 0.0 && self.view.window != nil {
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                        let batteryPercentage = Int(batteryLevel * 100.0)
                        
                        self.dismissAllUndoControllers()
                        self.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "lowbattery_30", scale: 1.0, colors: [:], title: presentationData.strings.PowerSaving_AlertEnabledTitle, text: presentationData.strings.PowerSaving_AlertEnabledText("\(batteryPercentage)").string, customUndoText: presentationData.strings.PowerSaving_AlertEnabledAction, timeout: 5.0), elevatedLayout: false, action: { [weak self] action in
                            if case .undo = action, let self {
                                let _ = updateMediaDownloadSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { settings in
                                    var settings = settings
                                    settings.energyUsageSettings.activationThreshold = 4
                                    return settings
                                }).startStandalone()
                            }
                            return false
                        }), in: .current)
                    }
                }
            })
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
        self.themeScreen?.dismiss()
        
        self.attachmentController?.dismiss()
        
        self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
        
        if let _ = self.peekData {
            self.peekTimerDisposable.set(nil)
        }
        
        if case .standard(.default) = self.mode {
            self.hasBrowserOrAppInFront.set(.single(false))
        }
        
        if let _ = self.currentPaidMessageUndoController, let peerId = self.chatLocation.peerId {
            self.context.engine.messages.forceSendPostponedPaidMessage(peerId: peerId)
        }
    }
    
    func saveInterfaceState(includeScrollState: Bool = true) {
        if case .messageOptions = self.subject {
            return
        }
        
        var includeScrollState = includeScrollState
        
        var peerId: PeerId
        var threadId: Int64?
        switch self.chatLocation {
        case let .peer(peerIdValue):
            peerId = peerIdValue
        case let .replyThread(replyThreadMessage):
            if replyThreadMessage.peerId == self.context.account.peerId && replyThreadMessage.threadId == self.context.account.peerId.toInt64() {
                peerId = replyThreadMessage.peerId
                threadId = nil
                includeScrollState = true
                
                let scrollState = self.chatDisplayNode.historyNode.immediateScrollState()
                let _ = ChatInterfaceState.update(engine: self.context.engine, peerId: peerId, threadId: replyThreadMessage.threadId, { current in
                    return current.withUpdatedHistoryScrollState(scrollState)
                }).startStandalone()
            } else {
                peerId = replyThreadMessage.peerId
                threadId = replyThreadMessage.threadId
            }
        case .customChatContents:
            return
        }
        
        let timestamp = Int32(Date().timeIntervalSince1970)
        var interfaceState = self.presentationInterfaceState.interfaceState.withUpdatedTimestamp(timestamp)
        if includeScrollState {
            let scrollState = self.chatDisplayNode.historyNode.immediateScrollState()
            interfaceState = interfaceState.withUpdatedHistoryScrollState(scrollState)
        }
        interfaceState = interfaceState.withUpdatedInputLanguage(self.chatDisplayNode.currentTextInputLanguage)
        if case .peer = self.chatLocation, let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum {
            interfaceState = interfaceState.withUpdatedComposeInputState(ChatTextInputState()).withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil)
        }
        let _ = ChatInterfaceState.update(engine: self.context.engine, peerId: peerId, threadId: threadId, { _ in
            return interfaceState
        }).startStandalone()
        
        self.context.engine.peers.setPerstistentChatInterfaceState(peerId: peerId, state: CodableEntry(self.presentationInterfaceState.persistentData))
    }
        
    override public func viewWillLeaveNavigation() {
        self.chatDisplayNode.willNavigateAway()
    }
    
    override public func inFocusUpdated(isInFocus: Bool) {
        self.disableStickerAnimationsPromise.set(!isInFocus)
        self.chatDisplayNode.inFocusUpdated(isInFocus: isInFocus)
    }
    
    func canManagePin() -> Bool {
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

    var suspendNavigationBarLayout: Bool = false
    var suspendedNavigationBarLayout: ContainerViewLayout?
    var additionalNavigationBarBackgroundHeight: CGFloat = 0.0
    var additionalNavigationBarHitTestSlop: CGFloat = 0.0
    var additionalNavigationBarCutout: CGSize?

    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.suspendNavigationBarLayout {
            self.suspendedNavigationBarLayout = layout
            return
        }
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: self.additionalNavigationBarCutout, transition: transition)
    }
    
    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        return nil
    }
    
    public func updateIsScrollingLockedAtTop(isScrollingLockedAtTop: Bool) {
        self.chatDisplayNode.isScrollingLockedAtTop = isScrollingLockedAtTop
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
        if case .compact = layout.metrics.widthClass, let attachmentController = self.attachmentController, attachmentController.window != nil {
            layout = layout.withUpdatedInputHeight(nil)
        }
                
        var navigationBarTransition = transition
        self.chatDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition, listViewTransaction: { updateSizeAndInsets, additionalScrollDistance, scrollToTop, completion in
            self.chatDisplayNode.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: additionalScrollDistance, scrollToTop: scrollToTop, completion: completion)
        }, updateExtraNavigationBarBackgroundHeight: { value, hitTestSlop, cutout, extraNavigationTransition in
            navigationBarTransition = extraNavigationTransition
            self.additionalNavigationBarBackgroundHeight = value
            self.additionalNavigationBarHitTestSlop = hitTestSlop
            self.additionalNavigationBarCutout = cutout
        })
        
        if case .compact = layout.metrics.widthClass {
            let hasOverlayNodes = self.context.sharedContext.mediaManager.overlayMediaManager.controller?.hasNodes ?? false
            if self.validLayout != nil && layout.size.width > layout.size.height && !hasOverlayNodes && self.traceVisibility() && isTopmostChatController(self) {
                var completed = false
                self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                    if !completed, let itemNode = itemNode as? ChatMessageItemView, let message = itemNode.item?.message, let (_, soundEnabled, _, _, _) = itemNode.playMediaWithSound(), soundEnabled {
                        let _ = self.controllerInteraction?.openMessage(message, OpenMessageParams(mode: .landscape))
                        completed = true
                    }
                }
            }
        }

        self.suspendNavigationBarLayout = false
        if let suspendedNavigationBarLayout = self.suspendedNavigationBarLayout {
            self.suspendedNavigationBarLayout = suspendedNavigationBarLayout
            self.applyNavigationBarLayout(suspendedNavigationBarLayout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, additionalCutout: self.additionalNavigationBarCutout, transition: navigationBarTransition)
        }
        self.navigationBar?.additionalContentNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: 0.0, bottom: self.additionalNavigationBarHitTestSlop, right: 0.0)
    }
    
    func updateChatPresentationInterfaceState(animated: Bool = true, interactive: Bool, saveInterfaceState: Bool = false, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        self.updateChatPresentationInterfaceState(transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, interactive: interactive, saveInterfaceState: saveInterfaceState, f, completion: completion)
    }
    
    func updateChatPresentationInterfaceState(transition: ContainedViewLayoutTransition, interactive: Bool, saveInterfaceState: Bool = false, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        updateChatPresentationInterfaceStateImpl(
            selfController: self,
            transition: transition,
            interactive: interactive,
            saveInterfaceState: saveInterfaceState,
            f,
            completion: completion
        )
    }
    
    func updateItemNodesSelectionStates(animated: Bool) {
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
    
    func updatePollTooltipMessageState(animated: Bool) {
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
    
    func updateItemNodesSearchTextHighlightStates() {
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
    
    func updateItemNodesHighlightedStates(animated: Bool) {
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
            if case .standard(.previewing) = self.mode {
                self.navigationButtonAction(button.action)
            } else if case let .peer(peerId) = self.chatLocation, case .openChatInfo(expandAvatar: true, _) = button.action, let storyStats = self.contentData?.state.storyStats, storyStats.unseenCount != 0, let avatarNode = self.avatarNode {
                self.openStories(peerId: peerId, avatarHeaderNode: nil, avatarNode: avatarNode.avatarNode)
            } else {
                self.navigationButtonAction(button.action)
            }
        }
    }
    
    @objc func secondaryRightNavigationButtonAction() {
        if let button = self.secondaryRightNavigationButton {
            self.navigationButtonAction(button.action)
        }
    }
    
    @objc func moreButtonPressed() {
        self.moreBarButton.play()
        self.moreBarButton.contextAction?(self.moreBarButton.containerNode, nil)
    }
    
    public func beginClearHistory(type: InteractiveHistoryClearingType) {
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
        
        self.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(context: self.context, title: NSAttributedString(string: statusText), text: nil), elevatedLayout: false, action: { [weak self] value in
            guard let strongSelf = self else {
                return false
            }
            if value == .commit {
                let _ = strongSelf.context.engine.messages.clearHistoryInteractively(peerId: peerId, threadId: nil, type: type).startStandalone(completed: {
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
    
    public func cancelSelectingMessages() {
        self.navigationButtonAction(.cancelMessageSelection)
    }
    
    func editMessageMediaWithMessages(_ messages: [EnqueueMessage]) {
        if let message = messages.first, case let .message(text, attributes, _, maybeMediaReference, _, _, _, _, _, _) = message, let mediaReference = maybeMediaReference {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                var entities: [MessageTextEntity] = []
                for attribute in attributes {
                    if let entitiesAttrbute = attribute as? TextEntitiesMessageAttribute {
                        entities = entitiesAttrbute.entities
                    }
                }
                let attributedText = chatInputStateStringWithAppliedEntities(text, entities: entities)
                
                var state = state
                if let editMessageState = state.editMessageState {
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
    
    func editMessageMediaWithLegacySignals(_ signals: [Any]) {
        let _ = (legacyAssetPickerEnqueueMessages(context: self.context, account: self.context.account, signals: signals)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] messages in
            self?.editMessageMediaWithMessages(messages.map { $0.message })
        })
    }
    
    public func presentAttachmentBot(botId: PeerId, payload: String?, justInstalled: Bool) {
        self.attachmentController?.dismiss(animated: true, completion: nil)
        self.presentAttachmentMenu(subject: .bot(id: botId, payload: payload, justInstalled: justInstalled))
    }
    
    func displayPollSolution(solution: TelegramMediaPollResults.Solution, sourceNode: ASDisplayNode, isAutomatic: Bool) {
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
                if controller.text == .entities(text: solution.text, entities: solution.entities) {
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
        
        let tooltipScreen = TooltipScreen(context: self.context, account: self.context.account, sharedContext: self.context.sharedContext, text: .entities(text: solution.text, entities: solution.entities), icon: .animation(name: "anim_infotip", delay: 0.2, tintColor: nil), location: .top, shouldDismissOnTouch: { point, _ in
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
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        if let strongSelf = self, let peer = peer {
                            strongSelf.controllerInteraction?.openPeer(peer, .default, nil, .default)
                        }
                    })
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.peerMention(peerId, mention), nil)
                }
            case let .textMention(mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeerMention(mention, nil)
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
                if controller.text == .plain(text: psaText) {
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
        
        let tooltipScreen = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .entities(text: psaText, entities: psaEntities), icon: .animation(name: "anim_infotip", delay: 0.2, tintColor: nil), location: .top, displayDuration: .custom(10.0), shouldDismissOnTouch: { point, _ in
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
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        if let strongSelf = self, let peer = peer {
                            strongSelf.controllerInteraction?.openPeer(peer, .default, nil, .default)
                        }
                    })
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.peerMention(peerId, mention), nil)
                }
            case let .textMention(mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeerMention(mention, nil)
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
    
    func displayPsa(type: String, sourceNode: ASDisplayNode, isAutomatic: Bool) {
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
                if controller.text == .plain(text: psaText) {
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
        
        let tooltipScreen = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .entities(text: psaText, entities: psaEntities), icon: .animation(name: "anim_infotip", delay: 0.2, tintColor: nil), location: .top, displayDuration: .custom(10.0), shouldDismissOnTouch: { point, _ in
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
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        if let strongSelf = self, let peer = peer {
                            strongSelf.controllerInteraction?.openPeer(peer, .default, nil, .default)
                        }
                    })
                case .longTap:
                    strongSelf.controllerInteraction?.longTap(.peerMention(peerId, mention), nil)
                }
            case let .textMention(mention):
                switch action {
                case .tap:
                    strongSelf.controllerInteraction?.openPeerMention(mention, nil)
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
        
    func configurePollCreation(isQuiz: Bool? = nil) -> ViewController? {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return nil
        }
        return createPollController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: EnginePeer(peer), isQuiz: isQuiz, completion: { [weak self] poll in
            guard let strongSelf = self else {
                return
            }
            strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                guard let strongSelf = self else {
                    return
                }
                let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.collapseInput()
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil) }
                        })
                    }
                }, nil)
                let message: EnqueueMessage = .message(
                    text: "",
                    attributes: [],
                    inlineStickers: [:],
                    mediaReference: .standalone(media: TelegramMediaPoll(
                        pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: Int64.random(in: Int64.min ... Int64.max)),
                        publicity: poll.publicity,
                        kind: poll.kind,
                        text: poll.text.string,
                        textEntities: poll.text.entities,
                        options: poll.options,
                        correctAnswers: poll.correctAnswers,
                        results: poll.results,
                        isClosed: false,
                        deadlineTimeout: poll.deadlineTimeout
                    )),
                    threadId: strongSelf.chatLocation.threadId,
                    replyToMessageId: nil,
                    replyToStoryId: nil,
                    localGroupingKey: nil,
                    correlationId: nil,
                    bubbleUpEmojiOrStickersets: []
                )
                strongSelf.sendMessages([message.withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel)])
            })
        })
    }
    
    func transformEnqueueMessages(_ messages: [EnqueueMessage], postpone: Bool = false) -> [EnqueueMessage] {
        let silentPosting = self.presentationInterfaceState.interfaceState.silentPosting
        return transformEnqueueMessages(messages, silentPosting: silentPosting, postpone: postpone)
    }
    
    @discardableResult func dismissAllUndoControllers() -> UndoOverlayController? {
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
        
        return currentOverlayController
    }
    
    func displayPremiumStickerTooltip(file: TelegramMediaFile, message: Message) {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
        guard !premiumConfiguration.isPremiumDisabled else {
            return
        }
        
        let currentOverlayController: UndoOverlayController? = self.dismissAllUndoControllers()
        
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
            |> deliverOnMainQueue).startStandalone(next: { [weak self] stickerPack in
                if let strongSelf = self, case let .result(info, _, _) = stickerPack {
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: file, loop: true, title: info.title, text: strongSelf.presentationData.strings.Stickers_PremiumPackInfoText, undoText: strongSelf.presentationData.strings.Stickers_PremiumPackView, customAction: nil), elevatedLayout: false, action: { [weak self] action in
                        if let strongSelf = self, action == .undo {
                            let _ = strongSelf.controllerInteraction?.openMessage(message, OpenMessageParams(mode: .default))
                        }
                        return false
                    }), in: .current)
                }
            })
        }
    }
    
    func displayEmojiPackTooltip(file: TelegramMediaFile, message: Message) {
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
            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                stickerPackReference = packReference
                break
            }
        }
        
        if let stickerPackReference = stickerPackReference {
            self.presentEmojiList(references: [stickerPackReference], previewIconFile: file)
            
            /*let _ = (self.context.engine.stickers.loadedStickerPack(reference: stickerPackReference, forceActualized: false)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] stickerPack in
                if let strongSelf = self, case let .result(info, _, _) = stickerPack {
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .sticker(context: strongSelf.context, file: file, loop: true, title: nil, text: strongSelf.presentationData.strings.Stickers_EmojiPackInfoText(info.title).string, undoText: strongSelf.presentationData.strings.Stickers_PremiumPackView, customAction: nil), elevatedLayout: false, action: { [weak self] action in
                        if let strongSelf = self, action == .undo {
                            strongSelf.presentEmojiList(references: [stickerPackReference])
                        }
                        return false
                    }), in: .current)
                }
            })*/
        }
    }
    
    func displayDiceTooltip(dice: TelegramMediaDice) {
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
                if let self, canSendMessagesToChat(self.presentationInterfaceState), action == .undo {
                    self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                        guard let self else {
                            return
                        }
                        self.sendMessages([.message(text: "", attributes: [], inlineStickers: [:], mediaReference: AnyMediaReference.standalone(media: TelegramMediaDice(emoji: dice.emoji)), threadId: self.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])], postpone: postpone)
                    })
                }
                return false
            }), in: .current)
        }
    }
    
    func transformEnqueueMessages(_ messages: [EnqueueMessage], silentPosting: Bool, scheduleTime: Int32? = nil, postpone: Bool = false) -> [EnqueueMessage] {
        var defaultReplyMessageSubject: EngineMessageReplySubject?
        switch self.chatLocation {
        case .peer:
            break
        case let .replyThread(replyThreadMessage):
            if let effectiveMessageId = replyThreadMessage.effectiveMessageId {
                defaultReplyMessageSubject = EngineMessageReplySubject(messageId: effectiveMessageId, quote: nil)
            }
        case .customChatContents:
            break
        }
        
        return messages.map { message in
            var message = message
            
            if let defaultReplyMessageSubject = defaultReplyMessageSubject {
                switch message {
                case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
                    if replyToMessageId == nil {
                        message = .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: defaultReplyMessageSubject, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
                    }
                case .forward:
                    break
                }
            }
            
            if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.peerId == self.context.account.peerId {
                switch message {
                case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
                    message = .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId ?? replyThreadMessage.threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
                case .forward:
                    break
                }
            }
            
            return message.withUpdatedAttributes { attributes in
                var attributes = attributes
                
                if let sendPaidMessageStars = self.presentationInterfaceState.sendPaidMessageStars {
                    var effectivePostpone = postpone
                    for i in (0 ..< attributes.count).reversed() {
                        if let paidStarsMessageAttribute = attributes[i] as? PaidStarsMessageAttribute {
                            effectivePostpone = effectivePostpone || paidStarsMessageAttribute.postponeSending
                            attributes.remove(at: i)
                        }
                    }
                    attributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: effectivePostpone))
                }
                
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
                
                if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum {
                    attributes.removeAll(where: { $0 is SendAsMessageAttribute })
                    if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = self.presentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.sendSomething) {
                        if let sendAsPeerId = self.presentationInterfaceState.currentSendAsPeerId {
                            attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
                        } else {
                            attributes.append(SendAsMessageAttribute(peerId: linkedMonoforumId))
                        }
                    }
                }
                if let sendAsPeerId = self.presentationInterfaceState.currentSendAsPeerId {
                    if attributes.first(where: { $0 is SendAsMessageAttribute }) == nil {
                        attributes.append(SendAsMessageAttribute(peerId: sendAsPeerId))
                    }
                }
                if let sendMessageEffect = self.presentationInterfaceState.interfaceState.sendMessageEffect {
                    if attributes.first(where: { $0 is EffectMessageAttribute }) == nil {
                        attributes.append(EffectMessageAttribute(id: sendMessageEffect))
                    }
                }
                return attributes
            }
        }
    }
    
    func shouldDivertMessagesToScheduled(targetPeer: EnginePeer? = nil, messages: [EnqueueMessage]) -> Signal<Bool, NoError> {
        return .single(false)
    }
    
    func sendMessages(_ messages: [EnqueueMessage], media: Bool = false, postpone: Bool = false, commit: Bool = false) {
        if case let .customChatContents(customChatContents) = self.subject {
            customChatContents.enqueueMessages(messages: messages)
            return
        }
        
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        
        let _ = (self.shouldDivertMessagesToScheduled(messages: messages)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] shouldDivert in
            guard let self else {
                return
            }
            
            var messages = messages
            var shouldOpenScheduledMessages = false
            
            if shouldDivert {
                messages = messages.map { message -> EnqueueMessage in
                    return message.withUpdatedAttributes { attributes in
                        var attributes = attributes
                        attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                        attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(Date().timeIntervalSince1970) + 10 * 24 * 60 * 60))
                        return attributes
                    }
                }
                shouldOpenScheduledMessages = true
            }
            
            var isScheduledMessages = false
            if case .scheduledMessages = self.presentationInterfaceState.subject {
                isScheduledMessages = true
            }
            
            if commit || !isScheduledMessages {
                self.commitPurposefulAction()
                
                let _ = (enqueueMessages(account: self.context.account, peerId: peerId, messages: self.transformEnqueueMessages(messages, postpone: postpone))
                |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                    if let strongSelf = self, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                        strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }
                })
                
                donateSendMessageIntent(account: self.context.account, sharedContext: self.context.sharedContext, intentContext: .chat, peerIds: [peerId])
                
                self.updateChatPresentationInterfaceState(interactive: true, { $0.updatedShowCommands(false) })
                
                if !isScheduledMessages && shouldOpenScheduledMessages {
                    if let layoutActionOnViewTransitionAction = self.layoutActionOnViewTransitionAction {
                        self.layoutActionOnViewTransitionAction = nil
                        layoutActionOnViewTransitionAction()
                    }
                    
                    self.openScheduledMessages(force: true, completion: { _ in
                    })
                }
            } else {
                self.presentScheduleTimePicker(style: media ? .media : .default, dismissByTapOutside: false, completion: { [weak self] time in
                    if let strongSelf = self {
                        strongSelf.sendMessages(strongSelf.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: time, postpone: postpone), commit: true)
                    }
                })
            }
        })
    }
    
    func enqueueMediaMessages(fromGallery: Bool = false, signals: [Any]?, silentPosting: Bool, scheduleTime: Int32? = nil, parameters: ChatSendMessageActionSheetController.SendParameters? = nil, getAnimatedTransitionSource: ((String) -> UIView?)? = nil, completion: @escaping () -> Void = {}) {
        if let _ = self.presentationInterfaceState.sendPaidMessageStars {
            self.presentPaidMessageAlertIfNeeded(count: Int32(signals?.count ?? 1), forceDark: fromGallery, completion: { [weak self] postpone in
                self?.commitEnqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, postpone: postpone, parameters: parameters, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
            })
        } else {
            self.commitEnqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, parameters: parameters, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
        }
    }
    
    private func commitEnqueueMediaMessages(signals: [Any]?, silentPosting: Bool, scheduleTime: Int32? = nil, postpone: Bool = false, parameters: ChatSendMessageActionSheetController.SendParameters? = nil, getAnimatedTransitionSource: ((String) -> UIView?)? = nil, completion: @escaping () -> Void = {}) {
        self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(context: self.context, account: self.context.account, signals: signals!)
        |> deliverOnMainQueue).startStrict(next: { [weak self] items in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.shouldDivertMessagesToScheduled(messages: items.map(\.message))
            |> deliverOnMainQueue).startStandalone(next: { shouldDivert in
                guard let strongSelf = self else {
                    return
                }
            
                var completionImpl: (() -> Void)? = completion

                var usedCorrelationId: Int64?

                var mappedMessages: [EnqueueMessage] = []
                var addedTransitions: [(Int64, [String], () -> Void)] = []
                
                var groupedCorrelationIds: [Int64: Int64] = [:]
                
                var skipAddingTransitions = false
                
                if shouldDivert {
                    skipAddingTransitions = true
                }
                
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
                    
                    if let parameters {
                        if let effect = parameters.effect {
                            message = message.withUpdatedAttributes { attributes in
                                var attributes = attributes
                                attributes.append(EffectMessageAttribute(id: effect.id))
                                return attributes
                            }
                        }
                        if parameters.textIsAboveMedia {
                            message = message.withUpdatedAttributes { attributes in
                                var attributes = attributes
                                attributes.append(InvertMediaMessageAttribute())
                                return attributes
                            }
                        }
                    }
                    
                    mappedMessages.append(message)
                }
                        
                if addedTransitions.count > 1 {
                    var transitions: [(Int64, ChatMessageTransitionNodeImpl.Source, () -> Void)] = []
                    for (correlationId, uniqueIds, initiated) in addedTransitions {
                        var source: ChatMessageTransitionNodeImpl.Source?
                        if uniqueIds.count > 1 {
                            source = .groupedMediaInput(ChatMessageTransitionNodeImpl.Source.GroupedMediaInput(extractSnapshots: {
                                return uniqueIds.compactMap({ getAnimatedTransitionSource?($0) })
                            }))
                        } else if let uniqueId = uniqueIds.first {
                            source = .mediaInput(ChatMessageTransitionNodeImpl.Source.MediaInput(extractSnapshot: {
                                return getAnimatedTransitionSource?(uniqueId)
                            }))
                        }
                        if let source = source {
                            transitions.append((correlationId, source, initiated))
                        }
                    }
                    strongSelf.chatDisplayNode.messageTransitionNode.add(grouped: transitions)
                } else if let (correlationId, uniqueIds, initiated) = addedTransitions.first {
                    var source: ChatMessageTransitionNodeImpl.Source?
                    if uniqueIds.count > 1 {
                        source = .groupedMediaInput(ChatMessageTransitionNodeImpl.Source.GroupedMediaInput(extractSnapshots: {
                            return uniqueIds.compactMap({ getAnimatedTransitionSource?($0) })
                        }))
                    } else if let uniqueId = uniqueIds.first {
                        source = .mediaInput(ChatMessageTransitionNodeImpl.Source.MediaInput(extractSnapshot: {
                            return getAnimatedTransitionSource?(uniqueId)
                        }))
                    }
                    if let source = source {
                        strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: source, initiated: {
                            initiated()
                        })
                    }
                }
                
                if case let .customChatContents(customChatContents) = strongSelf.presentationInterfaceState.subject, let messageLimit = customChatContents.messageLimit {
                    if let originalHistoryView = strongSelf.chatDisplayNode.historyNode.originalHistoryView, originalHistoryView.entries.count + mappedMessages.count > messageLimit {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.Chat_QuickReplyMediaMessageLimitReachedText(Int32(messageLimit)), actions: [
                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {})
                        ]), in: .window(.root))
                        return
                    }
                }
                                                    
                let messages = strongSelf.transformEnqueueMessages(mappedMessages, silentPosting: silentPosting, scheduleTime: scheduleTime, postpone: postpone)
                let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.collapseInput()
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil) }
                        })
                    }
                    completionImpl?()
                }, usedCorrelationId)

                strongSelf.sendMessages(messages.map { $0.withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel) }, media: true)
                
                if let _ = scheduleTime {
                    completion()
                }
            })
        }))
    }

    func enqueueChatContextResult(_ results: ChatContextResultCollection, _ result: ChatContextResult, hideVia: Bool = false, closeMediaInput: Bool = false, silentPosting: Bool = false, resetTextInputState: Bool = true, postpone: Bool = false) {
        if !canSendMessagesToChat(self.presentationInterfaceState) {
            return
        }
        
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }

        let sendMessage: (Int32?) -> Void = { [weak self] scheduleTime in
            guard let self else {
                return
            }
            let replyMessageSubject = self.presentationInterfaceState.interfaceState.replyMessageSubject
            
            let sendPaidMessageStars = self.presentationInterfaceState.sendPaidMessageStars
            if self.context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: peerId, threadId: self.chatLocation.threadId, botId: results.botId, result: result, replyToMessageId: replyMessageSubject?.subjectModel, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime, sendPaidMessageStars: sendPaidMessageStars, postpone: postpone) {
                self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.collapseInput()
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            var state = state
                            if resetTextInputState {
                                state = state.updatedInterfaceState { interfaceState in
                                    var interfaceState = interfaceState
                                    interfaceState = interfaceState.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil)
                                    interfaceState = interfaceState.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: "")))
                                    interfaceState = interfaceState.withUpdatedComposeDisableUrlPreviews([])
                                    return interfaceState
                                }
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
        
        if isScheduledMessages {
            self.presentScheduleTimePicker(style: .default, dismissByTapOutside: false, completion: { time in
                sendMessage(time)
            })
        } else {
            sendMessage(nil)
        }
    }
    
    func firstLoadedMessageToListen() -> Message? {
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
    
    var raiseToListenActivateRecordingTimer: SwiftSignalKit.Timer?
    
    func activateRaiseGesture() {
        self.raiseToListenActivateRecordingTimer?.invalidate()
        self.raiseToListenActivateRecordingTimer = nil
        if let messageToListen = self.firstLoadedMessageToListen() {
            let _ = self.controllerInteraction?.openMessage(messageToListen, OpenMessageParams(mode: .default))
        } else {
            let timeout = (self.voicePlaylistDidEndTimestamp + 1.0) - CACurrentMediaTime()
            self.raiseToListenActivateRecordingTimer = SwiftSignalKit.Timer(timeout: max(0.0, timeout), repeat: false, completion: { [weak self] in
                self?.requestAudioRecorder(beginWithTone: true)
            }, queue: .mainQueue())
            self.raiseToListenActivateRecordingTimer?.start()
        }
    }
    
    func deactivateRaiseGesture() {
        self.raiseToListenActivateRecordingTimer?.invalidate()
        self.raiseToListenActivateRecordingTimer = nil
        self.dismissMediaRecorder(.pause)
    }
    
    func updateDownButtonVisibility() {
        let recordingMediaMessage = self.audioRecorderValue != nil || self.videoRecorderValue != nil || self.presentationInterfaceState.interfaceState.mediaDraftState != nil
        
        var ignoreSearchState = false
        if case let .customChatContents(contents) = self.subject, case .hashTagSearch = contents.kind {
            ignoreSearchState = true
        }
        
        if !ignoreSearchState, let search = self.presentationInterfaceState.search, let results = search.resultsState, results.messageIndices.count != 0 {
            var resultIndex: Int?
            if let currentId = results.currentId, let index = results.messageIndices.firstIndex(where: { $0.id == currentId }) {
                resultIndex = index
            } else {
                resultIndex = nil
            }
            if let resultIndex {
                self.chatDisplayNode.navigateButtons.directionButtonState = ChatHistoryNavigationButtons.DirectionState(
                    up: ChatHistoryNavigationButtons.ButtonState(isEnabled: resultIndex != 0),
                    down: ChatHistoryNavigationButtons.ButtonState(isEnabled: resultIndex != Int(results.totalCount) - 1 || (self.shouldDisplayDownButton && !recordingMediaMessage))
                )
            } else {
                self.chatDisplayNode.navigateButtons.directionButtonState = ChatHistoryNavigationButtons.DirectionState(
                    up: ChatHistoryNavigationButtons.ButtonState(isEnabled: false),
                    down: ChatHistoryNavigationButtons.ButtonState(isEnabled: false)
                )
            }
        } else {
            self.chatDisplayNode.navigateButtons.directionButtonState = ChatHistoryNavigationButtons.DirectionState(
                up: nil,
                down: (self.shouldDisplayDownButton && !recordingMediaMessage) ? ChatHistoryNavigationButtons.ButtonState(isEnabled: true) : nil
            )
        }
    }
    
    func updateTextInputState(_ textInputState: ChatTextInputState) {
        self.updateChatPresentationInterfaceState(interactive: false, { state in
            state.updatedInterfaceState({ state in
                state.withUpdatedComposeInputState(textInputState)
            })
        })
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
    
    func openStories(peerId: EnginePeer.Id, avatarHeaderNode: ChatMessageAvatarHeaderNodeImpl?, avatarNode: AvatarNode?) {
        if let avatarNode = avatarHeaderNode?.avatarNode ?? avatarNode {
            StoryContainerScreen.openPeerStories(context: self.context, peerId: peerId, parentController: self, avatarNode: avatarNode)
        }
    }
    
    func openPeerMention(_ name: String, navigation: ChatControllerInteractionNavigateToPeer = .default, sourceMessageId: MessageId? = nil, progress: Promise<Bool>? = nil) {
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            let disposable: MetaDisposable
            if let resolvePeerByNameDisposable = self.resolvePeerByNameDisposable {
                disposable = resolvePeerByNameDisposable
            } else {
                disposable = MetaDisposable()
                self.resolvePeerByNameDisposable = disposable
            }
            var resolveSignal = self.context.engine.peers.resolvePeerByName(name: name, referrer: nil, ageLimit: 10)
            
            var cancelImpl: (() -> Void)?
            let presentationData = self.presentationData
            let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                if progress != nil {
                    return ActionDisposable {
                    }
                } else {
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
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case .progress:
                    progress?.set(.single(true))
                case let .result(peer):
                    progress?.set(.single(false))
                    
                    if let peer {
                        var navigation = navigation
                        if case .default = navigation {
                            if case let .user(user) = peer, user.botInfo != nil {
                                navigation = .chat(textInputState: nil, subject: nil, peekData: nil)
                            }
                        }
                        self.openResolved(result: .peer(peer._asPeer(), navigation), sourceMessageId: sourceMessageId)
                    } else {
                        self.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: self.presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                }
            }))
        })
    }
    
    func openHashtag(_ hashtag: String, peerName: String?) {
        let _ = self.presentVoiceMessageDiscardAlert(action: {
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
                    if let peer = peer {
                        return .single(peer._asPeer())
                    } else {
                        return .single(nil)
                    }
                }
            } else if let peerId = self.chatLocation.peerId {
                resolveSignal = self.context.account.postbox.loadedPeerWithId(peerId)
                |> map(Optional.init)
            } else {
                resolveSignal = .single(nil)
            }
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
            |> delay(0.25, queue: Queue.mainQueue())
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
                if let self, !hashtag.isEmpty {
                    if let _ = peerName, peer == nil {
                        self.present(textAlertController(context: self.context, title: nil, text: self.presentationInterfaceState.strings.Resolve_ChannelErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: self.presentationInterfaceState.strings.Common_OK, action: {})]), in: .window(.root))
                        return
                    }
                    var publicPosts = false
                    if let peer = self.presentationInterfaceState.renderedPeer, let channel = peer.peer as? TelegramChannel, case .broadcast = channel.info, !(channel.addressName ?? "").isEmpty {
                        publicPosts = true
                    } else if case let .customChatContents(contents) = self.subject, case let .hashTagSearch(publicPostsValue) = contents.kind {
                        publicPosts = publicPostsValue
                    }
                    let searchController = HashtagSearchController(context: self.context, peer: peer.flatMap(EnginePeer.init), query: hashtag, mode: peerName != nil ? .chatOnly : .generic, publicPosts: peerName == nil && publicPosts)
                    self.effectiveNavigationController?.pushViewController(searchController)
                }
            }))
        })
    }
    
    func shareAccountContact() {
        let _ = (self.context.account.postbox.loadedPeerWithId(self.context.account.peerId)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] accountPeer in
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
            items.append(ActionSheetTextItem(title: strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumberConfirmation(formatPhoneNumber(context: strongSelf.context, number: phoneNumber), EnginePeer(peer).compactDisplayTitle).string))
            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumber, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                guard let strongSelf = self else {
                    return
                }
                let _ = (strongSelf.context.engine.contacts.acceptAndShareContact(peerId: peer.id)
                |> deliverOnMainQueue).startStandalone(error: { _ in
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
    
    func addPeerContact() {
        if let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramUser, let peerStatusSettings = self.presentationInterfaceState.contactStatus?.peerStatusSettings, let contactData = DeviceContactExtendedData(peer: EnginePeer(peer)) {
            self.present(context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: self.context), environment: ShareControllerAppEnvironment(sharedContext: self.context.sharedContext), subject: .create(peer: peer, contactData: contactData, isSharing: true, shareViaException: peerStatusSettings.contains(.addExceptionWhenAddingContact), completion: { [weak self] peer, stableId, contactData in
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
    
    func dismissPeerContactOptions() {
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
        })).startStrict())
    }
    
    func deleteChat(reportChatSpam: Bool) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        self.commitPurposefulAction()
        self.chatDisplayNode.historyNode.disconnect()
        let _ = self.context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: reportChatSpam).startStandalone()
        self.effectiveNavigationController?.popToRoot(animated: true)
        
        let _ = self.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: peerId, isBlocked: true).startStandalone()
    }
    
    func startBot(_ payload: String?) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        
        let startingBot = self.startingBot
        startingBot.set(true)
        self.editMessageDisposable.set((self.context.engine.messages.requestStartBot(botPeerId: peerId, payload: payload) |> deliverOnMainQueue |> afterDisposed({
            startingBot.set(false)
        })).startStrict(completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedBotStartPayload(nil) })
            }
        }))
    }
    
    func openResolved(result: ResolvedUrl, sourceMessageId: MessageId?, progress: Promise<Bool>? = nil, forceExternal: Bool = false, concealed: Bool = false, commit: @escaping () -> Void = {}) {
        let urlContext: OpenURLContext
        
        let message = sourceMessageId.flatMap { self.chatDisplayNode.historyNode.messageInCurrentHistoryView($0) }
        if let peerId = self.chatLocation.peerId {
            urlContext = .chat(peerId: peerId, message: message, updatedPresentationData: self.updatedPresentationData)
        } else {
            urlContext = .generic
        }
        self.context.sharedContext.openResolvedUrl(result, context: self.context, urlContext: urlContext, navigationController: self.effectiveNavigationController, forceExternal: forceExternal, forceUpdate: false, openPeer: { [weak self] peerId, navigation in
            guard let strongSelf = self else {
                return
            }
            
            let dismissWebAppControllers: () -> Void = {
            }
            
            switch navigation {
                case let .chat(textInputState, subject, peekData):
                    dismissWebAppControllers()
                    if case .peer(peerId.id) = strongSelf.chatLocation {
                        if let subject = subject, case let .message(messageSubject, _, timecode, _) = subject {
                            if case let .id(messageId) = messageSubject {
                                strongSelf.navigateToMessage(from: sourceMessageId, to: .id(messageId, NavigateToMessageParams(timestamp: timecode, quote: nil)))
                            }
                        } else {
                            self?.playShakeAnimation()
                        }
                    } else if let navigationController = strongSelf.effectiveNavigationController {
                        if case let .channel(channel) = peerId, channel.isForumOrMonoForum {
                            strongSelf.context.sharedContext.navigateToForumChannel(context: strongSelf.context, peerId: peerId.id, navigationController: navigationController)
                        } else {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), subject: subject, updateTextInputState: !peerId.id.isGroupOrChannel ? textInputState : nil, keepStack: .always, peekData: peekData))
                        }
                    }
                    commit()
                case .info:
                    dismissWebAppControllers()
                    strongSelf.navigationActionDisposable.set((strongSelf.context.account.postbox.loadedPeerWithId(peerId.id)
                    |> take(1)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                        if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                            if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                strongSelf.effectiveNavigationController?.pushViewController(infoController)
                            }
                        }
                    }))
                    commit()
                case let .withBotStartPayload(startPayload):
                    dismissWebAppControllers()
                    if case .peer(peerId.id) = strongSelf.chatLocation {
                        strongSelf.startBot(startPayload.payload)
                    } else if let navigationController = strongSelf.effectiveNavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), botStart: startPayload, keepStack: .always))
                    }
                    commit()
                case let .withAttachBot(attachBotStart):
                    dismissWebAppControllers()
                    if let navigationController = strongSelf.effectiveNavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), attachBotStart: attachBotStart))
                    }
                    commit()
                case let .withBotApp(botAppStart):
                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId.id))
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                        guard let self, let peer else {
                            return
                        }
                        if let botApp = botAppStart.botApp {
                            self.presentBotApp(botApp: botApp, botPeer: peer, payload: botAppStart.payload, mode: botAppStart.mode, concealed: concealed, commit: {
                                dismissWebAppControllers()
                                commit()
                            })
                        } else {
                            self.context.sharedContext.openWebApp(context: self.context, parentController: self, updatedPresentationData: self.updatedPresentationData, botPeer: peer, chatPeer: nil, threadId: nil, buttonText: "", url: "", simple: true, source: .generic, skipTermsOfService: false, payload: botAppStart.payload)
                            commit()
                        }
                    })
                default:
                    break
                }
        }, sendFile: nil, sendSticker: { [weak self] f, sourceView, sourceRect in
            return self?.interfaceInteraction?.sendSticker(f, true, sourceView, sourceRect, nil, []) ?? false
        }, sendEmoji: { [weak self] text, attribute in
            guard let self, canSendMessagesToChat(self.presentationInterfaceState) else {
                return
            }
            self.controllerInteraction?.sendEmoji(text, attribute, false)
        },
        requestMessageActionUrlAuth: { [weak self] subject in
            if case let .url(url) = subject {
                self?.controllerInteraction?.requestMessageActionUrlAuth(url, subject)
            }
        }, joinVoiceChat: { [weak self] peerId, invite, call in
            self?.joinGroupCall(peerId: peerId, invite: invite, activeCall: EngineGroupCallDescription(call))
        }, present: { [weak self] c, a in
            if c is UndoOverlayController {
                self?.present(c, in: .current)
            } else {
                self?.present(c, in: .window(.root), with: a)
            }
        }, dismissInput: { [weak self] in
            self?.chatDisplayNode.dismissInput()
        }, contentContext: nil, progress: progress, completion: nil)
    }
    
    func openUrl(
        _ url: String,
        concealed: Bool,
        forceExternal: Bool = false,
        forceUpdate: Bool = false,
        skipUrlAuth: Bool = false,
        skipConcealedAlert: Bool = false,
        message: Message? = nil,
        allowInlineWebpageResolution: Bool = false,
        progress: Promise<Bool>? = nil,
        commit: @escaping () -> Void = {}
    ) {
        self.commitPurposefulAction()
        
        if allowInlineWebpageResolution, let message, let webpage = message.media.first(where: { $0 is TelegramMediaWebpage }) as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.url == url {
            if content.instantPage != nil {
                if let navigationController = self.navigationController as? NavigationController {
                    switch instantPageType(of: content) {
                    case .album:
                        break
                    default:
                        progress?.set(.single(false))
                        if let controller = self.context.sharedContext.makeInstantPageController(context: self.context, message: message, sourcePeerType: nil) {
                            navigationController.pushViewController(controller)
                        }
                        return
                    }
                }
            } else if content.file == nil, (content.image == nil || content.isMediaLargeByDefault == true || content.isMediaLargeByDefault == nil), let embedUrl = content.embedUrl, !embedUrl.isEmpty {
                progress?.set(.single(false))
                if let controllerInteraction = self.controllerInteraction {
                    if controllerInteraction.openMessage(message, OpenMessageParams(mode: .default)) {
                        return
                    }
                }
            }
        }
        
        let _ = self.presentVoiceMessageDiscardAlert(action: { [weak self] in
            guard let self else {
                return
            }
            let disposable = openUserGeneratedUrl(context: self.context, peerId: self.contentData?.state.peerView?.peerId, url: url, concealed: concealed, skipUrlAuth: skipUrlAuth, skipConcealedAlert: skipConcealedAlert, present: { [weak self] c in
                self?.present(c, in: .window(.root))
            }, openResolved: { [weak self] resolved in
                self?.openResolved(result: resolved, sourceMessageId: message?.id, progress: progress, forceExternal: forceExternal, concealed: concealed, commit: commit)
            }, progress: progress)
            self.navigationActionDisposable.set(disposable)
        }, performAction: true)
    }
    
    func openUrlIn(_ url: String) {
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
            guard let strongSelf = self, !imageItems.isEmpty else {
                return
            }
            let images = imageItems as! [UIImage]
            
            strongSelf.chatDisplayNode.updateDropInteraction(isActive: false)
            if images.count == 1, let image = images.first {
                let maxSide = max(image.size.width, image.size.height)
                if maxSide.isZero {
                    return
                }
                let aspectRatio = min(image.size.width, image.size.height) / maxSide
                if (imageHasTransparency(image) && aspectRatio > 0.2) {
                    strongSelf.enqueueStickerImage(image, isMemoji: false)
                    return
                }
            }
            strongSelf.chatDisplayNode.updateDropInteraction(isActive: false)
            strongSelf.displayPasteMenu(images.map { .image($0) })
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
    
    public func beginReportSelection(reason: NavigateToChatControllerParams.ReportReason) {
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedReportReason(ChatPresentationInterfaceState.ReportReasonData(title: reason.title, option: reason.option, message: reason.message)).updatedInterfaceState { $0.withUpdatedSelectedMessages([]) } })
    }
    
    func displayMediaRecordingTooltip() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        if self.birthdayTooltipController != nil {
            return
        }
        
        let rect: CGRect? = self.chatDisplayNode.frameForInputActionButton()
        
        let updatedMode: ChatTextInputMediaRecordingButtonMode = self.presentationInterfaceState.interfaceState.mediaRecordingMode
        
        let text: String
        
        var canSwitch = true
        if let channel = peer as? TelegramChannel {
            if channel.hasBannedPermission(.banSendVoice) != nil && channel.hasBannedPermission(.banSendInstantVideos) != nil {
                canSwitch = false
            } else if channel.hasBannedPermission(.banSendVoice) != nil {
                if channel.hasBannedPermission(.banSendInstantVideos) == nil {
                    canSwitch = false
                }
            } else if channel.hasBannedPermission(.banSendInstantVideos) != nil {
                if channel.hasBannedPermission(.banSendVoice) == nil {
                    canSwitch = false
                }
            }
        } else if let group = peer as? TelegramGroup {
            if group.hasBannedPermission(.banSendVoice) && group.hasBannedPermission(.banSendInstantVideos) {
                canSwitch = false
            } else if group.hasBannedPermission(.banSendVoice) {
                if !group.hasBannedPermission(.banSendInstantVideos) {
                    canSwitch = false
                }
            } else if group.hasBannedPermission(.banSendInstantVideos) {
                if !group.hasBannedPermission(.banSendVoice) {
                    canSwitch = false
                }
            }
        }
        
        if updatedMode == .audio {
            if canSwitch {
                text = self.presentationData.strings.Conversation_HoldForAudio
            } else {
                text = self.presentationData.strings.Conversation_HoldForAudioOnly
            }
        } else {
            if canSwitch {
                text = self.presentationData.strings.Conversation_HoldForVideo
            } else {
                text = self.presentationData.strings.Conversation_HoldForVideoOnly
            }
        }
        
        self.silentPostTooltipController?.dismiss()
        
        if let tooltipController = self.mediaRecordingModeTooltipController {
            tooltipController.updateContent(.text(text), animated: true, extendTimer: true)
        } else if let rect = rect {
            let tooltipController = TooltipController(content: .text(text), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize, padding: 2.0)
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
    
    func displaySendWhenOnlineTooltip() {
        guard let rect = self.chatDisplayNode.frameForInputActionButton(), self.effectiveNavigationController?.topViewController === self, let peerId = self.chatLocation.peerId else {
            return
        }
        let inputText = self.presentationInterfaceState.interfaceState.effectiveInputState.inputText.string
        guard !inputText.isEmpty else {
            return
        }
        
        self.sendingOptionsTooltipController?.dismiss()
        
        let _ = (ApplicationSpecificNotice.getSendWhenOnlineTip(accountManager: self.context.sharedContext.accountManager)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
            if let strongSelf = self, counter < 3 {
                let _ = (strongSelf.context.account.viewTracker.peerView(peerId)
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] peerView in
                    guard let strongSelf = self, let peer = peerViewMainPeer(peerView) else {
                        return
                    }
                    var sendWhenOnlineAvailable = false
                    if peer.id != strongSelf.context.account.peerId, let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case let .present(until) = presence.status, until != .max {
                        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        let (_, _, _, hours, _) = getDateTimeComponents(timestamp: currentTime)
                        if currentTime > until + 60 * 30 && hours >= 0 && hours <= 8 {
                            sendWhenOnlineAvailable = true
                        }
                    }
                    if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000 {
                        sendWhenOnlineAvailable = false
                    }
                    
                    if sendWhenOnlineAvailable {
                        let _ = ApplicationSpecificNotice.incrementSendWhenOnlineTip(accountManager: strongSelf.context.sharedContext.accountManager).startStandalone()
                        
                        let tooltipController = TooltipController(content: .text(strongSelf.presentationData.strings.Conversation_SendWhenOnlineTooltip), baseFontSize: strongSelf.presentationData.listsFontSize.baseDisplaySize, timeout: 3.0, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true, padding: 2.0)
                        strongSelf.sendingOptionsTooltipController = tooltipController
                        tooltipController.dismissed = { [weak self, weak tooltipController] _ in
                            if let strongSelf = self, let tooltipController = tooltipController, strongSelf.sendingOptionsTooltipController === tooltipController {
                                strongSelf.sendingOptionsTooltipController = nil
                            }
                        }
                        strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                            if let strongSelf = self {
                                return (strongSelf.chatDisplayNode, rect)
                            }
                            return nil
                        }))
                    }
                })
            }
        })
    }
    
    func displaySendingOptionsTooltip() {
        guard let rect = self.chatDisplayNode.frameForInputActionButton(), self.effectiveNavigationController?.topViewController === self else {
            return
        }
        self.sendingOptionsTooltipController?.dismiss()
        let tooltipController = TooltipController(content: .text(self.presentationData.strings.Conversation_SendingOptionsTooltip), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize, timeout: 3.0, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true, padding: 2.0)
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
    
    func displayEmojiTooltip() {
        guard let rect = self.chatDisplayNode.frameForEmojiButton(), self.effectiveNavigationController?.topViewController === self else {
            return
        }
        self.emojiTooltipController?.dismiss()
        let tooltipController = TooltipController(content: .text(self.presentationData.strings.Conversation_EmojiTooltip), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize, timeout: 3.0, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true, padding: 2.0)
        self.emojiTooltipController = tooltipController
        tooltipController.dismissed = { [weak self, weak tooltipController] _ in
            if let strongSelf = self, let tooltipController = tooltipController, strongSelf.emojiTooltipController === tooltipController {
                strongSelf.emojiTooltipController = nil
            }
        }
        self.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
            if let strongSelf = self {
                return (strongSelf.chatDisplayNode, rect.offsetBy(dx: 0.0, dy: -3.0))
            }
            return nil
        }))
    }
    
    func displayGroupEmojiTooltip() {
        guard let rect = self.chatDisplayNode.frameForEmojiButton(), self.effectiveNavigationController?.topViewController === self else {
            return
        }
        guard let peerId = self.chatLocation.peerId, let emojiPack = (self.contentData?.state.peerView?.cachedData as? CachedChannelData)?.emojiPack, let thumbnailFileId = emojiPack.thumbnailFileId else {
            return
        }
        
        let _ = (ApplicationSpecificNotice.groupEmojiPackSuggestion(accountManager: self.context.sharedContext.accountManager, peerId: peerId)
        |> deliverOnMainQueue).start(next: { [weak self] counter in
            guard let self, counter == 0 else {
                return
            }
            
            let _ = (self.context.engine.stickers.resolveInlineStickers(fileIds: [thumbnailFileId])
            |> deliverOnMainQueue).start(next: { [weak self] files in
                guard let self, let emojiFile = files.values.first else {
                    return
                }
                
                let textFont = Font.regular(self.presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0)
                let boldTextFont = Font.bold(self.presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0)
                let textColor = UIColor.white
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: textColor), linkAttribute: { _ in
                    return nil
                })
                
                let text = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(self.presentationData.strings.Chat_GroupEmojiTooltip(emojiPack.title).string, attributes: markdownAttributes))
                
                let range = (text.string as NSString).range(of: "#")
                if range.location != NSNotFound {
                    text.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiFile.fileId.id, file: emojiFile), range: range)
                }
                
                let tooltipScreen = TooltipScreen(
                    context: self.context,
                    account: self.context.account,
                    sharedContext: self.context.sharedContext,
                    text: .attributedString(text: text),
                    location: .point(rect.offsetBy(dx: 0.0, dy: -3.0), .bottom),
                    displayDuration: .default,
                    cornerRadius: 10.0,
                    shouldDismissOnTouch: { _, _ in
                        return .ignore
                    }
                )
                self.present(tooltipScreen, in: .current)
                self.emojiPackTooltipController = tooltipScreen
                
                let _ = ApplicationSpecificNotice.incrementGroupEmojiPackSuggestion(accountManager: self.context.sharedContext.accountManager, peerId: peerId).startStandalone()
            })
        })
    }
    
    private var didDisplayBirthdayTooltip = false
    func displayBirthdayTooltip() {
        guard !self.didDisplayBirthdayTooltip else {
            return
        }
        if let birthday = (self.contentData?.state.peerView?.cachedData as? CachedUserData)?.birthday {
            PeerInfoScreenImpl.preloadBirthdayAnimations(context: self.context, birthday: birthday)
        }
        guard let rect = self.chatDisplayNode.frameForGiftButton(), self.effectiveNavigationController?.topViewController === self, let peer = self.presentationInterfaceState.renderedPeer?.peer.flatMap({ EnginePeer($0) }) else {
            return
        }
        
        self.didDisplayBirthdayTooltip = true
        
        let _ = (ApplicationSpecificNotice.dismissedBirthdayPremiumGiftTip(accountManager: self.context.sharedContext.accountManager, peerId: peer.id)
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] timestamp in
            if let self {
                let currentTime = Int32(Date().timeIntervalSince1970)
                if let timestamp, currentTime < timestamp + 60 * 60 * 24 {
                    return
                }
                
                let peerName = peer.compactDisplayTitle
                let text = self.presentationData.strings.Chat_BirthdayTooltip(peerName, peerName).string
                
                let tooltipScreen = TooltipScreen(
                    context: self.context,
                    account: self.context.account,
                    sharedContext: self.context.sharedContext,
                    text: .markdown(text: text),
                    location: .point(rect.offsetBy(dx: 0.0, dy: -3.0), .bottom),
                    displayDuration: .custom(6.0),
                    cornerRadius: 10.0,
                    shouldDismissOnTouch: { _, _ in
                        return .dismiss(consume: false)
                    }
                )
                self.birthdayTooltipController = tooltipScreen
                Queue.mainQueue().after(0.35) {
                    self.present(tooltipScreen, in: .current)
                }
                
                let _ = ApplicationSpecificNotice.incrementDismissedBirthdayPremiumGiftTip(accountManager: self.context.sharedContext.accountManager, peerId: peer.id, timestamp: Int32(Date().timeIntervalSince1970)).startStandalone()
            }
        })
    }
    
    func displayChecksTooltip() {
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
    
    func displayProcessingVideoTooltip(messageId: EngineMessage.Id) {
        self.checksTooltipController?.dismiss()
        
        var latestNode: ChatMessageItemView?
        self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                var found = false
                for (message, _) in item.content {
                    if message.id == messageId {
                        found = true
                        break
                    }
                }
                if !found {
                    return
                }
                latestNode = itemNode
            }
        }
        
        if let itemNode = latestNode, let statusNode = itemNode.getStatusNode() {
            let bounds = statusNode.view.convert(statusNode.view.bounds, to: self.chatDisplayNode.view)
            let location = CGPoint(x: bounds.midX, y: bounds.minY - 8.0)
            
            let tooltipController = TooltipController(content: .text(self.presentationData.strings.Chat_MessageTooltipVideoProcessing), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize, balancedTextLayout: true, isBlurred: true, timeout: 4.5, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
            self.checksTooltipController = tooltipController
            tooltipController.dismissed = { [weak self, weak tooltipController] _ in
                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.checksTooltipController === tooltipController {
                    strongSelf.checksTooltipController = nil
                }
            }
            
            let _ = self.chatDisplayNode.messageTransitionNode.addCustomOffsetHandler(itemNode: itemNode, update: { [weak tooltipController] offset, transition in
                guard let tooltipController, tooltipController.isNodeLoaded else {
                    return false
                }
                guard let containerView = tooltipController.view else {
                    return false
                }
                containerView.bounds = containerView.bounds.offsetBy(dx: 0.0, dy: -offset)
                transition.animateOffsetAdditive(layer: containerView.layer, offset: offset)
                
                return true
            })
            
            self.present(tooltipController, in: .current, with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                guard let self else {
                    return nil
                }
                return (self.chatDisplayNode, CGRect(origin: location, size: CGSize()))
            }, sourceRectIsGlobal: true))
        }
    }
    
    func dismissAllTooltips() {
        self.emojiTooltipController?.dismiss()
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
            if let controller = controller as? QuickShareToastScreen {
                controller.dismissWithCommitAction()
            }
            if let controller = controller as? TooltipScreen, !controller.alwaysVisible {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            if let controller = controller as? TooltipScreen, !controller.alwaysVisible {
                controller.dismiss()
            }
            return true
        })
    }
    
    func commitPurposefulAction() {
        if let purposefulAction = self.purposefulAction {
            self.purposefulAction = nil
            purposefulAction()
        }
    }
    
    public override var keyShortcuts: [KeyShortcut] {
        return self.keyShortcutsInternal
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
                if let result = itemNode.transitionNode(id: messageId, media: media, adjustRect: false) {
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
    
    public func activateInput(type: ChatControllerActivateInput) {
        if self.didAppear {
            switch type {
            case .text:
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    return state.updatedInputMode({ _ in
                        switch type {
                        case .text:
                            return .text
                        case .entityInput:
                            return .media(mode: .other, expanded: nil, focused: false)
                        }
                    })
                })
            case .entityInput:
                self.chatDisplayNode.openStickers(beginWithEmoji: true)
            }
        } else {
            self.scheduledActivateInput = type
        }
    }
    
    func clearInputText() {
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
    
    func updateSlowmodeStatus() {
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
                    |> deliverOnMainQueue).startStrict(completed: { [weak self] in
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
    
    func openScheduledMessages(force: Bool = false, completion: @escaping (ChatControllerImpl) -> Void = { _ in }) {
        guard let navigationController = self.effectiveNavigationController else {
            return
        }
        if navigationController.topViewController == self || force {
        } else {
            return
        }
        
        var mappedChatLocation = self.chatLocation
        if case let .replyThread(message) = self.chatLocation, message.peerId == self.context.account.peerId {
            mappedChatLocation = .peer(id: self.context.account.peerId)
        }
        
        let controller = ChatControllerImpl(context: self.context, chatLocation: mappedChatLocation, subject: .scheduledMessages)
        controller.navigationPresentation = .modal
        navigationController.pushViewController(controller, completion: { [weak controller] in
            let _ = controller
            /*if let controller {
                completion(controller)
            }*/
        })
        completion(controller)
    }
    
    func openPinnedMessages(at messageId: MessageId?) {
        let _ = self.presentVoiceMessageDiscardAlert(action: { [weak self] in
            guard let self, let navigationController = self.effectiveNavigationController, navigationController.topViewController == self else {
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
        })
    }
    
    func performUpdatedClosedPinnedMessageId(pinnedMessageId: MessageId) {
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
    
    func performRequestedUnpinAllMessages(count: Int, pinnedMessageId: MessageId) {
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
                        let _ = (strongSelf.context.engine.messages.requestUnpinAllMessages(peerId: peerId, threadId: strongSelf.chatLocation.threadId)
                        |> deliverOnMainQueue).startStandalone(error: { _ in
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
    
    func presentScheduleTimePicker(style: ChatScheduleTimeControllerStyle = .default, selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        let _ = (self.context.account.viewTracker.peerView(peerId)
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peerView in
            guard let strongSelf = self, let peer = peerViewMainPeer(peerView) else {
                return
            }
            var sendWhenOnlineAvailable = false
            if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case .present = presence.status {
                sendWhenOnlineAvailable = true
            }
            if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000 {
                sendWhenOnlineAvailable = false
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
    
    func presentTimerPicker(style: ChatTimerScreenStyle = .default, selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        guard case .peer = self.chatLocation else {
            return
        }
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, style: style, currentTime: selectedTime, dismissByTapOutside: dismissByTapOutside, completion: { time in
            completion(time)
        })
        self.chatDisplayNode.dismissInput()
        self.present(controller, in: .window(.root))
    }
    
    func presentVoiceMessageDiscardAlert(action: @escaping () -> Void = {}, alertAction: (() -> Void)? = nil, delay: Bool = false, performAction: Bool = true) -> Bool {
        if let _ = self.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
            alertAction?()
            Queue.mainQueue().after(delay ? 0.2 : 0.0) {
                self.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: self.presentationData.strings.Conversation_DiscardVoiceMessageDescription, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Conversation_DiscardVoiceMessageAction, action: { [weak self] in
                    self?.stopMediaRecorder()
                    Queue.mainQueue().after(0.1) {
                        action()
                    }
                })]), in: .window(.root))
            }
            
            return true
        } else if performAction {
            action()
        }
        return false
    }
    
    func presentRecordedVoiceMessageDiscardAlert(action: @escaping () -> Void = {}, alertAction: (() -> Void)? = nil, delay: Bool = false, performAction: Bool = true) -> Bool {
        if let _ = self.presentationInterfaceState.interfaceState.mediaDraftState {
            alertAction?()
            Queue.mainQueue().after(delay ? 0.2 : 0.0) {
                self.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: self.presentationData.strings.Conversation_DiscardRecordedVoiceMessageDescription, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Conversation_DiscardRecordedVoiceMessageAction, action: { [weak self] in
                    self?.stopMediaRecorder()
                    Queue.mainQueue().after(0.1) {
                        action()
                    }
                })]), in: .window(.root))
            }
            
            return true
        } else if performAction {
            action()
        }
        return false
    }
    
    func presentAutoremoveSetup() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        let controller = ChatTimerScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, style: .default, mode: .autoremove, currentTime: self.presentationInterfaceState.autoremoveTimeout, dismissByTapOutside: true, completion: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            let _ = (strongSelf.context.engine.peers.setChatMessageAutoremoveTimeoutInteractively(peerId: peer.id, timeout: value == 0 ? nil : value)
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
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .autoDelete(isOn: isOn, title: nil, text: text, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
            })
        })
        self.chatDisplayNode.dismissInput()
        self.present(controller, in: .window(.root))
    }
    
    func presentChatRequestAdminInfo() {
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
    
    var crossfading = false
    func presentCrossfadeSnapshot() {
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
    
    public func hintPlayNextOutgoingGift() {
        self.controllerInteraction?.playNextOutgoingGift = true
    }
    
    var effectiveNavigationController: NavigationController? {
        if let navigationController = self.navigationController as? NavigationController {
            return navigationController
        } else if case let .inline(navigationController) = self.presentationInterfaceState.mode {
            return navigationController
        } else if case let .overlay(navigationController) = self.presentationInterfaceState.mode {
            return navigationController
        } else {
            if let navigationController = self.customNavigationController {
                return navigationController
            }
            return nil
        }
    }
    
    public func activateSearch(domain: ChatSearchDomain = .everything, query: String = "") {
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
    
    public func playShakeAnimation() {
        if self.shakeFeedback == nil {
            self.shakeFeedback = HapticFeedback()
        }
        self.shakeFeedback?.error()
        
        self.chatDisplayNode.historyNodeContainer.layer.addShakeAnimation(amplitude: -6.0, decay: true)
    }
    
    public func updatePushedTransition(_ fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        if !transition.isAnimated {
            self.chatDisplayNode.historyNode.layer.removeAnimation(forKey: "sublayerTransform")
        }
        let scale: CGFloat = 1.0 - 0.06 * fraction
        transition.updateSublayerTransformScale(node: self.chatDisplayNode.historyNode, scale: scale)
    }
    
    func restrictedSendingContentsText() -> String {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return self.presentationData.strings.Chat_SendNotAllowedText
        }
        
        var itemList: [String] = []
        
        let order: [TelegramChatBannedRightsFlags] = [
            .banSendText,
            .banSendPhotos,
            .banSendVideos,
            .banSendVoice,
            .banSendInstantVideos,
            .banSendFiles,
            .banSendMusic,
            .banSendStickers
        ]
        
        for right in order {
            if let channel = peer as? TelegramChannel {
                if channel.hasBannedPermission(right) != nil {
                    continue
                }
            } else if let group = peer as? TelegramGroup {
                if group.hasBannedPermission(right) {
                    continue
                }
            }
            
            var title: String?
            switch right {
            case .banSendText:
                title = self.presentationData.strings.Chat_SendAllowedContentTypeText
            case .banSendPhotos:
                title = self.presentationData.strings.Chat_SendAllowedContentTypePhoto
            case .banSendVideos:
                title = self.presentationData.strings.Chat_SendAllowedContentTypeVideo
            case .banSendVoice:
                title = self.presentationData.strings.Chat_SendAllowedContentTypeVoiceMessage
            case .banSendInstantVideos:
                title = self.presentationData.strings.Chat_SendAllowedContentTypeVideoMessage
            case .banSendFiles:
                title = self.presentationData.strings.Chat_SendAllowedContentTypeFile
            case .banSendMusic:
                title = self.presentationData.strings.Chat_SendAllowedContentTypeMusic
            case .banSendStickers:
                title = self.presentationData.strings.Chat_SendAllowedContentTypeSticker
            default:
                break
            }
            if let title {
                itemList.append(title)
            }
        }
        
        if itemList.isEmpty {
            return self.presentationData.strings.Chat_SendNotAllowedText
        }
        
        var itemListString = ""
        if #available(iOS 13.0, *) {
            let listFormatter = ListFormatter()
            listFormatter.locale = localeWithStrings(presentationData.strings)
            if let value = listFormatter.string(from: itemList) {
                itemListString = value
            }
        }
        
        if itemListString.isEmpty {
            for i in 0 ..< itemList.count {
                if i != 0 {
                    itemListString.append(", ")
                }
                itemListString.append(itemList[i])
            }
        }
        
        return self.presentationData.strings.Chat_SendAllowedContentText(itemListString).string
    }
    
    func updateNextChannelToReadVisibility() {
        guard let contentData = self.contentData else {
            return
        }
        self.chatDisplayNode.historyNode.offerNextChannelToRead = contentData.state.offerNextChannelToRead && self.presentationInterfaceState.interfaceState.selectionState == nil
    }
    
    func displayGiveawayStatusInfo(messageId: EngineMessage.Id, giveawayInfo: PremiumGiveawayInfo) {
        presentGiveawayInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, messageId: messageId, giveawayInfo: giveawayInfo, present: { [weak self] c in
            guard let self else {
                return
            }
            self.present(c, in: .window(.root))
        }, openLink: { [weak self] slug in
            guard let self else {
                return
            }
            self.openResolved(result: .premiumGiftCode(slug: slug), sourceMessageId: messageId)
        })
    }
    
    public func transferScrollingVelocity(_ velocity: CGFloat) {
        self.chatDisplayNode.historyNode.transferVelocity(velocity)
    }
    
    public func performScrollToTop() -> Bool {
        let offset = self.chatDisplayNode.historyNode.visibleContentOffset()
        switch offset {
        case let .known(value) where value <= CGFloat.ulpOfOne:
            return false
        default:
            self.chatDisplayNode.historyNode.scrollToEndOfHistory()
            return true
        }
    }
    
    private var updateChatLocationThreadDisposable: Disposable?
    private var isUpdatingChatLocationThread: Bool = false
    var currentChatSwitchDirection: ChatControllerAnimateInnerChatSwitchDirection?
    
    public func updateChatLocationThread(threadId: Int64?, animationDirection: ChatControllerAnimateInnerChatSwitchDirection? = nil) {
        if self.isUpdatingChatLocationThread {
            return
        }
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        if self.chatLocation.threadId == threadId {
            return
        }
        guard let peer = self.presentationInterfaceState.renderedPeer?.chatMainPeer else {
            return
        }
        
        self.saveInterfaceState()
        
        let updatedChatLocation: ChatLocation
        if let threadId {
            var isMonoforum = false
            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum) {
                isMonoforum = true
            }
            
            updatedChatLocation = .replyThread(message: ChatReplyThreadMessage(
                peerId: peerId,
                threadId: threadId,
                channelMessageId: nil,
                isChannelPost: false,
                isForumPost: true,
                isMonoforumPost: isMonoforum,
                maxMessage: nil,
                maxReadIncomingMessageId: nil,
                maxReadOutgoingMessageId: nil,
                unreadCount: 0,
                initialFilledHoles: IndexSet(),
                initialAnchor: .automatic,
                isNotAvailable: false
            ))
        } else {
            updatedChatLocation = .peer(id: peerId)
        }
        
        let navigationSnapshot = self.chatTitleView?.prepareSnapshotState()
        let avatarSnapshot = self.chatInfoNavigationButton?.buttonItem.customDisplayNode?.view.window != nil ? (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.prepareSnapshotState() : nil
        
        let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        let historyNode = self.chatDisplayNode.createHistoryNodeForChatLocation(chatLocation: updatedChatLocation, chatLocationContextHolder: chatLocationContextHolder)
        self.isUpdatingChatLocationThread = true
        self.reloadChatLocation(chatLocation: updatedChatLocation, chatLocationContextHolder: chatLocationContextHolder, historyNode: historyNode, apply: { [weak self, weak historyNode] apply in
            guard let self, let historyNode else {
                return
            }
            
            self.currentChatSwitchDirection = animationDirection
            self.chatLocation = updatedChatLocation
            self.chatDisplayNode.prepareSwitchToChatLocation(historyNode: historyNode, animationDirection: animationDirection)
            
            apply(true)
            
            if let navigationSnapshot, let animationDirection {
                let mappedAnimationDirection: ChatTitleView.AnimateFromSnapshotDirection
                switch animationDirection {
                case .up:
                    mappedAnimationDirection = .up
                case .down:
                    mappedAnimationDirection = .down
                case .left:
                    mappedAnimationDirection = .left
                case .right:
                    mappedAnimationDirection = .right
                }
                
                self.chatTitleView?.animateFromSnapshot(navigationSnapshot, direction: mappedAnimationDirection)
            }
            
            if let avatarSnapshot, self.chatInfoNavigationButton?.buttonItem.customDisplayNode?.view.window != nil {
                (self.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.animateFromSnapshot(avatarSnapshot)
            }
            
            self.currentChatSwitchDirection = nil
            self.isUpdatingChatLocationThread = false
        })
    }
    
    public var contentContainerNode: ASDisplayNode {
        return self.chatDisplayNode.contentContainerNode
    }
}
