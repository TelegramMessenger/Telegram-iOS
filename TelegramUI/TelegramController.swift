import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import Postbox

enum MediaAccessoryPanelVisibility {
    case none
    case specific(size: ContainerViewLayoutSizeClass)
    case always
}

enum LocationBroadcastPanelSource {
    case none
    case summary
    case peer(PeerId)
}

private func presentLiveLocationController(account: Account, peerId: PeerId, controller: ViewController) {
    if let id = account.telegramApplicationContext.liveLocationManager?.internalMessageForPeerId(peerId) {
        let _ = (account.postbox.transaction { transaction -> Message? in
            return transaction.getMessage(id)
        } |> deliverOnMainQueue).start(next: { [weak controller] message in
            if let message = message, let strongController = controller {
                let _ = openChatMessage(account: account, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: strongController.navigationController as? NavigationController, modal: true, dismissInput: {
                    controller?.view.endEditing(true)
                }, present: { c, a in
                    controller?.present(c, in: .window(.root), with: a)
                }, transitionNode: { _, _ in
                    return nil
                }, addToTransitionSurface: { _ in
                }, openUrl: { _ in
                }, openPeer: { peer, navigation in
                }, callPeer: { _ in
                }, enqueueMessage: { _ in 
                }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in})
            }
        })
    }
}

public class TelegramController: ViewController {
    private let account: Account
    
    let mediaAccessoryPanelVisibility: MediaAccessoryPanelVisibility
    let locationBroadcastPanelSource: LocationBroadcastPanelSource
    
    private var mediaStatusDisposable: Disposable?
    private var locationBroadcastDisposable: Disposable?
    
    private(set) var playlistStateAndType: (SharedMediaPlaylistItem, MusicPlaybackSettingsOrder, MediaManagerPlayerType)?
    
    var tempVoicePlaylistEnded: (() -> Void)?
    var tempVoicePlaylistItemChanged: ((SharedMediaPlaylistItem?, SharedMediaPlaylistItem?) -> Void)?
    
    private var mediaAccessoryPanel: (MediaNavigationAccessoryPanel, MediaManagerPlayerType)?
    
    private var locationBroadcastMode: LocationBroadcastNavigationAccessoryPanelMode?
    private var locationBroadcastPeers: [Peer]?
    private var locationBroadcastMessages: [MessageId: Message]?
    private var locationBroadcastAccessoryPanel: LocationBroadcastNavigationAccessoryPanel?
    
    private var dismissingPanel: ASDisplayNode?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    override public var navigationHeight: CGFloat {
        var height = super.navigationHeight
        if let _ = self.mediaAccessoryPanel {
            height += 36.0
        }
        if let _ = self.locationBroadcastAccessoryPanel {
            height += 36.0
        }
        return height
    }
    
    public var primaryNavigationHeight: CGFloat {
        return super.navigationHeight
    }
    
    init(account: Account, navigationBarPresentationData: NavigationBarPresentationData?, mediaAccessoryPanelVisibility: MediaAccessoryPanelVisibility, locationBroadcastPanelSource: LocationBroadcastPanelSource) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.mediaAccessoryPanelVisibility = mediaAccessoryPanelVisibility
        self.locationBroadcastPanelSource = locationBroadcastPanelSource
        
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        if case .none = mediaAccessoryPanelVisibility {} else if let mediaManager = account.telegramApplicationContext.mediaManager {
            self.mediaStatusDisposable = (mediaManager.globalMediaPlayerState
                |> deliverOnMainQueue).start(next: { [weak self] playlistStateAndType in
                if let strongSelf = self {
                    if !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.0, playlistStateAndType?.0.item) ||
                        strongSelf.playlistStateAndType?.1 != playlistStateAndType?.0.order || strongSelf.playlistStateAndType?.2 != playlistStateAndType?.1 {
                        var previousVoiceItem: SharedMediaPlaylistItem?
                        if let playlistStateAndType = strongSelf.playlistStateAndType, playlistStateAndType.2 == .voice {
                            previousVoiceItem = playlistStateAndType.0
                        }
                        
                        var updatedVoiceItem: SharedMediaPlaylistItem?
                        if let playlistStateAndType = playlistStateAndType, playlistStateAndType.1 == .voice {
                            updatedVoiceItem = playlistStateAndType.0.item
                        }
                        
                        strongSelf.tempVoicePlaylistItemChanged?(previousVoiceItem, updatedVoiceItem)
                        if let playlistStateAndType = playlistStateAndType {
                            strongSelf.playlistStateAndType = (playlistStateAndType.0.item, playlistStateAndType.0.order, playlistStateAndType.1)
                        } else {
                            var voiceEnded = false
                            if strongSelf.playlistStateAndType?.2 == .voice {
                                voiceEnded = true
                            }
                            strongSelf.playlistStateAndType = nil
                            if voiceEnded {
                                strongSelf.tempVoicePlaylistEnded?()
                            }
                        }
                        strongSelf.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
        
        if let liveLocationManager = account.telegramApplicationContext.liveLocationManager {
            switch locationBroadcastPanelSource {
                case .none:
                    self.locationBroadcastMode = nil
                case .summary, .peer:
                    let signal: Signal<([Peer]?, [MessageId: Message]?), NoError>
                    switch locationBroadcastPanelSource {
                        case let .peer(peerId):
                            self.locationBroadcastMode = .peer
                            signal = liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId)
                            |> map { ($0, nil) }
                        default:
                            self.locationBroadcastMode = .summary
                            signal = liveLocationManager.summaryManager.broadcastingToMessages()
                                |> map { messages -> ([Peer]?, [MessageId: Message]?) in
                                    if messages.isEmpty {
                                        return (nil, nil)
                                    } else {
                                        var peers: [Peer] = []
                                        for message in messages.values.sorted(by: { MessageIndex($0) < MessageIndex($1) }) {
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
                                    strongSelf.locationBroadcastAccessoryPanel?.update(peers: peers, mode: locationBroadcastMode)
                                }
                            }
                        }
                    })
            }
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
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
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = super.navigationHeight
        
        var additionalHeight: CGFloat = 0.0
        
        if let locationBroadcastPeers = self.locationBroadcastPeers, let locationBroadcastMode = self.locationBroadcastMode {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight.isZero ? -panelHeight : (navigationHeight + additionalHeight + UIScreenPixel)), size: CGSize(width: layout.size.width, height: panelHeight))
            additionalHeight += panelHeight
            
            let locationBroadcastAccessoryPanel: LocationBroadcastNavigationAccessoryPanel
            if let current = self.locationBroadcastAccessoryPanel {
                locationBroadcastAccessoryPanel = current
                transition.updateFrame(node: locationBroadcastAccessoryPanel, frame: panelFrame)
                locationBroadcastAccessoryPanel.updateLayout(size: panelFrame.size, transition: transition)
            } else {
                let presentationData = self.account.telegramApplicationContext.currentPresentationData.with { $0 }
                locationBroadcastAccessoryPanel = LocationBroadcastNavigationAccessoryPanel(accountPeerId: self.account.peerId, theme: presentationData.theme, strings: presentationData.strings, tapAction: { [weak self] in
                    if let strongSelf = self {
                        switch strongSelf.locationBroadcastPanelSource {
                            case .none:
                                break
                            case .summary:
                                if let locationBroadcastMessages = strongSelf.locationBroadcastMessages {
                                    let messages = locationBroadcastMessages.values.sorted(by: { MessageIndex($0) > MessageIndex($1) })
                                    
                                    if messages.count == 1 {
                                        presentLiveLocationController(account: strongSelf.account, peerId: messages[0].id.peerId, controller: strongSelf)
                                    } else {
                                        let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                                        let controller = ActionSheetController(presentationTheme: presentationData.theme)
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
                                                        items.append(LocationBroadcastActionSheetItem(account: strongSelf.account, peer: peer, title: peer.displayTitle, beginTimestamp: beginTimeAndTimeout.0, timeout: beginTimeAndTimeout.1, strings: presentationData.strings, action: {
                                                            dismissAction()
                                                            if let strongSelf = self {
                                                                presentLiveLocationController(account: strongSelf.account, peerId: peer.id, controller: strongSelf)
                                                            }
                                                        }))
                                                    }
                                                }
                                            }
                                            items.append(ActionSheetButtonItem(title: presentationData.strings.LiveLocation_MenuStopAll, color: .destructive, action: {
                                                dismissAction()
                                                if let locationBroadcastPeers = strongSelf.locationBroadcastPeers {
                                                    for peer in locationBroadcastPeers {
                                                        self?.account.telegramApplicationContext.liveLocationManager?.cancelLiveLocation(peerId: peer.id)
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
                                presentLiveLocationController(account: strongSelf.account, peerId: peerId, controller: strongSelf)
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
                        let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                        let controller = ActionSheetController(presentationTheme: presentationData.theme)
                        let dismissAction: () -> Void = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        var items: [ActionSheetItem] = []
                        if let closePeers = closePeers, !closePeers.isEmpty {
                            items.append(ActionSheetTextItem(title: presentationData.strings.LiveLocation_MenuChatsCount(Int32(closePeers.count))))
                            for peer in closePeers {
                                items.append(ActionSheetButtonItem(title: peer.displayTitle, action: {
                                    dismissAction()
                                    if let strongSelf = self {
                                        presentLiveLocationController(account: strongSelf.account, peerId: peer.id, controller: strongSelf)
                                    }
                                }))
                            }
                            items.append(ActionSheetButtonItem(title: presentationData.strings.LiveLocation_MenuStopAll, color: .destructive, action: {
                                dismissAction()
                                for peer in closePeers {
                                    self?.account.telegramApplicationContext.liveLocationManager?.cancelLiveLocation(peerId: peer.id)
                                }
                            }))
                        } else if let closePeerId = closePeerId {
                            items.append(ActionSheetButtonItem(title: presentationData.strings.Map_StopLiveLocation, color: .destructive, action: {
                                dismissAction()
                                self?.account.telegramApplicationContext.liveLocationManager?.cancelLiveLocation(peerId: closePeerId)
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
                locationBroadcastAccessoryPanel.update(peers: locationBroadcastPeers, mode: locationBroadcastMode)
                locationBroadcastAccessoryPanel.updateLayout(size: panelFrame.size, transition: .immediate)
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
        
        if let (item, _, type) = self.playlistStateAndType, !mediaAccessoryPanelHidden {
            let panelHeight = MediaNavigationAccessoryHeaderNode.minimizedHeight
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight.isZero ? -panelHeight : (navigationHeight + additionalHeight + UIScreenPixel)), size: CGSize(width: layout.size.width, height: panelHeight))
            if let (mediaAccessoryPanel, mediaType) = self.mediaAccessoryPanel, mediaType == type {
                transition.updateFrame(layer: mediaAccessoryPanel.layer, frame: panelFrame)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: transition)
                mediaAccessoryPanel.containerNode.headerNode.playbackItem = item
               
                if let mediaManager = self.account.telegramApplicationContext.mediaManager {
                    mediaAccessoryPanel.containerNode.headerNode.playbackStatus = mediaManager.globalMediaPlayerState
                    |> map { state in
                        return state?.0.status ?? MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused)
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
                
                let mediaAccessoryPanel = MediaNavigationAccessoryPanel(account: self.account)
                mediaAccessoryPanel.containerNode.headerNode.displayScrubber = type != .voice
                mediaAccessoryPanel.close = { [weak self] in
                    if let strongSelf = self, let (_, _, type) = strongSelf.playlistStateAndType {
                        strongSelf.account.telegramApplicationContext.mediaManager?.setPlaylist(nil, type: type)
                    }
                }
                mediaAccessoryPanel.toggleRate = {
                    [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.account.postbox.transaction { transaction -> AudioPlaybackRate in
                        let settings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.musicPlaybackSettings) as? MusicPlaybackSettings ?? MusicPlaybackSettings.defaultSettings
                        
                        let nextRate: AudioPlaybackRate
                        switch settings.voicePlaybackRate {
                            case .x1:
                                nextRate = .x2
                            case .x2:
                                nextRate = .x1
                        }
                        transaction.setPreferencesEntry(key: ApplicationSpecificPreferencesKeys.musicPlaybackSettings, value: settings.withUpdatedVoicePlaybackRate(nextRate))
                        return nextRate
                    }
                    |> deliverOnMainQueue).start(next: { baseRate in
                        guard let strongSelf = self, let (_, _, type) = strongSelf.playlistStateAndType else {
                            return
                        }
                        
                        strongSelf.account.telegramApplicationContext.mediaManager?.playlistControl(.setBaseRate(baseRate), type: type)
                    })
                }
                mediaAccessoryPanel.togglePlayPause = { [weak self] in
                    if let strongSelf = self, let (_, _, type) = strongSelf.playlistStateAndType {
                        strongSelf.account.telegramApplicationContext.mediaManager?.playlistControl(.playback(.togglePlayPause), type: type)
                    }
                }
                mediaAccessoryPanel.tapAction = { [weak self] in
                    if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController, let (state, order, type) = strongSelf.playlistStateAndType {
                        if let id = state.id as? PeerMessagesMediaPlaylistItemId {
                            if type == .music {
                                let controller = OverlayPlayerController(account: strongSelf.account, peerId: id.messageId.peerId, type: type, initialMessageId: id.messageId, initialOrder: order, parentNavigationController: strongSelf.navigationController as? NavigationController) 
                                strongSelf.displayNode.view.window?.endEditing(true)
                                strongSelf.present(controller, in: .window(.root))
                            } else {
                                navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(id.messageId.peerId), messageId: id.messageId)
                            }
                        }
                    }
                }
                mediaAccessoryPanel.frame = panelFrame
                if let dismissingPanel = self.dismissingPanel {
                    self.displayNode.insertSubnode(mediaAccessoryPanel, aboveSubnode: dismissingPanel)
                } else if let navigationBar = self.navigationBar {
                    self.displayNode.insertSubnode(mediaAccessoryPanel, aboveSubnode: navigationBar)
                } else {
                    self.displayNode.addSubnode(mediaAccessoryPanel)
                }
                self.mediaAccessoryPanel = (mediaAccessoryPanel, type)
                mediaAccessoryPanel.updateLayout(size: panelFrame.size, transition: .immediate)
                mediaAccessoryPanel.containerNode.headerNode.playbackItem = item
                if let mediaManager = self.account.telegramApplicationContext.mediaManager {
                    mediaAccessoryPanel.containerNode.headerNode.playbackStatus = mediaManager.globalMediaPlayerState
                    |> map { state in
                        return state?.0.status ?? MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused)
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
}
