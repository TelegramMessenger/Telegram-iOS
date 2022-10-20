import Display
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import SearchBarNode
import SearchUI
import ContactListUI
import AppBundle

final class ComposeControllerNode: ASDisplayNode {
    let contactListNode: ContactListNode
    
    private let context: AccountContext
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var navigationBar: NavigationBar?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((PeerId) -> Void)?
    
    var openCreateNewGroup: (() -> Void)?
    var openCreateNewSecretChat: (() -> Void)?
    var openCreateContact: (() -> Void)?
    var openCreateNewChannel: (() -> Void)?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var openCreateNewGroupImpl: (() -> Void)?
        var openCreateContactImpl: (() -> Void)?
        var openCreateNewChannelImpl: (() -> Void)?
        
        self.contactListNode = ContactListNode(context: context, presentation: .single(.natural(options: [
            ContactListAdditionalOption(title: self.presentationData.strings.Compose_NewGroup, icon: .generic(UIImage(bundleImageName: "Contact List/CreateGroupActionIcon")!), action: {
                openCreateNewGroupImpl?()
            }),
            ContactListAdditionalOption(title: self.presentationData.strings.NewContact_Title, icon: .generic(UIImage(bundleImageName: "Contact List/AddMemberIcon")!), action: {
                openCreateContactImpl?()
            }),
            ContactListAdditionalOption(title: self.presentationData.strings.Compose_NewChannel, icon: .generic(UIImage(bundleImageName: "Contact List/CreateChannelActionIcon")!), action: {
                openCreateNewChannelImpl?()
            })
        ], includeChatList: false)), displayPermissionPlaceholder: false)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.contactListNode)
        
        openCreateNewGroupImpl = { [weak self] in
            self?.openCreateNewGroup?()
        }
        openCreateContactImpl = { [weak self] in
            self?.contactListNode.listNode.clearHighlightAnimated(true)
            self?.openCreateContact?()
        }
        openCreateNewChannelImpl = { [weak self] in
            self?.openCreateNewChannel?()
        }
        
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
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.searchDisplayController?.updatePresentationData(presentationData)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        self.contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: transition)
        
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ContactsSearchContainerNode(context: self.context, onlyWriteable: false, categories: [.cloudContacts, .global], addContact: nil, openPeer: { [weak self] peer in
            if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch, case let .peer(peer, _, _) = peer {
                requestOpenPeerFromSearch(peer.id)
            }
        }, contextAction: nil), cancel: { [weak self] in
            self?.requestDeactivateSearch?()
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
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
}
