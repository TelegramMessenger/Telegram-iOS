import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import UniversalMediaPlayer
import AccountContext
import OverlayStatusController
import PresentationDataUtils

public enum MediaAccessoryPanelVisibility {
    case none
    case specific(size: ContainerViewLayoutSizeClass)
    case always
}

public enum LocationBroadcastPanelSource {
    case none
    case summary
    case peer(PeerId)
}

private func presentLiveLocationController(context: AccountContext, peerId: PeerId, controller: ViewController) {
    let presentImpl: (Message?) -> Void = { [weak controller] message in
        if let message = message, let strongController = controller {
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: strongController.navigationController as? NavigationController, modal: true, dismissInput: {
                controller?.view.endEditing(true)
            }, present: { c, a in
                controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
            }, transitionNode: { _, _ in
                return nil
            }, addToTransitionSurface: { _ in
            }, openUrl: { _ in
            }, openPeer: { peer, navigation in
            }, callPeer: { _ in
            }, enqueueMessage: { _ in
            }, sendSticker: nil,
            setupTemporaryHiddenMedia: { _, _, _ in
            }, chatAvatarHiddenMedia: { _, _ in
            }))
        }
    }
    if let id = context.liveLocationManager?.internalMessageForPeerId(peerId) {
        let _ = (context.account.postbox.transaction { transaction -> Message? in
            return transaction.getMessage(id)
        } |> deliverOnMainQueue).start(next: presentImpl)
    } else if let liveLocationManager = context.liveLocationManager {
        let _ = (liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId)
        |> take(1)
        |> map { peersAndMessages -> Message? in
            return peersAndMessages?.first?.1
        } |> deliverOnMainQueue).start(next: presentImpl)
    }
}

open class TelegramBaseController: ViewController, KeyShortcutResponder {
    private let context: AccountContext
    
    public let mediaAccessoryPanelVisibility: MediaAccessoryPanelVisibility
    public let locationBroadcastPanelSource: LocationBroadcastPanelSource
    
    private var mediaStatusDisposable: Disposable?
    private var locationBroadcastDisposable: Disposable?
    
    public private(set) var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account)?
    
    public var tempVoicePlaylistEnded: (() -> Void)?
    public var tempVoicePlaylistItemChanged: ((SharedMediaPlaylistItem?, SharedMediaPlaylistItem?) -> Void)?
    
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    
    private var locationBroadcastMode: LocationBroadcastNavigationAccessoryPanelMode?
    private var locationBroadcastPeers: [Peer]?
    private var locationBroadcastMessages: [MessageId: Message]?
    private var locationBroadcastAccessoryPanel: LocationBroadcastNavigationAccessoryPanel?
    
    private var dismissingPanel: ASDisplayNode?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var playlistPreloadDisposable: Disposable?
    
    override open var navigationHeight: CGFloat {
        return super.navigationHeight + self.additionalHeight
    }
    
    override open var navigationInsetHeight: CGFloat {
        return super.navigationInsetHeight + self.additionalHeight
    }
    
    override open var visualNavigationInsetHeight: CGFloat {
        return super.visualNavigationInsetHeight + self.additionalHeight
    }
    
    private var additionalHeight: CGFloat {
        var height: CGFloat = 0.0
        if let _ = self.mediaAccessoryPanel {
            height += MediaNavigationAccessoryHeaderNode.minimizedHeight
        }
        if let _ = self.locationBroadcastAccessoryPanel {
            height += MediaNavigationAccessoryHeaderNode.minimizedHeight
        }
        return height
    }
    
    open var primaryNavigationHeight: CGFloat {
        return super.navigationHeight
    }
    
    public init(context: AccountContext, navigationBarPresentationData: NavigationBarPresentationData?, mediaAccessoryPanelVisibility: MediaAccessoryPanelVisibility, locationBroadcastPanelSource: LocationBroadcastPanelSource) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.mediaAccessoryPanelVisibility = mediaAccessoryPanelVisibility
        self.locationBroadcastPanelSource = locationBroadcastPanelSource
        
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        if case .none = mediaAccessoryPanelVisibility {
        } else {
            self.mediaStatusDisposable = (context.sharedContext.mediaManager.globalMediaPlayerState
            |> mapToSignal { playlistStateAndType -> Signal<(Account, SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> in
                if let (account, state, type) = playlistStateAndType {
                    switch state {
                        case let .state(state):
                            return .single((account, state, type))
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
                    var previousVoiceItem: SharedMediaPlaylistItem?
                    if let playlistStateAndType = strongSelf.playlistStateAndType, playlistStateAndType.4 == .voice {
                        previousVoiceItem = playlistStateAndType.0
                    }
                    
                    var updatedVoiceItem: SharedMediaPlaylistItem?
                    if let playlistStateAndType = playlistStateAndType, playlistStateAndType.2 == .voice {
                        updatedVoiceItem = playlistStateAndType.1.item
                    }
                    
                    strongSelf.tempVoicePlaylistItemChanged?(previousVoiceItem, updatedVoiceItem)
                    if let playlistStateAndType = playlistStateAndType {
                        strongSelf.playlistStateAndType = (playlistStateAndType.1.item, playlistStateAndType.1.previousItem, playlistStateAndType.1.nextItem, playlistStateAndType.1.order, playlistStateAndType.2, playlistStateAndType.0)
                    } else {
                        var voiceEnded = false
                        if strongSelf.playlistStateAndType?.4 == .voice {
                            voiceEnded = true
                        }
                        strongSelf.playlistStateAndType = nil
                        if voiceEnded {
                            strongSelf.tempVoicePlaylistEnded?()
                        }
                    }
                    strongSelf.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                }
            })
        }
        
        if let liveLocationManager = context.liveLocationManager {
            switch locationBroadcastPanelSource {
                case .none:
                    self.locationBroadcastMode = nil
                case .summary, .peer:
                    let signal: Signal<([Peer]?, [MessageId: Message]?), NoError>
                    switch locationBroadcastPanelSource {
                        case let .peer(peerId):
                            self.locationBroadcastMode = .peer
                            signal = combineLatest(liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId), liveLocationManager.summaryManager.broadcastingToMessages())
                            |> map { peersAndMessages, outgoingMessages in
                                var peers = peersAndMessages?.map { $0.0 }
                                for message in outgoingMessages.values {
                                    if message.id.peerId == peerId, let author = message.author {
                                        if peers == nil {
                                            peers = []
                                        }
                                        peers?.append(author)
                                    }
                                }
                                return (peers, outgoingMessages)
                            }
                        default:
                            self.locationBroadcastMode = .summary
                            signal = liveLocationManager.summaryManager.broadcastingToMessages()
                            |> map { messages -> ([Peer]?, [MessageId: Message]?) in
                                if messages.isEmpty {
                                    return (nil, nil)
                                } else {
                                    var peers: [Peer] = []
                                    for message in messages.values.sorted(by: { $0.index < $1.index }) {
                                        if let peer = message.peers[message.id.peerId] {
                                            peers.append(peer)
                                        }
                                    }
                                    return (peers, messages)
                                }
                            }
                        
                    }
                    
                    self.locationBroadcastDisposable = (signal
                    |> deliverOnMainQueue).start(next: { [weak self] peers, messages in
                        if let strongSelf = self {
                            var updated = false
                            if let current = strongSelf.locationBroadcastPeers, let peers = peers {
                                updated = !arePeerArraysEqual(current, peers)
                            } else if (strongSelf.locationBroadcastPeers != nil) != (peers != nil) {
                                updated = true
                            }
                            
                            strongSelf.locationBroadcastMessages = messages
                            
                            if updated {
                                let wasEmpty = strongSelf.locationBroadcastPeers == nil
                                strongSelf.locationBroadcastPeers = peers
                                if wasEmpty != (peers == nil) {
                                    strongSelf.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                                } else if let peers = peers, let locationBroadcastMode = strongSelf.locationBroadcastMode {
                                    var canClose = true
                                    if case let .peer(peerId) = strongSelf.locationBroadcastPanelSource, let messages = messages {
                                        canClose = false
                                        for messageId in messages.keys {
                                            if messageId.peerId == peerId {
                                                canClose = true
                                            }
                                        }
                                    }
                                    strongSelf.locationBroadcastAccessoryPanel?.update(peers: peers, mode: locationBroadcastMode, canClose: canClose)
                                }
                            }
                        }
                    })
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.mediaAccessoryPanel?.0.containerNode.updatePresentationData(presentationData)
                    strongSelf.locationBroadcastAccessoryPanel?.updatePresentationData(presentationData)
                }
            }
        })
    }
    
    deinit {
        self.mediaStatusDisposable?.dispose()
        self.locationBroadcastDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        var navigationHeight = super.navigationHeight
        if !self.displayNavigationBar {
            navigationHeight = 0.0
        }
        
        var additionalHeight: CGFloat = 0.0
        
        if let locationBroadcastPeers = self.locationBroadcastPeers, let locationBroadcastMode = self.locationBroadcastMode {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight.isZero ? -panelHeight : (navigationHeight + additionalHeight + UIScreenPixel)), size: CGSize(width: layout.size.width, height: panelHeight))
            additionalHeight += panelHeight
            
            let locationBroadcastAccessoryPanel: LocationBroadcastNavigationAccessoryPanel
            if let current = self.locationBroadcastAccessoryPanel {
                locationBroadcastAccessoryPanel = current
                transition.updateFrame(node: locationBroadcastAccessoryPanel, frame: panelFrame)
                locationBroadcastAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
            } else {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                locationBroadcastAccessoryPanel = LocationBroadcastNavigationAccessoryPanel(accountPeerId: self.context.account.peerId, theme: presentationData.theme, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, tapAction: { [weak self] in
                    if let strongSelf = self {
                        switch strongSelf.locationBroadcastPanelSource {
                            case .none:
                                break
                            case .summary:
                                if let locationBroadcastMessages = strongSelf.locationBroadcastMessages {
                                    let messages = locationBroadcastMessages.values.sorted(by: { $0.index > $1.index })
                                    
                                    if messages.count == 1 {
                                        presentLiveLocationController(context: strongSelf.context, peerId: messages[0].id.peerId, controller: strongSelf)
                                    } else {
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        let controller = ActionSheetController(presentationData: presentationData)
                                        let dismissAction: () -> Void = { [weak controller] in
                                            controller?.dismissAnimated()
                                        }
                                        var items: [ActionSheetItem] = []
                                        if !messages.isEmpty {
                                            items.append(ActionSheetTextItem(title: presentationData.strings.LiveLocation_MenuChatsCount(Int32(messages.count))))
                                            for message in messages {
                                                if let peer = message.peers[message.id.peerId] {
                                                    var beginTimeAndTimeout: (Double, Double)?
                                                    for media in message.media {
                                                        if let media = media as? TelegramMediaMap, let timeout = media.liveBroadcastingTimeout {
                                                            beginTimeAndTimeout = (Double(message.timestamp), Double(timeout))
                                                        }
                                                    }
                                                    
                                                    if let beginTimeAndTimeout = beginTimeAndTimeout {
                                                        items.append(LocationBroadcastActionSheetItem(context: strongSelf.context, peer: peer, title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), beginTimestamp: beginTimeAndTimeout.0, timeout: beginTimeAndTimeout.1, strings: presentationData.strings, action: {
                                                            dismissAction()
                                                            if let strongSelf = self {
                                                                presentLiveLocationController(context: strongSelf.context, peerId: peer.id, controller: strongSelf)
                                                            }
                                                        }))
                                                    }
                                                }
                                            }
                                            items.append(ActionSheetButtonItem(title: presentationData.strings.LiveLocation_MenuStopAll, color: .destructive, action: {
                                                dismissAction()
                                                if let locationBroadcastPeers = strongSelf.locationBroadcastPeers {
                                                    for peer in locationBroadcastPeers {
                                                        self?.context.liveLocationManager?.cancelLiveLocation(peerId: peer.id)
                                                    }
                                                }
                                            }))
                                        }
                                        controller.setItemGroups([
                                            ActionSheetItemGroup(items: items),
                                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                                            ])
                                        strongSelf.view.endEditing(true)
                                        strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }
                                }
                            case let .peer(peerId):
                                presentLiveLocationController(context: strongSelf.context, peerId: peerId, controller: strongSelf)
                        }
                    }
                }, close: { [weak self] in
                    if let strongSelf = self {
                        var closePeers: [Peer]?
                        var closePeerId: PeerId?
                        switch strongSelf.locationBroadcastPanelSource {
                            case .none:
                                break
                            case .summary:
                                if let locationBroadcastPeers = strongSelf.locationBroadcastPeers {
                                    if locationBroadcastPeers.count > 1 {
                                        closePeers = locationBroadcastPeers
                                    } else {
                                        closePeerId = locationBroadcastPeers.first?.id
                                    }
                                }
                            case let .peer(peerId):
                                closePeerId = peerId
                        }
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        var items: [ActionSheetItem] = []
                        if let closePeers = closePeers, !closePeers.isEmpty {
                            items.append(ActionSheetTextItem(title: presentationData.strings.LiveLocation_MenuChatsCount(Int32(closePeers.count))))
                            for peer in closePeers {
                                items.append(ActionSheetButtonItem(title: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), action: {
                                    dismissAction()
                                    if let strongSelf = self {
                                        presentLiveLocationController(context: strongSelf.context, peerId: peer.id, controller: strongSelf)
                                    }
                                }))
                            }
                            items.append(ActionSheetButtonItem(title: presentationData.strings.LiveLocation_MenuStopAll, color: .destructive, action: {
                                dismissAction()
                                for peer in closePeers {
                                    self?.context.liveLocationManager?.cancelLiveLocation(peerId: peer.id)
                                }
                            }))
                        } else if let closePeerId = closePeerId {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Map_StopLiveLocation, color: .destructive, action: {
                                dismissAction()
                                self?.context.liveLocationManager?.cancelLiveLocation(peerId: closePeerId)
                            }))
                        }
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                            ])
                        strongSelf.view.endEditing(true)
                        strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }
                })
                if let navigationBar = self.navigationBar {
                    self.displayNode.insertSubnode(locationBroadcastAccessoryPanel, aboveSubnode: navigationBar)
                } else {
                    self.displayNode.addSubnode(locationBroadcastAccessoryPanel)
                }
                self.locationBroadcastAccessoryPanel = locationBroadcastAccessoryPanel
                locationBroadcastAccessoryPanel.frame = panelFrame
                
                var canClose = true
                if case let .peer(peerId) = self.locationBroadcastPanelSource, let messages = self.locationBroadcastMessages {
                    canClose = false
                    for messageId in messages.keys {
                        if messageId.peerId == peerId {
                            canClose = true
                        }
                    }
                }
                
                locationBroadcastAccessoryPanel.update(peers: locationBroadcastPeers, mode: locationBroadcastMode, canClose: canClose)
                locationBroadcastAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: .immediate)
                if transition.isAnimated {
                    locationBroadcastAccessoryPanel.animateIn(transition)
                }
            }
        } else if let locationBroadcastAccessoryPanel = self.locationBroadcastAccessoryPanel {
            self.locationBroadcastAccessoryPanel = nil
            if transition.isAnimated {
                locationBroadcastAccessoryPanel.animateOut(transition, completion: { [weak locationBroadcastAccessoryPanel] in
                    locationBroadcastAccessoryPanel?.removeFromSupernode()
                })
            } else {
                locationBroadcastAccessoryPanel.removeFromSupernode()
            }
        }
        
        let mediaAccessoryPanelHidden: Bool
        switch self.mediaAccessoryPanelVisibility {
            case .always:
                mediaAccessoryPanelHidden = false
            case .none:
                mediaAccessoryPanelHidden = true
            case let .specific(size):
                mediaAccessoryPanelHidden = size != layout.metrics.widthClass
        }
        
        if let (item, previousItem, nextItem, order, type, _) = self.playlistStateAndType, !mediaAccessoryPanelHidden {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight.isZero ? -panelHeight : (navigationHeight + additionalHeight)), size: CGSize(width: layout.size.width, height: panelHeight))
            if let (mediaAccessoryPanel, mediaType) = self.mediaAccessoryPanel, mediaType == type {
                transition.updateFrame(layer: mediaAccessoryPanel.layer, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
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
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = type != .voice
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
                    guard let strongSelf = self, let _ = strongSelf.navigationController as? NavigationController, let (state, _, _, order, type, account) = strongSelf.playlistStateAndType else {
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
                                self?.present(controller, in: .window(.root))
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
                                    let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, parentNavigationController: strongSelf.navigationController as? NavigationController)
                                    strongSelf.displayNode.view.window?.endEditing(true)
                                    strongSelf.present(controller, in: .window(.root))
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
                    self.displayNode.insertSubnode(mediaAccessoryPanel, aboveSubnode: dismissingPanel)
                } else if let navigationBar = self.navigationBar {
                    self.displayNode.insertSubnode(mediaAccessoryPanel, belowSubnode: navigationBar)
                } else {
                    self.displayNode.addSubnode(mediaAccessoryPanel)
                }
                self.mediaAccessoryPanel = (mediaAccessoryPanel, type)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: .immediate)
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
    }
    
    open var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
}
