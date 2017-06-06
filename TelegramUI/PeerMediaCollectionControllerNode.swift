import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private func historyNodeImplForMode(_ mode: PeerMediaCollectionMode, account: Account, peerId: PeerId, messageId: MessageId?, controllerInteraction: ChatControllerInteraction) -> ASDisplayNode {
    switch mode {
        case .photoOrVideo:
            return ChatHistoryGridNode(account: account, peerId: peerId, messageId: messageId, tagMask: .PhotoOrVideo, controllerInteraction: controllerInteraction)
        case .file:
            let node = ChatHistoryListNode(account: account, peerId: peerId, tagMask: .File, messageId: messageId, controllerInteraction: controllerInteraction, mode: .list)
            node.preloadPages = true
            return node
        case .music:
            let node = ChatHistoryListNode(account: account, peerId: peerId, tagMask: .Music, messageId: messageId, controllerInteraction: controllerInteraction, mode: .list)
            node.preloadPages = true
            return node
        case .webpage:
            let node = ChatHistoryListNode(account: account, peerId: peerId, tagMask: .WebPage, messageId: messageId, controllerInteraction: controllerInteraction, mode: .list)
            node.preloadPages = true
            return node
    }
}

class PeerMediaCollectionControllerNode: ASDisplayNode {
    private let account: Account
    private let peerId: PeerId
    private let controllerInteraction: ChatControllerInteraction
    private let interfaceInteraction: ChatPanelInterfaceInteraction
    
    private var historyNodeImpl: ASDisplayNode
    var historyNode: ChatHistoryNode {
        return self.historyNodeImpl as! ChatHistoryNode
    }
    
    private let candidateHistoryNodeReadyDisposable = MetaDisposable()
    private var candidateHistoryNode: (ASDisplayNode, PeerMediaCollectionMode)?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    var requestUpdateMediaCollectionInterfaceState: (Bool, (PeerMediaCollectionInterfaceState) -> PeerMediaCollectionInterfaceState) -> Void = { _ in }
    
    private var mediaCollectionInterfaceState: PeerMediaCollectionInterfaceState
    
    private var modeSelectionNode: PeerMediaCollectionModeSelectionNode?
    private var selectionPanel: ChatMessageSelectionInputPanelNode?
    
    private var chatPresentationInterfaceState: ChatPresentationInterfaceState
    
    private var presentationData: PresentationData
    
    init(account: Account, peerId: PeerId, messageId: MessageId?, controllerInteraction: ChatControllerInteraction, interfaceInteraction: ChatPanelInterfaceInteraction) {
        self.account = account
        self.peerId = peerId
        self.controllerInteraction = controllerInteraction
        self.interfaceInteraction = interfaceInteraction
        
        self.presentationData = (account.applicationContext as! TelegramApplicationContext).currentPresentationData.with { $0 }
        self.mediaCollectionInterfaceState = PeerMediaCollectionInterfaceState(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        self.historyNodeImpl = historyNodeImplForMode(self.mediaCollectionInterfaceState.mode, account: account, peerId: peerId, messageId: messageId, controllerInteraction: controllerInteraction)
        
        self.chatPresentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.historyNodeImpl)
    }
    
    deinit {
        self.candidateHistoryNodeReadyDisposable.dispose()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, listViewTransaction: (ListViewUpdateSizeAndInsets) -> Void) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        if let selectionState = self.mediaCollectionInterfaceState.selectionState {
            let interfaceState = self.chatPresentationInterfaceState.updatedPeer({ _ in self.mediaCollectionInterfaceState.peer })
            
            if let selectionPanel = self.selectionPanel {
                selectionPanel.selectedMessageCount = selectionState.selectedIds.count
                let panelHeight = selectionPanel.updateLayout(width: layout.size.width, transition: transition, interfaceState: interfaceState)
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
            } else {
                let selectionPanel = ChatMessageSelectionInputPanelNode(theme: self.chatPresentationInterfaceState.theme)
                selectionPanel.interfaceInteraction = self.interfaceInteraction
                selectionPanel.selectedMessageCount = selectionState.selectedIds.count
                selectionPanel.backgroundColor = self.presentationData.theme.chat.inputPanel.panelBackgroundColor
                let panelHeight = selectionPanel.updateLayout(width: layout.size.width, transition: .immediate, interfaceState: interfaceState)
                self.selectionPanel = selectionPanel
                self.addSubnode(selectionPanel)
                selectionPanel.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom), size: CGSize(width: layout.size.width, height: panelHeight))
                transition.updateFrame(node: selectionPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight)))
            }
        } else if let selectionPanel = self.selectionPanel {
            self.selectionPanel = nil
            transition.updateFrame(node: selectionPanel, frame: selectionPanel.frame.offsetBy(dx: 0.0, dy: selectionPanel.bounds.size.height), completion: { [weak selectionPanel] _ in
                selectionPanel?.removeFromSupernode()
            })
        }
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let previousBounds = self.historyNodeImpl.bounds
        self.historyNodeImpl.bounds = CGRect(x: previousBounds.origin.x, y: previousBounds.origin.y, width: layout.size.width, height: layout.size.height)
        self.historyNodeImpl.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        var additionalBottomInset: CGFloat = 0.0
        if let selectionPanel = self.selectionPanel {
            additionalBottomInset = selectionPanel.bounds.size.height
        }
        
        listViewTransaction(ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: insets.top, left:
            insets.right, bottom: insets.bottom + additionalBottomInset, right: insets.left), duration: duration, curve: listViewCurve))
        
        if let (candidateHistoryNode, _) = self.candidateHistoryNode {
            let previousBounds = candidateHistoryNode.bounds
            candidateHistoryNode.bounds = CGRect(x: previousBounds.origin.x, y: previousBounds.origin.y, width: layout.size.width, height: layout.size.height)
            candidateHistoryNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
            
            (candidateHistoryNode as! ChatHistoryNode).updateLayout(transition: transition, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: insets.top, left:
                insets.right, bottom: insets.bottom + additionalBottomInset, right: insets.left), duration: duration, curve: listViewCurve))
        }
        
        if self.mediaCollectionInterfaceState.selectingMode {
            if let modeSelectionNode = self.modeSelectionNode {
                modeSelectionNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                modeSelectionNode.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
                modeSelectionNode.mediaCollectionInterfaceState = self.mediaCollectionInterfaceState
            } else {
                let modeSelectionNode = PeerMediaCollectionModeSelectionNode(mediaCollectionInterfaceState: self.mediaCollectionInterfaceState)
                modeSelectionNode.selectedMode = { [weak self] mode in
                    if let requestUpdateMediaCollectionInterfaceState = self?.requestUpdateMediaCollectionInterfaceState {
                        requestUpdateMediaCollectionInterfaceState(true, { $0.withToggledSelectingMode().withMode(mode) })
                    }
                }
                modeSelectionNode.dismiss = { [weak self] in
                    if let requestUpdateMediaCollectionInterfaceState = self?.requestUpdateMediaCollectionInterfaceState {
                        requestUpdateMediaCollectionInterfaceState(true, { $0.withToggledSelectingMode() })
                    }
                }
                modeSelectionNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                modeSelectionNode.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                modeSelectionNode.mediaCollectionInterfaceState = self.mediaCollectionInterfaceState
                self.insertSubnode(modeSelectionNode, aboveSubnode: self.historyNodeImpl)
                modeSelectionNode.animateIn()
                self.modeSelectionNode = modeSelectionNode
            }
        } else if let modeSelectionNode = self.modeSelectionNode {
            self.modeSelectionNode = nil
            modeSelectionNode.animateOut { [weak modeSelectionNode] in
                modeSelectionNode?.removeFromSupernode()
            }
        }
    }
    
    func updateMediaCollectionInterfaceState(_ mediaCollectionInterfaceState: PeerMediaCollectionInterfaceState, animated: Bool) {
        if self.mediaCollectionInterfaceState != mediaCollectionInterfaceState {
            if self.mediaCollectionInterfaceState.mode != mediaCollectionInterfaceState.mode {
                if let containerLayout = self.containerLayout, self.candidateHistoryNode == nil || self.candidateHistoryNode!.1 != mediaCollectionInterfaceState.mode {
                    let node = historyNodeImplForMode(mediaCollectionInterfaceState.mode, account: self.account, peerId: self.peerId, messageId: nil, controllerInteraction: self.controllerInteraction)
                    self.candidateHistoryNode = (node, mediaCollectionInterfaceState.mode)
                    
                    var insets = containerLayout.0.insets(options: [.input])
                    insets.top += containerLayout.1
                    
                    let previousBounds = node.bounds
                    node.bounds = CGRect(x: previousBounds.origin.x, y: previousBounds.origin.y, width: containerLayout.0.size.width, height: containerLayout.0.size.height)
                    node.position = CGPoint(x: containerLayout.0.size.width / 2.0, y: containerLayout.0.size.height / 2.0)
                    
                    var additionalBottomInset: CGFloat = 0.0
                    if let selectionPanel = self.selectionPanel {
                        additionalBottomInset = selectionPanel.bounds.size.height
                    }
                    
                    (node as! ChatHistoryNode).updateLayout(transition: .immediate, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: containerLayout.0.size, insets: UIEdgeInsets(top: insets.top, left: insets.right, bottom: insets.bottom + additionalBottomInset, right: insets.left), duration: 0.0, curve: .Default))
                    
                    self.candidateHistoryNodeReadyDisposable.set(((node as! ChatHistoryNode).historyState.get()
                        |> deliverOnMainQueue).start(next: { [weak self, weak node] _ in
                            if let strongSelf = self, let strongNode = node, strongNode == strongSelf.candidateHistoryNode?.0 {
                                strongSelf.candidateHistoryNode = nil
                                strongSelf.insertSubnode(strongNode, aboveSubnode: strongSelf.historyNodeImpl)
                                strongSelf.historyNodeImpl.removeFromSupernode()
                                strongSelf.historyNodeImpl = strongNode
                            }
                        }))
                }
            }
            
            self.mediaCollectionInterfaceState = mediaCollectionInterfaceState
            
            if let modeSelectionNode = self.modeSelectionNode {
                modeSelectionNode.mediaCollectionInterfaceState = mediaCollectionInterfaceState
            }
            
            self.requestLayout(animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
        }
    }
}
