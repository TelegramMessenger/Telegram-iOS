import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore

public class PeerMediaCollectionController: ViewController {
    private var containerLayout = ContainerViewLayout()
    
    private let account: Account
    private let peerId: PeerId
    private let messageId: MessageId?
    
    private let peerDisposable = MetaDisposable()
    private let navigationActionDisposable = MetaDisposable()
    
    private let messageIndexDisposable = MetaDisposable()
    
    private let _peerReady = Promise<Bool>()
    private var didSetPeerReady = false
    private let peer = Promise<Peer?>(nil)
    
    private var interfaceState = PeerMediaCollectionInterfaceState()
    
    private var rightNavigationButton: PeerMediaCollectionNavigationButton?
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private var titleView: PeerMediaCollectionTitleView?
    private var controllerInteraction: ChatControllerInteraction?
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    public init(account: Account, peerId: PeerId, messageId: MessageId? = nil) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        
        super.init()
        
        self.titleView = PeerMediaCollectionTitleView(toggle: { [weak self] in
            self?.updateInterfaceState { $0.withToggledSelectingMode() }
        })
        
        self.navigationItem.titleView = self.titleView
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                //strongSelf.chatDisplayNode.historyNode.scrollToStartOfHistory()
            }
        }
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] id in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                var galleryMedia: Media?
                if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                    for media in message.media {
                        if let file = media as? TelegramMediaFile {
                            galleryMedia = file
                        } else if let image = media as? TelegramMediaImage {
                            galleryMedia = image
                        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                            if let file = content.file {
                                galleryMedia = file
                            } else if let image = content.image {
                                galleryMedia = image
                            }
                        }
                    }
                }
                
                if let galleryMedia = galleryMedia {
                    if let file = galleryMedia as? TelegramMediaFile, file.mimeType == "audio/mpeg" {
                        
                    } else {
                        let gallery = GalleryController(account: strongSelf.account, messageId: id)
                        
                        strongSelf.galleryHiddenMesageAndMediaDisposable.set(gallery.hiddenMedia.start(next: { [weak strongSelf] messageIdAndMedia in
                            if let strongSelf = strongSelf {
                                if let messageIdAndMedia = messageIdAndMedia {
                                    strongSelf.controllerInteraction?.hiddenMedia = [messageIdAndMedia.0: [messageIdAndMedia.1]]
                                } else {
                                    strongSelf.controllerInteraction?.hiddenMedia = [:]
                                }
                                strongSelf.mediaCollectionDisplayNode.historyNode.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? ChatMessageItemView {
                                        itemNode.updateHiddenMedia()
                                    } else if let itemNode = itemNode as? ListMessageNode {
                                        itemNode.updateHiddenMedia()
                                    } else if let itemNode = itemNode as? GridMessageItemNode {
                                        itemNode.updateHiddenMedia()
                                    }
                                }
                            }
                        }))
                        
                        strongSelf.present(gallery, in: .window, with: GalleryControllerPresentationArguments(transitionArguments: { [weak self] messageId, media in
                            if let strongSelf = self {
                                var transitionNode: ASDisplayNode?
                                strongSelf.mediaCollectionDisplayNode.historyNode.forEachItemNode { itemNode in
                                    if let itemNode = itemNode as? ChatMessageItemView {
                                        if let result = itemNode.transitionNode(id: messageId, media: media) {
                                            transitionNode = result
                                        }
                                    } else if let itemNode = itemNode as? ListMessageNode {
                                        if let result = itemNode.transitionNode(id: messageId, media: media) {
                                            transitionNode = result
                                        }
                                    } else if let itemNode = itemNode as? GridMessageItemNode {
                                        if let result = itemNode.transitionNode(id: messageId, media: media) {
                                            transitionNode = result
                                        }
                                    }
                                }
                                if let transitionNode = transitionNode {
                                    return GalleryTransitionArguments(transitionNode: transitionNode, transitionContainerNode: strongSelf.mediaCollectionDisplayNode, transitionBackgroundNode: strongSelf.mediaCollectionDisplayNode.historyNode as! ASDisplayNode)
                                }
                            }
                            return nil
                        }))
                    }
                }
            }
            }, openSecretMessagePreview: { _ in }, closeSecretMessagePreview: { }, openPeer: { [weak self] id, navigation, _ in
                if let strongSelf = self {
                    if let id = id {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: id, messageId: nil))
                    }
                }
            }, openPeerMention: { _ in
            }, openMessageContextMenu: { [weak self] id, node, frame in
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                        /*if let contextMenuController = contextMenuForChatPresentationIntefaceState(strongSelf.presentationInterfaceState, account: strongSelf.account, message: message, interfaceInteraction: strongSelf.interfaceInteraction) {
                            strongSelf.present(contextMenuController, in: .window, with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak strongSelf, weak node] in
                                if let node = node {
                                    return (node, frame)
                                } else {
                                    return nil
                                }
                            }))
                        }*/
                    }
                }
            }, navigateToMessage: { [weak self] fromId, id in
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    if id.peerId == strongSelf.peerId {
                        var fromIndex: MessageIndex?
                        
                        if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
                            fromIndex = MessageIndex(message)
                        }
                        
                        /*if let fromIndex = fromIndex {
                            if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                                strongSelf.mediaCollectionDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: MessageIndex(message))
                            } else {
                                strongSelf.messageIndexDisposable.set((strongSelf.account.postbox.messageIndexAtId(id) |> deliverOnMainQueue).start(next: { [weak strongSelf] index in
                                    if let strongSelf = strongSelf, let index = index {
                                        strongSelf.mediaCollectionDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: index)
                                    }
                                }))
                            }
                        }*/
                    } else {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: id.peerId, messageId: id))
                    }
                }
            }, clickThroughMessage: { [weak self] in
                self?.view.endEditing(true)
            }, toggleMessageSelection: { [weak self] id in
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                        strongSelf.updateInterfaceState(animated: true, { $0.withToggledSelectedMessage(id) })
                    }
                }
            }, sendMessage: { _ in
            },sendSticker: { _ in
            }, requestMessageActionCallback: { _ in
            }, openUrl: { _ in
            }, shareCurrentLocation: {
            }, shareAccountContact: {
            }, sendBotCommand: { _, _ in
            }, openInstantPage: { _ in
            }, openHashtag: {_ in
            }, updateInputState: { _ in
            })
        
        self.controllerInteraction = controllerInteraction
        
        self.interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _ in
        }, setupEditMessage: { _ in
        }, beginMessageSelection: { _ in
        }, deleteSelectedMessages: {
        }, forwardSelectedMessages: {
        }, updateTextInputState: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, editMessage: { _, _ in
        }, beginMessageSearch: {
        }, navigateToMessage: { _ in 
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _ in
        }, sendBotCommand: { _ in
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _ in
        }, beginAudioRecording: {
        }, finishAudioRecording: { _ in 
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _ in
        }, unblockPeer: {
        }, pinMessage: { _ in
        }, unpinMessage: {
        }, reportPeer: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, statuses: nil)
        
        self.updateInterfaceState(animated: false, { return $0 })
        
        self.peer.set(account.postbox.peerView(id: peerId) |> map { $0.peers[$0.peerId] })
        
        peerDisposable.set((self.peer.get()
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let strongSelf = self {
                    strongSelf.updateInterfaceState(animated: false, { return $0.withUpdatedPeer(peer) })
                    if !strongSelf.didSetPeerReady {
                        strongSelf.didSetPeerReady = true
                        strongSelf._peerReady.set(.single(true))
                    }
                }
            }))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.messageIndexDisposable.dispose()
        self.navigationActionDisposable.dispose()
        self.galleryHiddenMesageAndMediaDisposable.dispose()
    }
    
    var mediaCollectionDisplayNode: PeerMediaCollectionControllerNode {
        get {
            return super.displayNode as! PeerMediaCollectionControllerNode
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerMediaCollectionControllerNode(account: self.account, peerId: self.peerId, messageId: self.messageId, controllerInteraction: self.controllerInteraction!)
        
        self.ready.set(combineLatest(self.mediaCollectionDisplayNode.historyNode.historyState.get(), self._peerReady.get()) |> map { $1 })
        
        self.mediaCollectionDisplayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        
        self.mediaCollectionDisplayNode.requestUpdateMediaCollectionInterfaceState = { [weak self] animated, f in
            self?.updateInterfaceState(animated: animated, f)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.mediaCollectionDisplayNode.historyNode.preloadPages = true
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.containerLayout = layout
        
        self.mediaCollectionDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition,  listViewTransaction: { updateSizeAndInsets in
            self.mediaCollectionDisplayNode.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        })
    }
    
    func updateInterfaceState(animated: Bool = true, _ f: (PeerMediaCollectionInterfaceState) -> PeerMediaCollectionInterfaceState) {
        let updatedInterfaceState = f(self.interfaceState)
        
        if self.isNodeLoaded {
            self.mediaCollectionDisplayNode.updateMediaCollectionInterfaceState(updatedInterfaceState, animated: animated)
            self.titleView?.updateMediaCollectionInterfaceState(updatedInterfaceState, animated: animated)
        }
        self.interfaceState = updatedInterfaceState
        
        if let button = rightNavigationButtonForPeerMediaCollectionInterfaceState(updatedInterfaceState, currentButton: self.rightNavigationButton, target: self, selector: #selector(self.rightNavigationButtonAction)) {
            self.navigationItem.setRightBarButton(button.buttonItem, animated: true)
            self.rightNavigationButton = button
        } else if let _ = self.rightNavigationButton {
            self.navigationItem.setRightBarButton(nil, animated: true)
            self.rightNavigationButton = nil
        }
        
        if let controllerInteraction = self.controllerInteraction {
            if updatedInterfaceState.selectionState != controllerInteraction.selectionState {
                let animated = animated || controllerInteraction.selectionState == nil || updatedInterfaceState.selectionState == nil
                controllerInteraction.selectionState = updatedInterfaceState.selectionState
                self.mediaCollectionDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView {
                        itemNode.updateSelectionState(animated: animated)
                    } else if let itemNode = itemNode as? GridMessageItemNode {
                        itemNode.updateSelectionState(animated: animated)
                    }
                }
            }
        }
    }
    
    @objc func rightNavigationButtonAction() {
        if let button = self.rightNavigationButton {
            self.navigationButtonAction(button.action)
        }
    }
    
    private func navigationButtonAction(_ action: PeerMediaCollectionNavigationButtonAction) {
        switch action {
            case .cancelMessageSelection:
                self.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
            case .beginMessageSelection:
                self.updateInterfaceState(animated: true, { $0.withSelectionState() })
        }
    }
}
