import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import UniversalMediaPlayer
import TelegramBaseController
import OverlayStatusController
import ListMessageItem
import UndoUI
import ChatPresentationInterfaceState

final class PeerInfoListPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let chatControllerInteraction: ChatControllerInteraction
    
    weak var parentController: ViewController?
    
    private let listNode: ChatHistoryListNode
    
    private var currentParams: (size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    private let selectedMessagesPromise = Promise<Set<MessageId>?>(nil)
    private var selectedMessages: Set<MessageId>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    
    private var hiddenMediaDisposable: Disposable?
    private var mediaStatusDisposable: Disposable?
    private var playlistPreloadDisposable: Disposable?
    
    private var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account)?
    private var mediaAccessoryPanelContainer: PassthroughContainerNode
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    private var dismissingPanel: ASDisplayNode?

    private let statusPromise = Promise<PeerInfoStatusData?>(nil)
    var status: Signal<PeerInfoStatusData?, NoError> {
        self.statusPromise.get()
    }

    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    var tabBarOffset: CGFloat {
        return 0.0
    }
    
    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, chatControllerInteraction: ChatControllerInteraction, peerId: PeerId, tagMask: MessageTags) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        
        self.selectedMessages = chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
        self.selectedMessagesPromise.set(.single(self.selectedMessages))
        
        let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        self.listNode = ChatHistoryListNode(context: context, updatedPresentationData: updatedPresentationData ?? (context.sharedContext.currentPresentationData.with({ $0 }), context.sharedContext.presentationData), chatLocation: .peer(id: peerId), chatLocationContextHolder: chatLocationContextHolder, tagMask: tagMask, subject: nil, controllerInteraction: chatControllerInteraction, selectedMessages: self.selectedMessagesPromise.get(), mode: .list(search: false, reversed: false, displayHeaders: .allButLast, hintLinks: tagMask == .webPage, isGlobalSearch: false))
        self.listNode.clipsToBounds = true
        self.listNode.defaultToSynchronousTransactionWhileScrolling = true
        self.listNode.scroller.bounces = false
                
        self.mediaAccessoryPanelContainer = PassthroughContainerNode()
        self.mediaAccessoryPanelContainer.clipsToBounds = true
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        self.addSubnode(self.mediaAccessoryPanelContainer)
        
        self.ready.set(self.listNode.historyState.get()
        |> take(1)
        |> map { _ -> Bool in true })
        
        if [.file, .music, .voiceOrInstantVideo].contains(tagMask) {
            self.mediaStatusDisposable = (context.sharedContext.mediaManager.globalMediaPlayerState
            |> mapToSignal { playlistStateAndType -> Signal<(Account, SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> in
                if let (account, state, type) = playlistStateAndType {
                    switch state {
                    case let .state(state):
                        if let playlistId = state.playlistId as? PeerMessagesMediaPlaylistId, case .peer(peerId) = playlistId {
                            switch type {
                            case .voice:
                                if tagMask != .voiceOrInstantVideo {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            case .music:
                                if tagMask != .music {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            case .file:
                                if tagMask != .file {
                                    return .single(nil) |> delay(0.2, queue: .mainQueue())
                                }
                            }
                            return .single((account, state, type))
                        } else {
                            return .single(nil) |> delay(0.2, queue: .mainQueue())
                        }
                    case .loading:
                        return .single(nil) |> delay(0.2, queue: .mainQueue())
                    }
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] playlistStateAndType in
                guard let strongSelf = self else {
                    return
                }
                if !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.0, playlistStateAndType?.1.item) ||
                    !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.1, playlistStateAndType?.1.previousItem) ||
                    !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.2, playlistStateAndType?.1.nextItem) ||
                    strongSelf.playlistStateAndType?.3 != playlistStateAndType?.1.order || strongSelf.playlistStateAndType?.4 != playlistStateAndType?.2 {
                    
                    if let playlistStateAndType = playlistStateAndType {
                        strongSelf.playlistStateAndType = (playlistStateAndType.1.item, playlistStateAndType.1.previousItem, playlistStateAndType.1.nextItem, playlistStateAndType.1.order, playlistStateAndType.2, playlistStateAndType.0)
                    } else {
                        strongSelf.playlistStateAndType = nil
                    }
                    
                    if let (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, topInset: topInset, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: true, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }

        self.statusPromise.set(context.account.postbox.combinedView(keys: [PostboxViewKey.historyTagSummaryView(tag: tagMask, peerId: peerId, namespace: Namespaces.Message.Cloud)])
        |> map { views -> PeerInfoStatusData? in
            let count: Int32 = (views.views[PostboxViewKey.historyTagSummaryView(tag: tagMask, peerId: peerId, namespace: Namespaces.Message.Cloud)] as? MessageHistoryTagSummaryView)?.count ?? 0
            if count == 0 {
                return nil
            }

            let presentationData = context.sharedContext.currentPresentationData.with { $0 }

            switch tagMask {
            case MessageTags.file:
                return PeerInfoStatusData(text: presentationData.strings.SharedMedia_FileCount(Int32(count)), isActivity: false, key: .files)
            case MessageTags.music:
                return PeerInfoStatusData(text: presentationData.strings.SharedMedia_MusicCount(Int32(count)), isActivity: false, key: .music)
            case MessageTags.voiceOrInstantVideo:
                return PeerInfoStatusData(text: presentationData.strings.SharedMedia_VoiceMessageCount(Int32(count)), isActivity: false, key: .voice)
            case MessageTags.webPage:
                return PeerInfoStatusData(text: presentationData.strings.SharedMedia_LinkCount(Int32(count)), isActivity: false, key: .links)
            default:
                return nil
            }
        })
    }
    
    deinit {
        self.hiddenMediaDisposable?.dispose()
        self.mediaStatusDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
    }
    
    func ensureMessageIsVisible(id: MessageId) {
        
    }
    
    func scrollToTop() -> Bool {
        let offset = self.listNode.visibleContentOffset()
        switch offset {
        case let .known(value) where value <= CGFloat.ulpOfOne:
            return false
        default:
            self.listNode.scrollToEndOfHistory()
            return true
        }
    }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, topInset, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        
        var topPanelHeight: CGFloat = 0.0
        if let (item, previousItem, nextItem, order, type, _) = self.playlistStateAndType {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            topPanelHeight = floor(panelHeight * expandProgress)
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelHeight - panelHeight), size: CGSize(width: size.width, height: panelHeight))
            if let (mediaAccessoryPanel, mediaType) = self.mediaAccessoryPanel, mediaType == type {
                transition.updateFrame(layer: mediaAccessoryPanel.layer, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: sideInset, rightInset: sideInset, transition: transition)
                switch order {
                case .regular:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, previousItem, nextItem)
                case .reversed:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nextItem, previousItem)
                case .random:
                    mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nil, nil)
                }
                let delayedStatus = self.context.sharedContext.mediaManager.globalMediaPlayerState
                |> mapToSignal { value -> Signal<(Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?, NoError> in
                    guard let value = value else {
                        return .single(nil)
                    }
                    switch value.1 {
                        case .state:
                            return .single(value)
                        case .loading:
                            return .single(value) |> delay(0.1, queue: .mainQueue())
                    }
                }
                
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = delayedStatus
                |> map { state -> MediaPlayerStatus in
                    if let stateOrLoading = state?.1, case let .state(state) = stateOrLoading {
                        return state.status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
            } else {
                if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
                    self.mediaAccessoryPanel = nil
                    self.dismissingPanel = mediaAccessoryPanel
                    mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                        mediaAccessoryPanel?.removeFromSupernode()
                        if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                            strongSelf.dismissingPanel = nil
                        }
                    })
                }
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(context: self.context, presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, displayBackground: true)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = item.playbackData?.type != .instantVideo
                mediaAccessoryPanel.getController = { [weak self] in
                    return self?.parentController
                }
                mediaAccessoryPanel.presentInGlobalOverlay = { [weak self] c in
                    self?.parentController?.presentInGlobalOverlay(c)
                }
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.setPlaylist(nil, type: type, control: SharedMediaPlayerControlAction.playback(.pause))
                    }
                }
                mediaAccessoryPanel.setRate = { [weak self] rate in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> AudioPlaybackRate in
                        let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings)?.get(MusicPlaybackSettings.self) ?? MusicPlaybackSettings.defaultSettings
                        
                        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { _ in
                            return PreferencesEntry(settings.withUpdatedVoicePlaybackRate(rate))
                        })
                        return rate
                    }
                    |> deliverOnMainQueue).start(next: { baseRate in
                        guard let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType else {
                            return
                        }
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.setBaseRate(baseRate), type: type)
                        
                        if let controller = strongSelf.parentController {
                            var hasTooltip = false
                            controller.forEachController({ controller in
                                if let controller = controller as? UndoOverlayController {
                                    hasTooltip = true
                                    controller.dismissWithCommitAction()
                                }
                                return true
                            })
                            
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let slowdown: Bool?
                            if baseRate == .x1 {
                                slowdown = true
                            } else if baseRate == .x2 {
                                slowdown = false
                            } else {
                                slowdown = nil
                            }
                            if let slowdown = slowdown {
                                controller.present(
                                    UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .audioRate(
                                            slowdown: slowdown,
                                            text: slowdown ? presentationData.strings.Conversation_AudioRateTooltipNormal : presentationData.strings.Conversation_AudioRateTooltipSpeedUp
                                        ),
                                        elevatedLayout: false,
                                        animateInAsReplacement: hasTooltip,
                                        action: { action in
                                            return true
                                        }
                                    ),
                                    in: .current
                                )
                            }
                        }
                    })
                }
                mediaAccessoryPanel.togglePlayPause = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: type)
                    }
                }
                mediaAccessoryPanel.playPrevious = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.next, type: type)
                    }
                }
                mediaAccessoryPanel.playNext = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.previous, type: type)
                    }
                }
                mediaAccessoryPanel.tapAction = { [weak self] in
                    guard let strongSelf = self, let _ = strongSelf.chatControllerInteraction.navigationController(), let (state, _, _, order, type, account) = strongSelf.playlistStateAndType else {
                        return
                    }
                    if let id = state.id as? PeerMessagesMediaPlaylistItemId {
                        if type == .music {
                            let signal = strongSelf.context.sharedContext.messageFromPreloadedChatHistoryViewForLocation(id: id.messageId, location: ChatHistoryLocationInput(content: .InitialSearch(location: .id(id.messageId), count: 60, highlight: true), id: 0), context: strongSelf.context, chatLocation: .peer(id: id.messageId.peerId), subject: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), tagMask: MessageTags.music)
                            
                            var cancelImpl: (() -> Void)?
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let progressSignal = Signal<Never, NoError> { subscriber in
                                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                    cancelImpl?()
                                }))
                                self?.chatControllerInteraction.presentController(controller, nil)
                                return ActionDisposable { [weak controller] in
                                    Queue.mainQueue().async() {
                                        controller?.dismiss()
                                    }
                                }
                            }
                            |> runOn(Queue.mainQueue())
                            |> delay(0.15, queue: Queue.mainQueue())
                            let progressDisposable = MetaDisposable()
                            var progressStarted = false
                            strongSelf.playlistPreloadDisposable?.dispose()
                            strongSelf.playlistPreloadDisposable = (signal
                            |> afterDisposed {
                                Queue.mainQueue().async {
                                    progressDisposable.dispose()
                                }
                            }
                            |> deliverOnMainQueue).start(next: { index in
                                guard let strongSelf = self else {
                                    return
                                }
                                if let _ = index.0 {
                                    let controllerContext: AccountContext
                                    if account.id == strongSelf.context.account.id {
                                        controllerContext = strongSelf.context
                                    } else {
                                        controllerContext = strongSelf.context.sharedContext.makeTempAccountContext(account: account)
                                    }
                                    let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, playlistLocation: nil, parentNavigationController: strongSelf.chatControllerInteraction.navigationController())
                                    strongSelf.view.window?.endEditing(true)
                                    strongSelf.chatControllerInteraction.presentController(controller, nil)
                                } else if index.1 {
                                    if !progressStarted {
                                        progressStarted = true
                                        progressDisposable.set(progressSignal.start())
                                    }
                                }
                            }, completed: {
                            })
                            cancelImpl = {
                                self?.playlistPreloadDisposable?.dispose()
                            }
                        } else {
                            strongSelf.context.sharedContext.navigateToChat(accountId: strongSelf.context.account.id, peerId: id.messageId.peerId, messageId: id.messageId)
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                if let dismissingPanel = self.dismissingPanel {
                    self.mediaAccessoryPanelContainer.insertSubnode(mediaAccessoryPanel, aboveSubnode: dismissingPanel)
                } else {
                    self.mediaAccessoryPanelContainer.addSubnode(mediaAccessoryPanel)
                }
                self.mediaAccessoryPanel = (mediaAccessoryPanel, type)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: sideInset, rightInset: sideInset, transition: .immediate)
                switch order {
                    case .regular:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, previousItem, nextItem)
                    case .reversed:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nextItem, previousItem)
                    case .random:
                        mediaAccessoryPanel.containerNode.headerNode.playbackItems = (item, nil, nil)
                }
                mediaAccessoryPanel.containerNode.headerNode.playbackStatus = self.context.sharedContext.mediaManager.globalMediaPlayerState
                |> map { state -> MediaPlayerStatus in
                    if let stateOrLoading = state?.1, case let .state(state) = stateOrLoading {
                        return state.status
                    } else {
                        return MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
                    }
                }
                mediaAccessoryPanel.animateIn(transition: transition)
            }
        } else if let (mediaAccessoryPanel, _) = self.mediaAccessoryPanel {
            self.mediaAccessoryPanel = nil
            self.dismissingPanel = mediaAccessoryPanel
            mediaAccessoryPanel.animateOut(transition: transition, completion: { [weak self, weak mediaAccessoryPanel] in
                mediaAccessoryPanel?.removeFromSupernode()
                if let strongSelf = self, strongSelf.dismissingPanel === mediaAccessoryPanel {
                    strongSelf.dismissingPanel = nil
                }
            })
        }
        
        transition.updateFrame(node: self.mediaAccessoryPanelContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: size.width, height: MediaNavigationAccessoryHeaderNode.minimizedHeight)))
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: topPanelHeight + topInset, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve))
        if isScrollingLockedAtTop {
            switch self.listNode.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            case .none:
                break
            default:
                self.listNode.scrollToEndOfHistory()
            }
        }
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        self.listNode.messageInCurrentHistoryView(id)
    }
    
    func updateHiddenMedia() {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                itemNode.updateHiddenMedia()
            }
        }
    }
    
    func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
            self.listNode.transferVelocity(velocity)
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            }
        }
        return transitionNode
    }
    
    func addToTransitionSurface(view: UIView) {
        self.view.addSubview(view)
    }
    
    func updateSelectedMessages(animated: Bool) {
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateSelectionState(animated: animated)
            }
        }
        self.selectedMessages = self.chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
    }
}
