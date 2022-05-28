import Foundation
import UIKit
import TelegramCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences
import AccountContext
import ShareController
import UndoUI

final class OverlayAudioPlayerControllerImpl: ViewController, OverlayAudioPlayerController {
    private let context: AccountContext
    let peerId: PeerId
    let type: MediaManagerPlayerType
    let initialMessageId: MessageId
    let initialOrder: MusicPlaybackSettingsOrder
    let playlistLocation: SharedMediaPlaylistLocation?
    
    private weak var parentNavigationController: NavigationController?
    
    private var animatedIn = false
    
    private var controllerNode: OverlayAudioPlayerControllerNode {
        return self.displayNode as! OverlayAudioPlayerControllerNode
    }
    
    private var accountInUseDisposable: Disposable?
    
    init(context: AccountContext, peerId: PeerId, type: MediaManagerPlayerType, initialMessageId: MessageId, initialOrder: MusicPlaybackSettingsOrder, playlistLocation: SharedMediaPlaylistLocation? = nil, parentNavigationController: NavigationController?) {
        self.context = context
        self.peerId = peerId
        self.type = type
        self.initialMessageId = initialMessageId
        self.initialOrder = initialOrder
        self.playlistLocation = playlistLocation
        self.parentNavigationController = parentNavigationController
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.ready.set(.never())
        
        self.accountInUseDisposable = context.sharedContext.setAccountUserInterfaceInUse(context.account.id)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.accountInUseDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = OverlayAudioPlayerControllerNode(context: self.context, peerId: self.peerId, type: self.type, initialMessageId: self.initialMessageId, initialOrder: self.initialOrder, playlistLocation: self.playlistLocation, requestDismiss: { [weak self] in
            self?.dismiss()
        }, requestShare: { [weak self] messageId in
            if let strongSelf = self {
                let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
                |> deliverOnMainQueue).start(next: { message in
                    if let strongSelf = self, let message = message {
                        let shareController = ShareController(context: strongSelf.context, subject: .messages([message._asMessage()]), showInChat: { message in
                            if let strongSelf = self {
                                strongSelf.context.sharedContext.navigateToChat(accountId: strongSelf.context.account.id, peerId: message.id.peerId, messageId: message.id)
                                strongSelf.dismiss()
                            }
                        }, externalShare: true)
                        shareController.completed = { [weak self] peerIds in
                            if let strongSelf = self {
                                let _ = (strongSelf.context.engine.data.get(
                                    EngineDataList(
                                        peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                                    )
                                )
                                |> deliverOnMainQueue).start(next: { [weak self] peerList in
                                    if let strongSelf = self {
                                        let peers = peerList.compactMap { $0 }
                                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                        
                                        let text: String
                                        var savedMessages = false
                                        if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                                            text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                                            savedMessages = true
                                        } else {
                                            if peers.count == 1, let peer = peers.first {
                                                let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                                let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                                            } else if let peer = peers.first {
                                                let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                                text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                                            } else {
                                                text = ""
                                            }
                                        }
                                        
                                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                                    }
                                })
                            }
                        }
                        strongSelf.controllerNode.view.endEditing(true)
                        strongSelf.present(shareController, in: .window(.root))
                    }
                })
            }
        }, requestSearchByArtist: { [weak self] artist in
            if let strongSelf = self {
                strongSelf.context.sharedContext.openSearch(filter: .music, query: artist)
                strongSelf.dismiss()
            }
        })
        
        self.ready.set(self.controllerNode.ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
