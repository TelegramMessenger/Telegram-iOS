import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private final class ChatListControllerNodeView: UITracingLayerView, PreviewingHostView {
    var previewingDelegate: PreviewingHostViewDelegate? {
        return PreviewingHostViewDelegate(controllerForLocation: { [weak self] sourceView, point in
            return self?.controller?.previewingController(from: sourceView, for: point)
        }, commitController: { [weak self] controller in
            self?.controller?.previewingCommit(controller)
        })
    }
    
    weak var controller: ChatListController?
}

final class ChatListControllerNode: ASDisplayNode {
    private let context: AccountContext
    private let groupId: PeerGroupId?
    private var presentationData: PresentationData
    
    private var chatListEmptyNode: ChatListEmptyNode?
    private var chatListEmptyIndicator: ActivityIndicator?
    let chatListNode: ChatListNode
    var navigationBar: NavigationBar?
    weak var controller: ChatListController?
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((Peer, Bool) -> Void)?
    var requestOpenRecentPeerOptions: ((Peer) -> Void)?
    var requestOpenMessageFromSearch: ((Peer, MessageId) -> Void)?
    var requestAddContact: ((String) -> Void)?
    var dismissSelf: (() -> Void)?
    
    init(context: AccountContext, groupId: PeerGroupId?, controlsHistoryPreload: Bool, presentationData: PresentationData, controller: ChatListController) {
        self.context = context
        self.groupId = groupId
        self.presentationData = presentationData
        
        self.chatListNode = ChatListNode(context: context, groupId: groupId, controlsHistoryPreload: controlsHistoryPreload, mode: .chatList, theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations)
        
        self.controller = controller
        
        super.init()
        
        self.setViewBlock({
            return ChatListControllerNodeView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.chatListNode)
        self.chatListNode.isEmptyUpdated = { [weak self] isEmptyState in
            guard let strongSelf = self else {
                return
            }
            switch isEmptyState {
                case .empty(false):
                    if strongSelf.groupId != nil {
                        strongSelf.dismissSelf?()
                    } else if strongSelf.chatListEmptyNode == nil {
                        let chatListEmptyNode = ChatListEmptyNode(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings)
                        strongSelf.chatListEmptyNode = chatListEmptyNode
                        strongSelf.insertSubnode(chatListEmptyNode, belowSubnode: strongSelf.chatListNode)
                        if let (layout, navigationHeight) = strongSelf.containerLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                        }
                    }
                default:
                    if let chatListEmptyNode = strongSelf.chatListEmptyNode {
                        strongSelf.chatListEmptyNode = nil
                        chatListEmptyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak chatListEmptyNode] _ in
                            chatListEmptyNode?.removeFromSupernode()
                        })
                    }
            }
            switch isEmptyState {
                case .empty(true):
                    if strongSelf.chatListEmptyIndicator == nil {
                        let chatListEmptyIndicator = ActivityIndicator(type: .custom(strongSelf.presentationData.theme.list.itemAccentColor, 22.0, 1.0, false))
                        strongSelf.chatListEmptyIndicator = chatListEmptyIndicator
                        strongSelf.insertSubnode(chatListEmptyIndicator, belowSubnode: strongSelf.chatListNode)
                        if let (layout, navigationHeight) = strongSelf.containerLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                        }
                    }
                default:
                    if let chatListEmptyIndicator = strongSelf.chatListEmptyIndicator {
                        strongSelf.chatListEmptyIndicator = nil
                        chatListEmptyIndicator.removeFromSupernode()
                    }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        (self.view as? ChatListControllerNodeView)?.controller = self.controller
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.chatListNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations)
        self.searchDisplayController?.updatePresentationData(presentationData)
        self.chatListEmptyNode?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
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
            listViewCurve = .Default(duration: duration)
        } 
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.chatListNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        
        if let chatListEmptyNode = self.chatListEmptyNode {
            let emptySize = CGSize(width: updateSizeAndInsets.size.width, height: updateSizeAndInsets.size.height - updateSizeAndInsets.insets.top - updateSizeAndInsets.insets.bottom)
            transition.updateFrame(node: chatListEmptyNode, frame: CGRect(origin: CGPoint(x: 0.0, y: updateSizeAndInsets.insets.top), size: emptySize))
            chatListEmptyNode.updateLayout(size: emptySize, transition: transition)
        }
        
        if let chatListEmptyIndicator = self.chatListEmptyIndicator {
            let indicatorSize = chatListEmptyIndicator.measure(CGSize(width: 100.0, height: 100.0))
            transition.updateFrame(node: chatListEmptyIndicator, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - indicatorSize.width) / 2.0), y: updateSizeAndInsets.insets.top + floor((layout.size.height -  updateSizeAndInsets.insets.top - updateSizeAndInsets.insets.bottom - indicatorSize.height) / 2.0)), size: indicatorSize))
        }
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ChatListSearchContainerNode(context: self.context, filter: [], groupId: self.groupId, openPeer: { [weak self] peer, dismissSearch in
            self?.requestOpenPeerFromSearch?(peer, dismissSearch)
        }, openRecentPeerOptions: { [weak self] peer in
            self?.requestOpenRecentPeerOptions?(peer)
        }, openMessage: { [weak self] peer, messageId in
            if let requestOpenMessageFromSearch = self?.requestOpenMessageFromSearch {
                requestOpenMessageFromSearch(peer, messageId)
            }
        }, addContact: { [weak self] phoneNumber in
            if let requestAddContact = self?.requestAddContact {
                requestAddContact(phoneNumber)
            }
        }), cancel: { [weak self] in
            if let requestDeactivateSearch = self?.requestDeactivateSearch {
                requestDeactivateSearch()
            }
        })
        self.chatListNode.accessibilityElementsHidden = true
        
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
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
            self.chatListNode.accessibilityElementsHidden = false
        }
    }
    
    func scrollToTop() {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.contentNode.scrollToTop()
        } else {
            self.chatListNode.scrollToPosition(.top)
        }
    }
}
