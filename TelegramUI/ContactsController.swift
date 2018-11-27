import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore

public class ContactsController: ViewController {
    private let account: Account
    
    private var contactsNode: ContactsControllerNode {
        return self.displayNode as! ContactsControllerNode
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var authorizationDisposable: Disposable?
    
    public init(account: Account) {
        self.account = account
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.Contacts_Title
        self.tabBarItem.title = self.presentationData.strings.Contacts_Title
        
        let icon = UIImage(bundleImageName: "Chat List/Tabs/IconContacts")        
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.addPressed))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.contactsNode.contactListNode.scrollToTop()
            }
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
        
        self.authorizationDisposable = (DeviceAccess.authorizationStatus(account: account, subject: .contacts)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.tabBarItem.badgeValue = nil
                //strongSelf.tabBarItem.badgeValue = status != .allowed ? "!" : nil
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.authorizationDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = self.presentationData.strings.Contacts_Title
        self.tabBarItem.title = self.presentationData.strings.Contacts_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        if self.navigationItem.rightBarButtonItem != nil {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.addPressed))
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ContactsControllerNode(account: self.account, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
        self._ready.set(self.contactsNode.contactListNode.ready)
        
        self.contactsNode.navigationBar = self.navigationBar
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { [weak self] peer in
            self?.contactsNode.contactListNode.openPeer?(peer)
            /*if let strongSelf = self {
                switch peer {
                    case let .peer(peer, _):
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(peer.id)))
                    case let .deviceContact(stableId, _):
                        break
                }
            }*/
        }
        
        self.contactsNode.contactListNode.openPrivacyPolicy = { [weak self] in
            if let strongSelf = self {
                openExternalUrl(account: strongSelf.account, context: .generic, url: "https://telegram.org/privacy", forceExternal: true, presentationData: strongSelf.presentationData, applicationContext: strongSelf.account.telegramApplicationContext, navigationController: strongSelf.navigationController as? NavigationController, dismissInput: {})
            }
        }
        
        self.contactsNode.contactListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer in
            if let strongSelf = self {
                strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                switch peer {
                    case let .peer(peer, _):
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, chatLocation: .peer(peer.id)))
                    case let .deviceContact(id, _):
                        let _ = (strongSelf.account.telegramApplicationContext.contactDataManager.extendedData(stableId: id)
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { value in
                            guard let strongSelf = self, let value = value else {
                                return
                            }
                            (strongSelf.navigationController as? NavigationController)?.pushViewController(deviceContactInfoController(account: strongSelf.account, subject: .vcard(nil, id, value)))
                        })
                }
            }
        }
        
        self.contactsNode.openInvite = { [weak self] in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(InviteContactsController(account: strongSelf.account))
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
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.contactsNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            self.contactsNode.deactivateSearch()
        }
    }
    
    @objc func addPressed() {
        let _ = (DeviceAccess.contacts
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            
            if let value = value, value {
                let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: "", lastName: "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Home>!$_", value: "")]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [])
                strongSelf.present(deviceContactInfoController(account: strongSelf.account, subject: .create(peer: nil, contactData: contactData, completion: { peer, stableId, contactData in
                    guard let strongSelf = self else {
                        return
                    }
                    if let peer = peer {
                        if let infoController = peerInfoController(account: strongSelf.account, peer: peer) {
                            (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                        }
                    } else {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(deviceContactInfoController(account: strongSelf.account, subject: .vcard(nil, stableId, contactData)))
                    }
                })), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else {
                let presentationData = strongSelf.presentationData
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                    self?.account.telegramApplicationContext.applicationBindings.openSettings()
                })]), in: .window(.root))
            }
        })
    }
}
