import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class PeerSelectionControllerNode: ASDisplayNode {
    private let account: Account
    private let dismiss: () -> Void
    private let filter: ChatListNodePeersFilter
    
    var inProgress: Bool = false {
        didSet {
            
        }
    }
    
    var navigationBar: NavigationBar?
    
    private let toolbarBackgroundNode: ASDisplayNode
    private let toolbarSeparatorNode: ASDisplayNode
    private let segmentedControl: UISegmentedControl
    
    private var contactListNode: ContactListNode?
    private let chatListNode: ChatListNode
    
    private var contactListActive = false
    
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeer: ((PeerId) -> Void)?
    var requestOpenPeerFromSearch: ((Peer) -> Void)?
    var requestOpenMessageFromSearch: ((Peer, MessageId) -> Void)?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var readyValue = Promise<Bool>()
    var ready: Signal<Bool, NoError> {
        return self.readyValue.get()
    }
    
    init(account: Account, filter: ChatListNodePeersFilter, dismiss: @escaping () -> Void) {
        self.account = account
        self.dismiss = dismiss
        self.filter = filter
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.toolbarBackgroundNode = ASDisplayNode()
        self.toolbarBackgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        
        self.toolbarSeparatorNode = ASDisplayNode()
        self.toolbarSeparatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.segmentedControl = UISegmentedControl(items: [self.presentationData.strings.DialogList_TabTitle, self.presentationData.strings.Contacts_TabTitle])
        self.segmentedControl.tintColor = self.presentationData.theme.rootController.navigationBar.accentTextColor
        self.segmentedControl.selectedSegmentIndex = 0
        
        self.chatListNode = ChatListNode(account: account, groupId: nil, controlsHistoryPreload: false, mode: .peers(filter: filter), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.chatListNode.activateSearch = { [weak self] in
            self?.requestActivateSearch?()
        }
        
        self.chatListNode.peerSelected = { [weak self] peerId in
            self?.requestOpenPeer?(peerId)
        }
        
        self.addSubnode(self.chatListNode)
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    strongSelf.presentationData = presentationData
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
                    }
                }
            })
        
        self.addSubnode(self.toolbarBackgroundNode)
        self.addSubnode(self.toolbarSeparatorNode)
        
        self.view.addSubview(self.segmentedControl)
        
        self.segmentedControl.addTarget(self, action: #selector(indexChanged), for: .valueChanged)
        
        self.readyValue.set(self.chatListNode.ready)
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.searchDisplayController?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
        self.chatListNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        let cleanInsets = layout.insets(options: [])
        
        let toolbarHeight: CGFloat = 44.0 + cleanInsets.bottom
        
        transition.updateFrame(node: self.toolbarBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: toolbarHeight)))
        transition.updateFrame(node: self.toolbarSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        var controlSize = self.segmentedControl.sizeThatFits(layout.size)
        controlSize.width = min(layout.size.width, max(200.0, controlSize.width))
        transition.updateFrame(view: self.segmentedControl, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - controlSize.width) / 2.0), y: layout.size.height - toolbarHeight + floor((44.0 - controlSize.height) / 2.0)), size: controlSize))
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        insets.bottom = max(insets.bottom, cleanInsets.bottom)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.chatListNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.chatListNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
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
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.chatListNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        
        if let contactListNode = self.contactListNode {
            contactListNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            contactListNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
            
            let contactsInsets = insets
            
            contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, intrinsicInsets: contactsInsets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, standardInputHeight: layout.standardInputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging), transition: transition)
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        if self.chatListNode.supernode != nil {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            self.chatListNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            if let _ = self.searchDisplayController {
                return
            }
            
            if let placeholderNode = maybePlaceholderNode {
                self.searchDisplayController = SearchDisplayController(theme: self.presentationData.theme, strings: self.presentationData.strings, contentNode: ChatListSearchContainerNode(account: self.account, filter: self.filter, groupId: nil, openPeer: { [weak self] peer, _ in
                    if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
                        requestOpenPeerFromSearch(peer)
                    }
                }, openRecentPeerOptions: { _ in
                }, openMessage: { [weak self] peer, messageId in
                    if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
                        requestOpenMessageFromSearch(peer, messageId)
                    }
                }), cancel: { [weak self] in
                    if let requestDeactivateSearch = self?.requestDeactivateSearch {
                        requestDeactivateSearch()
                    }
                })
                
                self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                self.searchDisplayController?.activate(insertSubnode: { subnode in
                    self.insertSubnode(subnode, belowSubnode: navigationBar)
                }, placeholder: placeholderNode)
            }
        } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            contactListNode.listNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            if let _ = self.searchDisplayController {
                return
            }
            
            if let placeholderNode = maybePlaceholderNode {
                self.searchDisplayController = SearchDisplayController(theme: self.presentationData.theme, strings: self.presentationData.strings, contentNode: ContactsSearchContainerNode(account: self.account, onlyWriteable: true, categories: [.cloudContacts, .global], openPeer: { [weak self] peer in
                    if let strongSelf = self {
                        switch peer {
                            case let .peer(peer, _):
                                let _ = (strongSelf.account.postbox.transaction { transaction -> Peer? in
                                    return transaction.getPeer(peer.id)
                                } |> deliverOnMainQueue).start(next: { peer in
                                    if let strongSelf = self, let peer = peer {
                                        strongSelf.requestOpenPeerFromSearch?(peer)
                                    }
                                })
                            case let .deviceContact(stableId, contact):
                                break
                        }
                    }
                }), cancel: { [weak self] in
                    if let requestDeactivateSearch = self?.requestDeactivateSearch {
                        requestDeactivateSearch()
                    }
                })
                
                self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                self.searchDisplayController?.activate(insertSubnode: { subnode in
                    self.insertSubnode(subnode, belowSubnode: navigationBar)
                }, placeholder: placeholderNode)
            }
        }
    }
    
    func deactivateSearch() {
        if let searchDisplayController = self.searchDisplayController {
            if self.chatListNode.supernode != nil {
                var maybePlaceholderNode: SearchBarPlaceholderNode?
                self.chatListNode.forEachItemNode { node in
                    if let node = node as? ChatListSearchItemNode {
                        maybePlaceholderNode = node.searchBarNode
                    }
                }
                
                searchDisplayController.deactivate(placeholder: maybePlaceholderNode)
                self.searchDisplayController = nil
            } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
                var maybePlaceholderNode: SearchBarPlaceholderNode?
                contactListNode.listNode.forEachItemNode { node in
                    if let node = node as? ChatListSearchItemNode {
                        maybePlaceholderNode = node.searchBarNode
                    }
                }
                
                searchDisplayController.deactivate(placeholder: maybePlaceholderNode)
                self.searchDisplayController = nil
            }
        }
    }
    
    func scrollToTop() {
        if self.chatListNode.supernode != nil {
            self.chatListNode.scrollToPosition(.top)
        } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
            contactListNode.scrollToTop()
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
            completion?()
        })
    }
    
    @objc func indexChanged() {
        guard let (layout, navigationHeight) = self.containerLayout else {
            return
        }
            
        let contactListActive = self.segmentedControl.selectedSegmentIndex == 1
        if contactListActive != self.contactListActive {
            self.contactListActive = contactListActive
            if contactListActive {
                if let contactListNode = self.contactListNode {
                    self.insertSubnode(contactListNode, aboveSubnode: self.chatListNode)
                    self.chatListNode.removeFromSupernode()
                    self.recursivelyEnsureDisplaySynchronously(true)
                    contactListNode.enableUpdates = true
                } else {
                    let contactListNode = ContactListNode(account: account, presentation: .natural(displaySearch: true, options: []))
                    self.contactListNode = contactListNode
                    contactListNode.enableUpdates = true
                    contactListNode.activateSearch = { [weak self] in
                        self?.requestActivateSearch?()
                    }
                    contactListNode.openPeer = { [weak self] peer in
                        if case let .peer(peer, _) = peer {
                            self?.requestOpenPeer?(peer.id)
                        }
                    }
                    
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                    
                    let _ = (contactListNode.ready |> deliverOnMainQueue).start(next: { [weak self] _ in
                        if let strongSelf = self {
                            if let contactListNode = strongSelf.contactListNode {
                                strongSelf.insertSubnode(contactListNode, aboveSubnode: strongSelf.chatListNode)
                            }
                            strongSelf.chatListNode.removeFromSupernode()
                            strongSelf.recursivelyEnsureDisplaySynchronously(true)
                        }
                    })
                }
            } else if let contactListNode = self.contactListNode {
                contactListNode.enableUpdates = false
                
                self.insertSubnode(chatListNode, aboveSubnode: contactListNode)
                contactListNode.removeFromSupernode()
            }
        }
    }
}
