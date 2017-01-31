import Display
import AsyncDisplayKit
import UIKit
import Postbox
import TelegramCore

private let createGroupIcon = UIImage(bundleImageName: "Contact List/CreateGroupActionIcon")?.precomposed()
private let createSecretChatIcon = UIImage(bundleImageName: "Contact List/CreateSecretChatActionIcon")?.precomposed()
private let createChannelIcon = UIImage(bundleImageName: "Contact List/CreateChannelActionIcon")?.precomposed()

final class ComposeControllerNode: ASDisplayNode {
    let contactListNode: ContactListNode
    
    private let account: Account
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var navigationBar: NavigationBar?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((PeerId) -> Void)?
    
    var openCreateNewGroup: (() -> Void)?
    var openCreateNewSecretChat: (() -> Void)?
    var openCreateNewChannel: (() -> Void)?
    
    init(account: Account) {
        self.account = account
        
        var openCreateNewGroupImpl: (() -> Void)?
        var openCreateNewSecretChatImpl: (() -> Void)?
        var openCreateNewChannelImpl: (() -> Void)?
        
        self.contactListNode = ContactListNode(account: account, presentation: .natural(displaySearch: true, options: [
            ContactListAdditionalOption(title: "New Group", icon: createGroupIcon, action: {
                openCreateNewGroupImpl?()
            }),
            ContactListAdditionalOption(title: "New Secret Chat", icon: createSecretChatIcon, action: {
                openCreateNewSecretChatImpl?()
            }),
            ContactListAdditionalOption(title: "New Channel", icon: createChannelIcon, action: {
                openCreateNewChannelImpl?()
            })
        ]))
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = UIColor.white
        
        self.addSubnode(self.contactListNode)
        
        openCreateNewGroupImpl = { [weak self] in
            self?.openCreateNewGroup?()
        }
        openCreateNewSecretChatImpl = { [weak self] in
            self?.openCreateNewSecretChat?()
        }
        openCreateNewChannelImpl = { [weak self] in
            self?.openCreateNewChannel?()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        self.contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, intrinsicInsets: insets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight), transition: transition)
        
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        var maybePlaceholderNode: SearchBarPlaceholderNode?
        self.contactListNode.listNode.forEachItemNode { node in
            if let node = node as? ChatListSearchItemNode {
                maybePlaceholderNode = node.searchBarNode
            }
        }
        
        if let _ = self.searchDisplayController {
            return
        }
        
        if let placeholderNode = maybePlaceholderNode {
            self.searchDisplayController = SearchDisplayController(contentNode: ContactsSearchContainerNode(account: self.account, openPeer: { [weak self] peerId in
                if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
                    requestOpenPeerFromSearch(peerId)
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
    
    func deactivateSearch() {
        if let searchDisplayController = self.searchDisplayController {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            self.contactListNode.listNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            searchDisplayController.deactivate(placeholder: maybePlaceholderNode)
            self.searchDisplayController = nil
        }
    }
}
