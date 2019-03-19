import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore

public class ComposeController: ViewController {
    private let context: AccountContext
    
    private var contactsNode: ComposeControllerNode {
        return self.displayNode as! ComposeControllerNode
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let createActionDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.Compose_NewMessage
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.contactsNode.contactListNode.scrollToTop()
            }
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
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: { [weak self] in
            self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)
        self.title = self.presentationData.strings.Compose_NewMessage
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ComposeControllerNode(context: self.context)
        self._ready.set(self.contactsNode.contactListNode.ready)
        
        self.contactsNode.navigationBar = self.navigationBar
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { [weak self] peerId in
            self?.openPeer(peerId: peerId)
        }
        
        self.contactsNode.contactListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer in
            if case let .peer(peer, _) = peer {
                self?.openPeer(peerId: peer.id)
            }
        }

        self.contactsNode.openCreateNewGroup = { [weak self] in
            if let strongSelf = self {
                let controller = ContactMultiselectionController(context: strongSelf.context, mode: .groupCreation, options: [])
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
                strongSelf.createActionDisposable.set((controller.result
                    |> deliverOnMainQueue).start(next: { [weak controller] peerIds in
                        if let strongSelf = self, let controller = controller {
                            let createGroup = createGroupController(context: strongSelf.context, peerIds: peerIds.compactMap({ peerId in
                                if case let .peer(peerId) = peerId {
                                    return peerId
                                } else {
                                    return nil
                                }
                            }))
                            (controller.navigationController as? NavigationController)?.pushViewController(createGroup)
                        }
                    }))
            }
        }
        
        self.contactsNode.openCreateNewSecretChat = { [weak self] in
            if let strongSelf = self {
                let controller = ContactSelectionController(context: strongSelf.context, title: { $0.Compose_NewEncryptedChatTitle })
                strongSelf.createActionDisposable.set((controller.result
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak controller] peer in
                    if let strongSelf = self, let contactPeer = peer, case let .peer(peer, _) = contactPeer {
                        controller?.dismissSearch()
                        controller?.displayNavigationActivity = true
                        strongSelf.createActionDisposable.set((createSecretChat(account: strongSelf.context.account, peerId: peer.id) |> deliverOnMainQueue).start(next: { peerId in
                            if let strongSelf = self, let controller = controller {
                                controller.displayNavigationActivity = false
                                (controller.navigationController as? NavigationController)?.replaceAllButRootController(ChatController(context: strongSelf.context, chatLocation: .peer(peerId)), animated: true)
                            }
                        }, error: { _ in
                            if let strongSelf = self, let controller = controller {
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                
                                controller.displayNavigationActivity = false
                                controller.present(textAlertController(context: strongSelf.context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }))
                    }
                }))
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
            }
        }
        
        self.contactsNode.openCreateNewChannel = { [weak self] in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(legacyChannelIntroController(context: strongSelf.context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings))
            }
        }
        
        self.contactsNode.contactListNode.suppressPermissionWarning = { [weak self] in
            if let strongSelf = self {
                presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                    strongSelf.present(c, in: .window(.root), with: a)
                })
            }
        }
        
        self.contactsNode.contactListNode.contentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
            }
        }
        
        self.contactsNode.contactListNode.contentScrollingEnded = { [weak self] listView in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                return fixNavigationSearchableListNodeScrolling(listView, searchNode: searchContentNode)
            } else {
                return false
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, actualNavigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            if let searchContentNode = self.searchContentNode {
                self.contactsNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode {
                self.contactsNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
        }
    }
    
    private func openPeer(peerId: PeerId) {
        (self.navigationController as? NavigationController)?.replaceTopController(ChatController(context: self.context, chatLocation: .peer(peerId)), animated: true)
    }
}
