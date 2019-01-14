import Foundation
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

public final class TelegramRootController: NavigationController {
    private let account: Account
    
    public var rootTabController: TabBarController?
    
    public var contactsController: ContactsController?
    public var callListController: CallListController?
    public var chatListController: ChatListController?
    public var accountSettingsController: ViewController?
    
    private var permissionsDisposable: Disposable?
    private var presentationDataDisposable: Disposable?
    private var presentationData: PresentationData
    
    public init(account: Account) {
        self.account = account
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(mode: .automaticMasterDetail, theme: NavigationControllerTheme(presentationTheme: self.presentationData.theme))
        
        //self.permissionsDisposable =
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData
                if previousTheme !== presentationData.theme {
                    strongSelf.rootTabController?.updateTheme(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData), theme: TabBarControllerTheme(rootControllerTheme: presentationData.theme))
                    strongSelf.rootTabController?.statusBar.statusBarStyle = presentationData.theme.rootController.statusBar.style.style
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.permissionsDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    public func addRootControllers(showCallsTab: Bool) {
        let tabBarController = TabBarController(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), theme: TabBarControllerTheme(rootControllerTheme: self.presentationData.theme))
        let chatListController = ChatListController(account: self.account, groupId: nil, controlsHistoryPreload: true)
        let callListController = CallListController(account: self.account, mode: .tab)
        
        var controllers: [ViewController] = []
        
        let contactsController = ContactsController(account: self.account)
        controllers.append(contactsController)
        
        if showCallsTab {
            controllers.append(callListController)
        }
        controllers.append(chatListController)
        
        let accountSettingsController = settingsController(account: self.account, accountManager: self.account.telegramApplicationContext.accountManager)
        controllers.append(accountSettingsController)
        
        tabBarController.setControllers(controllers, selectedIndex: controllers.count - 2)
        
        self.contactsController = contactsController
        self.callListController = callListController
        self.chatListController = chatListController
        self.accountSettingsController = accountSettingsController
        self.rootTabController = tabBarController
        self.pushViewController(tabBarController, animated: false)
        
        ///TESTBED
        
        guard let controller = self.viewControllers.last as? ViewController else {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15) {
            //(controller.navigationController as? NavigationController)?.pushViewController(ThemeGridController(account: self.account))
            
//            let wrapperNode = ASDisplayNode()
//            let bounds = controller.displayNode.bounds
//            wrapperNode.frame = bounds
//            wrapperNode.backgroundColor = .gray
//            //controller.displayNode.addSubnode(wrapperNode)
//
//            let radialStatusSize: CGFloat = 50.0
//            let statusNode = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.6))
//            statusNode.frame = CGRect(origin: CGPoint(x: floor(bounds.midX - radialStatusSize / 2.0), y: floor(bounds.midY - radialStatusSize / 2.0)), size: CGSize(width: radialStatusSize, height: radialStatusSize))
//            wrapperNode.addSubnode(statusNode)
//
//            let color = UIColor.white
//            var smth = false
//            let button = HighlightTrackingButtonNode()
//            button.frame = CGRect(origin: CGPoint(x: floor(bounds.midX - radialStatusSize / 2.0), y: floor(bounds.midY - radialStatusSize / 2.0)), size: CGSize(width: radialStatusSize, height: radialStatusSize))
//            wrapperNode.addSubnode(button)
//            button.highligthedChanged = { value in
//                if value {
//                    if smth {
//                        smth = false
//                        //statusNode.transitionToState(.play(color), animated: true, completion: {})
//                        statusNode.transitionToState(.download(.white), animated: true, completion: {})
//                        //statusNode.transitionToState(.none, animated: true, completion: {})
//                    } else {
//                        smth = true
//                        statusNode.transitionToState(.progress(color: color, lineWidth: nil, value: 0.3, cancelEnabled: true), animated: true, completion: {})
//                    }
//                }
//            }
//            button.addTarget(self, action: #selector(self.mock), forControlEvents: .touchUpInside)
//            statusNode.transitionToState(.download(.white), animated: false, completion: {})
        }
    }
    
    @objc func mock() {
        
    }
    
    public func updateRootControllers(showCallsTab: Bool) {
        guard let rootTabController = self.rootTabController else {
            return
        }
        var controllers: [ViewController] = []
        controllers.append(self.contactsController!)
        if showCallsTab {
            controllers.append(self.callListController!)
        }
        controllers.append(self.chatListController!)
        controllers.append(self.accountSettingsController!)
        
        rootTabController.setControllers(controllers, selectedIndex: nil)
    }
    
    public func openChatsSearch() {
        guard let rootTabController = self.rootTabController else {
            return
        }
        
        self.popToRoot(animated: false)
        
        if let index = rootTabController.controllers.index(where: { $0 is ChatListController}) {
            rootTabController.selectedIndex = index
        }
        
        self.chatListController?.activateSearch()
    }
    
    public func openRootCompose() {
        self.chatListController?.composePressed()
    }
    
    public func openRootCamera() {
        guard let controller = self.viewControllers.last as? ViewController else {
            return
        }
        presentedLegacyShortcutCamera(account: self.account, saveCapturedMedia: false, saveEditedPhotos: false, mediaGrouping: true, parentController: controller)
    }
}
