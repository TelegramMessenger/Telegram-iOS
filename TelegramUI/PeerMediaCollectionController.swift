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
    
    private var interfaceState: PeerMediaCollectionInterfaceState
    
    private var rightNavigationButton: PeerMediaCollectionNavigationButton?
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    
    private var titleView: PeerMediaCollectionTitleView?
    private var controllerInteraction: ChatControllerInteraction?
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let messageContextDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    public init(account: Account, peerId: PeerId, messageId: MessageId? = nil) {
        self.account = account
        self.peerId = peerId
        self.messageId = messageId
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.interfaceState = PeerMediaCollectionInterfaceState(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        super.init(navigationBarTheme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme))
        
        self.titleView = PeerMediaCollectionTitleView(mediaCollectionInterfaceState: self.interfaceState, toggle: { [weak self] in
            self?.updateInterfaceState { $0.withToggledSelectingMode() }
        })
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.navigationItem.titleView = self.titleView
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.mediaCollectionDisplayNode.historyNode.scrollToEndOfHistory()
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
                        let gallery = GalleryController(account: strongSelf.account, messageId: id, replaceRootController: { controller, ready in
                            if let strongSelf = self {
                                (strongSelf.navigationController as? NavigationController)?.replaceTopController(controller, animated: false, ready: ready)
                            }
                        })
                        
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
                    strongSelf.updateInterfaceState(animated: true, { $0.withToggledSelectedMessage(id) })
                }
            }, sendMessage: { _ in
            },sendSticker: { _ in
            }, sendGif: { _ in
            }, requestMessageActionCallback: { _ in
            }, openUrl: { _ in
            }, shareCurrentLocation: {
            }, shareAccountContact: {
            }, sendBotCommand: { _, _ in
            }, openInstantPage: { _ in
            }, openHashtag: {_ in
            }, updateInputState: { _ in
            }, openMessageShareMenu: { _ in
            }, presentController: { _ in
            }, callPeer: { _ in
            }, longTap: { _ in
            })
        
        self.controllerInteraction = controllerInteraction
        
        self.interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _ in
        }, setupEditMessage: { _ in
        }, beginMessageSelection: { _ in
        }, deleteSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let messageIds = strongSelf.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                    strongSelf.messageContextDisposable.set((combineLatest(chatDeleteMessagesOptions(account: strongSelf.account, messageIds: messageIds), strongSelf.peer.get() |> take(1)) |> deliverOnMainQueue).start(next: { options, peer in
                        if let strongSelf = self, let peer = peer, !options.isEmpty {
                            let actionSheet = ActionSheetController()
                            var items: [ActionSheetItem] = []
                            var personalPeerName: String?
                            var isChannel = false
                            if let user = peer as? TelegramUser {
                                personalPeerName = user.compactDisplayTitle
                            } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                                isChannel = true
                            }
                            
                            if options.contains(.globally) {
                                let globalTitle: String
                                if isChannel {
                                    globalTitle = "Delete"
                                } else if let personalPeerName = personalPeerName {
                                    globalTitle = "Delete for me and \(personalPeerName)"
                                } else {
                                    globalTitle = "Delete for everyone"
                                }
                                items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self {
                                        strongSelf.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
                                        let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: .forEveryone).start()
                                    }
                                }))
                            }
                            if options.contains(.locally) {
                                items.append(ActionSheetButtonItem(title: "Delete for me", color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self {
                                        strongSelf.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
                                        let _ = deleteMessagesInteractively(postbox: strongSelf.account.postbox, messageIds: Array(messageIds), type: .forLocalPeer).start()
                                    }
                                }))
                            }
                            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                                ])])
                            strongSelf.present(actionSheet, in: .window)
                        }
                    }))
                }
            }
        }, forwardSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let forwardMessageIdsSet = strongSelf.interfaceState.selectionState?.selectedIds {
                    let forwardMessageIds = Array(forwardMessageIdsSet).sorted()
                    
                    let controller = PeerSelectionController(account: strongSelf.account)
                    controller.peerSelected = { [weak controller] peerId in
                        if let strongSelf = self, let _ = controller {
                            let _ = (strongSelf.account.postbox.modify({ modifier -> Void in
                                modifier.updatePeerChatInterfaceState(peerId, update: { currentState in
                                    if let currentState = currentState as? ChatInterfaceState {
                                        return currentState.withUpdatedForwardMessageIds(forwardMessageIds)
                                    } else {
                                        return ChatInterfaceState().withUpdatedForwardMessageIds(forwardMessageIds)
                                    }
                                })
                            }) |> deliverOnMainQueue).start(completed: {
                                if let strongSelf = self {
                                    strongSelf.updateInterfaceState(animated: false, { $0.withoutSelectionState() })
                                    
                                    let ready = ValuePromise<Bool>()
                                    
                                    strongSelf.messageContextDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                        if let strongController = controller {
                                            strongController.dismiss()
                                        }
                                    }))
                                    
                                    (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChatController(account: strongSelf.account, peerId: peerId), animated: false, ready: ready)
                                }
                            })
                        }
                    }
                    strongSelf.present(controller, in: .window)
                }
            }
        }, updateTextInputState: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, editMessage: { _, _ in
        }, beginMessageSearch: {
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in 
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
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
        self.messageContextDisposable.dispose()
    }
    
    var mediaCollectionDisplayNode: PeerMediaCollectionControllerNode {
        get {
            return super.displayNode as! PeerMediaCollectionControllerNode
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerMediaCollectionControllerNode(account: self.account, peerId: self.peerId, messageId: self.messageId, controllerInteraction: self.controllerInteraction!, interfaceInteraction: self.interfaceInteraction!)
        
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
