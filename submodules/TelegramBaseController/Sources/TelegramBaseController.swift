import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import UniversalMediaPlayer
import AccountContext
import OverlayStatusController
import PresentationDataUtils
import TelegramCallsUI
import UndoUI

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
    let presentImpl: (EngineMessage?) -> Void = { [weak controller] message in
        if let message = message, let strongController = controller {
            let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: false, navigationController: strongController.navigationController as? NavigationController, modal: true, dismissInput: {
                controller?.view.endEditing(true)
            }, present: { c, a in
                controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
            }, transitionNode: { _, _ in
                return nil
            }, addToTransitionSurface: { _ in
            }, openUrl: { _ in
            }, openPeer: { peer, navigation in
            }, callPeer: { _, _ in
            }, enqueueMessage: { message in
                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
            }, sendSticker: nil,
            setupTemporaryHiddenMedia: { _, _, _ in
            }, chatAvatarHiddenMedia: { _, _ in
            }))
        }
    }
    if let id = context.liveLocationManager?.internalMessageForPeerId(peerId) {
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))
        |> deliverOnMainQueue).start(next: presentImpl)
    } else if let liveLocationManager = context.liveLocationManager {
        let _ = (liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId)
        |> take(1)
        |> map { peersAndMessages -> EngineMessage? in
            return peersAndMessages?.first?.1
        } |> deliverOnMainQueue).start(next: presentImpl)
    }
}

open class TelegramBaseController: ViewController, KeyShortcutResponder {
    private let context: AccountContext
    
    public let mediaAccessoryPanelVisibility: MediaAccessoryPanelVisibility
    public let locationBroadcastPanelSource: LocationBroadcastPanelSource
    public let groupCallPanelSource: GroupCallPanelSource
    
    private var mediaStatusDisposable: Disposable?
    private var locationBroadcastDisposable: Disposable?
    private var currentGroupCallDisposable: Disposable?
    
    public private(set) var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account)?
    private var playlistLocation: SharedMediaPlaylistLocation?
    
    public var tempVoicePlaylistEnded: (() -> Void)?
    public var tempVoicePlaylistItemChanged: ((SharedMediaPlaylistItem?, SharedMediaPlaylistItem?) -> Void)?
    public var tempVoicePlaylistCurrentItem: SharedMediaPlaylistItem?
    
    public var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    
    private var locationBroadcastMode: LocationBroadcastNavigationAccessoryPanelMode?
    private var locationBroadcastPeers: [EnginePeer]?
    private var locationBroadcastMessages: [EngineMessage.Id: EngineMessage]?
    private var locationBroadcastAccessoryPanel: LocationBroadcastNavigationAccessoryPanel?
    
    private var groupCallPanelData: GroupCallPanelData?
    private var groupCallAccessoryPanel: GroupCallNavigationAccessoryPanel?
    
    private var dismissingPanel: ASDisplayNode?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var playlistPreloadDisposable: Disposable?
    
    override open var additionalNavigationBarHeight: CGFloat {
        var height: CGFloat = 0.0
        if let _ = self.groupCallAccessoryPanel {
            height += 50.0
        }
        if let _ = self.mediaAccessoryPanel {
            height += MediaNavigationAccessoryHeaderNode.minimizedHeight
        }
        if let _ = self.locationBroadcastAccessoryPanel {
            height += MediaNavigationAccessoryHeaderNode.minimizedHeight
        }
        return height
    }
    
    public init(context: AccountContext, navigationBarPresentationData: NavigationBarPresentationData?, mediaAccessoryPanelVisibility: MediaAccessoryPanelVisibility, locationBroadcastPanelSource: LocationBroadcastPanelSource, groupCallPanelSource: GroupCallPanelSource) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.mediaAccessoryPanelVisibility = mediaAccessoryPanelVisibility
        self.locationBroadcastPanelSource = locationBroadcastPanelSource
        self.groupCallPanelSource = groupCallPanelSource
        
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
                    
                    strongSelf.tempVoicePlaylistCurrentItem = updatedVoiceItem
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
                strongSelf.playlistLocation = playlistStateAndType?.1.playlistLocation
            })
        }
        
        if let liveLocationManager = context.liveLocationManager {
            switch locationBroadcastPanelSource {
                case .none:
                    self.locationBroadcastMode = nil
                case .summary, .peer:
                    let signal: Signal<([EnginePeer]?, [EngineMessage.Id: EngineMessage]?), NoError>
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
                            |> map { messages -> ([EnginePeer]?, [EngineMessage.Id: EngineMessage]?) in
                                if messages.isEmpty {
                                    return (nil, nil)
                                } else {
                                    var peers: [EnginePeer] = []
                                    for message in messages.values.sorted(by: { $0.index < $1.index }) {
                                        if let peer = message.peers[message.id.peerId] {
                                            peers.append(EnginePeer(peer))
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
                                updated = current != peers
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
        
        if let callManager = context.sharedContext.callManager {
            switch groupCallPanelSource {
            case .none, .all:
                break
            case let .peer(peerId):
                let currentGroupCall: Signal<PresentationGroupCall?, NoError> = callManager.currentGroupCallSignal
                |> distinctUntilChanged(isEqual: { lhs, rhs in
                    return lhs?.internalId == rhs?.internalId
                })
                |> map { call -> PresentationGroupCall? in
                    guard let call = call, call.peerId == peerId && call.account.peerId == context.account.peerId else {
                        return nil
                    }
                    return call
                }
                
                let availableGroupCall: Signal<GroupCallPanelData?, NoError>
                if case let .peer(peerId) = groupCallPanelSource {
                    availableGroupCall = context.account.viewTracker.peerView(peerId)
                    |> map { peerView -> (CachedChannelData.ActiveCall?, EnginePeer?) in
                        let peer = peerView.peers[peerId].flatMap(EnginePeer.init)
                        if let cachedData = peerView.cachedData as? CachedChannelData {
                            return (cachedData.activeCall, peer)
                        } else if let cachedData = peerView.cachedData as? CachedGroupData {
                            return (cachedData.activeCall, peer)
                        } else {
                            return (nil, peer)
                        }
                    }
                    |> distinctUntilChanged(isEqual: { lhs, rhs in
                        if lhs.0 != rhs.0 {
                            return false
                        }
                        return true
                    })
                    |> mapToSignal { activeCall, peer -> Signal<GroupCallPanelData?, NoError> in
                        guard let activeCall = activeCall else {
                            return .single(nil)
                        }

                        var isChannel = false
                        if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                            isChannel = true
                        }
                        
                        return Signal { [weak context] subscriber in
                            guard let context = context, let callContextCache = context.cachedGroupCallContexts as? AccountGroupCallContextCacheImpl else {
                                return EmptyDisposable
                            }
                            
                            let disposable = MetaDisposable()
                            
                            callContextCache.impl.syncWith { impl in
                                let callContext = impl.get(account: context.account, engine: context.engine, peerId: peerId, isChannel: isChannel, call: EngineGroupCallDescription(activeCall))
                                disposable.set((callContext.context.panelData
                                |> deliverOnMainQueue).start(next: { panelData in
                                    callContext.keep()
                                    subscriber.putNext(panelData)
                                }))
                            }
                            
                            return ActionDisposable {
                                disposable.dispose()
                            }
                        }
                        |> runOn(.mainQueue())
                    }
                } else {
                    availableGroupCall = .single(nil)
                }
                
                let previousCurrentGroupCall = Atomic<PresentationGroupCall?>(value: nil)
                self.currentGroupCallDisposable = combineLatest(queue: .mainQueue(), availableGroupCall, currentGroupCall).start(next: { [weak self] availableState, currentGroupCall in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let previousCurrentGroupCall = previousCurrentGroupCall.swap(currentGroupCall)
                    
                    let panelData: GroupCallPanelData?
                    if previousCurrentGroupCall != nil && currentGroupCall == nil && availableState?.participantCount == 1 {
                        panelData = nil
                    } else {
                        panelData = currentGroupCall != nil || (availableState?.participantCount == 0 && availableState?.info.scheduleTimestamp == nil && availableState?.info.isStream == false) ? nil : availableState
                    }
                    
                    let wasEmpty = strongSelf.groupCallPanelData == nil
                    strongSelf.groupCallPanelData = panelData
                    let isEmpty = strongSelf.groupCallPanelData == nil
                    if wasEmpty != isEmpty {
                        strongSelf.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                    } else if let groupCallPanelData = strongSelf.groupCallPanelData {
                        strongSelf.groupCallAccessoryPanel?.update(data: groupCallPanelData)
                    }
                })
            }
        }
        
        self.presentationDataDisposable = (self.updatedPresentationData.1
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.mediaAccessoryPanel?.0.containerNode.updatePresentationData(presentationData)
                    strongSelf.locationBroadcastAccessoryPanel?.updatePresentationData(presentationData)
                    strongSelf.groupCallAccessoryPanel?.updatePresentationData(presentationData)
                }
            }
        })
    }
    
    open var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) {
        return (self.presentationData, self.context.sharedContext.presentationData)
    }
    
    deinit {
        self.mediaStatusDisposable?.dispose()
        self.locationBroadcastDisposable?.dispose()
        self.currentGroupCallDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.playlistPreloadDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var suspendNavigationBarLayout: Bool = false
    private var suspendedNavigationBarLayout: ContainerViewLayout?
    private var additionalNavigationBarBackgroundHeight: CGFloat = 0.0

    override open func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if self.suspendNavigationBarLayout {
            self.suspendedNavigationBarLayout = layout
            return
        }
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, transition: transition)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.suspendNavigationBarLayout = true
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        var navigationHeight = super.navigationLayout(layout: layout).navigationFrame.maxY - self.additionalNavigationBarHeight
        if !self.displayNavigationBar {
            navigationHeight = 0.0
        }
        
        var additionalHeight: CGFloat = 0.0
        
        if let groupCallPanelData = self.groupCallPanelData {
            let panelHeight: CGFloat = 50.0
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight.isZero ? -panelHeight : (navigationHeight + additionalHeight + UIScreenPixel)), size: CGSize(width: layout.size.width, height: panelHeight))
            additionalHeight += panelHeight
            
            let groupCallAccessoryPanel: GroupCallNavigationAccessoryPanel
            if let current = self.groupCallAccessoryPanel {
                groupCallAccessoryPanel = current
                transition.updateFrame(node: groupCallAccessoryPanel, frame: panelFrame)
                groupCallAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
            } else {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                groupCallAccessoryPanel = GroupCallNavigationAccessoryPanel(context: self.context, presentationData: presentationData, tapAction: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.joinGroupCall(
                        peerId: groupCallPanelData.peerId,
                        invite: nil,
                        activeCall: EngineGroupCallDescription(id: groupCallPanelData.info.id, accessHash: groupCallPanelData.info.accessHash, title: groupCallPanelData.info.title, scheduleTimestamp: groupCallPanelData.info.scheduleTimestamp, subscribedToScheduled: groupCallPanelData.info.subscribedToScheduled, isStream: groupCallPanelData.info.isStream)
                    )
                })
                self.navigationBar?.additionalContentNode.addSubnode(groupCallAccessoryPanel)
                self.groupCallAccessoryPanel = groupCallAccessoryPanel
                groupCallAccessoryPanel.frame = panelFrame
                
                groupCallAccessoryPanel.update(data: groupCallPanelData)
                groupCallAccessoryPanel.updateLayout(size: panelFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: .immediate)
                if transition.isAnimated {
                    groupCallAccessoryPanel.animateIn(transition)
                }
            }
        } else if let groupCallAccessoryPanel = self.groupCallAccessoryPanel {
            self.groupCallAccessoryPanel = nil
            if transition.isAnimated {
                groupCallAccessoryPanel.animateOut(transition, completion: { [weak groupCallAccessoryPanel] in
                    groupCallAccessoryPanel?.removeFromSupernode()
                })
            } else {
                groupCallAccessoryPanel.removeFromSupernode()
            }
        }
        
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
                                                        items.append(LocationBroadcastActionSheetItem(context: strongSelf.context, peer: peer, title: EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), beginTimestamp: beginTimeAndTimeout.0, timeout: beginTimeAndTimeout.1, strings: presentationData.strings, action: {
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
                        var closePeers: [EnginePeer]?
                        var closePeerId: EnginePeer.Id?
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
                self.navigationBar?.additionalContentNode.addSubnode(locationBroadcastAccessoryPanel)
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
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(context: self.context, presentationData: self.updatedPresentationData.0)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = item.playbackData?.type != .instantVideo
                mediaAccessoryPanel.getController = { [weak self] in
                    return self
                }
                mediaAccessoryPanel.presentInGlobalOverlay = { [weak self] c in
                    self?.presentInGlobalOverlay(c)
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
                        
                        var hasTooltip = false
                        strongSelf.forEachController({ controller in
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
                            strongSelf.present(
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
                            if let playlistLocation = strongSelf.playlistLocation as? PeerMessagesPlaylistLocation, case .custom = playlistLocation {
                                let controllerContext: AccountContext
                                if account.id == strongSelf.context.account.id {
                                    controllerContext = strongSelf.context
                                } else {
                                    controllerContext = strongSelf.context.sharedContext.makeTempAccountContext(account: account)
                                }
                                let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, playlistLocation: playlistLocation, parentNavigationController: strongSelf.navigationController as? NavigationController)
                                strongSelf.displayNode.view.window?.endEditing(true)
                                strongSelf.present(controller, in: .window(.root))
                            } else {
                                let signal = strongSelf.context.sharedContext.messageFromPreloadedChatHistoryViewForLocation(id: id.messageId, location: ChatHistoryLocationInput(content: .InitialSearch(location: .id(id.messageId), count: 60, highlight: true), id: 0), context: strongSelf.context, chatLocation: .peer(id: id.messageId.peerId), subject: nil, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil), tagMask: MessageTags.music)
                                
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
                                        let controller = strongSelf.context.sharedContext.makeOverlayAudioPlayerController(context: controllerContext, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, playlistLocation: nil, parentNavigationController: strongSelf.navigationController as? NavigationController)
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
                            }
                        } else {
                            strongSelf.context.sharedContext.navigateToChat(accountId: strongSelf.context.account.id, peerId: id.messageId.peerId, messageId: id.messageId)
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                if let dismissingPanel = self.dismissingPanel {
                    self.navigationBar?.additionalContentNode.insertSubnode(mediaAccessoryPanel, aboveSubnode: dismissingPanel)
                } else {
                    self.navigationBar?.additionalContentNode.addSubnode(mediaAccessoryPanel)
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

        self.suspendNavigationBarLayout = false
        if let suspendedNavigationBarLayout = self.suspendedNavigationBarLayout {
            self.suspendedNavigationBarLayout = suspendedNavigationBarLayout
            self.applyNavigationBarLayout(suspendedNavigationBarLayout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: self.additionalNavigationBarBackgroundHeight, transition: transition)
        }
    }
    
    open var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
    
    open func joinGroupCall(peerId: PeerId, invite: String?, activeCall: EngineGroupCallDescription) {
        let context = self.context
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        self.view.endEditing(true)
        
        self.context.joinGroupCall(peerId: peerId, invite: invite, requestJoinAsPeerId: { completion in
            let currentAccountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId)
            |> map { peer in
                return [FoundPeer(peer: peer, subscribers: nil)]
            }
            
            let _ = (combineLatest(
                currentAccountPeer,
                context.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: peerId),
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.CallJoinAsPeerId(id: peerId))
            )
            |> map { currentAccountPeer, availablePeers, callJoinAsPeerId -> ([FoundPeer], EnginePeer.Id?) in
                var result = currentAccountPeer
                result.append(contentsOf: availablePeers)
                return (result, callJoinAsPeerId)
            }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] peers, callJoinAsPeerId in
                guard let strongSelf = self else {
                    return
                }
                
                let defaultJoinAsPeerId: PeerId? = callJoinAsPeerId
                                
                if peers.count == 1, let peer = peers.first {
                    completion(peer.peer.id)
                } else {
                    if let defaultJoinAsPeerId = defaultJoinAsPeerId {
                        completion(defaultJoinAsPeerId)
                    } else {
                        let controller = ActionSheetController(presentationData: presentationData)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        
                        var items: [ActionSheetItem] = []
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
                            
                        items.append(VoiceChatAccountHeaderActionSheetItem(title: presentationData.strings.VoiceChat_SelectAccount, text: isGroup ? presentationData.strings.VoiceChat_DisplayAsInfoGroup : presentationData.strings.VoiceChat_DisplayAsInfo))
                        for peer in peers {
                            var subtitle: String?
                            if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                                subtitle = presentationData.strings.VoiceChat_PersonalAccount
                            } else if let subscribers = peer.subscribers {
                                if let peer = peer.peer as? TelegramChannel, case .broadcast = peer.info {
                                    subtitle = strongSelf.presentationData.strings.Conversation_StatusSubscribers(subscribers)
                                } else {
                                    subtitle = strongSelf.presentationData.strings.Conversation_StatusMembers(subscribers)
                                }
                            }
                            
                            items.append(VoiceChatPeerActionSheetItem(context: context, peer: peer.peer, title: EnginePeer(peer.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), subtitle: subtitle ?? "", action: {
                                dismissAction()
                                completion(peer.peer.id)
                            }))
                        }
                        
                        controller.setItemGroups([
                            ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                        ])
                        strongSelf.present(controller, in: .window(.root))
                    }
                }
            })
        }, activeCall: activeCall)
    }
}
