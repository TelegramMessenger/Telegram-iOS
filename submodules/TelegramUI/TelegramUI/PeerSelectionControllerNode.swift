import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import SearchBarNode
import SearchUI
import ContactListUI
import ChatListUI

final class PeerSelectionControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let present: (ViewController, Any?) -> Void
    private let dismiss: () -> Void
    private let filter: ChatListNodePeersFilter
    
    var inProgress: Bool = false {
        didSet {
            
        }
    }
    
    var navigationBar: NavigationBar?
    
    private let toolbarBackgroundNode: ASDisplayNode?
    private let toolbarSeparatorNode: ASDisplayNode?
    private let segmentedControl: UISegmentedControl?
    
    var contactListNode: ContactListNode?
    let chatListNode: ChatListNode
    
    private var contactListActive = false
    
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    var contentScrollingEnded: ((ListView) -> Bool)?
    
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
    
    init(context: AccountContext, filter: ChatListNodePeersFilter, hasContactSelector: Bool, present: @escaping (ViewController, Any?) -> Void, dismiss: @escaping () -> Void) {
        self.context = context
        self.present = present
        self.dismiss = dismiss
        self.filter = filter
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        if hasContactSelector {
            self.toolbarBackgroundNode = ASDisplayNode()
            self.toolbarBackgroundNode?.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
            
            self.toolbarSeparatorNode = ASDisplayNode()
            self.toolbarSeparatorNode?.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
            
            self.segmentedControl = UISegmentedControl(items: [self.presentationData.strings.DialogList_TabTitle, self.presentationData.strings.Contacts_TabTitle])
            self.segmentedControl?.tintColor = self.presentationData.theme.rootController.navigationBar.accentTextColor
            self.segmentedControl?.selectedSegmentIndex = 0
        } else {
            self.toolbarBackgroundNode = nil
            self.toolbarSeparatorNode = nil
            self.segmentedControl = nil
        }
       
        
        self.chatListNode = ChatListNode(context: context, groupId: .root, controlsHistoryPreload: false, mode: .peers(filter: filter), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.chatListNode.activateSearch = { [weak self] in
            self?.requestActivateSearch?()
        }
        
        self.chatListNode.peerSelected = { [weak self] peerId, _, _ in
            self?.requestOpenPeer?(peerId)
        }
        
        self.chatListNode.contentOffsetChanged = { [weak self] offset in
            self?.contentOffsetChanged?(offset)
        }
        
        self.chatListNode.contentScrollingEnded = { [weak self] listView in
            return self?.contentScrollingEnded?(listView) ?? false
        }
        
        self.addSubnode(self.chatListNode)
        self.presentationDataDisposable = (context.sharedContext.presentationData
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
        
        if hasContactSelector {
            self.addSubnode(self.toolbarBackgroundNode!)
            self.addSubnode(self.toolbarSeparatorNode!)
            self.view.addSubview(self.segmentedControl!)
            self.segmentedControl!.addTarget(self, action: #selector(indexChanged), for: .valueChanged)
        }
        
        
        self.readyValue.set(self.chatListNode.ready)
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.searchDisplayController?.updatePresentationData(self.presentationData)
        self.chatListNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations)
        
        self.toolbarBackgroundNode?.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.toolbarSeparatorNode?.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.segmentedControl?.tintColor = self.presentationData.theme.rootController.navigationBar.accentTextColor
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        let cleanInsets = layout.insets(options: [])
        
        var toolbarHeight: CGFloat = cleanInsets.bottom

        if let segmentedControl = segmentedControl, let toolbarBackgroundNode = toolbarBackgroundNode, let toolbarSeparatorNode = toolbarSeparatorNode {
            toolbarHeight += 44
            transition.updateFrame(node: toolbarBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: toolbarHeight)))
            transition.updateFrame(node: toolbarSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
            
            var controlSize = segmentedControl.sizeThatFits(layout.size)
            controlSize.width = min(layout.size.width, max(200.0, controlSize.width))
            transition.updateFrame(view: segmentedControl, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - controlSize.width) / 2.0), y: layout.size.height - toolbarHeight + floor((44.0 - controlSize.height) / 2.0)), size: controlSize))
        }
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.bottom = max(insets.bottom, cleanInsets.bottom)
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        headerInsets.bottom = max(headerInsets.bottom, cleanInsets.bottom)
        headerInsets.left += layout.safeInsets.left
        headerInsets.right += layout.safeInsets.right
        
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
                    case .easeInOut, .custom:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: headerInsets, duration: duration, curve: listViewCurve)
        
        self.chatListNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        
        if let contactListNode = self.contactListNode {
            contactListNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
            contactListNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
            
            let contactsInsets = insets
            
            contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: contactsInsets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: transition)
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight, _) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        if self.chatListNode.supernode != nil {
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ChatListSearchContainerNode(context: self.context, filter: self.filter, groupId: .root, openPeer: { [weak self] peer, _ in
                if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
                    requestOpenPeerFromSearch(peer)
                }
            }, openRecentPeerOptions: { _ in
            }, openMessage: { [weak self] peer, messageId in
                if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
                    requestOpenMessageFromSearch(peer, messageId)
                }
            }, addContact: nil), cancel: { [weak self] in
                if let requestDeactivateSearch = self?.requestDeactivateSearch {
                    requestDeactivateSearch()
                }
            })
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
                if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                    if isSearchBar {
                        strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                    } else {
                        strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                    }
                }
            }, placeholder: placeholderNode)
            
        } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ContactsSearchContainerNode(context: self.context, onlyWriteable: true, categories: [.cloudContacts, .global], openPeer: { [weak self] peer in
                if let strongSelf = self {
                    switch peer {
                        case let .peer(peer, _, _):
                            let _ = (strongSelf.context.account.postbox.transaction { transaction -> Peer? in
                                return transaction.getPeer(peer.id)
                            } |> deliverOnMainQueue).start(next: { peer in
                                if let strongSelf = self, let peer = peer {
                                    strongSelf.requestOpenPeerFromSearch?(peer)
                                }
                            })
                        case .deviceContact:
                            break
                    }
                }
            }), cancel: { [weak self] in
                if let requestDeactivateSearch = self?.requestDeactivateSearch {
                    requestDeactivateSearch()
                }
            })
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
                if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                    if isSearchBar {
                        strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                    } else {
                        strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                    }
                }
            }, placeholder: placeholderNode)
        }
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            if self.chatListNode.supernode != nil {
                searchDisplayController.deactivate(placeholder: placeholderNode)
                self.searchDisplayController = nil
            } else if let contactListNode = self.contactListNode, contactListNode.supernode != nil {
                searchDisplayController.deactivate(placeholder: placeholderNode)
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
        self.clipsToBounds = true
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
            completion?()
        })
    }
    
    @objc func indexChanged() {
        guard let (layout, navigationHeight, actualNavigationHeight) = self.containerLayout, let segmentedControl = self.segmentedControl else {
            return
        }
            
        let contactListActive = segmentedControl.selectedSegmentIndex == 1
        if contactListActive != self.contactListActive {
            self.contactListActive = contactListActive
            if contactListActive {
                if let contactListNode = self.contactListNode {
                    self.insertSubnode(contactListNode, aboveSubnode: self.chatListNode)
                    self.chatListNode.removeFromSupernode()
                    self.recursivelyEnsureDisplaySynchronously(true)
                    contactListNode.enableUpdates = true
                } else {
                    let contactListNode = ContactListNode(context: context, presentation: .single(.natural(options: [], includeChatList: false)))
                    self.contactListNode = contactListNode
                    contactListNode.enableUpdates = true
                    contactListNode.activateSearch = { [weak self] in
                        self?.requestActivateSearch?()
                    }
                    contactListNode.openPeer = { [weak self] peer in
                        if case let .peer(peer, _, _) = peer {
                            self?.requestOpenPeer?(peer.id)
                        }
                    }
                    contactListNode.suppressPermissionWarning = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                                strongSelf.present(c, a)
                            })
                        }
                    }
                    contactListNode.contentOffsetChanged = { [weak self] offset in
                        self?.contentOffsetChanged?(offset)
                    }
                    
                    contactListNode.contentScrollingEnded = { [weak self] listView in
                        return self?.contentScrollingEnded?(listView) ?? false
                    }
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, actualNavigationBarHeight: actualNavigationHeight, transition: .immediate)
                    
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
