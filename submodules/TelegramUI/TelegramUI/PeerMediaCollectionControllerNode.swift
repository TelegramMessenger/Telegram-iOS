import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import SearchBarNode
import SearchUI
import ChatListSearchItemNode

struct PeerMediaCollectionMessageForGallery {
    let message: Message
    let fromSearchResults: Bool
}

private func historyNodeImplForMode(_ mode: PeerMediaCollectionMode, context: AccountContext, theme: PresentationTheme, peerId: PeerId, messageId: MessageId?, controllerInteraction: ChatControllerInteraction, selectedMessages: Signal<Set<MessageId>?, NoError>) -> ChatHistoryNode & ASDisplayNode {
    switch mode {
        case .photoOrVideo:
            let node = ChatHistoryGridNode(context: context, peerId: peerId, messageId: messageId, tagMask: .photoOrVideo, controllerInteraction: controllerInteraction)
            node.showVerticalScrollIndicator = true
            if theme.list.plainBackgroundColor.argb == 0xffffffff {
                node.indicatorStyle = .default
            } else {
                node.indicatorStyle = .white
            }
            return node
        case .file:
            let node = ChatHistoryListNode(context: context, chatLocation: .peer(peerId), tagMask: .file, subject: messageId.flatMap { .message($0) }, controllerInteraction: controllerInteraction, selectedMessages: selectedMessages, updatingMedia: .single([:]), mode: .list(search: true, reversed: false))
            node.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
            node.didEndScrolling = { [weak node] in
                guard let node = node else {
                    return
                }
                fixSearchableListNodeScrolling(node)
            }
            node.preloadPages = true
            return node
        case .music:
            let node = ChatHistoryListNode(context: context, chatLocation: .peer(peerId), tagMask: .music, subject: messageId.flatMap { .message($0) }, controllerInteraction: controllerInteraction, selectedMessages: selectedMessages, updatingMedia: .single([:]), mode: .list(search: true, reversed: false))
            node.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
            node.didEndScrolling = { [weak node] in
                guard let node = node else {
                    return
                }
                fixSearchableListNodeScrolling(node)
            }
            node.preloadPages = true
            return node
        case .webpage:
            let node = ChatHistoryListNode(context: context, chatLocation: .peer(peerId), tagMask: .webPage, subject: messageId.flatMap { .message($0) }, controllerInteraction: controllerInteraction, selectedMessages: selectedMessages, updatingMedia: .single([:]), mode: .list(search: true, reversed: false))
            node.verticalScrollIndicatorColor = theme.list.scrollIndicatorColor
            node.didEndScrolling = { [weak node] in
                guard let node = node else {
                    return
                }
                fixSearchableListNodeScrolling(node)
            }
            node.preloadPages = true
            return node
    }
}

private func updateLoadNodeState(_ node: PeerMediaCollectionEmptyNode, _ loadState: ChatHistoryNodeLoadState?) {
    if let loadState = loadState {
        switch loadState {
            case .messages:
                node.isHidden = true
                node.isLoading = false
            case .empty:
                node.isHidden = false
                node.isLoading = false
            case .loading:
                node.isHidden = false
                node.isLoading = true
        }
    } else {
        node.isHidden = false
        node.isLoading = true
    }
}

private func tagMaskForMode(_ mode: PeerMediaCollectionMode) -> MessageTags {
    switch mode {
        case .photoOrVideo:
            return .photoOrVideo
        case .file:
            return .file
        case .music:
            return .music
        case .webpage:
            return .webPage
    }
}

class PeerMediaCollectionControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    private let controllerInteraction: ChatControllerInteraction
    private let interfaceInteraction: ChatPanelInterfaceInteraction
    private let navigationBar: NavigationBar?
    
    private let sectionsNode: PeerMediaCollectionSectionsNode
    
    private(set) var historyNode: ChatHistoryNode & ASDisplayNode
    private var historyEmptyNode: PeerMediaCollectionEmptyNode
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private let candidateHistoryNodeReadyDisposable = MetaDisposable()
    private var candidateHistoryNode: (ASDisplayNode, PeerMediaCollectionMode)?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    var requestUpdateMediaCollectionInterfaceState: (Bool, (PeerMediaCollectionInterfaceState) -> PeerMediaCollectionInterfaceState) -> Void = { _, _ in }
    let requestDeactivateSearch: () -> Void
    
    private var mediaCollectionInterfaceState: PeerMediaCollectionInterfaceState
    
    private let selectedMessagesPromise = Promise<Set<MessageId>?>(nil)
    var selectedMessages: Set<MessageId>? {
        didSet {
            if self.selectedMessages != oldValue {
                self.selectedMessagesPromise.set(.single(self.selectedMessages))
            }
        }
    }
    private var selectionPanel: ChatMessageSelectionInputPanelNode?
    private var selectionPanelSeparatorNode: ASDisplayNode?
    private var selectionPanelBackgroundNode: ASDisplayNode?
    
    private var chatPresentationInterfaceState: ChatPresentationInterfaceState
    
    private var presentationData: PresentationData
    
    init(context: AccountContext, peerId: PeerId, messageId: MessageId?, controllerInteraction: ChatControllerInteraction, interfaceInteraction: ChatPanelInterfaceInteraction, navigationBar: NavigationBar?, requestDeactivateSearch: @escaping () -> Void) {
        self.context = context
        self.peerId = peerId
        self.controllerInteraction = controllerInteraction
        self.interfaceInteraction = interfaceInteraction
        self.navigationBar = navigationBar
        
        self.requestDeactivateSearch = requestDeactivateSearch
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.mediaCollectionInterfaceState = PeerMediaCollectionInterfaceState(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        self.sectionsNode = PeerMediaCollectionSectionsNode(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        self.historyNode = historyNodeImplForMode(self.mediaCollectionInterfaceState.mode, context: context, theme: self.presentationData.theme, peerId: peerId, messageId: messageId, controllerInteraction: controllerInteraction, selectedMessages: self.selectedMessagesPromise.get())
        self.historyEmptyNode = PeerMediaCollectionEmptyNode(mode: self.mediaCollectionInterfaceState.mode, theme: self.presentationData.theme, strings: self.presentationData.strings)
        self.historyEmptyNode.isHidden = true
        
        self.chatPresentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: .defaultValue, fontSize: self.presentationData.fontSize, accountPeerId: context.account.peerId, mode: .standard(previewing: false), chatLocation: .peer(self.peerId), isScheduledMessages: false)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.historyNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.historyNode)
        self.addSubnode(self.historyEmptyNode)
        if let navigationBar = navigationBar {
            self.addSubnode(navigationBar)
        }
        if let navigationBar = self.navigationBar {
            self.insertSubnode(self.sectionsNode, aboveSubnode: navigationBar)
        } else {
            self.addSubnode(self.sectionsNode)
        }
        
        self.sectionsNode.indexUpdated = { [weak self] index in
            if let strongSelf = self {
                let mode: PeerMediaCollectionMode
                switch index {
                    case 0:
                        mode = .photoOrVideo
                    case 1:
                        mode = .file
                    case 2:
                        mode = .webpage
                    case 3:
                        mode = .music
                    default:
                        mode = .photoOrVideo
                }
                strongSelf.requestUpdateMediaCollectionInterfaceState(true, { $0.withMode(mode) })
            }
        }
        
        updateLoadNodeState(self.historyEmptyNode, self.historyNode.loadState)
        self.historyNode.setLoadStateUpdated { [weak self] loadState, _ in
            if let strongSelf = self {
                updateLoadNodeState(strongSelf.historyEmptyNode, loadState)
            }
        }
    }
    
    deinit {
        self.candidateHistoryNodeReadyDisposable.dispose()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeightAndPrimaryHeight: (CGFloat, CGFloat), transition: ContainedViewLayoutTransition, listViewTransaction: (ListViewUpdateSizeAndInsets) -> Void) {
        let navigationBarHeight = navigationBarHeightAndPrimaryHeight.0
        let primaryNavigationBarHeight = navigationBarHeightAndPrimaryHeight.1
        let navigationBarHeightDelta = (navigationBarHeight - primaryNavigationBarHeight)
        
        self.containerLayout = (layout, navigationBarHeight)
        
        var vanillaInsets = layout.insets(options: [])
        vanillaInsets.top += navigationBarHeight
        
        var additionalInset: CGFloat = 0.0
        
        if (navigationBarHeight - (layout.statusBarHeight ?? 0.0)).isLessThanOrEqualTo(44.0) {
        } else {
            additionalInset += 10.0
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
            if !searchDisplayController.isDeactivating {
                vanillaInsets.top += (layout.statusBarHeight ?? 0.0) - navigationBarHeightDelta
            }
        }
        
        let sectionsHeight = self.sectionsNode.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, additionalInset: additionalInset, transition: transition, interfaceState: self.mediaCollectionInterfaceState)
        var sectionOffset: CGFloat = 0.0
        if primaryNavigationBarHeight.isZero {
            sectionOffset = -sectionsHeight - navigationBarHeightDelta
        } else {
            //layout.statusBarHeight ?? 0.0
            //if navigationBarHeightAndPrimaryHeight.0 > navigationBarHeightAndPrimaryHeight.1 {
            //    sectionOffset += 1.0
            //}//
        }
        transition.updateFrame(node: self.sectionsNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight + sectionOffset), size: CGSize(width: layout.size.width, height: sectionsHeight)))
        
        var insets = vanillaInsets
        if !primaryNavigationBarHeight.isZero {
            insets.top += sectionsHeight
        }
        
        if let inputHeight = layout.inputHeight {
            insets.bottom += inputHeight
        }
        
        if let selectionState = self.mediaCollectionInterfaceState.selectionState {
            let interfaceState = self.chatPresentationInterfaceState.updatedPeer({ _ in self.mediaCollectionInterfaceState.peer.flatMap(RenderedPeer.init) })
            
            if let selectionPanel = self.selectionPanel {
                selectionPanel.selectedMessages = selectionState.selectedIds
                let panelHeight = selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: 0.0, isSecondary: false, transition: transition, interfaceState: interfaceState, metrics: layout.metrics)
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
                if let selectionPanelSeparatorNode = self.selectionPanelSeparatorNode {
                    transition.updateFrame(node: selectionPanelSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
                }
                if let selectionPanelBackgroundNode = self.selectionPanelBackgroundNode {
                    transition.updateFrame(node: selectionPanelBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: insets.bottom + panelHeight)))
                }
            } else {
                let selectionPanelBackgroundNode = ASDisplayNode()
                selectionPanelBackgroundNode.isLayerBacked = true
                selectionPanelBackgroundNode.backgroundColor = self.mediaCollectionInterfaceState.theme.chat.inputPanel.panelBackgroundColor
                self.addSubnode(selectionPanelBackgroundNode)
                self.selectionPanelBackgroundNode = selectionPanelBackgroundNode
                
                let selectionPanel = ChatMessageSelectionInputPanelNode(theme: self.chatPresentationInterfaceState.theme, strings: self.chatPresentationInterfaceState.strings, peerMedia: true)
                selectionPanel.context = self.context
                selectionPanel.backgroundColor = self.presentationData.theme.chat.inputPanel.panelBackgroundColor
                selectionPanel.interfaceInteraction = self.interfaceInteraction
                selectionPanel.selectedMessages = selectionState.selectedIds
                let panelHeight = selectionPanel.updateLayout(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, maxHeight: 0.0, isSecondary: false, transition: .immediate, interfaceState: interfaceState, metrics: layout.metrics)
                self.selectionPanel = selectionPanel
                self.addSubnode(selectionPanel)
                
                let selectionPanelSeparatorNode = ASDisplayNode()
                selectionPanelSeparatorNode.isLayerBacked = true
                selectionPanelSeparatorNode.backgroundColor = self.mediaCollectionInterfaceState.theme.chat.inputPanel.panelSeparatorColor
                self.addSubnode(selectionPanelSeparatorNode)
                self.selectionPanelSeparatorNode = selectionPanelSeparatorNode
                
                selectionPanel.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: panelHeight))
                selectionPanelBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: 0.0))
                selectionPanelSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height), size: CGSize(width: layout.size.width, height: UIScreenPixel))
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
                transition.updateFrame(node: selectionPanelBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: insets.bottom + panelHeight)))
                transition.updateFrame(node: selectionPanelSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
            }
        } else if let selectionPanel = self.selectionPanel {
            self.selectionPanel = nil
            transition.updateFrame(node: selectionPanel, frame: selectionPanel.frame.offsetBy(dx: 0.0, dy: selectionPanel.bounds.size.height + insets.bottom), completion: { [weak selectionPanel] _ in
                selectionPanel?.removeFromSupernode()
            })
            if let selectionPanelSeparatorNode = self.selectionPanelSeparatorNode {
                transition.updateFrame(node: selectionPanelSeparatorNode, frame: selectionPanelSeparatorNode.frame.offsetBy(dx: 0.0, dy: selectionPanel.bounds.size.height + insets.bottom), completion: { [weak selectionPanelSeparatorNode] _ in
                    selectionPanelSeparatorNode?.removeFromSupernode()
                })
            }
            if let selectionPanelBackgroundNode = self.selectionPanelBackgroundNode {
                transition.updateFrame(node: selectionPanelBackgroundNode, frame: selectionPanelBackgroundNode.frame.offsetBy(dx: 0.0, dy: selectionPanel.bounds.size.height + insets.bottom), completion: { [weak selectionPanelSeparatorNode] _ in
                    selectionPanelSeparatorNode?.removeFromSupernode()
                })
            }
        }
        
        let previousBounds = self.historyNode.bounds
        self.historyNode.bounds = CGRect(x: previousBounds.origin.x, y: previousBounds.origin.y, width: layout.size.width, height: layout.size.height)
        self.historyNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)

        self.historyNode.backgroundColor = self.mediaCollectionInterfaceState.theme.list.plainBackgroundColor
        self.backgroundColor = self.mediaCollectionInterfaceState.theme.list.plainBackgroundColor
        
        self.historyEmptyNode.updateLayout(size: layout.size, insets: vanillaInsets, transition: transition, interfaceState: mediaCollectionInterfaceState)
        transition.updateFrame(node: self.historyEmptyNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var additionalBottomInset: CGFloat = 0.0
        if let selectionPanel = self.selectionPanel {
            additionalBottomInset = selectionPanel.bounds.size.height
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        listViewTransaction(ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: insets.top, left:
            insets.right + layout.safeInsets.right, bottom: insets.bottom + additionalBottomInset, right: insets.left + layout.safeInsets.right), duration: duration, curve: curve))
        
        if let (candidateHistoryNode, _) = self.candidateHistoryNode {
            let previousBounds = candidateHistoryNode.bounds
            candidateHistoryNode.bounds = CGRect(x: previousBounds.origin.x, y: previousBounds.origin.y, width: layout.size.width, height: layout.size.height)
            candidateHistoryNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
            
            (candidateHistoryNode as! ChatHistoryNode).updateLayout(transition: transition, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: insets.top, left:
                insets.right + layout.safeInsets.right, bottom: insets.bottom + additionalBottomInset, right: insets.left + layout.safeInsets.left), duration: duration, curve: curve))
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        var maybePlaceholderNode: SearchBarPlaceholderNode?
        if let listNode = historyNode as? ListView {
            listNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
        }
        
        if let _ = self.searchDisplayController {
            return
        }
        
        if let placeholderNode = maybePlaceholderNode {
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, contentNode: ChatHistorySearchContainerNode(context: self.context, peerId: self.peerId, tagMask: tagMaskForMode(self.mediaCollectionInterfaceState.mode), interfaceInteraction: self.controllerInteraction), cancel: { [weak self] in
                self?.requestDeactivateSearch()
            })
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { [weak self] subnode, isSearchBar in
                if let strongSelf = self {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                }
            }, placeholder: placeholderNode)
        }
        
    }
    
    func deactivateSearch() {
        if let searchDisplayController = self.searchDisplayController {
            self.searchDisplayController = nil
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            if let listNode = self.historyNode as? ListView {
                listNode.forEachItemNode { node in
                    if let node = node as? ChatListSearchItemNode {
                        maybePlaceholderNode = node.searchBarNode
                    }
                }
            }
            
            searchDisplayController.deactivate(placeholder: maybePlaceholderNode)
        }
    }
    
    func updateMediaCollectionInterfaceState(_ mediaCollectionInterfaceState: PeerMediaCollectionInterfaceState, animated: Bool) {
        if self.mediaCollectionInterfaceState != mediaCollectionInterfaceState {
            if self.mediaCollectionInterfaceState.mode != mediaCollectionInterfaceState.mode {
                let previousMode = self.mediaCollectionInterfaceState.mode
                if let containerLayout = self.containerLayout, self.candidateHistoryNode == nil || self.candidateHistoryNode!.1 != mediaCollectionInterfaceState.mode {
                    let node = historyNodeImplForMode(mediaCollectionInterfaceState.mode, context: self.context, theme: self.presentationData.theme, peerId: self.peerId, messageId: nil, controllerInteraction: self.controllerInteraction, selectedMessages: self.selectedMessagesPromise.get())
                    node.backgroundColor = mediaCollectionInterfaceState.theme.list.plainBackgroundColor
                    self.candidateHistoryNode = (node, mediaCollectionInterfaceState.mode)
                    
                    var vanillaInsets = containerLayout.0.insets(options: [])
                    vanillaInsets.top += containerLayout.1
                    
                    if let searchDisplayController = self.searchDisplayController {
                        if !searchDisplayController.isDeactivating {
                            vanillaInsets.top += containerLayout.0.statusBarHeight ?? 0.0
                        }
                    }
                    
                    var insets = vanillaInsets
                    
                    if !containerLayout.1.isZero {
                        insets.top += self.sectionsNode.bounds.size.height
                    }
                    
                    if let inputHeight = containerLayout.0.inputHeight {
                        insets.bottom += inputHeight
                    }
                    
                    let previousBounds = node.bounds
                    node.bounds = CGRect(x: previousBounds.origin.x, y: previousBounds.origin.y, width: containerLayout.0.size.width, height: containerLayout.0.size.height)
                    node.position = CGPoint(x: containerLayout.0.size.width / 2.0, y: containerLayout.0.size.height / 2.0)
                    
                    var additionalBottomInset: CGFloat = 0.0
                    if let selectionPanel = self.selectionPanel {
                        additionalBottomInset = selectionPanel.bounds.size.height
                    }
                    
                    node.updateLayout(transition: .immediate, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: containerLayout.0.size, insets: UIEdgeInsets(top: insets.top, left: insets.right + containerLayout.0.safeInsets.right, bottom: insets.bottom + additionalBottomInset, right: insets.left + containerLayout.0.safeInsets.left), duration: 0.0, curve: .Default(duration: nil)))
                    
                    let historyEmptyNode = PeerMediaCollectionEmptyNode(mode: mediaCollectionInterfaceState.mode, theme: self.mediaCollectionInterfaceState.theme, strings: self.mediaCollectionInterfaceState.strings)
                    historyEmptyNode.isHidden = true
                    historyEmptyNode.updateLayout(size: containerLayout.0.size, insets: vanillaInsets, transition: .immediate, interfaceState: self.mediaCollectionInterfaceState)
                    historyEmptyNode.frame = CGRect(origin: CGPoint(), size: containerLayout.0.size)
                    
                    self.candidateHistoryNodeReadyDisposable.set((node.historyState.get()
                    |> deliverOnMainQueue).start(next: { [weak self, weak node] _ in
                        if let strongSelf = self, let strongNode = node, strongNode == strongSelf.candidateHistoryNode?.0 {
                            strongSelf.candidateHistoryNode = nil
                            strongSelf.insertSubnode(strongNode, belowSubnode: strongSelf.historyNode)
                            strongSelf.insertSubnode(historyEmptyNode, aboveSubnode: strongNode)
                            
                            let previousNode = strongSelf.historyNode
                            let previousEmptyNode = strongSelf.historyEmptyNode
                            strongSelf.historyNode = strongNode
                            strongSelf.historyEmptyNode = historyEmptyNode
                            updateLoadNodeState(strongSelf.historyEmptyNode, strongSelf.historyNode.loadState)
                            strongSelf.historyNode.setLoadStateUpdated { loadState, _ in
                                if let strongSelf = self {
                                    updateLoadNodeState(strongSelf.historyEmptyNode, loadState)
                                }
                            }
                            
                            let directionMultiplier: CGFloat
                            if previousMode.rawValue < mediaCollectionInterfaceState.mode.rawValue {
                                directionMultiplier = 1.0
                            } else {
                                directionMultiplier = -1.0
                            }
                            
                            previousNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -directionMultiplier * strongSelf.bounds.width, y: 0.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak previousNode] _ in
                                previousNode?.removeFromSupernode()
                            })
                            previousEmptyNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -directionMultiplier * strongSelf.bounds.width, y: 0.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak previousEmptyNode] _ in
                                previousEmptyNode?.removeFromSupernode()
                            })
                            strongSelf.historyNode.layer.animatePosition(from: CGPoint(x: directionMultiplier * strongSelf.bounds.width, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            strongSelf.historyEmptyNode.layer.animatePosition(from: CGPoint(x: directionMultiplier * strongSelf.bounds.width, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        }
                    }))
                }
            }
            
            self.mediaCollectionInterfaceState = mediaCollectionInterfaceState
            
            self.requestLayout(animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
        }
    }
    
    func updateHiddenMedia() {
        self.historyNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMessageItemView {
                itemNode.updateHiddenMedia()
            } else if let itemNode = itemNode as? ListMessageNode {
                itemNode.updateHiddenMedia()
            } else if let itemNode = itemNode as? GridMessageItemNode {
                itemNode.updateHiddenMedia()
            }
        }
        
        if let searchContentNode = self.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
            searchContentNode.updateHiddenMedia()
        }
    }
    
    func messageForGallery(_ id: MessageId) -> PeerMediaCollectionMessageForGallery? {
        if let message = self.historyNode.messageInCurrentHistoryView(id) {
            return PeerMediaCollectionMessageForGallery(message: message, fromSearchResults: false)
        }
        
        if let searchContentNode = self.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
            if let message = searchContentNode.messageForGallery(id) {
                return PeerMediaCollectionMessageForGallery(message: message, fromSearchResults: true)
            }
        }
        
        return nil
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let searchContentNode = self.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode {
            if let transitionNode = searchContentNode.transitionNodeForGallery(messageId: messageId, media: media) {
                return transitionNode
            }
        }
        
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.historyNode.forEachItemNode { itemNode in
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
            return transitionNode
        }
        
        return nil
    }
    
    func clearHighlightAnimated(_ animated: Bool) {
        if let listView = self.historyNode as? ListView {
            listView.clearHighlightAnimated(animated)
        }
    }
}
