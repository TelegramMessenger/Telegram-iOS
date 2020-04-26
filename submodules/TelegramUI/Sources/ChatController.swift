import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
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
import ReactionSelectionNode
import AvatarNode
import MessageReactionListUI
import AppBundle
#if ENABLE_WALLET
import WalletUI
import WalletUrl
#endif
import LocalizedPeerData
import PhoneNumberFormat
import SettingsUI
import UrlWhitelist
import TelegramIntents
import TooltipUI
import StatisticsUI

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
    //case group(Promise<ChatListTopPeersView>)
}

private enum ChatRecordingActivity {
    case voice
    case instantVideo
    case none
}

public enum NavigateToMessageLocation {
    case id(MessageId)
    case index(MessageIndex)
    case upperBound(PeerId)
    
    var messageId: MessageId? {
        switch self {
            case let .id(id):
                return id
            case let .index(index):
                return index.id
            case .upperBound:
                return nil
        }
    }
    
    var peerId: PeerId {
        switch self {
            case let .id(id):
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

let ChatControllerCount = Atomic<Int32>(value: 0)

public final class ChatControllerImpl: TelegramBaseController, ChatController, GalleryHiddenMediaTarget, UIDropInteractionDelegate {
    private var validLayout: ContainerViewLayout?
    
    public weak var parentController: ViewController?
    
    public var peekActions: ChatControllerPeekActions = .standard
    private var didSetup3dTouch: Bool = false
    
    private let context: AccountContext
    public let chatLocation: ChatLocation
    public let subject: ChatControllerSubject?
    private let botStart: ChatControllerInitialBotStart?
    
    private let peerDisposable = MetaDisposable()
    private let navigationActionDisposable = MetaDisposable()
    private var networkStateDisposable: Disposable?
    
    private let messageIndexDisposable = MetaDisposable()
    
    private let _chatLocationInfoReady = Promise<Bool>()
    private var didSetChatLocationInfoReady = false
    private let chatLocationInfoData: ChatLocationInfoData
    
    private var presentationInterfaceState: ChatPresentationInterfaceState
    
    private var chatTitleView: ChatTitleView?
    private var leftNavigationButton: ChatNavigationButton?
    private var rightNavigationButton: ChatNavigationButton?
    private var chatInfoNavigationButton: ChatNavigationButton?
    
    private var peerView: PeerView?
    
    private var historyStateDisposable: Disposable?
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    private let temporaryHiddenGalleryMediaDisposable = MetaDisposable()
    
    private var controllerInteraction: ChatControllerInteraction?
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

    private let editingMessage = ValuePromise<Float?>(nil, ignoreRepeated: true)
    private let startingBot = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let unblockingPeer = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let searching = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let searchResult = Promise<(SearchMessagesResult, SearchMessagesState, SearchMessagesLocation)?>()
    private let loadingMessage = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    private var preloadHistoryPeerId: PeerId?
    private let preloadHistoryPeerIdDisposable = MetaDisposable()
    
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
    private var chatUnreadMentionCountDisposable: Disposable?
    private var peerInputActivitiesDisposable: Disposable?
    
    private var recentlyUsedInlineBotsValue: [Peer] = []
    private var recentlyUsedInlineBotsDisposable: Disposable?
    
    private var unpinMessageDisposable: MetaDisposable?
    
    private let typingActivityPromise = Promise<Bool>(false)
    private var inputActivityDisposable: Disposable?
    private var recordingActivityValue: ChatRecordingActivity = .none
    private let recordingActivityPromise = ValuePromise<ChatRecordingActivity>(.none, ignoreRepeated: true)
    private var recordingActivityDisposable: Disposable?
    private var acquiredRecordingActivityDisposable: Disposable?
    
    private var searchDisposable: MetaDisposable?
    
    private var historyNavigationStack = ChatHistoryNavigationStack()
    
    public let canReadHistory = ValuePromise<Bool>(true, ignoreRepeated: true)
    private var reminderActivity: NSUserActivity?
    private var isReminderActivityEnabled: Bool = false
    
    private var canReadHistoryValue = false
    private var canReadHistoryDisposable: Disposable?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    private var automaticMediaDownloadSettingsDisposable: Disposable?
    
    private var stickerSettings: ChatInterfaceStickerSettings
    private var stickerSettingsDisposable: Disposable?
    
    private var applicationInForegroundDisposable: Disposable?
    
    private var checkedPeerChatServiceActions = false
    
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
    
    private var currentMessageTooltipScreens: [(TooltipScreen, ListViewItemNode)] = []
    
    private weak var slowmodeTooltipController: ChatSlowmodeHintController?
    
    private weak var currentContextController: ContextController?
    
    private weak var sendMessageActionsController: ChatSendMessageActionSheetController?
    private var searchResultsController: ChatSearchResultsController?
    
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
    
    private var focusOnSearchAfterAppearance: Bool = false
    
    private let keepPeerInfoScreenDataHotDisposable = MetaDisposable()

    public override var customData: Any? {
        return self.chatLocation
    }
    
    var purposefulAction: (() -> Void)?
    
    public init(context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject? = nil, botStart: ChatControllerInitialBotStart? = nil, mode: ChatControllerPresentationMode = .standard(previewing: false)) {
        let _ = ChatControllerCount.modify { value in
            return value + 1
        }
        
        self.context = context
        self.chatLocation = chatLocation
        self.subject = subject
        self.botStart = botStart
        
        var locationBroadcastPanelSource: LocationBroadcastPanelSource
        
        switch chatLocation {
            case let .peer(peerId):
                locationBroadcastPanelSource = .peer(peerId)
                self.chatLocationInfoData = .peer(Promise())
            /*case .group:
                locationBroadcastPanelSource = .none
                self.chatLocationInfoData = .group(Promise())*/
        }
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.automaticMediaDownloadSettings = context.sharedContext.currentAutomaticMediaDownloadSettings.with { $0 }
        
        self.stickerSettings = ChatInterfaceStickerSettings(loopAnimatedStickers: false)
        
        var isScheduledMessages = false
        if let subject = subject, case .scheduledMessages = subject {
            self.canReadHistory.set(false)
            isScheduledMessages = true
        }
        
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: context.account.peerId, mode: mode, chatLocation: chatLocation, isScheduledMessages: isScheduledMessages)
        
        var mediaAccessoryPanelVisibility = MediaAccessoryPanelVisibility.none
        if case .standard = mode {
            mediaAccessoryPanelVisibility = .specific(size: .compact)
        } else {
            locationBroadcastPanelSource = .none
        }
        let navigationBarPresentationData: NavigationBarPresentationData?
        switch mode {
            case .inline:
                navigationBarPresentationData = nil
            default:
                navigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        }
        super.init(context: context, navigationBarPresentationData: navigationBarPresentationData, mediaAccessoryPanelVisibility: mediaAccessoryPanelVisibility, locationBroadcastPanelSource: locationBroadcastPanelSource)
        
        self.automaticallyControlPresentationContextLayout = false
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            strongSelf.chatDisplayNode.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] action in
            guard let strongSelf = self else {
                return true
            }
            if let _ = strongSelf.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Conversation_DiscardVoiceMessageDescription, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Conversation_DiscardVoiceMessageAction, action: {
                    self?.stopMediaRecorder()
                    action()
                })]), in: .window(.root))
                
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
            
            var openMessageByAction: Bool = false

            for media in message.media {
                if let action = media as? TelegramMediaAction {
                    switch action.action {
                        case .pinnedMessageUpdated:
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    strongSelf.navigateToMessage(from: message.id, to: .id(attribute.messageId))
                                    break
                                }
                            }
                        case let .photoUpdated(image):
                            openMessageByAction = image != nil
                        case .gameScore:
                            for attribute in message.attributes {
                                if let attribute = attribute as? ReplyMessageAttribute {
                                    strongSelf.navigateToMessage(from: message.id, to: .id(attribute.messageId))
                                    break
                                }
                            }
                        default:
                            break
                    }
                    if !openMessageByAction {
                        return true
                    }
                }
            }
            
            return context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, message: message, standalone: false, reverseMessageGalleryOrder: false, mode: mode, navigationController: strongSelf.effectiveNavigationController, dismissInput: {
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
                self?.openUrl(url, concealed: false, message: nil)
            }, openPeer: { peer, navigation in
                self?.openPeer(peerId: peer.id, navigation: navigation, fromMessage: nil)
            }, callPeer: { peerId in
                self?.controllerInteraction?.callPeer(peerId)
            }, enqueueMessage: { message in
                self?.sendMessages([message])
            }, sendSticker: canSendMessagesToChat(strongSelf.presentationInterfaceState) ? { fileReference, sourceNode, sourceRect in
                return self?.controllerInteraction?.sendSticker(fileReference, false, sourceNode, sourceRect) ?? false
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
                    strongSelf.controllerInteraction?.openUrl(url, concealed, nil, nil)
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
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil)
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
            }, storeMediaPlaybackState: { [weak self] messageId, timestamp in
                var storedState: MediaPlaybackStoredState?
                if let timestamp = timestamp {
                    storedState = MediaPlaybackStoredState(timestamp: timestamp, playbackRate: .x1)
                }
                let _ = updateMediaPlaybackStoredStateInteractively(postbox: strongSelf.context.account.postbox, messageId: messageId, state: storedState).start()
            })))
        }, openPeer: { [weak self] id, navigation, fromMessage in
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
                let _ = combineLatest(queue: .mainQueue(), contextMenuForChatPresentationIntefaceState(chatPresentationInterfaceState: strongSelf.presentationInterfaceState, context: strongSelf.context, messages: updatedMessages, controllerInteraction: strongSelf.controllerInteraction, selectAll: selectAll, interfaceInteraction: strongSelf.interfaceInteraction), loadedStickerPack(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, reference: .animatedEmoji, forceActualized: false), ApplicationSpecificNotice.getChatTextSelectionTips(accountManager: strongSelf.context.sharedContext.accountManager)
                ).start(next: { actions, animatedEmojiStickers, chatTextSelectionTips in
                    guard let strongSelf = self, !actions.isEmpty else {
                        return
                    }
                    var reactionItems: [ReactionContextItem] = []
                    
                    /*let reactions: [(String, String, String)] = [
                        ("😔", "Sad", "sad"),
                        ("😳", "Surprised", "surprised"),
                        ("😂", "Fun", "lol"),
                        ("👍", "Like", "thumbsup"),
                        ("❤", "Love", "heart"),
                        ("🥳", "Celebrate", "celebrate"),
                        ("😭", "Cry", "cry"),
                        ("😒", "Meh", "meh"),
                        ("👌", "OK", "ok"),
                        ("😐", "Poker", "poker"),
                        ("💩", "Poop", "poop"),
                        ("😊", "Smile", "smile")
                    ]
                    
                    for (value, text, name) in reactions {
                        if let path = getAppBundle().path(forResource: name, ofType: "tgs") {
                            reactionItems.append(ReactionContextItem(value: value, text: text, path: path))
                        }
                    }*/
                    if Namespaces.Message.allScheduled.contains(message.id.namespace) {
                        reactionItems = []
                    }
                    
                    let numberOfComponents = message.text.components(separatedBy: CharacterSet.whitespacesAndNewlines).count
                    let displayTextSelectionTip = numberOfComponents >= 3 && !message.text.isEmpty && chatTextSelectionTips < 3
                    if displayTextSelectionTip {
                        let _ = ApplicationSpecificNotice.incrementChatTextSelectionTips(accountManager: strongSelf.context.sharedContext.accountManager).start()
                    }
                    
                    let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, message: message)), items: .single(actions), reactionItems: reactionItems, recognizer: recognizer, gesture: gesture, displayTextSelectionTip: displayTextSelectionTip)
                    strongSelf.currentContextController = controller
                    controller.reactionSelected = { [weak controller] value in
                        guard let strongSelf = self, let message = updatedMessages.first else {
                            return
                        }
                        strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                                if item.message.id == message.id {
                                    itemNode.awaitingAppliedReaction = (value, { [weak itemNode] in
                                        guard let controller = controller else {
                                            return
                                        }
                                        if let itemNode = itemNode, let (targetNode, count) = itemNode.targetReactionNode(value: value) {
                                            controller.dismissWithReaction(value: value, into: targetNode, hideNode: count == 1, completion: {
                                            })
                                        } else {
                                            controller.dismiss()
                                        }
                                    })
                                }
                            }
                        }
                        let _ = updateMessageReactionsInteractively(postbox: strongSelf.context.account.postbox, messageId: message.id, reaction: value).start()
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
        }, openMessageContextActions: { message, node, rect, gesture in
            gesture?.cancel()
        }, navigateToMessage: { [weak self] fromId, id in
            self?.navigateToMessage(from: fromId, to: .id(id))
        }, tapMessage: nil, clickThroughMessage: { [weak self] in
            self?.chatDisplayNode.dismissInput()
        }, toggleMessagesSelection: { [weak self] ids, value in
            guard let strongSelf = self, strongSelf.isNodeLoaded else {
                return
            }
            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withToggledSelectedMessages(ids, value: value) } })
            if let selectionState = strongSelf.presentationInterfaceState.interfaceState.selectionState {
                let count = selectionState.selectedIds.count
                let text: String
                if count == 1 {
                    text = "1 message selected"
                } else {
                    text = "\(count) messages selected"
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
                    UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: text as NSString)
                })
            }
        }, sendCurrentMessage: { [weak self] silentPosting in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.sendCurrentMessage(silentPosting: silentPosting)
            }
        }, sendMessage: { [weak self] text in
            guard let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) else {
                return
            }
            guard !strongSelf.presentationInterfaceState.isScheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            })
            var attributes: [MessageAttribute] = []
            let entities = generateTextEntities(text, enabledTypes: .all)
            if !entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: entities))
            }
            strongSelf.sendMessages([.message(text: text, attributes: attributes, mediaReference: nil, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
        }, sendSticker: { [weak self] fileReference, clearInput, sourceNode, sourceRect in
            guard let strongSelf = self else {
                return false
            }
            
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, !strongSelf.presentationInterfaceState.isScheduledMessages {
                strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceNode, sourceRect)
                return false
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
                            if case let .media(mode, maybeExpanded) = current, maybeExpanded != nil {
                                return .media(mode: mode, expanded: nil)
                            }
                            return current
                        }
                        
                        return current
                    })
                }
            })
            strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: fileReference.abstract, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
            return true
        }, sendGif: { [weak self] fileReference, sourceNode, sourceRect in
            if let strongSelf = self {
                if let _ = strongSelf.presentationInterfaceState.slowmodeState, !strongSelf.presentationInterfaceState.isScheduledMessages {
                    strongSelf.interfaceInteraction?.displaySlowmodeTooltip(sourceNode, sourceRect)
                    return false
                }
                
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }.updatedInputMode { current in
                                if case let .media(mode, maybeExpanded) = current, maybeExpanded != nil  {
                                    return .media(mode: mode, expanded: nil)
                                }
                                return current
                            }
                        })
                    }
                })
                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: fileReference.abstract, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
            }
            return true
        }, requestMessageActionCallback: { [weak self] messageId, data, isGame in
            if let strongSelf = self {
                guard !strongSelf.presentationInterfaceState.isScheduledMessages else {
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
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
                    
                    strongSelf.messageActionCallbackDisposable.set(((requestMessageActionCallback(account: strongSelf.context.account, messageId: messageId, isGame: isGame, data: data)
                    |> afterDisposed {
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
                    })
                    |> deliverOnMainQueue).start(next: { result in
                        if let strongSelf = self {
                            switch result {
                                case .none:
                                    break
                                case let .alert(text):
                                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                case let .toast(text):
                                    let message: Signal<String?, NoError> = .single(text)
                                    let noMessage: Signal<String?, NoError> = .single(nil)
                                    let delayedNoMessage: Signal<String?, NoError> = noMessage |> delay(1.0, queue: Queue.mainQueue())
                                    strongSelf.botCallbackAlertMessage.set(message |> then(delayedNoMessage))
                                case let .url(url):
                                    if isGame {
                                        strongSelf.chatDisplayNode.dismissInput()
                                        strongSelf.effectiveNavigationController?.pushViewController(GameController(context: strongSelf.context, url: url, message: message))
                                    } else {
                                        strongSelf.openUrl(url, concealed: false)
                                    }
                            }
                        }
                    }))
                }
            }
        }, requestMessageActionUrlAuth: { [weak self] defaultUrl, messageId, buttonId in
            if let strongSelf = self {
                guard !strongSelf.presentationInterfaceState.isScheduledMessages else {
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                if let _ = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
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
                    strongSelf.messageActionUrlAuthDisposable.set(((combineLatest(strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.context.account.peerId), requestMessageActionUrlAuth(account: strongSelf.context.account, messageId: messageId, buttonId: buttonId) |> afterDisposed {
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
                                    strongSelf.openUrl(defaultUrl, concealed: false)
                                case let .request(domain, bot, requestWriteAccess):
                                    let controller = chatMessageActionUrlAuthController(context: strongSelf.context, defaultUrl: defaultUrl, domain: domain, bot: bot, requestWriteAccess: requestWriteAccess, displayName: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), open: { [weak self] authorize, allowWriteAccess in
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
                                                
                                                strongSelf.messageActionUrlAuthDisposable.set(((acceptMessageActionUrlAuth(account: strongSelf.context.account, messageId: messageId, buttonId: buttonId, allowWriteAccess: allowWriteAccess) |> afterDisposed {
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
                                                                strongSelf.openUrl(url, concealed: false)
                                                            default:
                                                                strongSelf.openUrl(defaultUrl, concealed: false)
                                                        }
                                                    }
                                                }))
                                            } else {
                                                strongSelf.openUrl(defaultUrl, concealed: false)
                                            }
                                        }
                                    })
                                    strongSelf.chatDisplayNode.dismissInput()
                                    strongSelf.present(controller, in: .window(.root))
                                case let .accepted(url):
                                    strongSelf.openUrl(url, concealed: false)
                            }
                        }
                    }))
                }
            }
        }, activateSwitchInline: { [weak self] peerId, inputString in
            guard let strongSelf = self else {
                return
            }
            guard !strongSelf.presentationInterfaceState.isScheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            if let botStart = strongSelf.botStart, case let .automatic(returnToPeerId, scheduled) = botStart.behavior {
                strongSelf.openPeer(peerId: returnToPeerId, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), subject: scheduled ? .scheduledMessages : nil), fromMessage: nil)
            } else {
                strongSelf.openPeer(peerId: peerId, navigation: .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: inputString)), subject: nil), fromMessage: nil)
            }
        }, openUrl: { [weak self] url, concealed, _, message in
            if let strongSelf = self {
                strongSelf.openUrl(url, concealed: concealed, message: message)
            }
        }, shareCurrentLocation: { [weak self] in
            if let strongSelf = self {
                guard !strongSelf.presentationInterfaceState.isScheduledMessages else {
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Conversation_ShareBotLocationConfirmationTitle, text: strongSelf.presentationData.strings.Conversation_ShareBotLocationConfirmation, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    if let strongSelf = self, let locationManager = strongSelf.context.sharedContext.locationManager {
                        let _ = (currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
                        |> deliverOnMainQueue).start(next: { coordinate in
                            if let strongSelf = self {
                                if let coordinate = coordinate {
                                    strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaMap(latitude: coordinate.latitude, longitude: coordinate.longitude, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil)), replyToMessageId: nil, localGroupingKey: nil)])
                                } else {
                                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})]), in: .window(.root))
                                }
                            }
                        })
                    }
                })]), in: .window(.root))
            }
        }, shareAccountContact: { [weak self] in
            if let strongSelf = self {
                guard !strongSelf.presentationInterfaceState.isScheduledMessages else {
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_BotActionUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Conversation_ShareBotContactConfirmationTitle, text: strongSelf.presentationData.strings.Conversation_ShareBotContactConfirmation, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                    if let strongSelf = self {
                        let _ = (strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.context.account.peerId)
                        |> deliverOnMainQueue).start(next: { peer in
                            if let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
                                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)), replyToMessageId: nil, localGroupingKey: nil)])
                            }
                        })
                    }
                })]), in: .window(.root))
            }
        }, sendBotCommand: { [weak self] messageId, command in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({})
                var postAsReply = false
                if !command.contains("@") {
                    switch strongSelf.chatLocation {
                        case let .peer(peerId):
                            if (peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup) {
                                postAsReply = true
                            }
                        /*case .group:
                            postAsReply = true*/
                    }
                }
                
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil) }
                        })
                    }
                })
                var attributes: [MessageAttribute] = []
                let entities = generateTextEntities(command, enabledTypes: .all)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                strongSelf.sendMessages([.message(text: command, attributes: attributes, mediaReference: nil, replyToMessageId: (postAsReply && messageId != nil) ? messageId! : nil, localGroupingKey: nil)])
            }
        }, openInstantPage: { [weak self] message, associatedData in
            if let strongSelf = self, strongSelf.isNodeLoaded, let navigationController = strongSelf.effectiveNavigationController, let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(message.id) {
                openChatInstantPage(context: strongSelf.context, message: message, sourcePeerType: associatedData?.automaticDownloadPeerType, navigationController: navigationController)
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
                    (self?.navigationController as? NavigationController)?.pushViewController(c)
                }, present: { [weak self] c, a in
                    self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                })
            }
        }, openHashtag: { [weak self] peerName, hashtag in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.resolvePeerByNameDisposable == nil {
                strongSelf.resolvePeerByNameDisposable = MetaDisposable()
            }
            let account = strongSelf.context.account
            var resolveSignal: Signal<Peer?, NoError>
            if let peerName = peerName {
                resolveSignal = resolvePeerByName(account: strongSelf.context.account, name: peerName)
                |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                    if let peerId = peerId {
                        return account.postbox.loadedPeerWithId(peerId)
                        |> map(Optional.init)
                    } else {
                        return .single(nil)
                    }
                }
            } else if case let .peer(peerId) = strongSelf.chatLocation {
                resolveSignal = context.account.postbox.loadedPeerWithId(peerId)
                |> map(Optional.init)
            } else {
                resolveSignal = .single(nil)
            }
            var cancelImpl: (() -> Void)?
            let presentationData = strongSelf.presentationData
            let progressSignal = Signal<Never, NoError> { subscriber in
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
            cancelImpl = {
                self?.resolvePeerByNameDisposable?.set(nil)
            }
            strongSelf.resolvePeerByNameDisposable?.set((resolveSignal
            |> deliverOnMainQueue).start(next: { peer in
                if let strongSelf = self, !hashtag.isEmpty {
                    let searchController = HashtagSearchController(context: strongSelf.context, peer: peer, query: hashtag)
                    strongSelf.effectiveNavigationController?.pushViewController(searchController)
                }
            }))
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
            if let strongSelf = self, let messages = strongSelf.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(id) {
                let shareController = ShareController(context: strongSelf.context, subject: .messages(messages))
                shareController.dismissed = { shared in
                    if shared {
                        self?.commitPurposefulAction()
                    }
                }
                strongSelf.chatDisplayNode.dismissInput()
                strongSelf.present(shareController, in: .window(.root), blockInteraction: true)
            }
        }, presentController: { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }, navigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }, chatControllerNode: { [weak self] in
            return self?.chatDisplayNode
        }, reactionContainerNode: { [weak self] in
            return self?.chatDisplayNode.reactionContainerNode
        }, presentGlobalOverlayController: { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }, callPeer: { [weak self] peerId in
            if let strongSelf = self {
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
                        
                        strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.Call_ConnectionErrorTitle, text: presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        return
                    }
                    
                    let callResult = context.sharedContext.callManager?.requestCall(account: context.account, peerId: peer.id, endCurrentIfAny: false)
                    if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
                        if currentPeerId == peer.id {
                            context.sharedContext.navigateToCurrentCall()
                        } else {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let _ = (context.account.postbox.transaction { transaction -> (Peer?, Peer?) in
                                return (transaction.getPeer(peer.id), transaction.getPeer(currentPeerId))
                            }
                            |> deliverOnMainQueue).start(next: { peer, current in
                                if let peer = peer, let current = current {
                                    strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                        let _ = context.sharedContext.callManager?.requestCall(account: context.account, peerId: peer.id, endCurrentIfAny: true)
                                    })]), in: .window(.root))
                                }
                            })
                        }
                    }
                })
            }
        }, longTap: { [weak self] action, message in
            if let strongSelf = self {
                switch action {
                    case let .url(url):
                        var cleanUrl = url
                        var canAddToReadingList = true
                        var canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
                        let mailtoString = "mailto:"
                        let telString = "tel:"
                        var openText = strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                        var phoneNumber: String?
                        if cleanUrl.hasPrefix(mailtoString) {
                            canAddToReadingList = false
                            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
                        } else if cleanUrl.hasPrefix(telString) {
                            canAddToReadingList = false
                            phoneNumber = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
                            cleanUrl = phoneNumber!
                            openText = strongSelf.presentationData.strings.UserInfo_PhoneCall
                            canOpenIn = false
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
                        items.append(ActionSheetButtonItem(title: canAddToReadingList ? strongSelf.presentationData.strings.ShareMenu_CopyShareLink : strongSelf.presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = cleanUrl
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
                                strongSelf.openPeer(peerId: peerId, navigation: .chat(textInputState: nil, subject: nil), fromMessage: nil)
                            }
                        }))
                        if !mention.isEmpty {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = mention
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
                                    strongSelf.openPeerMention(mention)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                    UIPasteboard.general.string = mention
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
                                    strongSelf.sendMessages([.message(text: command, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])
                                }
                            }))
                        }
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            UIPasteboard.general.string = command
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
                                    if case let .peer(peerId) = strongSelf.chatLocation {
                                        peerSignal = strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                                        |> map(Optional.init)
                                    } else {
                                        peerSignal = .single(nil)
                                    }
                                    let _ = (peerSignal
                                    |> deliverOnMainQueue).start(next: { peer in
                                        if let strongSelf = self {
                                            let searchController = HashtagSearchController(context: strongSelf.context, peer: peer, query: hashtag)
                                            strongSelf.effectiveNavigationController?.pushViewController(searchController)
                                        }
                                    })
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = hashtag
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
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: text),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                if let strongSelf = self {
                                    strongSelf.controllerInteraction?.seekToTimecode(message, timecode, true)
                                }
                            }),
                            ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                UIPasteboard.general.string = text
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
                        
                        var signal = getBankCardInfo(account: strongSelf.context.account, cardNumber: number)
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
            if let strongSelf = self {
                strongSelf.commitPurposefulAction()
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    for media in message.media {
                        if let invoice = media as? TelegramMediaInvoice {
                            strongSelf.chatDisplayNode.dismissInput()
                            if let receiptMessageId = invoice.receiptMessageId {
                                strongSelf.present(BotReceiptController(context: strongSelf.context, invoice: invoice, messageId: receiptMessageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            } else {
                                strongSelf.present(BotCheckoutController(context: strongSelf.context, invoice: invoice, messageId: messageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            }
                        }
                    }
                }
            }
        }, openSearch: {
        }, setupReply: { [weak self] messageId in
            self?.interfaceInteraction?.setupReplyMessage(messageId, { _ in })
        }, canSetupReply: { [weak self] message in
            if !message.flags.contains(.Incoming) {
                if !message.flags.intersection([.Failed, .Sending, .Unsent]).isEmpty {
                    return false
                }
            }
            if let strongSelf = self {
                return canReplyInChat(strongSelf.presentationInterfaceState)
            }
            return false
        }, navigateToFirstDateMessage: { [weak self] timestamp in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.chatLocation {
                case let .peer(peerId):
                    strongSelf.navigateToMessage(from: nil, to: .index(MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: timestamp - Int32(NSTimeZone.local.secondsFromGMT()))), scrollPosition: .bottom(0.0), rememberInStack: false, animated: true, completion: nil)
            }
        }, requestRedeliveryOfFailedMessages: { [weak self] id in
            guard let strongSelf = self else {
                return
            }
            if id.namespace == Namespaces.Message.ScheduledCloud {
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Message] in
                    return transaction.getMessageGroup(id) ?? []
                } |> deliverOnMainQueue).start(next: { messages in
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
                            strongSelf.interfaceInteraction?.deleteMessages(messages, controller, f)
                        }
                    })))
                    
                    let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, message: message)), items: .single(actions), reactionItems: [], recognizer: nil)
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
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Message] in
                    return transaction.getMessageFailedGroup(id) ?? []
                } |> deliverOnMainQueue).start(next: { messages in
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
                            groups[groupInfo.stableId]?.append(message)
                        } else {
                            notGrouped.append(message)
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
                        actions.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_MessageDialogRetryAll(totalGroupCount).0, icon: { theme in
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
                            let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: [id], type: .forLocalPeer).start()
                        }
                        f(.dismissWithoutContent)
                    })))
                    
                    let controller = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .extracted(ChatMessageContextExtractedContentSource(chatNode: strongSelf.chatDisplayNode, message: topMessage)), items: .single(actions), reactionItems: [], recognizer: nil)
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
                strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
                    self?.present(controller, in: .window(.root), with: arguments)
                }, pushController: { [weak self] controller in
                    if let strongSelf = self {
                        strongSelf.effectiveNavigationController?.pushViewController(controller)
                    }
                }, completed: {})
            }
        }, rateCall: { [weak self] message, callId in
            if let strongSelf = self {
                let controller = callRatingController(sharedContext: strongSelf.context.sharedContext, account: strongSelf.context.account, callId: callId, userInitiated: true, present: { [weak self] c, a in
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
            
            guard !strongSelf.presentationInterfaceState.isScheduledMessages else {
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ScheduledMessages_PollUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                return
            }
            if controllerInteraction.pollActionState.pollMessageIdsInProgress[id] == nil {
                #if DEBUG
                if false {
                    var found = false
                    strongSelf.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                        if !found, let itemNode = itemNode as? ChatMessageBubbleItemNode, itemNode.item?.message.id == id {
                            found = true
                            if strongSelf.selectPollOptionFeedback == nil {
                                strongSelf.selectPollOptionFeedback = HapticFeedback()
                            }
                            strongSelf.selectPollOptionFeedback?.error()
                            itemNode.animateQuizInvalidOptionSelected()
                        }
                    }
                    return;
                }
                if false {
                    if strongSelf.selectPollOptionFeedback == nil {
                        strongSelf.selectPollOptionFeedback = HapticFeedback()
                    }
                    strongSelf.selectPollOptionFeedback?.success()
                    strongSelf.chatDisplayNode.animateQuizCorrectOptionSelected()
                    return;
                }
                if false {
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(text: "controllerInteraction.pollActionState.pollMessageIdsInProgress[id] = opaqueIdentifiers"), elevatedLayout: true, action: { _ in return false }), in: .window(.root))
                    return;
                }
                #endif
                
                controllerInteraction.pollActionState.pollMessageIdsInProgress[id] = opaqueIdentifiers
                strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(id)
                let disposables: DisposableDict<MessageId>
                if let current = strongSelf.selectMessagePollOptionDisposables {
                    disposables = current
                } else {
                    disposables = DisposableDict()
                    strongSelf.selectMessagePollOptionDisposables = disposables
                }
                let signal = requestMessageSelectPollOption(account: strongSelf.context.account, messageId: id, opaqueIdentifiers: opaqueIdentifiers)
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
            let _ = (strongSelf.context.account.postbox.transaction { transaction -> Message? in
                return transaction.getMessage(messageId)
            }
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
                            if case let .visible(fraction) = itemNode.visibility, fraction > 0.7 {
                                action(Double(timestamp))
                            } else {
                                let _ = strongSelf.controllerInteraction?.openMessage(message, .timecode(Double(timestamp)))
                            }
                            found = true
                        }
                    }
                }
                if !found {
                    let _ = strongSelf.controllerInteraction?.openMessage(message, .timecode(Double(timestamp)))
                }
            }
        }, scheduleCurrentMessage: { [weak self] in
            if let strongSelf = self {
                strongSelf.presentScheduleTimePicker(completion: { [weak self] time in
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.sendCurrentMessage(scheduleTime: time, completion: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))) }
                                })
                                
                                if !strongSelf.presentationInterfaceState.isScheduledMessages && time != scheduleWhenOnlineTimestamp {
                                    strongSelf.openScheduledMessages()
                                }
                            }
                        })
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
                    let _ = sendScheduledMessageNowInteractively(postbox: strongSelf.context.account.postbox, messageId: messageIds.first!).start()
                }
            }
        }, editScheduledMessagesTime: { [weak self] messageIds in
            if let strongSelf = self, let messageId = messageIds.first {
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> Message? in
                    return transaction.getMessage(messageId)
                } |> deliverOnMainQueue).start(next: { [weak self] message in
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
                            let signal = requestEditMessage(account: strongSelf.context.account, messageId: messageId, text: message.text, media: .keep, entities: entities, disableUrlPreview: false, scheduleTime: time)
                            strongSelf.editMessageDisposable.set((signal |> deliverOnMainQueue).start(next: { result in
                            }, error: { error in
                            }))
                        }
                    })
                })
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
                    let shareController = ShareController(context: strongSelf.context, subject: .text(text.string), externalShare: true, immediateExternalShare: false)
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
            }
        }, updateMessageReaction: { [weak self] messageId, reaction in
            guard let strongSelf = self else {
                return
            }
            let _ = updateMessageReactionsInteractively(postbox: strongSelf.context.account.postbox, messageId: messageId, reaction: reaction).start()
        }, openMessageReactions: { [weak self] messageId in
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.account.postbox.transaction { transaction -> Message? in
                return transaction.getMessage(messageId)
            }
            |> deliverOnMainQueue).start(next: { message in
                guard let strongSelf = self, let message = message else {
                    return
                }
                var initialReactions: [MessageReaction] = []
                for attribute in message.attributes {
                    if let attribute = attribute as? ReactionsMessageAttribute {
                        initialReactions = attribute.reactions
                    }
                }
                
                if !initialReactions.isEmpty {
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.present(MessageReactionListController(context: strongSelf.context, messageId: message.id, initialReactions: initialReactions), in: .window(.root))
                }
            })
        }, displaySwipeToReplyHint: {  [weak self] in
            if let strongSelf = self, let validLayout = strongSelf.validLayout, min(validLayout.size.width, validLayout.size.height) > 320.0 {
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .swipeToReply(title: strongSelf.presentationData.strings.Conversation_SwipeToReplyHintTitle, text: strongSelf.presentationData.strings.Conversation_SwipeToReplyHintText), elevatedLayout: true, action: { _ in return false }), in: .window(.root))
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
                        return value
                    })
                })
            })
        }, openMessagePollResults: { [weak self] messageId, optionOpaqueIdentifier in
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.account.postbox.transaction { transaction -> Message? in
                return transaction.getMessage(messageId)
            }
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
        }, openPollCreation: { [weak self] isQuiz in
            guard let strongSelf = self else {
                return
            }
            strongSelf.presentPollCreation(isQuiz: isQuiz)
        }, displayPollSolution: { [weak self] solution, sourceNode in
            self?.displayPollSolution(solution: solution, sourceNode: sourceNode, isAutomatic: false)
        }, displayPsa: { [weak self] type, sourceNode in
            self?.displayPsa(type: type, sourceNode: sourceNode, isAutomatic: false)
        }, displayDiceTooltip: { [weak self] dice in
            self?.displayDiceTooltip(dice: dice)
        }, animateDiceSuccess: { [weak self] in
            self?.chatDisplayNode.animateQuizCorrectOptionSelected()
        }, requestMessageUpdate: { [weak self] id in
            if let strongSelf = self {
                strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(id)
            }
        }, cancelInteractiveKeyboardGestures: { [weak self] in
            (self?.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
            self?.chatDisplayNode.cancelInteractiveKeyboardGestures()
        }, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings, pollActionState: ChatInterfacePollActionState(), stickerSettings: self.stickerSettings)
        
        self.controllerInteraction = controllerInteraction
        
        if case let .peer(peerId) = chatLocation, peerId != context.account.peerId, subject != .scheduledMessages {
            self.navigationBar?.userInfo = PeerInfoNavigationSourceTag(peerId: peerId)
        }
        
        self.chatTitleView = ChatTitleView(account: self.context.account, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder)
        self.navigationItem.titleView = self.chatTitleView
        self.chatTitleView?.pressed = { [weak self] in
            if let strongSelf = self {
                if strongSelf.chatLocation == .peer(strongSelf.context.account.peerId) {
                    if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: true) {
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
            self?.interfaceInteraction?.beginMessageSearch(.everything, "")
        }
        
        let chatInfoButtonItem: UIBarButtonItem
        switch chatLocation {
            case .peer:
                let avatarNode = ChatAvatarNavigationNode()
                avatarNode.chatController = self
                avatarNode.contextAction = { [weak self] node, gesture in
                    guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, peer.smallProfileImage != nil else {
                        return
                    }
                    let galleryController = AvatarGalleryController(context: strongSelf.context, peer: peer, remoteEntries: nil, replaceRootController: { controller, ready in
                    }, synchronousLoad: true)
                    galleryController.setHintWillBePresentedInPreviewingContext(true)
                    
                    let items: Signal<[ContextMenuItem], NoError> = context.account.postbox.transaction { transaction -> [ContextMenuItem] in
                        var items: [ContextMenuItem] = [
                            .action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.dismissWithoutContent)
                                self?.navigationButtonAction(.openChatInfo(expandAvatar: true))
                            }))
                        ]
                        if let cachedData = transaction.getPeerCachedData(peerId: peer.id) as? CachedChannelData, cachedData.flags.contains(.canViewStats) {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.ChannelInfo_Stats, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Statistics"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.dismissWithoutContent)
                                guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer else {
                                    return
                                }
                                strongSelf.view.endEditing(true)
                                strongSelf.push(channelStatsController(context: context, peerId: peer.id, cachedPeerData: cachedData))
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
                    
                    let contextController = ContextController(account: strongSelf.context.account, presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: galleryController, sourceNode: node)), items: items, reactionItems: [], gesture: gesture)
                    strongSelf.presentInGlobalOverlay(contextController)
                }
                chatInfoButtonItem = UIBarButtonItem(customDisplayNode: avatarNode)!
        }
        chatInfoButtonItem.target = self
        chatInfoButtonItem.action = #selector(self.rightNavigationButtonAction)
        chatInfoButtonItem.accessibilityLabel = self.presentationData.strings.Conversation_Info
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
        
        switch chatLocation {
            case let .peer(peerId):
                if case let .peer(peerView) = self.chatLocationInfoData {
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
                                    return context.peerChannelMemberCategoriesContextsManager.recentOnline(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
                                    |> map(Optional.init)
                                } else {
                                    return context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId)
                                    |> map(Optional.init)
                                }
                            } else {
                                return .single(nil)
                            }
                        }
                        onlineMemberCount = recentOnlineSignal
                        
                        self.reportIrrelvantGeoNoticePromise.set(context.account.postbox.transaction { transaction -> Bool? in
                            if let _ = transaction.getNoticeEntry(key: ApplicationSpecificNotice.irrelevantPeerGeoReportKey(peerId: peerId)) as? ApplicationSpecificBoolNotice {
                                return true
                            } else {
                                return false
                            }
                        })
                    } else {
                        self.reportIrrelvantGeoNoticePromise.set(.single(nil))
                    }
                    
                    if !isScheduledMessages && peerId.namespace != Namespaces.Peer.SecretChat {
                        hasScheduledMessages = peerView.get()
                        |> take(1)
                        |> mapToSignal { view -> Signal<Bool, NoError> in
                            if let peer = peerViewMainPeer(view) as? TelegramChannel, !peer.hasPermission(.sendMessages) {
                                return .single(false)
                            } else {
                                return context.account.viewTracker.scheduledMessagesViewForLocation(chatLocation)
                                |> map { view, _, _ in
                                    return !view.entries.isEmpty
                                }
                            }
                        }
                    }
                    
                    self.peerDisposable.set((combineLatest(queue: Queue.mainQueue(), peerView.get(), onlineMemberCount, hasScheduledMessages, self.reportIrrelvantGeoNoticePromise.get())
                    |> deliverOnMainQueue).start(next: { [weak self] peerView, onlineMemberCount, hasScheduledMessages, peerReportNotice in
                        if let strongSelf = self {
                            if let peer = peerViewMainPeer(peerView) {
                                strongSelf.chatTitleView?.titleContent = .peer(peerView: peerView, onlineMemberCount: onlineMemberCount, isScheduledMessages: isScheduledMessages)
                                let imageOverride: AvatarNodeImageOverride?
                                if strongSelf.context.account.peerId == peer.id {
                                    imageOverride = .savedMessagesIcon
                                } else if peer.isDeleted {
                                    imageOverride = .deletedIcon
                                } else {
                                    imageOverride = nil
                                }
                                (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.avatarNode.setPeer(context: strongSelf.context, theme: strongSelf.presentationData.theme, peer: peer, overrideImage: imageOverride)
                                (strongSelf.chatInfoNavigationButton?.buttonItem.customDisplayNode as? ChatAvatarNavigationNode)?.contextActionIsEnabled =  peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil
                            }
                            
                            if strongSelf.peerView === peerView && strongSelf.reportIrrelvantGeoNotice == peerReportNotice && strongSelf.hasScheduledMessages == hasScheduledMessages {
                                return
                            }
                            
                            strongSelf.reportIrrelvantGeoNotice = peerReportNotice
                            strongSelf.hasScheduledMessages = hasScheduledMessages
                            
                            var upgradedToPeerId: PeerId?
                            if let previous = strongSelf.peerView, let group = previous.peers[previous.peerId] as? TelegramGroup, group.migrationReference == nil, let updatedGroup = peerView.peers[peerView.peerId] as? TelegramGroup, let migrationReference = updatedGroup.migrationReference {
                                upgradedToPeerId = migrationReference.peerId
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
                                    let (recentDisposable, _) = strongSelf.context.peerChannelMemberCategoriesContextsManager.recent(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
                                    let (adminsDisposable, _) = strongSelf.context.peerChannelMemberCategoriesContextsManager.admins(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, accountPeerId: context.account.peerId, peerId: peerView.peerId, updated: { _ in })
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
                                    peerDiscussionId = cachedData.linkedDiscussionPeerId
                                } else {
                                    peerGeoLocation = cachedData.peerGeoLocation
                                }
                            }
                            var renderedPeer: RenderedPeer?
                            var contactStatus: ChatContactStatus?
                            if let peer = peerView.peers[peerView.peerId] {
                                if let cachedData = peerView.cachedData as? CachedUserData {
                                    contactStatus = ChatContactStatus(canAddContact: !peerView.peerIsContact, canReportIrrelevantLocation: false, peerStatusSettings: cachedData.peerStatusSettings)
                                } else if let cachedData = peerView.cachedData as? CachedGroupData {
                                    contactStatus = ChatContactStatus(canAddContact: false, canReportIrrelevantLocation: false, peerStatusSettings: cachedData.peerStatusSettings)
                                } else if let cachedData = peerView.cachedData as? CachedChannelData {
                                    var canReportIrrelevantLocation = true
                                    if let peer = peerView.peers[peerView.peerId] as? TelegramChannel, peer.participationStatus == .member {
                                        canReportIrrelevantLocation = false
                                    }
                                    if let peerReportNotice = peerReportNotice, peerReportNotice {
                                        canReportIrrelevantLocation = false
                                    }
                                    contactStatus = ChatContactStatus(canAddContact: false, canReportIrrelevantLocation: canReportIrrelevantLocation, peerStatusSettings: cachedData.peerStatusSettings)
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
                                if !peerStatusSettings.isEmpty {
                                    if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                                        didDisplayActionsPanel = true
                                    } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                                        didDisplayActionsPanel = true
                                    } else if peerStatusSettings.contains(.canShareContact) {
                                        didDisplayActionsPanel = true
                                    } else if contactStatus.canReportIrrelevantLocation && peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
                                        didDisplayActionsPanel = true
                                    }
                                }
                            }
                            
                            var displayActionsPanel = false
                            if let contactStatus = contactStatus, !contactStatus.isEmpty, let peerStatusSettings = contactStatus.peerStatusSettings {
                                if !peerStatusSettings.isEmpty {
                                    if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                                        displayActionsPanel = true
                                    } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) {
                                        displayActionsPanel = true
                                    } else if peerStatusSettings.contains(.canShareContact) {
                                        displayActionsPanel = true
                                    } else if contactStatus.canReportIrrelevantLocation && peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
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
                                }.updatedIsNotAccessible(isNotAccessible).updatedContactStatus(contactStatus).updatedHasBots(hasBots).updatedIsArchived(isArchived).updatedPeerIsMuted(peerIsMuted).updatedPeerDiscussionId(peerDiscussionId).updatedPeerGeoLocation(peerGeoLocation).updatedExplicitelyCanPinMessages(explicitelyCanPinMessages).updatedHasScheduledMessages(hasScheduledMessages)
                            })
                            if !strongSelf.didSetChatLocationInfoReady {
                                strongSelf.didSetChatLocationInfoReady = true
                                strongSelf._chatLocationInfoReady.set(.single(true))
                            }
                            strongSelf.updateReminderActivity()
                            if let upgradedToPeerId = upgradedToPeerId {
                                if let navigationController = strongSelf.effectiveNavigationController {
                                    var viewControllers = navigationController.viewControllers
                                    if let index = viewControllers.firstIndex(where: { $0 === strongSelf }) {
                                        viewControllers[index] = ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(upgradedToPeerId))
                                        navigationController.setViewControllers(viewControllers, animated: false)
                                    }
                                }
                            }
                        }
                    }))
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
                            if let audioRecorder = audioRecorder {
                                if panelState.mediaRecordingState == nil {
                                    return panelState.withUpdatedMediaRecordingState(.audio(recorder: audioRecorder, isLocked: strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId))
                                }
                            } else {
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
                                    return panelState.withUpdatedMediaRecordingState(.video(status: .recording(videoRecorder.audioStatus), isLocked: false))
                                }
                            } else {
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })
                    
                    if let videoRecorder = videoRecorder {
                        strongSelf.recorderFeedback?.impact(.light)
                        
                        videoRecorder.onDismiss = {
                            if let strongSelf = self {
                                strongSelf.videoRecorder.set(.single(nil))
                            }
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
                    
                    if let previousVideoRecorderValue = previousVideoRecorderValue {
                        previousVideoRecorderValue.dismissVideo()
                    }
                }
            }
        })
        
        if let botStart = botStart, case .automatic = botStart.behavior {
            self.startBot(botStart.payload)
        }
        
        self.inputActivityDisposable = (self.typingActivityPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.context.account.updateLocalInputActivity(peerId: peerId, activity: .typingText, isPresent: value)
            }
        })
        
        self.recordingActivityDisposable = (self.recordingActivityPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.acquiredRecordingActivityDisposable?.dispose()
                switch value {
                    case .voice:
                        strongSelf.acquiredRecordingActivityDisposable = strongSelf.context.account.acquireLocalInputActivity(peerId: peerId, activity: .recordingVoice)
                    case .instantVideo:
                        strongSelf.acquiredRecordingActivityDisposable = strongSelf.context.account.acquireLocalInputActivity(peerId: peerId, activity: .recordingInstantVideo)
                    case .none:
                        strongSelf.acquiredRecordingActivityDisposable = nil
                }
            }
        })
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                let previousChatWallpaper = strongSelf.presentationData.chatWallpaper
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings || presentationData.chatWallpaper != previousChatWallpaper {
                    strongSelf.themeAndStringsUpdated()
                }
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
        
        self.stickerSettingsDisposable = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            var stickerSettings = StickerSettings.defaultSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings] as? StickerSettings {
                stickerSettings = value
            }
            
            let chatStickerSettings = ChatInterfaceStickerSettings(stickerSettings: stickerSettings)
            
            if let strongSelf = self, strongSelf.stickerSettings != chatStickerSettings {
                strongSelf.stickerSettings = chatStickerSettings
                strongSelf.controllerInteraction?.stickerSettings = chatStickerSettings
                if strongSelf.isNodeLoaded {
                    strongSelf.chatDisplayNode.updateStickerSettings(chatStickerSettings)
                }
            }
        })
        
        self.applicationInForegroundDisposable = (context.sharedContext.applicationBindings.applicationInForeground
        |> distinctUntilChanged
        |> deliverOn(Queue.mainQueue())).start(next: { [weak self] value in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                if !value {
                    strongSelf.saveInterfaceState()
                    strongSelf.raiseToListen?.applicationResignedActive()
                    
                    strongSelf.stopMediaRecorder()
                }
            }
        })
        
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
        self.chatUnreadMentionCountDisposable?.dispose()
        self.peerInputActivitiesDisposable?.dispose()
        self.recentlyUsedInlineBotsDisposable?.dispose()
        self.unpinMessageDisposable?.dispose()
        self.inputActivityDisposable?.dispose()
        self.recordingActivityDisposable?.dispose()
        self.acquiredRecordingActivityDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.searchDisposable?.dispose()
        self.applicationInForegroundDisposable?.dispose()
        self.canReadHistoryDisposable?.dispose()
        self.networkStateDisposable?.dispose()
        self.chatAdditionalDataDisposable.dispose()
        self.shareStatusDisposable?.dispose()
        self.context.sharedContext.mediaManager.galleryHiddenMediaManager.removeTarget(self)
        self.preloadHistoryPeerIdDisposable.dispose()
        self.reportIrrelvantGeoDisposable?.dispose()
        self.reminderActivity?.invalidate()
        self.updateSlowmodeStatusDisposable.dispose()
        self.keepPeerInfoScreenDataHotDisposable.dispose()
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
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.chatTitleView?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
        self.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
            var state = state
            state = state.updatedTheme(self.presentationData.theme)
            state = state.updatedStrings(self.presentationData.strings)
            state = state.updatedDateTimeFormat(self.presentationData.dateTimeFormat)
            state = state.updatedChatWallpaper(self.presentationData.chatWallpaper)
            state = state.updatedBubbleCorners(self.presentationData.chatBubbleCorners)
            return state
        })
        
        self.currentContextController?.updateTheme(presentationData: self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatControllerNode(context: self.context, chatLocation: self.chatLocation, subject: self.subject, controllerInteraction: self.controllerInteraction!, chatPresentationInterfaceState: self.presentationInterfaceState, automaticMediaDownloadSettings: self.automaticMediaDownloadSettings, navigationBar: self.navigationBar, controller: self)
        
        self.chatDisplayNode.historyNode.didScrollWithOffset = { [weak self] offset, transition, itemNode in
            guard let strongSelf = self else {
                return
            }
            for (tooltipScreen, tooltipItemNode) in strongSelf.currentMessageTooltipScreens {
                if let itemNode = itemNode {
                    if itemNode === tooltipItemNode {
                        tooltipScreen.addRelativeScrollingOffset(-offset, transition: transition)
                    }
                } else {
                    tooltipScreen.addRelativeScrollingOffset(-offset, transition: transition)
                }
            }
        }
        
        self.chatDisplayNode.peerView = self.peerView
        
        let initialData = self.chatDisplayNode.historyNode.initialData
        |> take(1)
        |> beforeNext { [weak self] combinedInitialData in
            guard let strongSelf = self, let combinedInitialData = combinedInitialData else {
                return
            }
            if let interfaceState = combinedInitialData.initialData?.chatInterfaceState as? ChatInterfaceState {
                var pinnedMessageId: MessageId?
                var peerIsBlocked: Bool = false
                var callsAvailable: Bool = true
                var callsPrivate: Bool = false
                var slowmodeState: ChatSlowmodeState?
                if let cachedData = combinedInitialData.cachedData as? CachedChannelData {
                    pinnedMessageId = cachedData.pinnedMessageId
                    if let channel = combinedInitialData.initialData?.peer as? TelegramChannel, channel.isRestrictedBySlowmode, let timeout = cachedData.slowModeTimeout {
                        if let slowmodeUntilTimestamp = calculateSlowmodeActiveUntilTimestamp(account: strongSelf.context.account, untilTimestamp: cachedData.slowModeValidUntilTimestamp) {
                            slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .timestamp(slowmodeUntilTimestamp))
                        }
                    }
                } else if let cachedData = combinedInitialData.cachedData as? CachedUserData {
                    peerIsBlocked = cachedData.isBlocked
                    callsAvailable = cachedData.callsAvailable
                    callsPrivate = cachedData.callsPrivate
                    pinnedMessageId = cachedData.pinnedMessageId
                } else if let cachedData = combinedInitialData.cachedData as? CachedGroupData {
                    pinnedMessageId = cachedData.pinnedMessageId
                } else if let _ = combinedInitialData.cachedData as? CachedSecretChatData {
                }
                var pinnedMessage: Message?
                if let pinnedMessageId = pinnedMessageId {
                    if let cachedDataMessages = combinedInitialData.cachedDataMessages {
                        pinnedMessage = cachedDataMessages[pinnedMessageId]
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
                        updated = updatedChatEditInterfaceMessagetState(state: updated, message: message)
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
        if case let .peer(peerId) = self.chatLocation {
            hasPendingMessages = self.context.account.pendingMessageManager.hasPendingMessages
            |> mapToSignal { peerIds -> Signal<Bool, NoError> in
                let value = peerIds.contains(peerId)
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
        
        self.cachedDataDisposable = combineLatest(queue: .mainQueue(), self.chatDisplayNode.historyNode.cachedPeerDataAndMessages, hasPendingMessages).start(next: { [weak self] cachedDataAndMessages, hasPendingMessages in
            if let strongSelf = self {
                let (cachedData, messages) = cachedDataAndMessages
                
                var pinnedMessageId: MessageId?
                var peerIsBlocked: Bool = false
                var callsAvailable: Bool = false
                var callsPrivate: Bool = false
                var slowmodeState: ChatSlowmodeState?
                if let cachedData = cachedData as? CachedChannelData {
                    pinnedMessageId = cachedData.pinnedMessageId
                    if let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isRestrictedBySlowmode, let timeout = cachedData.slowModeTimeout {
                        if hasPendingMessages {
                            slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .pendingMessages)
                        } else if let slowmodeUntilTimestamp = calculateSlowmodeActiveUntilTimestamp(account: strongSelf.context.account, untilTimestamp: cachedData.slowModeValidUntilTimestamp) {
                            slowmodeState = ChatSlowmodeState(timeout: timeout, variant: .timestamp(slowmodeUntilTimestamp))
                        }
                    }
                } else if let cachedData = cachedData as? CachedUserData {
                    peerIsBlocked = cachedData.isBlocked
                    callsAvailable = cachedData.callsAvailable
                    callsPrivate = cachedData.callsPrivate
                    pinnedMessageId = cachedData.pinnedMessageId
                } else if let cachedData = cachedData as? CachedGroupData {
                    pinnedMessageId = cachedData.pinnedMessageId
                } else if let _ = cachedData as? CachedSecretChatData {
                }
                
                var pinnedMessage: Message?
                if let pinnedMessageId = pinnedMessageId {
                    pinnedMessage = messages?[pinnedMessageId]
                }
                
                var pinnedMessageUpdated = false
                if let current = strongSelf.presentationInterfaceState.pinnedMessage, let updated = pinnedMessage {
                    if current.id != updated.id || current.stableVersion != updated.stableVersion {
                        pinnedMessageUpdated = true
                    }
                } else if (strongSelf.presentationInterfaceState.pinnedMessage != nil) != (pinnedMessage != nil) {
                    pinnedMessageUpdated = true
                }
                
                let callsDataUpdated = strongSelf.presentationInterfaceState.callsAvailable != callsAvailable || strongSelf.presentationInterfaceState.callsPrivate != callsPrivate
                
                if strongSelf.presentationInterfaceState.pinnedMessageId != pinnedMessageId || strongSelf.presentationInterfaceState.pinnedMessage?.stableVersion != pinnedMessage?.stableVersion || strongSelf.presentationInterfaceState.peerIsBlocked != peerIsBlocked || pinnedMessageUpdated || callsDataUpdated || strongSelf.presentationInterfaceState.slowmodeState != slowmodeState  {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        return state
                        .updatedPinnedMessageId(pinnedMessageId)
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
            }
        })
        
        self.historyStateDisposable = self.chatDisplayNode.historyNode.historyState.get().start(next: { [weak self] state in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: strongSelf.isViewLoaded && strongSelf.view.window != nil, {
                    $0.updatedChatHistoryState(state)
                })
            }
        })
        
        self.ready.set(combineLatest(self.chatDisplayNode.historyNode.historyState.get(), self._chatLocationInfoReady.get(), initialData) |> map { _, chatLocationInfoReady, _ in
            return chatLocationInfoReady
        })
        
        if self.context.sharedContext.immediateExperimentalUISettings.crashOnLongQueries {
            let _ = (self.ready.get()
            |> filter({ $0 })
            |> take(1)
            |> timeout(0.8, queue: .concurrentDefaultQueue(), alternate: Signal { _ in
                preconditionFailure()
            })).start()
        }
        
        self.chatDisplayNode.historyNode.contentPositionChanged = { [weak self] offset in
            if let strongSelf = self {
                let offsetAlpha: CGFloat
                let plainInputSeparatorAlpha: CGFloat
                switch offset {
                    case let .known(offset):
                        if offset < 40.0 {
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
                
                strongSelf.chatDisplayNode.navigateButtons.displayDownButton = !offsetAlpha.isZero
                strongSelf.chatDisplayNode.updatePlainInputSeparatorAlpha(plainInputSeparatorAlpha, transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }
        
        self.chatDisplayNode.historyNode.scrolledToIndex = { [weak self] toIndex in
            if let strongSelf = self, case let .message(index) = toIndex {
                if let controllerInteraction = strongSelf.controllerInteraction {
                    if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(index.id) {
                        let highlightedState = ChatInterfaceHighlightedState(messageStableId: message.stableId)
                        controllerInteraction.highlightedState = highlightedState
                        strongSelf.updateItemNodesHighlightedStates(animated: false)
                        
                        strongSelf.messageContextDisposable.set((Signal<Void, NoError>.complete() |> delay(0.7, queue: Queue.mainQueue())).start(completed: {
                            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                                if controllerInteraction.highlightedState == highlightedState {
                                    controllerInteraction.highlightedState = nil
                                    strongSelf.updateItemNodesHighlightedStates(animated: true)
                                }
                            }
                        }))
                    }
                }
            }
        }
        
        self.chatDisplayNode.historyNode.maxVisibleMessageIndexUpdated = { [weak self] index in
            if let strongSelf = self, !strongSelf.historyNavigationStack.isEmpty {
                strongSelf.historyNavigationStack.filterOutIndicesLessThan(index)
            }
        }
        
        self.chatDisplayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        
        self.chatDisplayNode.setupSendActionOnViewUpdate = { [weak self] f in
            self?.chatDisplayNode.historyNode.layoutActionOnViewTransition = { [weak self] transition in
                f()
                if let strongSelf = self, let validLayout = strongSelf.validLayout {
                    var mappedTransition: (ChatHistoryListViewTransition, ListViewUpdateSizeAndInsets?)?
                    
                    let isScheduledMessages = strongSelf.presentationInterfaceState.isScheduledMessages
                    strongSelf.chatDisplayNode.containerLayoutUpdated(validLayout, navigationBarHeight: strongSelf.navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut), listViewTransaction: { updateSizeAndInsets, _, _, _ in
                        var options = transition.options
                        let _ = options.insert(.Synchronous)
                        let _ = options.insert(.LowLatency)
                        let _ = options.insert(.PreferSynchronousResourceLoading)
                        options.remove(.AnimateInsertion)
                        options.insert(.RequestItemInsertionAnimations)
                        
                        let deleteItems = transition.deleteItems.map({ item in
                            return ListViewDeleteItem(index: item.index, directionHint: nil)
                        })
                        
                        var maxInsertedItem: Int?
                        var insertedIndex: Int?
                        var insertItems: [ListViewInsertItem] = []
                        for i in 0 ..< transition.insertItems.count {
                            let item = transition.insertItems[i]
                            if item.directionHint == .Down && (maxInsertedItem == nil || maxInsertedItem! < item.index) {
                                maxInsertedItem = item.index
                            }
                            insertedIndex = item.index
                            insertItems.append(ListViewInsertItem(index: item.index, previousIndex: item.previousIndex, item: item.item, directionHint: item.directionHint == .Down ? .Up : nil))
                        }
                        
                        var scrollToItem: ListViewScrollToItem?
                        if isScheduledMessages, let insertedIndex = insertedIndex {
                            scrollToItem = ListViewScrollToItem(index: insertedIndex, position: .visible, animated: true, curve: .Default(duration: 0.2), directionHint: .Down)
                        } else if transition.historyView.originalView.laterId == nil {
                            scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: 0.2), directionHint: .Up)
                        }
                        
                        var stationaryItemRange: (Int, Int)?
                        if let maxInsertedItem = maxInsertedItem {
                            stationaryItemRange = (maxInsertedItem + 1, Int.max)
                        }
                        
                        mappedTransition = (ChatHistoryListViewTransition(historyView: transition.historyView, deleteItems: deleteItems, insertItems: insertItems, updateItems: transition.updateItems, options: options, scrollToItem: scrollToItem, stationaryItemRange: stationaryItemRange, initialData: transition.initialData, keyboardButtonsMessage: transition.keyboardButtonsMessage, cachedData: transition.cachedData, cachedDataMessages: transition.cachedDataMessages, readStateData: transition.readStateData, scrolledToIndex: transition.scrolledToIndex, peerType: transition.peerType, networkType: transition.networkType, animateIn: false, reason: transition.reason, flashIndicators: transition.flashIndicators), updateSizeAndInsets)
                    })
                    
                    if let mappedTransition = mappedTransition {
                        return mappedTransition
                    }
                }
                return (transition, nil)
            }
        }
        
        self.chatDisplayNode.sendMessages = { [weak self] messages, silentPosting, scheduleTime, isAnyMessageTextPartitioned in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
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
                
                let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: transformedMessages)
                |> deliverOnMainQueue).start(next: { messageIds in
                    if let strongSelf = self {
                        if strongSelf.presentationInterfaceState.isScheduledMessages {
                        } else {
                            strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                        }
                    }
                })
                
                donateSendMessageIntent(account: strongSelf.context.account, sharedContext: strongSelf.context.sharedContext, intentContext: .chat, peerIds: [peerId])
            }
        }
        
        self.chatDisplayNode.requestUpdateChatInterfaceState = { [weak self] animated, saveInterfaceState, f in
            self?.updateChatPresentationInterfaceState(animated: animated, interactive: true, saveInterfaceState: saveInterfaceState, { $0.updatedInterfaceState(f) })
        }
        
        self.chatDisplayNode.requestUpdateInterfaceState = { [weak self] transition, interactive, f in
            self?.updateChatPresentationInterfaceState(transition: transition, interactive: interactive, f)
        }
        
        self.chatDisplayNode.displayAttachmentMenu = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.presentationInterfaceState.interfaceState.editMessage == nil, let _ = strongSelf.presentationInterfaceState.slowmodeState, !strongSelf.presentationInterfaceState.isScheduledMessages {
                if let rect = strongSelf.chatDisplayNode.frameForAttachmentButton() {
                    strongSelf.interfaceInteraction?.displaySlowmodeTooltip(strongSelf.chatDisplayNode, rect)
                }
                return
            }
            if case .peer = strongSelf.chatLocation, let messageId = strongSelf.presentationInterfaceState.interfaceState.editMessage?.messageId {
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> Message? in
                    return transaction.getMessage(messageId)
                } |> deliverOnMainQueue).start(next: { message in
                    guard let strongSelf = self, let editMessageState = strongSelf.presentationInterfaceState.editMessageState, case let .media(options) = editMessageState.content else {
                        return
                    }
                    var originalMediaReference: AnyMediaReference?
                    if let message = message {
                        for media in message.media {
                            if let image = media as? TelegramMediaImage {
                                originalMediaReference = .message(message: MessageReference(message), media: image)
                            } else if let file = media as? TelegramMediaFile {
                                if file.isVideo || file.isAnimated {
                                    originalMediaReference = .message(message: MessageReference(message), media: file)
                                }
                            }
                        }
                    }
                    strongSelf.presentAttachmentMenu(editMediaOptions: options, editMediaReference: originalMediaReference)
                })
            } else {
                strongSelf.presentAttachmentMenu(editMediaOptions: nil, editMediaReference: nil)
            }
        }
        self.chatDisplayNode.paste = { [weak self] data in
            switch data {
                case let .images(images):
                   self?.displayPasteMenu(images)
                case let .gif(data):
                    self?.enqueueGifData(data)
                case let .sticker(image, isMemoji):
                    self?.enqueueStickerImage(image, isMemoji: isMemoji)
            }
        }
        self.chatDisplayNode.updateTypingActivity = { [weak self] value in
            if let strongSelf = self, strongSelf.presentationInterfaceState.interfaceState.editMessage == nil && !strongSelf.presentationInterfaceState.isScheduledMessages {
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
                    strongSelf.navigateToMessage(from: nil, to: .id(messageId.id), rememberInStack: false)
                } else {
                    if case .known = strongSelf.chatDisplayNode.historyNode.visibleContentOffset() {
                        strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    } else if case let .peer(peerId) = strongSelf.chatLocation {
                        strongSelf.navigateToMessage(messageLocation: .upperBound(peerId), animated: true)
                    } else {
                        strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                    }
                }
            }
        }
        
        self.chatDisplayNode.navigateButtons.mentionsPressed = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded, case let .peer(peerId) = strongSelf.chatLocation {
                let signal = earliestUnseenPersonalMentionMessage(account: strongSelf.context.account, peerId: peerId)
                strongSelf.navigationActionDisposable.set((signal |> deliverOnMainQueue).start(next: { result in
                    if let strongSelf = self {
                        switch result {
                            case let .result(messageId):
                                if let messageId = messageId {
                                    strongSelf.navigateToMessage(from: nil, to: .id(messageId))
                                }
                            case .loading:
                                break
                        }
                    }
                }))
            }
        }
        
        self.chatDisplayNode.navigateButtons.mentionsMenu = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.WebSearch_RecentSectionClear, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                        return
                    }
                    let _ = clearPeerUnseenPersonalMessagesInteractively(account: strongSelf.context.account, peerId: peerId).start()
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(actionSheet, in: .window(.root))
        }
        
        let interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { [weak self] messageId, completion in
            if let strongSelf = self, strongSelf.isNodeLoaded, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId) {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageId(message.id) }).updatedSearch(nil) }, completion: completion)
                    strongSelf.updateItemNodesSearchTextHighlightStates()
                    strongSelf.chatDisplayNode.ensureInputViewFocused()
                } else {
                    completion(.immediate)
                }
            } else {
                completion(.immediate)
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
                            return $0.withUpdatedEditMessage(ChatEditMessageState(messageId: messageId, inputState: ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(message.text, entities: entities)), disableUrlPreview: nil))
                        }
                        
                        updated = updatedChatEditInterfaceMessagetState(state: updated, message: message)
                        updated = updated.updatedInputMode({ _ in
                            return .text
                        })
                        
                        return updated
                    }, completion: completion)
                }
            }
        }, beginMessageSelection: { [weak self] messageIds, completion in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withUpdatedSelectedMessages(messageIds) } }, completion: completion)
                
                    if let selectionState = strongSelf.presentationInterfaceState.interfaceState.selectionState {
                    let count = selectionState.selectedIds.count
                    let text: String
                    if count == 1 {
                        text = "1 message selected"
                    } else {
                        text = "\(count) messages selected"
                    }
                    UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: text)
                }
            } else {
                completion(.immediate)
            }
        }, deleteSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let messageIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                    strongSelf.messageContextDisposable.set((strongSelf.context.sharedContext.chatAvailableMessageActions(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: messageIds)
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
                strongSelf.present(peerReportOptionsController(context: strongSelf.context, subject: .messages(Array(messageIds).sorted()), present: { c, a in
                    self?.present(c, in: .window(.root), with: a)
                }, push: { c in
                    self?.push(c)
                }, completion: { _ in }), in: .window(.root))
            }
        }, reportMessages: { [weak self] messages, contextController in
            if let strongSelf = self, !messages.isEmpty {
                presentPeerReportOptions(context: strongSelf.context, parent: strongSelf, contextController: contextController, subject: .messages(messages.map({ $0.id }).sorted()), completion: { _ in })
            }
        }, deleteMessages: { [weak self] messages, contextController, completion in
            if let strongSelf = self, !messages.isEmpty {
                let messageIds = Set(messages.map { $0.id })
                strongSelf.messageContextDisposable.set((strongSelf.context.sharedContext.chatAvailableMessageActions(postbox: strongSelf.context.account.postbox, accountPeerId: strongSelf.context.account.peerId, messageIds: messageIds)
                |> deliverOnMainQueue).start(next: { actions in
                    if let strongSelf = self, !actions.options.isEmpty {
                        if let banAuthor = actions.banAuthor {
                            strongSelf.presentBanMessageOptions(accountPeerId: strongSelf.context.account.peerId, author: banAuthor, messageIds: messageIds, options: actions.options)
                            completion(.default)
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
                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: actions.options == .deleteLocally ? .forLocalPeer : .forEveryone).start()
                                completion(.dismissWithoutContent)
                            } else if (messages.first?.flags.isSending ?? false) {
                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone, deleteAllInGroup: true).start()
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
                    strongSelf.forwardMessages(messageIds: forwardMessageIds, resetCurrent: true)
                }
            }
        }, forwardMessages: { [weak self] messages in
            if let strongSelf = self, !messages.isEmpty {
                strongSelf.commitPurposefulAction()
                let forwardMessageIds = messages.map { $0.id }.sorted()
                strongSelf.forwardMessages(messageIds: forwardMessageIds)
            }
        }, shareSelectedMessages: { [weak self] in
            if let strongSelf = self, let selectedIds = strongSelf.presentationInterfaceState.interfaceState.selectionState?.selectedIds, !selectedIds.isEmpty {
                strongSelf.commitPurposefulAction()
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Message] in
                    var messages: [Message] = []
                    for id in selectedIds {
                        if let message = transaction.getMessage(id) {
                            messages.append(message)
                        }
                    }
                    return messages
                } |> deliverOnMainQueue).start(next: { messages in
                    if let strongSelf = self, !messages.isEmpty {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                        
                        let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                            return lhs.index < rhs.index
                        })), externalShare: true, immediateExternalShare: true)
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
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    return $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({
                        $0.withUpdatedMessageActionsState({ value in
                            var value = value
                            value.closedButtonKeyboardMessageId = updatedClosedButtonKeyboardMessageId
                            return value
                        })
                    })
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
                
                let editingMessage = strongSelf.editingMessage
                let text = trimChatInputText(convertMarkdownToAttributes(editMessage.inputState.inputText))
                let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                var entitiesAttribute: TextEntitiesMessageAttribute?
                if !entities.isEmpty {
                    entitiesAttribute = TextEntitiesMessageAttribute(entities: entities)
                }
                
                let media: RequestEditMessageMedia
                if let editMediaReference = strongSelf.presentationInterfaceState.editMessageState?.mediaReference {
                    media = .update(editMediaReference)
                } else {
                    media = .keep
                }
                
                strongSelf.context.account.pendingUpdateMessageManager.add(messageId: editMessage.messageId, text: text.string, media: media, entities: entitiesAttribute, disableUrlPreview: disableUrlPreview)
                
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    var state = state
                    state = state.updatedInterfaceState({ $0.withUpdatedEditMessage(nil) })
                    state = state.updatedEditMessageState(nil)
                    return state
                })
            }
        }, beginMessageSearch: { [weak self] domain, query in
            guard let strongSelf = self else {
                return
            }
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
                            
                            let controller = ChatSearchResultsController(context: strongSelf.context, location: searchLocation, searchQuery: searchData.query, searchResult: searchResult, searchState: searchState, navigateToMessageIndex: { index in
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
                        case .peer:
                            strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex), forceInCurrentChat: true)
                        /*case .group:
                            strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex))*/
                    }
                }
            }
        }, openCalendarSearch: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.chatDisplayNode.dismissInput()
                
                let controller = ChatDateSelectionSheet(presentationData: strongSelf.presentationData, completion: { timestamp in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.loadingMessage.set(true)
                    strongSelf.messageIndexDisposable.set((searchMessageIdByTimestamp(account: strongSelf.context.account, peerId: peerId, timestamp: timestamp) |> deliverOnMainQueue).start(next: { messageId in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(false)
                            if let messageId = messageId {
                                strongSelf.navigateToMessage(from: nil, to: .id(messageId), forceInCurrentChat: true)
                            }
                        }
                    }))
                })
                strongSelf.present(controller, in: .window(.root))
            }
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
        }, navigateToMessage: { [weak self] messageId in
            self?.navigateToMessage(from: nil, to: .id(messageId))
        }, navigateToChat: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            if let navigationController = strongSelf.effectiveNavigationController {
                strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), subject: nil, keepStack: .always))
            }
        }, openPeerInfo: { [weak self] in
            self?.navigationButtonAction(.openChatInfo(expandAvatar: false))
        }, togglePeerNotifications: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                let _ = togglePeerMuted(account: strongSelf.context.account, peerId: peerId).start()
            }
        }, sendContextResult: { [weak self] results, result, node, rect in
            guard let strongSelf = self else {
                return false
            }
            if let _ = strongSelf.presentationInterfaceState.slowmodeState, !strongSelf.presentationInterfaceState.isScheduledMessages {
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
                    })
                    var attributes: [MessageAttribute] = []
                    let entities = generateTextEntities(messageText, enabledTypes: .all)
                    if !entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                    }
                    strongSelf.sendMessages([.message(text: messageText, attributes: attributes, mediaReference: nil, replyToMessageId: replyMessageId, localGroupingKey: nil)])
                }
            }
        }, sendBotStart: { [weak self] payload in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                strongSelf.startBot(payload)
            }
        }, botSwitchChatWithPayload: { [weak self] peerId, payload in
            if let strongSelf = self, case let .peer(currentPeerId) = strongSelf.chatLocation {
                strongSelf.openPeer(peerId: peerId, navigation: .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .automatic(returnToPeerId: currentPeerId, scheduled: strongSelf.presentationInterfaceState.isScheduledMessages))), fromMessage: nil)
            }
        }, beginMediaRecording: { [weak self] isVideo in
            guard let strongSelf = self else {
                return
            }
            strongSelf.mediaRecordingModeTooltipController?.dismiss()
            
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
                        strongSelf.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Call_CallInProgressTitle, text: strongSelf.presentationData.strings.Call_RecordingDisabledMessage, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
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
                    DeviceAccess.authorizeAccess(to: .camera, presentationData: strongSelf.presentationData, present: { c, a in
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
        }, sendRecordedMedia: { [weak self] in
            self?.sendMediaRecording()
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
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedStickersTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).0
                        } else if personal {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedStickers
                        } else {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_DefaultRestrictedStickers
                        }
                    case .mediaRecording:
                        if untilDate != 0 && untilDate != Int32.max {
                            banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).0
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
                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: banDescription, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }, displayVideoUnmuteTip: { [weak self] location in
            guard let strongSelf = self, let layout = strongSelf.validLayout, strongSelf.traceVisibility() && isTopmostChatController(strongSelf) else {
                return
            }
            
            if let location = location, location.y < strongSelf.navigationHeight {
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
                    return $0.updatedInterfaceState { current in
                        let mode: ChatTextInputMediaRecordingButtonMode
                        switch current.mediaRecordingMode {
                            case .audio:
                                mode = .video
                            case .video:
                                mode = .audio
                        }
                        updatedMode = mode
                        return current.withUpdatedMediaRecordingMode(mode)
                    }
                })
                
                if let updatedMode = updatedMode, updatedMode == .video {
                    let _ = ApplicationSpecificNotice.incrementChatMediaMediaRecordingTips(accountManager: strongSelf.context.sharedContext.accountManager, count: 3).start()
                }
                
                strongSelf.displayMediaRecordingTooltip()
            }
        }, setupMessageAutoremoveTimeout: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                strongSelf.chatDisplayNode.dismissInput()
                
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat {
                    let controller = ChatSecretAutoremoveTimerActionSheetController(context: strongSelf.context, currentValue: peer.messageAutoremoveTimeout == nil ? 0 : peer.messageAutoremoveTimeout!, applyValue: { value in
                        if let strongSelf = self {
                            let _ = setSecretChatMessageAutoremoveTimeoutInteractively(account: strongSelf.context.account, peerId: peer.id, timeout: value == 0 ? nil : value).start()
                        }
                    })
                    strongSelf.present(controller, in: .window(.root))
                }
            }
        }, sendSticker: { [weak self] file, sourceNode, sourceRect in
            if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState) {
                return strongSelf.controllerInteraction?.sendSticker(file, true, sourceNode, sourceRect) ?? false
            } else {
                return false
            }
        }, unblockPeer: { [weak self] in
            self?.unblockPeer()
        }, pinMessage: { [weak self] messageId in
            if let strongSelf = self, case let .peer(currentPeerId) = strongSelf.chatLocation {
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
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
                    } else if let _ = peer as? TelegramUser, strongSelf.presentationInterfaceState.explicitelyCanPinMessages {
                        canManagePin = true
                    }
                        
                    if canManagePin {
                        let pinAction: (Bool) -> Void = { notify in
                            if let strongSelf = self {
                                let disposable: MetaDisposable
                                if let current = strongSelf.unpinMessageDisposable {
                                    disposable = current
                                } else {
                                    disposable = MetaDisposable()
                                    strongSelf.unpinMessageDisposable = disposable
                                }
                                disposable.set(requestUpdatePinnedMessage(account: strongSelf.context.account, peerId: currentPeerId, update: .pin(id: messageId, silent: !notify)).start())
                            }
                        }
                        
                        var pinImmediately = false
                        if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                            pinImmediately = true
                        } else if let _ = peer as? TelegramUser {
                            pinImmediately = true
                        }
                        
                        if pinImmediately {
                            pinAction(true)
                        } else {
                            strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Conversation_PinMessageAlertGroup, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_PinMessageAlert_OnlyPin, action: {
                                pinAction(false)
                            }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                                pinAction(true)
                            })]), in: .window(.root))
                        }
                    } else {
                        if let pinnedMessageId = strongSelf.presentationInterfaceState.pinnedMessage?.id {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                    var value = value
                                    value.closedPinnedMessageId = pinnedMessageId
                                    return value
                                    })
                                })
                            })
                        }
                    }
                }
            }
        }, unpinMessage: { [weak self] in
            if let strongSelf = self {
                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
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
                    } else if let _ = peer as? TelegramUser, strongSelf.presentationInterfaceState.explicitelyCanPinMessages {
                        canManagePin = true
                    }
                        
                    if canManagePin {
                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Conversation_UnpinMessageAlert, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Conversation_Unpin, action: {
                            if let strongSelf = self {
                                let disposable: MetaDisposable
                                if let current = strongSelf.unpinMessageDisposable {
                                    disposable = current
                                } else {
                                    disposable = MetaDisposable()
                                    strongSelf.unpinMessageDisposable = disposable
                                }
                                disposable.set(requestUpdatePinnedMessage(account: strongSelf.context.account, peerId: peer.id, update: .clear).start())
                            }
                        })]), in: .window(.root))
                    } else {
                        if let pinnedMessage = strongSelf.presentationInterfaceState.pinnedMessage {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                return $0.updatedInterfaceState({ $0.withUpdatedMessageActionsState({ value in
                                    var value = value
                                    value.closedPinnedMessageId = pinnedMessage.id
                                    return value
                                }) })
                            })
                        }
                    }
                }
            }
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
        }, beginCall: { [weak self] in
            if let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation {
                strongSelf.controllerInteraction?.callPeer(peerId)
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
                    let postbox = strongSelf.context.account.postbox
                    let network = strongSelf.context.account.network
                    let _ = (strongSelf.context.account.postbox.transaction { transaction -> Signal<Void, NoError> in
                        if getIsStickerSaved(transaction: transaction, fileId: stickerFile.fileId) {
                            removeSavedSticker(transaction: transaction, mediaId: stickerFile.fileId)
                            return .complete()
                        } else {
                            return addSavedSticker(postbox: postbox, network: network, file: stickerFile)
                                |> `catch` { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }
                        }
                    } |> switchToLatest).start()
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
            let signal = requestMessageSelectPollOption(account: strongSelf.context.account, messageId: id, opaqueIdentifiers: [])
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
                    let signal = requestClosePoll(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, stateManager: strongSelf.context.account.stateManager, messageId: id)
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
            let _ = (strongSelf.context.account.postbox.transaction { transaction -> Void in
                updatePeerGroupIdInteractively(transaction: transaction, peerId: peerId, groupId: .root)
            }
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
                
                let controller = chatTextLinkEditController(sharedContext: strongSelf.context.sharedContext, account: strongSelf.context.account, text: text ?? "", link: nil, apply: { [weak self] link in
                    if let strongSelf = self, let inputMode = inputMode, let selectionRange = selectionRange {
                        if let link = link {
                            strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                                return (chatTextInputAddLinkAttribute(current, url: link), inputMode)
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
                strongSelf.reportIrrelvantGeoDisposable = (TelegramCore.reportPeer(account: strongSelf.context.account, peerId: peerId, reason: .irrelevantLocation)
                |> deliverOnMainQueue).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.reportIrrelvantGeoNoticePromise.set(.single(true))
                        let _ = ApplicationSpecificNotice.setIrrelevantPeerGeoReport(postbox: strongSelf.context.account.postbox, peerId: peerId).start()
                        
                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.ReportPeer_AlertSuccess, actions: [TextAlertAction(type: TextAlertActionType.defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                })
            })]
            strongSelf.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.ReportGroupLocation_Title, text: strongSelf.presentationData.strings.ReportGroupLocation_Text, actions: actions), in: .window(.root))
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
                
                let controller = ChatSendMessageActionSheetController(context: strongSelf.context, controllerInteraction: strongSelf.controllerInteraction, interfaceState: strongSelf.presentationInterfaceState, gesture: gesture, sendButtonFrame: node.view.convert(node.bounds, to: nil), textInputNode: textInputNode, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.supportedOrientations = previousSupportedOrientations
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
        }, statuses: ChatPanelInterfaceInteractionStatuses(editingMessage: self.editingMessage.get(), startingBot: self.startingBot.get(), unblockingPeer: self.unblockingPeer.get(), searching: self.searching.get(), loadingMessage: self.loadingMessage.get()))
        
        switch self.chatLocation {
            case let .peer(peerId):
                if let subject = self.subject, case .scheduledMessages = subject {
                } else {
                    let unreadCountsKey: PostboxViewKey = .unreadCounts(items: [.peer(peerId), .total(nil)])
                    let notificationSettingsKey: PostboxViewKey = .peerNotificationSettings(peerIds: Set([peerId]))
                    self.chatUnreadCountDisposable = (self.context.account.postbox.combinedView(keys: [unreadCountsKey, notificationSettingsKey])
                    |> deliverOnMainQueue).start(next: { [weak self] views in
                        if let strongSelf = self {
                            var unreadCount: Int32 = 0
                            var totalChatCount: Int32 = 0
                            
                            let inAppSettings = strongSelf.context.sharedContext.currentInAppNotificationSettings.with { $0 }
                            if let view = views.views[unreadCountsKey] as? UnreadMessageCountsView {
                                if let count = view.count(for: .peer(peerId)) {
                                    unreadCount = count
                                }
                                if let (_, state) = view.total() {
                                    let (count, _) = renderedTotalUnreadCount(inAppSettings: inAppSettings, totalUnreadState: state)
                                    totalChatCount = count
                                }
                            }
                            
                            strongSelf.chatDisplayNode.navigateButtons.unreadCount = unreadCount
                            
                            if let view = views.views[notificationSettingsKey] as? PeerNotificationSettingsView, let notificationSettings = view.notificationSettings[peerId] {
                                var globalRemainingUnreadChatCount = totalChatCount
                                if !notificationSettings.isRemovedFromTotalUnreadCount(default: false) && unreadCount > 0 {
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
                            }
                        }
                    })
                
                    self.chatUnreadMentionCountDisposable = (self.context.account.viewTracker.unseenPersonalMessagesCount(peerId: peerId) |> deliverOnMainQueue).start(next: { [weak self] count in
                        if let strongSelf = self {
                            if case let .standard(previewing) = strongSelf.presentationInterfaceState.mode, previewing {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = 0
                            } else {
                                strongSelf.chatDisplayNode.navigateButtons.mentionCount = count
                            }
                        }
                    })
                    
                    let postbox = self.context.account.postbox
                    let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
                    self.peerInputActivitiesDisposable = (self.context.account.peerInputActivities(peerId: peerId)
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
                            return postbox.transaction { transaction -> [(Peer, PeerInputActivity)] in
                                var result: [(Peer, PeerInputActivity)] = []
                                var peerCache: [PeerId: Peer] = [:]
                                for (peerId, activity) in activities {
                                    if let peer = transaction.getPeer(peerId) {
                                        result.append((peer, activity))
                                        peerCache[peerId] = peer
                                    }
                                }
                                let _ = previousPeerCache.swap(peerCache)
                                return result
                            }
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] activities in
                        if let strongSelf = self {
                            strongSelf.chatTitleView?.inputActivities = (peerId, activities)
                        }
                    })
                }
                
                self.sentMessageEventsDisposable.set((self.context.account.pendingMessageManager.deliveredMessageEvents(peerId: peerId)
                |> deliverOnMainQueue).start(next: { [weak self] namespace in
                    if let strongSelf = self {
                        let inAppNotificationSettings = strongSelf.context.sharedContext.currentInAppNotificationSettings.with { $0 }
                        if inAppNotificationSettings.playSounds {
                            serviceSoundManager.playMessageDeliveredSound()
                        }
                        if !strongSelf.presentationInterfaceState.isScheduledMessages && namespace == Namespaces.Message.ScheduledCloud {
                            strongSelf.openScheduledMessages()
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
                                self?.openPeerMention("spambot", navigation: .chat(textInputState: nil, subject: nil))
                            }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]
                        } else {
                            actions = [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]
                        }
                        let controller = textAlertController(context: strongSelf.context, title: nil, text: text, actions: actions)
                        strongSelf.currentFailedMessagesAlertController = controller
                        strongSelf.present(controller, in: .window(.root))
                    }
                }))
        }
        
        self.interfaceInteraction = interfaceInteraction
        
        if self.focusOnSearchAfterAppearance {
            self.focusOnSearchAfterAppearance = false
            self.interfaceInteraction?.beginMessageSearch(.everything, "")
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
        
        let shouldBeActive = combineLatest(self.context.sharedContext.mediaManager.audioSession.isPlaybackActive() |> deliverOnMainQueue, self.chatDisplayNode.historyNode.hasVisiblePlayableItemNodes)
        |> mapToSignal { [weak self] isPlaybackActive, hasVisiblePlayableItemNodes -> Signal<Bool, NoError> in
            if hasVisiblePlayableItemNodes && !isPlaybackActive {
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
                    if case let .visible(fraction) = itemNode.visibility, fraction > 0.7 {
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
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.chatDisplayNode.historyNode.preloadPages = true
        self.chatDisplayNode.historyNode.experimentalSnapScrollToItem = false
        self.chatDisplayNode.historyNode.canReadHistory.set(combineLatest(context.sharedContext.applicationBindings.applicationInForeground, self.canReadHistory.get()) |> map { a, b in
            return a && b
        })
        
        self.chatDisplayNode.loadInputPanels(theme: self.presentationInterfaceState.theme, strings: self.presentationInterfaceState.strings, fontSize: self.presentationInterfaceState.fontSize)
        
        self.recentlyUsedInlineBotsDisposable = (recentlyUsedInlineBots(postbox: self.context.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] peers in
            self?.recentlyUsedInlineBotsValue = peers.filter({ $0.1 >= 0.14 }).map({ $0.0 })
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
                        
                        if case let .media(_, expanded) = strongSelf.presentationInterfaceState.inputMode, expanded != nil {
                            return false
                        }
                        
                        if !strongSelf.context.sharedContext.currentMediaInputSettings.with { $0.enableRaiseToSpeak } {
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
                if let strongSelf = self, let raiseToListen = strongSelf.raiseToListen {
                    strongSelf.voicePlaylistDidEndTimestamp = CACurrentMediaTime()
                    raiseToListen.activateBasedOnProximity(delay: 0.0)
                }
            }
            self.tempVoicePlaylistItemChanged = { [weak self] previousItem, currentItem in
                guard let strongSelf = self, case let .peer(peerId) = strongSelf.chatLocation else {
                    return
                }
                if let currentItem = currentItem?.id as? PeerMessagesMediaPlaylistItemId, let previousItem = previousItem?.id as? PeerMessagesMediaPlaylistItemId, previousItem.messageId.peerId == peerId, currentItem.messageId.peerId == peerId, currentItem.messageId != previousItem.messageId {
                    if strongSelf.chatDisplayNode.historyNode.isMessageVisibleOnScreen(currentItem.messageId) {
                        strongSelf.navigateToMessage(from: nil, to: .id(currentItem.messageId), scrollPosition: .center(.bottom), rememberInStack: false, animated: true, completion: nil)
                    }
                }
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
                        let _ = addSecretChatMessageScreenshot(account: strongSelf.context.account, peerId: peerId).start()
                        return true
                    } else {
                        return false
                    }
                })
            }
            
            if case let .peer(peerId) = self.chatLocation {
                let _ = checkPeerChatServiceActions(postbox: self.context.account.postbox, peerId: peerId).start()
            }
            
            if self.chatDisplayNode.frameForInputActionButton() != nil {
                let inputText = self.presentationInterfaceState.interfaceState.effectiveInputState.inputText.string
                if !inputText.isEmpty {
                    if inputText.count > 4 {
                        let _ = (ApplicationSpecificNotice.getChatMessageOptionsTip(accountManager: context.sharedContext.accountManager)
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
                case .generic:
                    text = strongSelf.presentationData.strings.Channel_EditMessageErrorGeneric
                case .restricted:
                    text = strongSelf.presentationData.strings.Group_ErrorSendRestrictedMedia
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                })]), in: .window(.root))
            }))
            
            if case let .peer(peerId) = self.chatLocation {
                self.keepPeerInfoScreenDataHotDisposable.set(keepPeerInfoScreenDataHot(context: self.context, peerId: peerId).start())
            }
        }
        
        if self.focusOnSearchAfterAppearance {
            self.focusOnSearchAfterAppearance = false
            if let searchNode = self.navigationBar?.contentNode as? ChatSearchNavigationContentNode {
                searchNode.activate()
            }
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.chatDisplayNode.historyNode.canReadHistory.set(.single(false))
        self.saveInterfaceState()
        
        self.dismissAllTooltips()
        
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
        
        self.sendMessageActionsController?.dismiss()
    }
    
    private func saveInterfaceState(includeScrollState: Bool = true) {
        if case let .peer(peerId) = self.chatLocation {
            let timestamp = Int32(Date().timeIntervalSince1970)
            var interfaceState = self.presentationInterfaceState.interfaceState.withUpdatedTimestamp(timestamp)
            if includeScrollState {
                let scrollState = self.chatDisplayNode.historyNode.immediateScrollState()
                interfaceState = interfaceState.withUpdatedHistoryScrollState(scrollState)
            }
            interfaceState = interfaceState.withUpdatedInputLanguage(self.chatDisplayNode.currentTextInputLanguage)
            let _ = updatePeerChatInterfaceState(account: self.context.account, peerId: peerId, state: interfaceState).start()
        }
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
    
    override public func inFocusUpdated(isInFocus: Bool) {
        self.chatDisplayNode.inFocusUpdated(isInFocus: isInFocus)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        self.chatTitleView?.layout = layout
        
        if self.hasScheduledMessages, let h = layout.inputHeight, h > 100.0 {
            print()
        }
        
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
        
        self.chatDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition, listViewTransaction: { updateSizeAndInsets, additionalScrollDistance, scrollToTop, completion in
            self.chatDisplayNode.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, additionalScrollDistance: additionalScrollDistance, scrollToTop: scrollToTop, completion: completion)
        })
    }
    
    override public func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        guard let layout = self.validLayout, case .compact = layout.metrics.widthClass else {
            return
        }
        let hasOverlayNodes = self.context.sharedContext.mediaManager.overlayMediaManager.controller?.hasNodes ?? false
        if self.validLayout != nil && orientation.isLandscape && !hasOverlayNodes && self.traceVisibility() && isTopmostChatController(self) {
            var completed = false
            self.chatDisplayNode.historyNode.forEachVisibleItemNode { itemNode in
                if !completed, let itemNode = itemNode as? ChatMessageItemView, let message = itemNode.item?.message,  let (_, soundEnabled, _, _, _) = itemNode.playMediaWithSound(), soundEnabled {
                    let _ = self.controllerInteraction?.openMessage(message, .landscape)
                    completed = true
                }
            }
        }
    }
    
    func updateChatPresentationInterfaceState(animated: Bool = true, interactive: Bool, saveInterfaceState: Bool = false, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        self.updateChatPresentationInterfaceState(transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, interactive: interactive, saveInterfaceState: saveInterfaceState, f, completion: completion)
    }
    
    func updateChatPresentationInterfaceState(transition: ContainedViewLayoutTransition, interactive: Bool, saveInterfaceState: Bool = false, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion externalCompletion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        var completion = externalCompletion
        var temporaryChatPresentationInterfaceState = f(self.presentationInterfaceState)
        
        if self.presentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup != temporaryChatPresentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup {
            if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, let _ = keyboardButtonsMessage.visibleButtonKeyboardMarkup {
                if self.presentationInterfaceState.interfaceState.editMessage == nil && self.presentationInterfaceState.interfaceState.composeInputState.inputText.length == 0 && keyboardButtonsMessage.id != temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.closedButtonKeyboardMessageId && temporaryChatPresentationInterfaceState.botStartPayload == nil {
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
        
        let contextQueryUpdates = contextQueryResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, context: self.context, currentQueryStates: &self.contextQueryStates)
        
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
            case let .update(query, signal):
                let currentQueryAndDisposable = self.contextQueryStates[kind]
                currentQueryAndDisposable?.1.dispose()
                
                var inScope = true
                var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
                self.contextQueryStates[kind] = (query, (signal |> deliverOnMainQueue).start(next: { [weak self] result in
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
                        switch error {
                            case let .inlineBotLocationRequest(peerId):
                                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Conversation_ShareInlineBotLocationConfirmation, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                    let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peerId, value: Int32(Date().timeIntervalSince1970 + 10 * 60)).start()
                                }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                                    let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: strongSelf.context.sharedContext.accountManager, peerId: peerId, value: 0).start()
                                })]), in: .window(.root))
                        }
                    }
                }))
                inScope = false
                if let inScopeResult = inScopeResult {
                    updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult(queryKind: kind, { previousResult in
                        return inScopeResult(previousResult)
                    })
                }
            
                if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                    if case .contextRequest = query {
                        let _ = (ApplicationSpecificNotice.getSecretChatInlineBotUsage(accountManager: self.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).start(next: { [weak self] value in
                            if let strongSelf = self, !value {
                                let _ = ApplicationSpecificNotice.setSecretChatInlineBotUsage(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Conversation_SecretChatContextBotAlert, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
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
                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Conversation_SecretLinkPreviewAlert, actions: [
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
                self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
                self.deferScreenEdgeGestures = []
            case .overlay:
                self.deferScreenEdgeGestures = [.top]
            case .inline:
                self.statusBar.statusBarStyle = .Ignore
        }
        
        if saveInterfaceState {
            self.saveInterfaceState(includeScrollState: false)
        }
    }
    
    private func updateItemNodesSelectionStates(animated: Bool) {
        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateSelectionState(animated: animated)
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
    
    private func navigationButtonAction(_ action: ChatNavigationButtonAction) {
        switch action {
        case .cancelMessageSelection:
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
        case .clearHistory:
            if case let .peer(peerId) = self.chatLocation {
                guard let peer = self.presentationInterfaceState.renderedPeer, let chatPeer = peer.peers[peer.peerId], let mainPeer = peer.chatMainPeer else {
                    return
                }
                
                let text: String
                if peerId == self.context.account.peerId {
                    text = self.presentationData.strings.Conversation_ClearSelfHistory
                } else if peerId.namespace == Namespaces.Peer.SecretChat {
                    text = self.presentationData.strings.Conversation_ClearSecretHistory
                } else if peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel {
                    text = self.presentationData.strings.Conversation_ClearGroupHistory
                } else {
                    text = self.presentationData.strings.Conversation_ClearPrivateHistory
                }
                
                var canRemoveGlobally = false
                let limitsConfiguration = self.context.currentLimitsConfiguration.with { $0 }
                if peerId.namespace == Namespaces.Peer.CloudUser && peerId != self.context.account.peerId {
                    if limitsConfiguration.maxMessageRevokeIntervalInPrivateChats == LimitsConfiguration.timeIntervalForever {
                        canRemoveGlobally = true
                    }
                }
                if let user = chatPeer as? TelegramUser, user.botInfo != nil {
                    canRemoveGlobally = false
                }
                
                let account = self.context.account
                
                let beginClear: (InteractiveHistoryClearingType) -> Void = { [weak self] type in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    strongSelf.chatDisplayNode.historyNode.historyAppearsCleared = true
                    
                    let statusText: String
                    if strongSelf.presentationInterfaceState.isScheduledMessages {
                        statusText = strongSelf.presentationData.strings.Undo_ScheduledMessagesCleared
                    } else if case .forEveryone = type {
                        statusText = strongSelf.presentationData.strings.Undo_ChatClearedForBothSides
                    } else {
                        statusText = strongSelf.presentationData.strings.Undo_ChatCleared
                    }
                    
                    strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(text: statusText), elevatedLayout: true, action: { value in
                        if value == .commit {
                            let _ = clearHistoryInteractively(postbox: account.postbox, peerId: peerId, type: type).start(completed: {
                                self?.chatDisplayNode.historyNode.historyAppearsCleared = false
                            })
                            return true
                        } else if value == .undo {
                            self?.chatDisplayNode.historyNode.historyAppearsCleared = false
                            return true
                        }
                        return false
                    }), in: .current)
                }
                
                let actionSheet = ActionSheetController(presentationData: self.presentationData)
                var items: [ActionSheetItem] = []
                
                if self.presentationInterfaceState.isScheduledMessages {
                    items.append(ActionSheetButtonItem(title: self.presentationData.strings.ScheduledMessages_ClearAllConfirmation, color: .destructive, action: { [weak self, weak actionSheet] in
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
                } else if canRemoveGlobally {
                    items.append(DeleteChatPeerActionSheetItem(context: self.context, peer: mainPeer, chatPeer: chatPeer, action: .clearHistory, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder))
                    items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteForEveryone(mainPeer.compactDisplayTitle).0, color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationTitle, text: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationText, actions: [
                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                            }),
                            TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteForEveryoneConfirmationAction, action: {
                                beginClear(.forEveryone)
                            })
                        ], parseMarkdown: true), in: .window(.root))
                    }))
                    items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteForCurrentUser, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        beginClear(.forLocalPeer)
                    }))
                } else {
                    items.append(ActionSheetTextItem(title: text))
                    items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ClearAll, color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let strongSelf = self else {
                            return
                        }
                        
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationTitle, text: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationText, actions: [
                            TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                            }),
                            TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.ChatList_DeleteSavedMessagesConfirmationAction, action: {
                                beginClear(.forLocalPeer)
                            })
                        ], parseMarkdown: true), in: .window(.root))
                    }))
                }

                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                
                self.chatDisplayNode.dismissInput()
                self.present(actionSheet, in: .window(.root))
            }
        case let .openChatInfo(expandAvatar):
            switch self.chatLocationInfoData {
            case let .peer(peerView):
                self.navigationActionDisposable.set((peerView.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] peerView in
                    if let strongSelf = self, let peer = peerView.peers[peerView.peerId], peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil && !strongSelf.presentationInterfaceState.isNotAccessible {
                        if peer.id == strongSelf.context.account.peerId {
                            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer, let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: true) {
                                strongSelf.effectiveNavigationController?.pushViewController(infoController)
                            }
                            //strongSelf.effectiveNavigationController?.pushViewController(PeerMediaCollectionController(context: strongSelf.context, peerId: strongSelf.context.account.peerId))
                        } else {
                            var expandAvatar = expandAvatar
                            if peer.smallProfileImage == nil {
                                expandAvatar = false
                            }
                            if let validLayout = strongSelf.validLayout, validLayout.deviceMetrics.type == .tablet {
                                expandAvatar = false
                            }
                            if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, peer: peer, mode: .generic, avatarInitiallyExpanded: expandAvatar, fromChat: true) {
                                strongSelf.effectiveNavigationController?.pushViewController(infoController)
                            }
                        }
                    }
                }))
            }
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
                    
                    let cacheUsageStats = (collectCacheUsageStats(account: strongSelf.context.account, peerId: peer.id)
                    |> deliverOnMainQueue).start(next: { [weak self, weak controller] result in
                        controller?.dismiss()
                        
                        guard let strongSelf = self, case let .result(stats) = result, var categories = stats.media[peer.id] else {
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
                                    title = presentationData.strings.Cache_Clear("\(dataSizeString(filteredSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))").0
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
                        
                        items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: peer, chatPeer: peer, action: .clearCache, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder))
                        
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
                                    items.append(ActionSheetCheckboxItem(title: stringForCategory(strings: presentationData.strings, category: categoryId), label: dataSizeString(categorySize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), value: true, action: { value in
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
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_Clear("\(dataSizeString(totalSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))").0, action: {
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
                                
                                var clearResourceIds = Set<WrappedMediaResourceId>()
                                for id in clearMediaIds {
                                    if let ids = stats.mediaResourceIds[id] {
                                        for resourceId in ids {
                                            clearResourceIds.insert(WrappedMediaResourceId(resourceId))
                                        }
                                    }
                                }
                                
                                var signal = clearCachedMediaResources(account: strongSelf.context.account, mediaResourceIds: clearResourceIds)
                                
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
                                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.ClearCache_Success("\(dataSizeString(selectedSize, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))", stringForDeviceType()).0), elevatedLayout: true, action: { _ in return false }), in: .current)
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
        if let message = messages.first, case let .message(desc) = message, let mediaReference = desc.mediaReference {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                var state = state
                if let editMessageState = state.editMessageState, case let .media(options) = editMessageState.content, !options.isEmpty {
                    state = state.updatedEditMessageState(ChatEditInterfaceMessageState(content: editMessageState.content, mediaReference: mediaReference))
                }
                if !desc.text.isEmpty {
                    state = state.updatedInterfaceState { state in
                        if let editMessage = state.editMessage {
                            return state.withUpdatedEditMessage(ChatEditMessageState(messageId: editMessage.messageId, inputState: ChatTextInputState(inputText: NSAttributedString(string: desc.text)), disableUrlPreview: editMessage.disableUrlPreview))
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
        guard case .peer = self.chatLocation else {
            return
        }
        
        let _ = (legacyAssetPickerEnqueueMessages(account: self.context.account, signals: signals)
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            self?.editMessageMediaWithMessages(messages)
        })
    }
    
    private func presentAttachmentMenu(editMediaOptions: MessageMediaEditingOptions?, editMediaReference: AnyMediaReference?) {
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings) as? GeneratedMediaStoreSettings
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
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).0
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
                        self?.presentPollCreation()
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
            
            let controller = legacyAttachmentMenu(context: strongSelf.context, peer: peer, editMediaOptions: menuEditMediaOptions, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, hasSchedule: !strongSelf.presentationInterfaceState.isScheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, canSendPolls: canSendPolls, presentationData: strongSelf.presentationData, parentController: legacyController, recentlyUsedInlineBots: strongSelf.recentlyUsedInlineBotsValue, initialCaption: inputText.string, openGallery: {
                self?.presentMediaPicker(fileMode: false, editingMedia: editMediaOptions != nil, completion: { signals, silentPosting, scheduleTime in
                    if !inputText.string.isEmpty {
                        //strongSelf.clearInputText()
                    }
                    if editMediaOptions != nil {
                        self?.editMessageMediaWithLegacySignals(signals)
                    } else {
                        self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                    }
                })
            }, openCamera: { [weak self] cameraView, menuController in
                if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                    presentedLegacyCamera(context: strongSelf.context, peer: peer, cameraView: cameraView, menuController: menuController, parentController: strongSelf, editingMedia: editMediaOptions != nil, saveCapturedPhotos: settings.storeEditedPhotos, mediaGrouping: true, initialCaption: inputText.string, hasSchedule: !strongSelf.presentationInterfaceState.isScheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime in
                        if let strongSelf = self {
                            if editMediaOptions != nil {
                                strongSelf.editMessageMediaWithLegacySignals(signals!)
                            } else {
                                strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                            }
                            if !inputText.string.isEmpty {
                                //strongSelf.clearInputText()
                            }
                        }
                    }, recognizedQRCode: { [weak self] code in
                        if let strongSelf = self {
                            if let (host, port, username, password, secret) = parseProxyUrl(code) {
                                strongSelf.openResolved(ResolvedUrl.proxy(host: host, port: port, username: username, password: password, secret: secret))
                            }/* else if let url = URL(string: code), let parsedWalletUrl = parseWalletUrl(url) {
                                //strongSelf.openResolved(ResolvedUrl.wallet(address: parsedWalletUrl.address, amount: parsedWalletUrl.amount, comment: parsedWalletUrl.comment))
                            }*/
                        }
                    }, presentSchedulePicker: { [weak self] done in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(completion: { [weak self] time in
                                if let strongSelf = self {
                                    done(time)
                                    if !strongSelf.presentationInterfaceState.isScheduledMessages && time != scheduleWhenOnlineTimestamp {
                                        strongSelf.openScheduledMessages()
                                    }
                                }
                            })
                        }
                    })
                }
            }, openFileGallery: {
                self?.presentFileMediaPickerOptions(editingMessage: editMediaOptions != nil)
            }, openWebSearch: {
                self?.presentWebSearch(editingMessage : editMediaOptions != nil)
            }, openMap: {
                self?.presentLocationPicker()
            }, openContacts: {
                self?.presentContactPicker()
            }, openPoll: {
                self?.presentPollCreation()
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
            }, presentSchedulePicker: { [weak self] done in
                if let strongSelf = self {
                    strongSelf.presentScheduleTimePicker(completion: { [weak self] time in
                        if let strongSelf = self {
                             done(time)
                            if !strongSelf.presentationInterfaceState.isScheduledMessages && time != scheduleWhenOnlineTimestamp {
                                strongSelf.openScheduledMessages()
                            }
                         }
                    })
                }
            }, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime in
                if !inputText.string.isEmpty {
                    //strongSelf.clearInputText()
                }
                if editMediaOptions != nil {
                    self?.editMessageMediaWithLegacySignals(signals!)
                } else {
                    self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                }
            }, selectRecentlyUsedInlineBot: { [weak self] peer in
                if let strongSelf = self, let addressName = peer.addressName {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState({ $0.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: "@" + addressName + " "))) }).updatedInputMode({ _ in
                            return .text
                        })
                    })
                }
            }, present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            })
            controller.didDismiss = { [weak legacyController] _ in
                legacyController?.dismiss()
            }
            controller.customRemoveFromParentViewController = { [weak legacyController] in
                legacyController?.dismiss()
            }
        
            strongSelf.present(legacyController, in: .window(.root))
            controller.present(in: emptyController, sourceView: nil, animated: true)
            
            let presentationDisposable = strongSelf.context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
                if let controller = controller {
                    controller.pallete = legacyMenuPaletteFromTheme(presentationData.theme)
                }
            })
            legacyController.disposables.add(presentationDisposable)
        })
    }
    
    private func presentFileMediaPickerOptions(editingMessage: Bool) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FilePhotoOrVideo, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.presentMediaPicker(fileMode: true, editingMedia: editingMessage, completion: { signals, silentPosting, scheduleTime in
                        if editingMessage {
                            self?.editMessageMediaWithLegacySignals(signals)
                        } else {
                            self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                        }
                    })
                }
            }),
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FileICloudDrive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.present(legacyICloudFilePicker(theme: strongSelf.presentationData.theme, completion: { urls in
                        if let strongSelf = self, !urls.isEmpty {
                            var signals: [Signal<ICloudFileDescription?, NoError>] = []
                            for url in urls {
                                signals.append(iCloudFileDescription(url))
                            }
                            strongSelf.enqueueMediaMessageDisposable.set((combineLatest(signals)
                            |> deliverOnMainQueue).start(next: { results in
                                if let strongSelf = self {
                                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                                    
                                    var messages: [EnqueueMessage] = []
                                    for item in results {
                                        if let item = item {
                                            let fileId = arc4random64()
                                            let mimeType = guessMimeTypeByFileExtension((item.fileName as NSString).pathExtension)
                                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                                            if mimeType == "application/pdf" {
                                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: ICloudFileResource(urlData: item.urlData, thumbnail: true)))
                                            }
                                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, immediateThumbnailData: nil, mimeType: mimeType, size: item.fileSize, attributes: [.FileName(fileName: item.fileName)])
                                            let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: file), replyToMessageId: replyMessageId, localGroupingKey: nil)
                                            messages.append(message)
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
                                            })
                                            strongSelf.sendMessages(messages)
                                        }
                                    }
                                }
                            }))
                        }
                    }), in: .window(.root))
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
    
    private func presentMediaPicker(fileMode: Bool, editingMedia: Bool, completion: @escaping ([Any], Bool, Int32) -> Void) {
        let postbox = self.context.account.postbox
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> Signal<(GeneratedMediaStoreSettings, SearchBotsConfiguration), NoError> in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings) as? GeneratedMediaStoreSettings
            return postbox.transaction { transaction -> (GeneratedMediaStoreSettings, SearchBotsConfiguration) in
                let configuration = currentSearchBotsConfiguration(transaction: transaction)
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
                    let legacyController = LegacyController(presentation: .navigation, theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
                    legacyController.navigationPresentation = .modal
                    legacyController.statusBar.statusBarStyle = strongSelf.presentationData.theme.rootController.statusBarStyle.style
                    legacyController.controllerLoaded = { [weak legacyController] in
                        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
                        legacyController?.view.disablesInteractiveModalDismiss = true
                    }
                    let controller = generator(legacyController.context)
                    legacyController.bind(controller: controller)
                    legacyController.deferScreenEdgeGestures = [.top]
                    
                    configureLegacyAssetPicker(controller, context: strongSelf.context, peer: peer, initialCaption: inputText.string, hasSchedule: !strongSelf.presentationInterfaceState.isScheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, presentWebSearch: editingMedia ? nil : { [weak self, weak legacyController] in
                        if let strongSelf = self {
                            let controller = WebSearchController(context: strongSelf.context, peer: peer, configuration: searchBotsConfiguration, mode: .media(completion: { results, selectionState, editingState, silentPosting in
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
                    }, presentSchedulePicker: { [weak self] done in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(completion: { [weak self] time in
                                if let strongSelf = self {
                                     done(time)
                                     if !strongSelf.presentationInterfaceState.isScheduledMessages && time != scheduleWhenOnlineTimestamp {
                                         strongSelf.openScheduledMessages()
                                     }
                                 }
                            })
                        }
                    })
                    controller.descriptionGenerator = legacyAssetPickerItemGenerator()
                    controller.completionBlock = { [weak legacyController] signals, silentPosting, scheduleTime in
                        if let legacyController = legacyController {
                            legacyController.dismiss()
                            completion(signals!, silentPosting, scheduleTime)
                        }
                    }
                    controller.dismissalBlock = { [weak legacyController] in
                        if let legacyController = legacyController {
                            legacyController.dismiss()
                        }
                    }
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.effectiveNavigationController?.pushViewController(legacyController)
                }
            })
        })
    }
    
    private func presentWebSearch(editingMessage: Bool) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        let _ = (self.context.account.postbox.transaction { transaction -> SearchBotsConfiguration in
            if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.searchBotsConfiguration) as? SearchBotsConfiguration {
                return entry
            } else {
                return SearchBotsConfiguration.defaultValue
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] configuration in
            if let strongSelf = self {
                let controller = WebSearchController(context: strongSelf.context, peer: peer, configuration: configuration, mode: .media(completion: { [weak self] results, selectionState, editingState, silentPosting in
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
                strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
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
        } else {
            selfPeerId = self.context.account.peerId
        }
        let _ = (self.context.account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(selfPeerId)
            }
            |> deliverOnMainQueue).start(next: { [weak self] selfPeer in
                guard let strongSelf = self, let selfPeer = selfPeer else {
                    return
                }
                let hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != strongSelf.context.account.peerId && !strongSelf.presentationInterfaceState.isScheduledMessages
                let controller = LocationPickerController(context: strongSelf.context, mode: .share(peer: peer, selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { [weak self] location, _ in
                    guard let strongSelf = self else {
                        return
                    }
                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                    let message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: location), replyToMessageId: replyMessageId, localGroupingKey: nil)
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                            })
                        }
                    })
                    strongSelf.sendMessages([message])
                })
                strongSelf.effectiveNavigationController?.pushViewController(controller)
                strongSelf.chatDisplayNode.dismissInput()
            })
    }
    
    private func presentContactPicker() {
        let contactsController = ContactSelectionControllerImpl(ContactSelectionControllerParams(context: self.context, title: { $0.Contacts_Title }, displayDeviceContacts: true))
        contactsController.navigationPresentation = .modal
        self.chatDisplayNode.dismissInput()
        self.effectiveNavigationController?.pushViewController(contactsController)
        self.controllerNavigationDisposable.set((contactsController.result
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self, let peer = peer {
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
                            })
                            let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil)
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
                                    })
                                    let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil)
                                    strongSelf.sendMessages([message])
                                }
                            }), completed: nil, cancelled: nil)
                            strongSelf.effectiveNavigationController?.pushViewController(contactController)
                        }
                    }
                }))
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
        
        let tooltipScreen = TooltipScreen(text: solution.text, textEntities: solution.entities, icon: .info, location: .top, shouldDismissOnTouch: { point in
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
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil)
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
        let psaEntities: [MessageTextEntity] = generateTextEntities(psaText, enabledTypes: .url)
        
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
        
        let tooltipScreen = TooltipScreen(text: psaText, textEntities: psaEntities, icon: .info, location: .top, displayDuration: .custom(10.0), shouldDismissOnTouch: { point in
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
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil)
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
        
        let psaEntities: [MessageTextEntity] = generateTextEntities(psaText, enabledTypes: .url)
        
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
        
        let tooltipScreen = TooltipScreen(text: psaText, textEntities: psaEntities, icon: .info, location: .top, displayDuration: .custom(10.0), shouldDismissOnTouch: { point in
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
                    strongSelf.controllerInteraction?.openPeer(peerId, .default, nil)
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
        
    private func presentPollCreation(isQuiz: Bool? = nil) {
        if case .peer = self.chatLocation, let peer = self.presentationInterfaceState.renderedPeer?.peer {
            self.effectiveNavigationController?.pushViewController(createPollController(context: self.context, peer: peer, isQuiz: isQuiz, completion: { [weak self] message in
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
                })
                strongSelf.sendMessages([message.withUpdatedReplyToMessageId(replyMessageId)])
            }))
        }
    }
    
    func transformEnqueueMessages(_ messages: [EnqueueMessage]) -> [EnqueueMessage] {
        let silentPosting = self.presentationInterfaceState.interfaceState.silentPosting
        return transformEnqueueMessages(messages, silentPosting: silentPosting)
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
        
        let value: String?
        switch dice.emoji {
            case "🎲":
                value = self.presentationData.strings.Conversation_Dice_u1F3B2
            case "🎯":
                value = self.presentationData.strings.Conversation_Dice_u1F3AF
            default:
                let emojiHex = dice.emoji.unicodeScalars.map({ String(format:"%02x", $0.value) }).joined().uppercased()
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
            self.present(UndoOverlayController(presentationData: self.presentationData, content: .dice(dice: dice, account: self.context.account, text: value, action: canSendMessagesToChat(self.presentationInterfaceState) ? self.presentationData.strings.Conversation_SendDice : nil), elevatedLayout: true, action: { [weak self] action in
                if let strongSelf = self, canSendMessagesToChat(strongSelf.presentationInterfaceState), action == .undo {
                    strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: AnyMediaReference.standalone(media: TelegramMediaDice(emoji: dice.emoji)), replyToMessageId: nil, localGroupingKey: nil)])
                }
                return false
            }), in: .window(.root))
        }
    }
    
    private func transformEnqueueMessages(_ messages: [EnqueueMessage], silentPosting: Bool, scheduleTime: Int32? = nil) -> [EnqueueMessage] {
        return messages.map { message in
            if silentPosting || scheduleTime != nil {
                return message.withUpdatedAttributes { attributes in
                    var attributes = attributes
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
                    return attributes
                }
            } else {
                return message
            }
        }
    }
    
    private func sendMessages(_ messages: [EnqueueMessage], commit: Bool = false) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        
        if commit || !self.presentationInterfaceState.isScheduledMessages {
            self.commitPurposefulAction()
            
            let _ = (enqueueMessages(account: self.context.account, peerId: peerId, messages: self.transformEnqueueMessages(messages))
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                if let strongSelf = self, !strongSelf.presentationInterfaceState.isScheduledMessages {
                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }
            })
            
            donateSendMessageIntent(account: self.context.account, sharedContext: self.context.sharedContext, intentContext: .chat, peerIds: [peerId])
        } else {
            self.presentScheduleTimePicker(dismissByTapOutside: false, completion: { [weak self] time in
                if let strongSelf = self {
                    strongSelf.sendMessages(strongSelf.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: time), commit: true)
                }
            })
        }
    }
    
    private func enqueueMediaMessages(signals: [Any]?, silentPosting: Bool, scheduleTime: Int32? = nil) {
        if case .peer = self.chatLocation {
            self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(account: self.context.account, signals: signals!)
            |> deliverOnMainQueue).start(next: { [weak self] messages in
                if let strongSelf = self {
                    let messages = strongSelf.transformEnqueueMessages(messages, silentPosting: silentPosting, scheduleTime: scheduleTime)
                    let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                            })
                        }
                    })
                    strongSelf.sendMessages(messages.map { $0.withUpdatedReplyToMessageId(replyMessageId) })
                }
            }))
        }
    }
    
    private func displayPasteMenu(_ images: [UIImage]) {
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings) as? GeneratedMediaStoreSettings
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).start(next: { [weak self] settings in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                strongSelf.chatDisplayNode.dismissInput()
                let _ = presentLegacyPasteMenu(context: strongSelf.context, peer: peer, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, presentationData: strongSelf.presentationData, images: images, sendMessagesWithSignals: { signals in
                    self?.enqueueMediaMessages(signals: signals, silentPosting: false)
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
                })
                strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageId) })
            }
        }))
    }
    
    private func enqueueStickerImage(_ image: UIImage, isMemoji: Bool) {
        let size = image.size.aspectFitted(CGSize(width: 512.0, height: 512.0))
        self.enqueueMediaMessageDisposable.set((convertToWebP(image: image, targetSize: size, targetBoundingSize: size, quality: 0.9) |> deliverOnMainQueue).start(next: { [weak self] data in
            if let strongSelf = self, !data.isEmpty {
                let resource = LocalFileMediaResource(fileId: arc4random64())
                strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                
                var fileAttributes: [TelegramMediaFileAttribute] = []
                fileAttributes.append(.FileName(fileName: "sticker.webp"))
                fileAttributes.append(.Sticker(displayText: "", packReference: nil, maskData: nil))
                fileAttributes.append(.ImageSize(size: PixelDimensions(size)))
                
                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: nil, resource: resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: "image/webp", size: data.count, attributes: fileAttributes)
                let message = EnqueueMessage.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil)
                
                let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                })
                strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageId) })
            }
        }))
    }
    
    private func enqueueChatContextResult(_ results: ChatContextResultCollection, _ result: ChatContextResult, hideVia: Bool = false) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        if let message = outgoingMessageWithChatContextResult(to: peerId, results: results, result: result, hideVia: hideVia), canSendMessagesToChat(self.presentationInterfaceState) {
            let replyMessageId = self.presentationInterfaceState.interfaceState.replyMessageId
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil).withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: ""))).withUpdatedComposeDisableUrlPreview(nil) }
                    })
                }
            })
            self.sendMessages([message.withUpdatedReplyToMessageId(replyMessageId)])
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
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        
        if self.videoRecorderValue == nil {
            if let currentInputPanelFrame = self.chatDisplayNode.currentInputPanelFrame() {
                if self.recorderFeedback == nil {
                    self.recorderFeedback = HapticFeedback()
                    self.recorderFeedback?.prepareImpact(.light)
                }
                
                self.videoRecorder.set(.single(legacyInstantVideoController(theme: self.presentationData.theme, panelFrame: self.view.convert(currentInputPanelFrame, to: nil), context: self.context, peerId: peerId, slowmodeState: !self.presentationInterfaceState.isScheduledMessages ? self.presentationInterfaceState.slowmodeState : nil, hasSchedule: !self.presentationInterfaceState.isScheduledMessages && peerId.namespace != Namespaces.Peer.SecretChat, send: { [weak self] message in
                    if let strongSelf = self {
                        let replyMessageId = strongSelf.presentationInterfaceState.interfaceState.replyMessageId
                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                            if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                })
                            }
                        })
                        let updatedMessage = message.withUpdatedReplyToMessageId(replyMessageId)
                        strongSelf.sendMessages([updatedMessage])
                    }
                }, displaySlowmodeTooltip: { [weak self] node, rect in
                    self?.interfaceInteraction?.displaySlowmodeTooltip(node, rect)
                }, presentSchedulePicker: { [weak self] done in
                    if let strongSelf = self {
                        strongSelf.presentScheduleTimePicker(completion: { [weak self] time in
                            if let strongSelf = self {
                                done(time)
                                if !strongSelf.presentationInterfaceState.isScheduledMessages && time != scheduleWhenOnlineTimestamp {
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
        if let _ = self.presentationInterfaceState.slowmodeState, !self.presentationInterfaceState.isScheduledMessages {
            updatedAction = .preview
        }
        
        if let audioRecorderValue = self.audioRecorderValue {
            audioRecorderValue.stop()
            
            switch updatedAction {
                case .dismiss:
                    break
                case .preview:
                    let _ = (audioRecorderValue.takenRecordedData() |> deliverOnMainQueue).start(next: { [weak self] data in
                        if let strongSelf = self, let data = data {
                            if data.duration < 0.5 {
                                strongSelf.recorderFeedback?.error()
                                strongSelf.recorderFeedback = nil
                            } else if let waveform = data.waveform {
                                let resource = LocalFileMediaResource(fileId: arc4random64(), size: data.compressedData.count)
                                
                                strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                                
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedRecordedMediaPreview(ChatRecordedMediaPreview(resource: resource, duration: Int32(data.duration), fileSize: Int32(data.compressedData.count), waveform: AudioWaveform(bitstream: waveform, bitsPerSample: 5)))
                                })
                                strongSelf.recorderFeedback = nil
                            }
                        }
                    })
                case .send:
                    let _ = (audioRecorderValue.takenRecordedData()
                    |> deliverOnMainQueue).start(next: { [weak self] data in
                        if let strongSelf = self, let data = data {
                            if data.duration < 0.5 {
                                strongSelf.recorderFeedback?.error()
                                strongSelf.recorderFeedback = nil
                            } else {
                                let randomId = arc4random64()
                                
                                let resource = LocalFileMediaResource(fileId: randomId)
                                strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                                
                                var waveformBuffer: MemoryBuffer?
                                if let waveform = data.waveform {
                                    waveformBuffer = MemoryBuffer(data: waveform)
                                }
                                
                                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                    if let strongSelf = self {
                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                        })
                                    }
                                })
                                
                                strongSelf.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: data.compressedData.count, attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
                                
                                strongSelf.recorderFeedback?.tap()
                                strongSelf.recorderFeedback = nil
                            }
                        }
                    })
            }
            self.audioRecorder.set(.single(nil))
        } else if let videoRecorderValue = self.videoRecorderValue {
            if case .send = updatedAction {
                videoRecorderValue.completeVideo()
                self.videoRecorder.set(.single(nil))
            } else {
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
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
            $0.updatedRecordedMediaPreview(nil)
        })
    }
    
    private func sendMediaRecording() {
        if let recordedMediaPreview = self.presentationInterfaceState.recordedMediaPreview {
            if let _ = self.presentationInterfaceState.slowmodeState, !self.presentationInterfaceState.isScheduledMessages {
                if let rect = self.chatDisplayNode.frameForInputActionButton() {
                    self.interfaceInteraction?.displaySlowmodeTooltip(self.chatDisplayNode, rect)
                }
                return
            }
            
            let waveformBuffer = MemoryBuffer(data: recordedMediaPreview.waveform.makeBitstream())
            
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedRecordedMediaPreview(nil).updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            })
            
            self.sendMessages([.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: nil, resource: recordedMediaPreview.resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int(recordedMediaPreview.fileSize), attributes: [.Audio(isVoice: true, duration: Int(recordedMediaPreview.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: self.presentationInterfaceState.interfaceState.replyMessageId, localGroupingKey: nil)])
        }
    }
    
    private func updateSearch(_ interfaceState: ChatPresentationInterfaceState) -> ChatPresentationInterfaceState? {
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
            switch search.domain {
                case .everything:
                    switch self.chatLocation {
                        case let .peer(peerId):
                            derivedSearchState = ChatSearchState(query: search.query, location: .peer(peerId: peerId, fromId: nil, tags: nil), loadMoreState: loadMoreStateFromResultsState(search.resultsState))
                    }
                case .members:
                    derivedSearchState = nil
                case let .member(peer):
                    switch self.chatLocation {
                        case let .peer(peerId):
                            derivedSearchState = ChatSearchState(query: search.query, location: .peer(peerId: peerId, fromId: peer.id, tags: nil), loadMoreState: loadMoreStateFromResultsState(search.resultsState))
                        /*case .group:
                            derivedSearchState = nil*/
                    }
            }
        }
        
        if derivedSearchState != self.searchState {
            let previousSearchState = self.searchState
            self.searchState = derivedSearchState
            if let searchState = derivedSearchState {
                if previousSearchState?.query != searchState.query || previousSearchState?.location != searchState.location {
                    var queryIsEmpty = false
                    if searchState.query.isEmpty {
                        if case let .peer(_, fromId, _) = searchState.location {
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

                        let search = searchMessages(account: self.context.account, location: searchState.location, query: searchState.query, state: nil, limit: limit)
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
                            let complete = results.completed
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
                                    case .peer:
                                        strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex), forceInCurrentChat: true)
                                    /*case .group:
                                        strongSelf.navigateToMessage(from: nil, to: .index(navigateIndex))*/
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
                        searchDisposable.set((searchMessages(account: self.context.account, location: searchState.location, query: searchState.query, state: loadMoreState, limit: limit)
                        |> delay(0.2, queue: Queue.mainQueue())
                        |> deliverOnMainQueue).start(next: { [weak self] results, updatedState in
                            guard let strongSelf = self else {
                                return
                            }
                            let complete = results.completed
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
        self.chatDisplayNode.historyNode.scrollToEndOfHistory()
    }
    
    func updateTextInputState(_ textInputState: ChatTextInputState) {
        self.updateChatPresentationInterfaceState(interactive: false, { state in
            state.updatedInterfaceState({ state in
                state.withUpdatedComposeInputState(textInputState)
            })
        })
    }
    
    public func navigateToMessage(messageLocation: NavigateToMessageLocation, animated: Bool, forceInCurrentChat: Bool = false, completion: (() -> Void)? = nil, customPresentProgress: ((ViewController, Any?) -> Void)? = nil) {
        let scrollPosition: ListViewScrollPosition
        if case .upperBound = messageLocation {
            scrollPosition = .top(0.0)
        } else {
            scrollPosition = .center(.bottom)
        }
        self.navigateToMessage(from: nil, to: messageLocation, scrollPosition: scrollPosition, rememberInStack: false, forceInCurrentChat: forceInCurrentChat, animated: animated, completion: completion, customPresentProgress: customPresentProgress)
    }
    
    private func navigateToMessage(from fromId: MessageId?, to messageLocation: NavigateToMessageLocation, scrollPosition: ListViewScrollPosition = .center(.bottom), rememberInStack: Bool = true, forceInCurrentChat: Bool = false, animated: Bool = true, completion: (() -> Void)? = nil, customPresentProgress: ((ViewController, Any?) -> Void)? = nil) {
        if self.isNodeLoaded {
            var fromIndex: MessageIndex?
            
            if let fromId = fromId, let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
                fromIndex = message.index
            } else {
                if let message = self.chatDisplayNode.historyNode.anchorMessageInCurrentHistoryView() {
                    fromIndex = message.index
                }
            }
            
            if case let .peer(peerId) = self.chatLocation, let messageId = messageLocation.messageId, (messageId.peerId != peerId && !forceInCurrentChat) || (self.presentationInterfaceState.isScheduledMessages && messageId.id != 0 && !Namespaces.Message.allScheduled.contains(messageId.namespace)) {
                if let navigationController = self.effectiveNavigationController {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(messageId.peerId), subject: .message(messageId), keepStack: .always))
                }
            } else if case let .peer(peerId) = self.chatLocation, (messageLocation.peerId == peerId || forceInCurrentChat) {
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
                        self.loadingMessage.set(false)
                        self.messageIndexDisposable.set(nil)
                        self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: message.index, animated: animated, scrollPosition: scrollPosition)
                        completion?()
                    } else if case let .index(index) = messageLocation, index.id.id == 0 && index.timestamp > 0, self.presentationInterfaceState.isScheduledMessages {
                        self.chatDisplayNode.historyNode.scrollToMessage(from: scrollFromIndex, to: index, animated: animated, scrollPosition: scrollPosition)
                    } else {
                        self.loadingMessage.set(true)
                        let searchLocation: ChatHistoryInitialSearchLocation
                        switch messageLocation {
                            case let .id(id):
                                searchLocation = .id(id)
                            case let .index(index):
                                searchLocation = .index(index)
                            case .upperBound:
                                searchLocation = .index(MessageIndex.upperBound(peerId: peerId))
                        }
                        let historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(location: searchLocation, count: 50), id: 0), account: self.context.account, chatLocation: self.chatLocation, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
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
                                strongSelf.loadingMessage.set(false)
                            }
                        }))
                        cancelImpl = { [weak self] in
                            if let strongSelf = self {
                                strongSelf.loadingMessage.set(false)
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
                        case let .id(id):
                            searchLocation = .id(id)
                        case let .index(index):
                            searchLocation = .index(index)
                        case .upperBound:
                            return
                    }
                    if let _ = fromId, rememberInStack {
                        self.historyNavigationStack.add(fromIndex)
                    }
                    self.loadingMessage.set(true)
                    let historyView = preloadedChatHistoryViewForLocation(ChatHistoryLocationInput(content: .InitialSearch(location: searchLocation, count: 50), id: 0), account: self.context.account, chatLocation: self.chatLocation, fixedCombinedReadStates: nil, tagMask: nil, additionalData: [])
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
                                strongSelf.effectiveNavigationController?.pushViewController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(messageLocation.peerId), subject: messageLocation.messageId.flatMap { .message($0) }))
                                completion?()
                            }
                        }
                    }, completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(false)
                        }
                    }))
                }
            }
        } else {
            completion?()
        }
    }
    
    private func forwardMessages(messageIds: [MessageId], resetCurrent: Bool = false) {
        let _ = (self.context.account.postbox.transaction { transaction -> [Message] in
            return messageIds.compactMap(transaction.getMessage)
        }
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            self?.forwardMessages(messages: messages, resetCurrent: resetCurrent)
        })
    }
    
    private func forwardMessages(messages: [Message], resetCurrent: Bool) {
        var filter: ChatListNodePeersFilter = [.onlyWriteable, .includeSavedMessages, .excludeDisabled]
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
        let controller = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context, filter: filter, attemptSelection: { peer in
            attemptSelectionImpl?(peer)
        }))
        let context = self.context
        attemptSelectionImpl = { [weak controller] peer in
            guard let controller = controller else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if hasPublicPolls {
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    controller.present(textAlertController(context: context, title: nil, text: hasPublicQuiz ? presentationData.strings.Forward_ErrorPublicQuizDisabledInChannels : presentationData.strings.Forward_ErrorPublicPollDisabledInChannels, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
            }
            controller.present(textAlertController(context: context, title: nil, text: presentationData.strings.Forward_ErrorDisabledForChat, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }
        controller.peerSelected = { [weak self, weak controller] peerId in
            guard let strongSelf = self, let strongController = controller else {
                return
            }
            
            if resetCurrent {
                 strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(nil) }) })
            }
            
            if case .peer(peerId) = strongSelf.chatLocation, strongSelf.parentController == nil {
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(messages.map { $0.id }).withoutSelectionState() }) })
                strongController.dismiss()
            } else if peerId == strongSelf.context.account.peerId {
                let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messages.map { message -> EnqueueMessage in
                    return .forward(source: message.id, grouping: .auto, attributes: [])
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
                        |> deliverOnMainQueue).start(completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .success), in: .window(.root))
                        }))
                    }
                })
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                strongController.dismiss()
            } else {
                let _ = (strongSelf.context.account.postbox.transaction({ transaction -> Void in
                    transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                        if let currentState = currentState as? ChatInterfaceState {
                            return currentState.withUpdatedForwardMessageIds(messages.map { $0.id })
                        } else {
                            return ChatInterfaceState().withUpdatedForwardMessageIds(messages.map { $0.id })
                        }
                    })
                }) |> deliverOnMainQueue).start(completed: {
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                        
                        let ready = ValuePromise<Bool>()
                        
                        strongSelf.controllerNavigationDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                            if let strongController = controller {
                                strongController.dismiss()
                            }
                        }))
                        
                        if let parentController = strongSelf.parentController {
                            (parentController.navigationController as? NavigationController)?.replaceTopController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(peerId)), animated: false, ready: ready)
                        } else {
                            strongSelf.effectiveNavigationController?.replaceTopController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(peerId)), animated: false, ready: ready)
                        }
                    }
                })
            }
        }
        self.chatDisplayNode.dismissInput()
        self.effectiveNavigationController?.pushViewController(controller)
    }
    
    private func openPeer(peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer, fromMessage: Message?, expandAvatar: Bool = false) {
        if case let .peer(currentPeerId) = self.chatLocation, peerId == currentPeerId {
            switch navigation {
                case .info:
                    self.navigationButtonAction(.openChatInfo(expandAvatar: expandAvatar))
                case let .chat(textInputState, _):
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
                default:
                    break
            }
        } else {
            if let peerId = peerId {
                switch self.chatLocation {
                    case let .peer(selfPeerId):
                        switch navigation {
                            case .info:
                                let peerSignal: Signal<Peer?, NoError>
                                if let fromMessage = fromMessage {
                                    peerSignal = loadedPeerFromMessage(account: self.context.account, peerId: peerId, messageId: fromMessage.id)
                                } else {
                                    peerSignal = self.context.account.postbox.loadedPeerWithId(peerId) |> map(Optional.init)
                                }
                                self.navigationActionDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    if let strongSelf = self, let peer = peer {
                                        var mode: PeerInfoControllerMode = .generic
                                        if let _ = fromMessage {
                                            mode = .group(selfPeerId)
                                        }
                                        var expandAvatar = expandAvatar
                                        if peer.smallProfileImage == nil {
                                            expandAvatar = false
                                        }
                                        if let validLayout = strongSelf.validLayout, validLayout.deviceMetrics.type == .tablet {
                                            expandAvatar = false
                                        }
                                        if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, peer: peer, mode: mode, avatarInitiallyExpanded: expandAvatar, fromChat: false) {
                                            strongSelf.effectiveNavigationController?.pushViewController(infoController)
                                        }
                                    }
                                }))
                            case let .chat(textInputState, subject):
                                if let textInputState = textInputState {
                                    let _ = (self.context.account.postbox.transaction({ transaction -> Void in
                                        transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                                            if let currentState = currentState as? ChatInterfaceState {
                                                return currentState.withUpdatedComposeInputState(textInputState)
                                            } else {
                                                return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                                            }
                                        })
                                    })
                                    |> deliverOnMainQueue).start(completed: { [weak self] in
                                        if let strongSelf = self, let navigationController = strongSelf.effectiveNavigationController {
                                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), subject: subject, updateTextInputState: textInputState))
                                        }
                                    })
                                } else {
                                    self.effectiveNavigationController?.pushViewController(ChatControllerImpl(context: self.context, chatLocation: .peer(peerId), subject: subject))
                                }
                            case let .withBotStartPayload(botStart):
                                self.effectiveNavigationController?.pushViewController(ChatControllerImpl(context: self.context, chatLocation: .peer(peerId), botStart: botStart))
                            default:
                                break
                        }
                    /*case .group:
                        (self.navigationController as? NavigationController)?.pushViewController(ChatControllerImpl(context: self.context, chatLocation: .peer(peerId), messageId: fromMessage?.id, botStart: nil))*/
                }
            } else {
                switch navigation {
                    case .info:
                        break
                    case let .chat(textInputState, _):
                        if let textInputState = textInputState {
                            let controller = self.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: self.context))
                            controller.peerSelected = { [weak self, weak controller] peerId in
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
                                        let _ = (strongSelf.context.account.postbox.transaction({ transaction -> Void in
                                            transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                                                if let currentState = currentState as? ChatInterfaceState {
                                                    return currentState.withUpdatedComposeInputState(textInputState)
                                                } else {
                                                    return ChatInterfaceState().withUpdatedComposeInputState(textInputState)
                                                }
                                            })
                                        }) |> deliverOnMainQueue).start(completed: {
                                            if let strongSelf = self {
                                                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
                                                
                                                let ready = ValuePromise<Bool>()
                                                
                                                strongSelf.controllerNavigationDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                                    if let strongController = controller {
                                                        strongController.dismiss()
                                                    }
                                                }))
                                                
                                                strongSelf.effectiveNavigationController?.replaceTopController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(peerId)), animated: false, ready: ready)
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
    }
    
    private func openPeerMention(_ name: String, navigation: ChatControllerInteractionNavigateToPeer = .default) {
        let disposable: MetaDisposable
        if let resolvePeerByNameDisposable = self.resolvePeerByNameDisposable {
            disposable = resolvePeerByNameDisposable
        } else {
            disposable = MetaDisposable()
            self.resolvePeerByNameDisposable = disposable
        }
        var resolveSignal = resolvePeerByName(account: self.context.account, name: name, ageLimit: 10)
        
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
        let account = self.context.account
        disposable.set((resolveSignal
        |> take(1)
        |> mapToSignal { peerId -> Signal<Peer?, NoError> in
            return account.postbox.transaction { transaction -> Peer? in
                if let peerId = peerId {
                    return transaction.getPeer(peerId)
                } else {
                    return nil
                }
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let strongSelf = self {
                if let peer = peer {
                    var navigation = navigation
                    if case .default = navigation {
                        if let peer = peer as? TelegramUser, peer.botInfo != nil {
                            navigation = .chat(textInputState: nil, subject: nil)
                        }
                    }
                    strongSelf.openResolved(.peer(peer.id, navigation))
                } else {
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }))
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
        self.editMessageDisposable.set((requestUpdatePeerIsBlocked(account: self.context.account, peerId: peerId, isBlocked: false)
        |> afterDisposed({ [weak self] in
            Queue.mainQueue().async {
                unblockingPeer.set(false)
                if let strongSelf = self, restartBot {
                    let _ = enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
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
                items.append(ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(peer.compactDisplayTitle).0))
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
                ActionSheetButtonItem(title: presentationData.strings.UserInfo_BlockActionTitle(peer.compactDisplayTitle).0, color: .destructive, action: { [weak self] in
                    dismissAction()
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.id, isBlocked: true).start()
                    if let _ = chatPeer as? TelegramSecretChat {
                        let _ = (strongSelf.context.account.postbox.transaction { transaction in
                            terminateSecretChat(transaction: transaction, peerId: chatPeer.id)
                        }).start()
                    }
                    if deleteChat {
                        let _ = removePeerChat(account: strongSelf.context.account, peerId: chatPeer.id, reportChatSpam: reportSpam).start()
                        strongSelf.effectiveNavigationController?.filterController(strongSelf, animated: true)
                    } else if reportSpam {
                        let _ = TelegramCore.reportPeer(account: strongSelf.context.account, peerId: peer.id, reason: .spam).start()
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
            items.append(ActionSheetTextItem(title: strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumberConfirmation(formatPhoneNumber(phoneNumber), peer.compactDisplayTitle).0))
            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumber, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                guard let strongSelf = self else {
                    return
                }
                let _ = (acceptAndShareContact(account: strongSelf.context.account, peerId: peer.id)
                |> deliverOnMainQueue).start(error: { _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }, completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .genericSuccess(strongSelf.presentationData.strings.Conversation_ShareMyPhoneNumber_StatusSuccess(peer.compactDisplayTitle).0, true)), in: .window(.root))
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
                    
                    self?.present(OverlayStatusController(theme: strongSelf.presentationData.theme, type: .genericSuccess(strongSelf.presentationData.strings.AddContact_StatusSuccess(peer.compactDisplayTitle).0, true)), in: .window(.root))
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
        self.editMessageDisposable.set((TelegramCore.dismissPeerStatusOptions(account: self.context.account, peerId: dismissPeerId)
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
        let _ = removePeerChat(account: self.context.account, peerId: peerId, reportChatSpam: reportChatSpam).start()
        self.effectiveNavigationController?.popToRoot(animated: true)
        
        let _ = requestUpdatePeerIsBlocked(account: self.context.account, peerId: peerId, isBlocked: true).start()
    }
    
    private func startBot(_ payload: String?) {
        guard case let .peer(peerId) = self.chatLocation else {
            return
        }
        
        let startingBot = self.startingBot
        startingBot.set(true)
        self.editMessageDisposable.set((requestStartBot(account: self.context.account, botPeerId: peerId, payload: payload) |> deliverOnMainQueue |> afterDisposed({
            startingBot.set(false)
        })).start(completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedBotStartPayload(nil) })
            }
        }))
    }
    
    private func openResolved(_ result: ResolvedUrl, message: Message? = nil) {
        self.context.sharedContext.openResolvedUrl(result, context: self.context, urlContext: .chat, navigationController: self.effectiveNavigationController, openPeer: { [weak self] peerId, navigation in
            guard let strongSelf = self else {
                return
            }
            switch navigation {
                case let .chat(_, subject):
                    if case .peer(peerId) = strongSelf.chatLocation {
                        if let subject = subject, case let .message(messageId) = subject {
                            strongSelf.navigateToMessage(from: nil, to: .id(messageId))
                        }
                    } else if let navigationController = strongSelf.effectiveNavigationController {
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), subject: subject, keepStack: .always))
                    }
                case .info:
                    strongSelf.navigationActionDisposable.set((strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                            if let strongSelf = self, peer.restrictionText(platform: "ios", contentSettings: strongSelf.context.currentContentSettings.with { $0 }) == nil {
                                if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
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
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), botStart: startPayload))
                    }
                default:
                    break
                }
            }, sendFile: nil,
            sendSticker: { [weak self] f, sourceNode, sourceRect in
            return self?.interfaceInteraction?.sendSticker(f, sourceNode, sourceRect) ?? false
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak self] in
            self?.chatDisplayNode.dismissInput()
        }, contentContext: message)
    }
    
    private func openUrl(_ url: String, concealed: Bool, message: Message? = nil) {
        self.commitPurposefulAction()
        
        var concealed = concealed
        
        let openImpl: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
        
            let disposable: MetaDisposable
            if let current = strongSelf.resolveUrlDisposable {
                disposable = current
            } else {
                disposable = MetaDisposable()
                strongSelf.resolveUrlDisposable = disposable
            }
            var cancelImpl: (() -> Void)?
            let presentationData = strongSelf.presentationData
            let progressSignal = Signal<Never, NoError> { subscriber in
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
            
            cancelImpl = { [weak self] in
                self?.resolveUrlDisposable?.set(nil)
            }
            disposable.set((strongSelf.context.sharedContext.resolveUrl(account: strongSelf.context.account, url: url)
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    strongSelf.openResolved(result, message: message)
                }
            }))
        }
        
        var parsedUrlValue: URL?
        if let parsed = URL(string: url) {
            parsedUrlValue = parsed
        } else if let parsed = URL(string: "https://" + url) {
            parsedUrlValue = parsed
        } else if let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsed = URL(string: encoded) {
            parsedUrlValue = parsed
        }
        print("parsedUrlValue = \(parsedUrlValue)")
        let host = parsedUrlValue?.host ?? url
        
        let rawHost = (host as NSString).removingPercentEncoding ?? host
        var latin = CharacterSet()
        latin.insert(charactersIn: "A"..."Z")
        latin.insert(charactersIn: "a"..."z")
        latin.insert(charactersIn: "0"..."9")
        var punctuation = CharacterSet()
        punctuation.insert(charactersIn: ".-/+")
        var hasLatin = false
        var hasNonLatin = false
        for c in rawHost {
            if c.unicodeScalars.allSatisfy(punctuation.contains) {
            } else if c.unicodeScalars.allSatisfy(latin.contains) {
                hasLatin = true
            } else {
                hasNonLatin = true
            }
        }
        if hasLatin && hasNonLatin {
            concealed = true
        }
        
        if let parsedUrlValue = parsedUrlValue, isConcealedUrlWhitelisted(parsedUrlValue) {
            concealed = false
        }
        
        if concealed {
            var rawDisplayUrl: String
            if hasNonLatin {
                rawDisplayUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
            } else {
                rawDisplayUrl = url
            }
            let maxLength = 180
            if rawDisplayUrl.count > maxLength {
                rawDisplayUrl = String(rawDisplayUrl[..<rawDisplayUrl.index(rawDisplayUrl.startIndex, offsetBy: maxLength - 2)]) + "..."
            }
            var displayUrl = rawDisplayUrl
            displayUrl = displayUrl.replacingOccurrences(of: "\u{202e}", with: "")
            self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Generic_OpenHiddenLinkAlert(displayUrl).0, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_Yes, action: {
                openImpl()
            })]), in: .window(.root))
        } else {
            openImpl()
        }
    }
    
    private func openUrlIn(_ url: String) {
        let actionSheet = OpenInActionSheetController(context: self.context, item: .url(url: url), openUrl: { [weak self] url in
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
            galleryController.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height), metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
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
                        if let previewData = chatMessagePreviewControllerData(context: self.context, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: self.effectiveNavigationController) {
                            switch previewData {
                                case let .gallery(gallery):
                                    gallery.setHintWillBePresentedInPreviewingContext(true)
                                    let rect = selectedTransitionNode.0.view.convert(selectedTransitionNode.0.bounds, to: sourceView)
                                    let sourceRect = rect.insetBy(dx: -2.0, dy: -2.0)
                                    gallery.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height), metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
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
                    } else if let encoded = (string as NSString).addingPercentEscapes(using: String.Encoding.utf8.rawValue), let parsed = URL(string: encoded) {
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
                                    controller.preferredBarTintColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
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
    
    func previewingCommit(_ viewControllerToCommit: UIViewController) {
        if let gallery = viewControllerToCommit as? AvatarGalleryController {
            self.chatDisplayNode.dismissInput()
            gallery.setHintWillBePresentedInPreviewingContext(false)
            self.present(gallery, in: .window(.root), with: AvatarGalleryControllerPresentationArguments(animated: false, transitionArguments: { _ in
                return nil
            }))
        } else if let gallery = viewControllerToCommit as? GalleryController {
            self.chatDisplayNode.dismissInput()
            gallery.setHintWillBePresentedInPreviewingContext(false)
            
            self.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(animated: false, transitionArguments: { [weak self] messageId, media in
                if let strongSelf = self {
                    var selectedTransitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                    strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView {
                            if let result = itemNode.transitionNode(id: messageId, media: media) {
                                selectedTransitionNode = result
                            }
                        }
                    }
                    if let selectedTransitionNode = selectedTransitionNode {
                        return GalleryTransitionArguments(transitionNode: selectedTransitionNode, addToTransitionSurface: { view in
                            if let strongSelf = self {
                                strongSelf.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.chatDisplayNode.historyNode.view)
                            }
                        })
                    }
                }
                return nil
            }))
        }
        
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            if let safariController = viewControllerToCommit as? SFSafariViewController {
                if let window = self.effectiveNavigationController?.view.window {
                    window.rootViewController?.present(safariController, animated: true)
                }
            }
        }
    }
    
    @available(iOSApplicationExtension 9.0, iOS 9.0, *)
    override public var previewActionItems: [UIPreviewActionItem] {
        struct PreviewActionsData {
            let notificationSettings: PeerNotificationSettings?
            let peer: Peer?
        }
        let chatLocation = self.chatLocation
        let data = Atomic<PreviewActionsData?>(value: nil)
        let semaphore = DispatchSemaphore(value: 0)
        let _ = self.context.account.postbox.transaction({ transaction -> Void in
            switch chatLocation {
                case let .peer(peerId):
                    let _ = data.swap(PreviewActionsData(notificationSettings: transaction.getPeerNotificationSettings(peerId), peer: transaction.getPeer(peerId)))
                /*case .group:
                    let _ = data.swap(PreviewActionsData(notificationSettings: nil, peer: nil))*/
            }
            semaphore.signal()
        }).start()
        semaphore.wait()
        
        return data.with { [weak self] data -> [UIPreviewActionItem] in
            var items: [UIPreviewActionItem] = []
            if let data = data, let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                
                switch strongSelf.peekActions {
                    case .standard:
                        if let peer = data.peer, peer.id != strongSelf.context.account.peerId {
                            if let _ = data.peer as? TelegramUser {
                                items.append(UIPreviewAction(title: "👍", style: .default, handler: { _, _ in
                                    if let strongSelf = self {
                                        let _ = enqueueMessages(account: strongSelf.context.account, peerId: peer.id, messages: strongSelf.transformEnqueueMessages([.message(text: "👍", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])).start()
                                    }
                                }))
                            }
                        
                            if let notificationSettings = data.notificationSettings as? TelegramPeerNotificationSettings {
                                if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                    items.append(UIPreviewAction(title: presentationData.strings.Conversation_Unmute, style: .default, handler: { _, _ in
                                        if let strongSelf = self {
                                            let _ = togglePeerMuted(account: strongSelf.context.account, peerId: peer.id).start()
                                        }
                                    }))
                                } else {
                                    let muteInterval: Int32
                                    if let _ = data.peer as? TelegramChannel {
                                        muteInterval = Int32.max
                                    } else {
                                        muteInterval = 1 * 60 * 60
                                    }
                                    let title: String
                                    if muteInterval == Int32.max {
                                        title = presentationData.strings.Conversation_Mute
                                    } else {
                                        title = muteForIntervalString(strings: presentationData.strings, value: muteInterval)
                                    }
                                    
                                    items.append(UIPreviewAction(title: title, style: .default, handler: { _, _ in
                                        if let strongSelf = self {
                                            let _ = updatePeerMuteSetting(account: strongSelf.context.account, peerId: peer.id, muteInterval: muteInterval).start()
                                        }
                                    }))
                                }
                            }
                        }
                    case let .remove(action):
                        items.append(UIPreviewAction(title: presentationData.strings.Common_Delete, style: .destructive, handler: { _, _ in
                            action()
                        }))
                }
            }
            return items
        }
    }
    
    private func debugStreamSingleVideo(_ id: MessageId) {
        let gallery = GalleryController(context: self.context, source: .peerMessagesAtId(id), streamSingleVideo: true, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.effectiveNavigationController?.replaceTopController(controller, animated: false, ready: ready)
            }
        }, baseNavigationController: self.effectiveNavigationController)
        
        self.chatDisplayNode.dismissInput()
        self.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { [weak self] messageId, media in
            if let strongSelf = self {
                var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                strongSelf.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView {
                        if let result = itemNode.transitionNode(id: messageId, media: media) {
                            transitionNode = result
                        }
                    }
                }
                if let transitionNode = transitionNode {
                    return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: { view in
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: strongSelf.chatDisplayNode.historyNode.view)
                        }
                    })
                }
            }
            return nil
        }))
    }
    
    private func presentBanMessageOptions(accountPeerId: PeerId, author: Peer, messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions) {
        if case let .peer(peerId) = self.chatLocation {
            self.navigationActionDisposable.set((fetchChannelParticipant(account: self.context.account, peerId: peerId, participantId: author.id)
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
                            title = strongSelf.presentationData.strings.Conversation_Moderate_DeleteAllMessages(author.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0
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
                                let mediaBox = strongSelf.context.account.postbox.mediaBox
                                let _ = strongSelf.context.account.postbox.transaction({ transaction -> Void in
                                    deleteAllMessagesWithAuthor(transaction: transaction, mediaBox: mediaBox, peerId: peerId, authorId: author.id, namespace: Namespaces.Message.Cloud)
                                }).start()
                                let _ = clearAuthorHistory(account: strongSelf.context.account, peerId: peerId, memberId: author.id).start()
                            } else if actions.contains(0) {
                                let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
                            }
                            if actions.contains(1) {
                                let _ = removePeerMember(account: strongSelf.context.account, peerId: peerId, memberId: author.id).start()
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
    
    private func presentDeleteMessageOptions(messageIds: Set<MessageId>, options: ChatAvailableMessageActionOptions, contextController: ContextController?, completion: @escaping (ContextMenuActionResult) -> Void) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        var personalPeerName: String?
        var isChannel = false
        if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser {
            personalPeerName = user.compactDisplayTitle
        } else if let peer = self.presentationInterfaceState.renderedPeer?.peer as? TelegramSecretChat, let associatedPeerId = peer.associatedPeerId, let user = self.presentationInterfaceState.renderedPeer?.peers[associatedPeerId] as? TelegramUser {
            personalPeerName = user.compactDisplayTitle
        } else if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
            isChannel = true
        }
        
        if options.contains(.cancelSending) {
            items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ContextMenuCancelSending, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
                }
            }))
        }
        
        var contextItems: [ContextMenuItem] = []
        var canDisplayContextMenu = true
        
        var unsendPersonalMessages = false
        if options.contains(.unsendPersonal) {
            canDisplayContextMenu = false
            items.append(ActionSheetTextItem(title: self.presentationData.strings.Chat_UnsendMyMessagesAlertTitle(personalPeerName ?? "").0))
            items.append(ActionSheetSwitchItem(title: self.presentationData.strings.Chat_UnsendMyMessages, isOn: false, action: { value in
                unsendPersonalMessages = value
            }))
        } else if options.contains(.deleteGlobally) {
            let globalTitle: String
            if isChannel {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
            } else if let personalPeerName = personalPeerName {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
            } else {
                globalTitle = self.presentationData.strings.Conversation_DeleteMessagesForEveryone
            }
            contextItems.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { [weak self] _, f in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
                    f(.dismissWithoutContent)
                }
            })))
            items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: .forEveryone).start()
                }
            }))
        }
        if options.contains(.deleteLocally) {
            var localOptionText = self.presentationData.strings.Conversation_DeleteMessagesForMe
            if self.presentationInterfaceState.isScheduledMessages {
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
                    let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: unsendPersonalMessages ? .forEveryone : .forLocalPeer).start()
                    f(.dismissWithoutContent)
                }
            })))
            items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState { $0.withoutSelectionState() } })
                    let _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: Array(messageIds), type: unsendPersonalMessages ? .forEveryone : .forLocalPeer).start()
                }
            }))
        }
        
        if canDisplayContextMenu, let contextController = contextController {
            contextController.setItems(.single(contextItems))
        } else {
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            self.chatDisplayNode.dismissInput()
            self.present(actionSheet, in: .window(.root))
            completion(.default)
        }
    }
    
    private func presentClearCacheSuggestion() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { $0.updatedInterfaceState({ $0.withoutSelectionState() }) })
        
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        
        items.append(DeleteChatPeerActionSheetItem(context: self.context, peer: peer, chatPeer: peer, action: .clearCacheSuggestion, strings: self.presentationData.strings, nameDisplayOrder: self.presentationData.nameDisplayOrder))
        
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
    
    private func displayMediaRecordingTooltip() {
        let rect: CGRect? = self.chatDisplayNode.frameForInputActionButton()
        
        let updatedMode: ChatTextInputMediaRecordingButtonMode = self.presentationInterfaceState.interfaceState.mediaRecordingMode
        
        let text: String
        if updatedMode == .audio {
            text = self.presentationData.strings.Conversation_HoldForAudio
        } else {
            text = self.presentationData.strings.Conversation_HoldForVideo
        }
        
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
    
    private func dismissAllTooltips() {
        self.sendingOptionsTooltipController?.dismiss()
        self.searchResultsTooltipController?.dismiss()
        self.messageTooltipController?.dismiss()
        self.videoUnmuteTooltipController?.dismiss()
        self.silentPostTooltipController?.dismiss()
        self.mediaRecordingModeTooltipController?.dismiss()
        self.mediaRestrictedTooltipController?.dismiss()
    }
    
    private func commitPurposefulAction() {
        if let purposefulAction = self.purposefulAction {
            self.purposefulAction = nil
            purposefulAction()
        }
    }
    
    public override var keyShortcuts: [KeyShortcut] {
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
        } else {
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
            KeyShortcut(title: strings.KeyCommand_ScrollUp, input: UIKeyCommand.inputUpArrow, modifiers: [.shift], action: { [weak self] in
                if let strongSelf = self {
                    _ = strongSelf.chatDisplayNode.historyNode.scrollWithDirection(.down, distance: 75.0)
                }
            }),
            KeyShortcut(title: strings.KeyCommand_ScrollDown, input: UIKeyCommand.inputDownArrow, modifiers: [.shift], action: { [weak self] in
                if let strongSelf = self {
                    _ = strongSelf.chatDisplayNode.historyNode.scrollWithDirection(.up, distance: 75.0)
                }
            }),
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
                        }.updatedInputMode({ _ in ChatInputMode.media(mode: .other, expanded: nil) })
                    })
                }
            })
        ]
        
        return inputShortcuts + otherShortcuts
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
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
            return state.updatedInputMode({ _ in .text })
        })
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
                        reminderActivity.title = self.presentationData.strings.Activity_RemindAboutGroup(peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).0
                    } else if let channel = peer as? TelegramChannel {
                        if case .broadcast = channel.info {
                            reminderActivity.title = self.presentationData.strings.Activity_RemindAboutChannel(peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).0
                        } else {
                            reminderActivity.title = self.presentationData.strings.Activity_RemindAboutGroup(peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).0
                        }
                    } else {
                        reminderActivity.title = self.presentationData.strings.Activity_RemindAboutUser(peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).0
                    }
                    reminderActivity.userInfo = ["peerId": peerId.toInt64(), "peerTitle": peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)]
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
    
    private func presentScheduleTimePicker(selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
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
            let controller = ChatScheduleTimeController(context: strongSelf.context, peerId: peerId, mode: mode, currentTime: selectedTime, minimalTime: strongSelf.presentationInterfaceState.slowmodeState?.timeout, dismissByTapOutside: dismissByTapOutside, completion: { time in
                completion(time)
            })
            strongSelf.chatDisplayNode.dismissInput()
            strongSelf.present(controller, in: .window(.root))
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
    
    func activateSearch() {
        self.focusOnSearchAfterAppearance = true
        self.interfaceInteraction?.beginMessageSearch(.everything, "")
    }
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
    }
}
