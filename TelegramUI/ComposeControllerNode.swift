import Display
import AsyncDisplayKit
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit

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
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    init(account: Account) {
        self.account = account
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        var openCreateNewGroupImpl: (() -> Void)?
        var openCreateNewSecretChatImpl: (() -> Void)?
        var openCreateNewChannelImpl: (() -> Void)?
        
        self.contactListNode = ContactListNode(account: account, presentation: .natural(displaySearch: true, options: [
            ContactListAdditionalOption(title: self.presentationData.strings.Compose_NewGroup, icon: generateTintedImage(image: UIImage(bundleImageName: "Contact List/CreateGroupActionIcon"), color: presentationData.theme.list.itemAccentColor), action: {
                openCreateNewGroupImpl?()
            }),
            ContactListAdditionalOption(title: self.presentationData.strings.Compose_NewEncryptedChat, icon: generateTintedImage(image: UIImage(bundleImageName: "Contact List/CreateSecretChatActionIcon"), color: presentationData.theme.list.itemAccentColor), action: {
                openCreateNewSecretChatImpl?()
            }),
            ContactListAdditionalOption(title: self.presentationData.strings.Compose_NewChannel, icon: generateTintedImage(image: UIImage(bundleImageName: "Contact List/CreateChannelActionIcon"), color: presentationData.theme.list.itemAccentColor), action: {
                openCreateNewChannelImpl?()
            })
        ]))
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
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
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.searchDisplayController?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
            if !searchDisplayController.isDeactivating {
                insets.top += layout.statusBarHeight ?? 0.0
            }
        }
        
        self.contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, standardInputHeight: layout.standardInputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging), transition: transition)
        
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
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
            self.searchDisplayController = SearchDisplayController(theme: self.presentationData.theme, strings: self.presentationData.strings, contentNode: ContactsSearchContainerNode(account: self.account, onlyWriteable: false, categories: [.cloudContacts, .global], openPeer: { [weak self] peer in
                if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch, case let .peer(peer, _) = peer {
                    requestOpenPeerFromSearch(peer.id)
                }
            }), cancel: { [weak self] in
                self?.requestDeactivateSearch?()
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
