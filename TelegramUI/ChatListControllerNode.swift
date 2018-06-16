import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

class ChatListControllerNode: ASDisplayNode {
    private let account: Account
    private let groupId: PeerGroupId?
    
    let chatListNode: ChatListNode
    var navigationBar: NavigationBar?
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((Peer) -> Void)?
    var requestOpenRecentPeerOptions: ((Peer) -> Void)?
    var requestOpenMessageFromSearch: ((Peer, MessageId) -> Void)?
    
    var themeAndStrings: (PresentationTheme, PresentationStrings, timeFormat: PresentationTimeFormat)
    
    init(account: Account, groupId: PeerGroupId?, controlsHistoryPreload: Bool, theme: PresentationTheme, strings: PresentationStrings, timeFormat: PresentationTimeFormat) {
        self.account = account
        self.groupId = groupId
        self.chatListNode = ChatListNode(account: account, groupId: groupId, controlsHistoryPreload: controlsHistoryPreload, mode: .chatList, theme: theme, strings: strings, timeFormat: timeFormat)
        
        self.themeAndStrings = (theme, strings, timeFormat)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.addSubnode(self.chatListNode)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, timeFormat: PresentationTimeFormat) {
        self.themeAndStrings = (theme, strings, timeFormat)
        self.chatListNode.updateThemeAndStrings(theme: theme, strings: strings, timeFormat: timeFormat)
        self.searchDisplayController?.updateThemeAndStrings(theme: theme, strings: strings)
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
            listViewCurve = .Default
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.chatListNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        
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
            self.searchDisplayController = SearchDisplayController(theme: self.themeAndStrings.0, strings: self.themeAndStrings.1, contentNode: ChatListSearchContainerNode(account: self.account, filter: [], groupId: self.groupId, openPeer: { [weak self] peer in
                self?.requestOpenPeerFromSearch?(peer)
            }, openRecentPeerOptions: { [weak self] peer in
                self?.requestOpenRecentPeerOptions?(peer)
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
