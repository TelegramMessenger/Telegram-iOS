import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AlertUI
import PresentationDataUtils
import SearchUI
import TelegramPermissionsUI
import AppBundle
import DeviceAccess

public class ComposeControllerImpl: ViewController, ComposeController {
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
        
        self.navigationPresentation = .modal
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Compose_NewMessage
                
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(cancelPressed))
        
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
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
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
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer, _ in
            if case let .peer(peer, _, _) = peer {
                self?.openPeer(peerId: peer.id)
            }
        }

        self.contactsNode.openCreateNewGroup = { [weak self] in
            if let strongSelf = self {
                let controller = strongSelf.context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: strongSelf.context, mode: .groupCreation, options: []))
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                    }
                })
                strongSelf.createActionDisposable.set((controller.result
                |> deliverOnMainQueue).start(next: { [weak controller] result in
                    var peerIds: [ContactListPeerId] = []
                    if case let .result(peerIdsValue, _) = result {
                        peerIds = peerIdsValue
                    }
                    
                    if let strongSelf = self, let controller = controller {
                        let createGroup = strongSelf.context.sharedContext.makeCreateGroupController(context: strongSelf.context, peerIds: peerIds.compactMap({ peerId in
                            if case let .peer(peerId) = peerId {
                                return peerId
                            } else {
                                return nil
                            }
                        }), initialTitle: nil, mode: .generic, completion: nil)
                        (controller.navigationController as? NavigationController)?.pushViewController(createGroup)
                    }
                }))
            }
        }
        
        self.contactsNode.openCreateNewSecretChat = { [weak self] in
            if let strongSelf = self {
                let controller = ContactSelectionControllerImpl(ContactSelectionControllerParams(context: strongSelf.context, autoDismiss: false, title: { $0.Compose_NewEncryptedChatTitle }))
                strongSelf.createActionDisposable.set((controller.result
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak controller] result in
                    if let strongSelf = self, let (contactPeers, _, _, _, _) = result, case let .peer(peer, _, _) = contactPeers.first {
                        controller?.dismissSearch()
                        controller?.displayNavigationActivity = true
                        strongSelf.createActionDisposable.set((strongSelf.context.engine.peers.createSecretChat(peerId: peer.id) |> deliverOnMainQueue).start(next: { peerId in
                            if let strongSelf = self, let controller = controller {
                                controller.displayNavigationActivity = false
                                (controller.navigationController as? NavigationController)?.replaceAllButRootController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: peerId)), animated: true)
                            }
                        }, error: { error in
                            if let strongSelf = self, let controller = controller {
                                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                controller.displayNavigationActivity = false
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = presentationData.strings.TwoStepAuth_FloodError
                                    default:
                                        text = presentationData.strings.Login_UnknownError
                                }
                                controller.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }))
                    }
                }))
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                    }
                })
            }
        }
        
        self.contactsNode.openCreateContact = { [weak self] in
            let _ = (DeviceAccess.authorizationStatus(subject: .contacts)
            |> take(1)
            |> deliverOnMainQueue).start(next: { status in
                guard let strongSelf = self else {
                    return
                }
                
                switch status {
                    case .allowed:
                        let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: "", lastName: "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: "+")]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(strongSelf.context.sharedContext.makeDeviceContactInfoController(context: strongSelf.context, subject: .create(peer: nil, contactData: contactData, isSharing: false, shareViaException: false, completion: { peer, stableId, contactData in
                            guard let strongSelf = self else {
                                return
                            }
                            if let peer = peer {
                                DispatchQueue.main.async {
                                    if let navigationController = strongSelf.navigationController as? NavigationController {
                                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: peer.id)))
                                    }
                                }
                            } else {
                                (strongSelf.navigationController as? NavigationController)?.replaceAllButRootController(strongSelf.context.sharedContext.makeDeviceContactInfoController(context: strongSelf.context, subject: .vcard(nil, stableId, contactData), completed: nil, cancelled: nil), animated: true)
                            }
                        }), completed: nil, cancelled: nil))
                    case .notDetermined:
                        DeviceAccess.authorizeAccess(to: .contacts)
                    default:
                        let presentationData = strongSelf.presentationData
                        strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            self?.context.sharedContext.applicationBindings.openSettings()
                        })]), in: .window(.root))
                }
            })
        }
        
        self.contactsNode.openCreateNewChannel = { [weak self] in
            if let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let controller = PermissionController(context: strongSelf.context, splashScreen: true)
                controller.setState(.custom(icon: .animation("Channel"), title: presentationData.strings.ChannelIntro_Title, subtitle: nil, text: presentationData.strings.ChannelIntro_Text, buttonTitle: presentationData.strings.ChannelIntro_CreateChannel, secondaryButtonTitle: nil, footerText: nil), animated: false)
                controller.proceed = { [weak self] result in
                    if let strongSelf = self {
                        (strongSelf.navigationController as? NavigationController)?.replaceTopController(createChannelController(context: strongSelf.context), animated: true)
                    }
                }
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                    }
                })
            }
        }
        
        self.contactsNode.contactListNode.suppressPermissionWarning = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
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
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
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
        (self.navigationController as? NavigationController)?.replaceTopController(ChatControllerImpl(context: self.context, chatLocation: .peer(id: peerId)), animated: true)
    }
    
    @objc private func cancelPressed() {
        (self.navigationController as? NavigationController)?.filterController(self, animated: true)
    }
}
