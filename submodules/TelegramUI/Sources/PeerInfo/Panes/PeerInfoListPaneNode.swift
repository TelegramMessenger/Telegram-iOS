import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
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

private final class PassthroughContainerNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                if let result = subnode.view.hitTest(self.view.convert(point, to: subnode.view), with: event) {
                    return result
                }
            }
        }
        return nil
    }
}

final class PeerInfoListPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let chatControllerInteraction: ChatControllerInteraction
    
    private let listNode: ChatHistoryListNode
    
    private var currentParams: (size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    let shouldReceiveExpandProgressUpdates: Bool
    
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
    
    init(context: AccountContext, chatControllerInteraction: ChatControllerInteraction, peerId: PeerId, tagMask: MessageTags) {
        self.context = context
        self.peerId = peerId
        self.chatControllerInteraction = chatControllerInteraction
        
        self.selectedMessages = chatControllerInteraction.selectionState.flatMap { $0.selectedIds }
        self.selectedMessagesPromise.set(.single(self.selectedMessages))
        
        self.listNode = ChatHistoryListNode(context: context, chatLocation: .peer(peerId), tagMask: tagMask, subject: nil, controllerInteraction: chatControllerInteraction, selectedMessages: self.selectedMessagesPromise.get(), mode: .list(search: false, reversed: false, displayHeaders: .allButLast))
        self.listNode.defaultToSynchronousTransactionWhileScrolling = true
        
        if tagMask == .music {
            self.shouldReceiveExpandProgressUpdates = true
        } else {
            self.shouldReceiveExpandProgressUpdates = false
        }
        
        self.mediaAccessoryPanelContainer = PassthroughContainerNode()
        self.mediaAccessoryPanelContainer.clipsToBounds = true
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        self.addSubnode(self.mediaAccessoryPanelContainer)
        
        self.ready.set(self.listNode.historyState.get()
        |> take(1)
        |> map { _ -> Bool in true })
        
        if tagMask == .music || tagMask == .voiceOrInstantVideo {
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
                    
                    if let (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, sideInset: sideInset, bottomInset: bottomInset, visibleHeight: visibleHeight, isScrollingLockedAtTop: isScrollingLockedAtTop, expandProgress: expandProgress, presentationData: presentationData, synchronous: true, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
    }
    
    deinit {
        self.hiddenMediaDisposable?.dispose()
        self.mediaStatusDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
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
    
    func update(size: CGSize, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, sideInset, bottomInset, visibleHeight, isScrollingLockedAtTop, expandProgress, presentationData)
        
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
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(context: self.context)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = item.playbackData?.type != .instantVideo
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType {
                        strongSelf.context.sharedContext.mediaManager.setPlaylist(nil, type: type, control: SharedMediaPlayerControlAction.playback(.pause))
                    }
                }
                mediaAccessoryPanel.toggleRate = {
                    [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> AudioPlaybackRate in
                        let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings) as? MusicPlaybackSettings ?? MusicPlaybackSettings.defaultSettings
                        
                        let nextRate: AudioPlaybackRate
                        switch settings.voicePlaybackRate {
                            case .x1:
                                nextRate = .x2
                            case .x2:
                                nextRate = .x1
                        }
                        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.musicPlaybackSettings, { _ in
                            return settings.withUpdatedVoicePlaybackRate(nextRate)
                        })
                        return nextRate
                    }
                    |> deliverOnMainQueue).start(next: { baseRate in
                        guard let strongSelf = self, let (_, _, _, _, type, _) = strongSelf.playlistStateAndType else {
                            return
                        }
                        strongSelf.context.sharedContext.mediaManager.playlistControl(.setBaseRate(baseRate), type: type)
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
                            let signal = strongSelf.context.sharedContext.messageFromPreloadedChatHistoryViewForLocation(id: id.messageId, location: ChatHistoryLocationInput(content: .InitialSearch(location: .id(id.messageId), count: 60), id: 0), account: account, chatLocation: .peer(id.messageId.peerId), tagMask: MessageTags.music)
                            
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
                                    let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, parentNavigationController: strongSelf.chatControllerInteraction.navigationController())
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
        
        transition.updateFrame(node: self.mediaAccessoryPanelContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: MediaNavigationAccessoryHeaderNode.minimizedHeight)))
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: topPanelHeight, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve))
        if isScrollingLockedAtTop {
            switch self.listNode.visibleContentOffset() {
            case .known(0.0), .none:
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
