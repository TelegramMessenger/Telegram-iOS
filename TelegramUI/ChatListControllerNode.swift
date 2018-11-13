import Foundation
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

class ChatListControllerNode: ASDisplayNode {
    private let account: Account
    private let groupId: PeerGroupId?
    
    private var chatListEmptyNode: ChatListEmptyNode?
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
    
    var themeAndStrings: (PresentationTheme, PresentationStrings, dateTimeFormat: PresentationDateTimeFormat)
    
    init(account: Account, groupId: PeerGroupId?, controlsHistoryPreload: Bool, presentationData: PresentationData, controller: ChatListController) {
        self.account = account
        self.groupId = groupId
        self.chatListNode = ChatListNode(account: account, groupId: groupId, controlsHistoryPreload: controlsHistoryPreload, mode: .chatList, theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: presentationData.disableAnimations)
        
        self.themeAndStrings = (presentationData.theme, presentationData.strings, presentationData.dateTimeFormat)
        
        self.controller = controller
        
        super.init()
        
        self.setViewBlock({
            return ChatListControllerNodeView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.chatListNode)
        self.chatListNode.isEmptyUpdated = { [weak self] isEmpty in
            guard let strongSelf = self else {
                return
            }
            if isEmpty {
                if strongSelf.chatListEmptyNode == nil {
                    let chatListEmptyNode = ChatListEmptyNode(theme: strongSelf.themeAndStrings.0, strings: strongSelf.themeAndStrings.1)
                    strongSelf.chatListEmptyNode = chatListEmptyNode
                    strongSelf.insertSubnode(chatListEmptyNode, belowSubnode: strongSelf.chatListNode)
                    if let (layout, navigationHeight) = strongSelf.containerLayout {
                        strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                    }
                }
            } else if let chatListEmptyNode = strongSelf.chatListEmptyNode {
                strongSelf.chatListEmptyNode = nil
                chatListEmptyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak chatListEmptyNode] _ in
                    chatListEmptyNode?.removeFromSupernode()
                })
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        (self.view as? ChatListControllerNodeView)?.controller = self.controller
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        self.themeAndStrings = (theme, strings, dateTimeFormat)
        
        self.backgroundColor = theme.chatList.backgroundColor
        
        self.chatListNode.updateThemeAndStrings(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameSortOrder: nameSortOrder, nameDisplayOrder: nameDisplayOrder, disableAnimations: disableAnimations)
        self.searchDisplayController?.updateThemeAndStrings(theme: theme, strings: strings)
        self.chatListEmptyNode?.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        
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
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
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
            self.searchDisplayController = SearchDisplayController(theme: self.themeAndStrings.0, strings: self.themeAndStrings.1, contentNode: ChatListSearchContainerNode(account: self.account, filter: [], groupId: self.groupId, openPeer: { [weak self] peer, dismissSearch in
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
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { subnode in
                self.insertSubnode(subnode, belowSubnode: navigationBar)
            }, placeholder: placeholderNode)
        }
    }
    
    func deactivateSearch(animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            self.chatListNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            searchDisplayController.deactivate(placeholder: maybePlaceholderNode, animated: animated)
            self.searchDisplayController = nil
        }
    }
}
