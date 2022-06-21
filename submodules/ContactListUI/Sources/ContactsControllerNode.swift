import Display
import UIKit
import AsyncDisplayKit
import UIKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import AccountContext
import SearchBarNode
import SearchUI
import AppBundle
import ContextUI

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

final class ContactsControllerNode: ASDisplayNode {
    let contactListNode: ContactListNode
    
    private let context: AccountContext
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var navigationBar: NavigationBar?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((ContactListPeer) -> Void)?
    var requestAddContact: ((String) -> Void)?
    var openPeopleNearby: (() -> Void)?
    var openInvite: (() -> Void)?
    var openQrScan: (() -> Void)?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    weak var controller: ContactsController?
    
    init(context: AccountContext, sortOrder: Signal<ContactsSortOrder, NoError>, present: @escaping (ViewController, Any?) -> Void, controller: ContactsController) {
        self.context = context
        self.controller = controller
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var addNearbyImpl: (() -> Void)?
        var inviteImpl: (() -> Void)?
        
        let options = [ContactListAdditionalOption(title: presentationData.strings.Contacts_AddPeopleNearby, icon: .generic(UIImage(bundleImageName: "Contact List/PeopleNearbyIcon")!), action: {
            addNearbyImpl?()
        }), ContactListAdditionalOption(title: presentationData.strings.Contacts_InviteFriends, icon: .generic(UIImage(bundleImageName: "Contact List/AddMemberIcon")!), action: {
            inviteImpl?()
        })]
        
        let presentation = sortOrder
        |> map { sortOrder -> ContactListPresentation in
            switch sortOrder {
                case .presence:
                    return .orderedByPresence(options: options)
                case .natural:
                    return .natural(options: options, includeChatList: false)
            }
        }
        
        var contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?) -> Void)?
        
        self.contactListNode = ContactListNode(context: context, presentation: presentation, displaySortOptions: true, contextAction: { peer, node, gesture in
            contextAction?(peer, node, gesture)
        })
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.contactListNode)
        
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
        
        addNearbyImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.openPeopleNearby?()
            }
        }
        
        inviteImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.openInvite?()
            }
        }
        
        contextAction = { [weak self] peer, node, gesture in
            self?.contextAction(peer: peer, node: node, gesture: gesture)
        }
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.searchDisplayController?.updatePresentationData(self.presentationData)
    }
    
    func scrollToTop() {
        if let contentNode = self.searchDisplayController?.contentNode as? ContactsSearchContainerNode {
            contentNode.scrollToTop()
        } else {
            self.contactListNode.scrollToTop()
        }
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
    
    private func contextAction(peer: EnginePeer, node: ASDisplayNode, gesture: ContextGesture?) {
        guard let contactsController = self.controller else {
            return
        }
        let chatController = self.context.sharedContext.makeChatController(context: self.context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(previewing: true))
        chatController.canReadHistory.set(false)
        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: contactContextMenuItems(context: self.context, peerId: peer.id, contactsController: contactsController) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
        contactsController.presentInGlobalOverlay(contextController)
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ContactsSearchContainerNode(context: self.context, onlyWriteable: false, categories: [.cloudContacts, .global, .deviceContacts], addContact: { [weak self] phoneNumber in
            if let requestAddContact = self?.requestAddContact {
                requestAddContact(phoneNumber)
            }
        }, openPeer: { [weak self] peer in
            if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
                requestOpenPeerFromSearch(peer)
            }
        }, contextAction: { [weak self] peer, node, gesture in
            self?.contextAction(peer: peer, node: node, gesture: gesture)
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
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode, animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode, animated: animated)
            self.searchDisplayController = nil
        }
    }
}
