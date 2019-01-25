import Foundation
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

public final class TelegramRootController: NavigationController {
    private let context: AccountContext
    
    public var rootTabController: TabBarController?
    
    public var contactsController: ContactsController?
    public var callListController: CallListController?
    public var chatListController: ChatListController?
    public var accountSettingsController: ViewController?
    
    private var permissionsDisposable: Disposable?
    private var presentationDataDisposable: Disposable?
    private var presentationData: PresentationData
    
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.currentPresentationData.with { $0 }
        
        super.init(mode: .automaticMasterDetail, theme: NavigationControllerTheme(presentationTheme: self.presentationData.theme))
        
        self.presentationDataDisposable = (context.presentationData
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
        let chatListController = ChatListController(context: self.context, groupId: nil, controlsHistoryPreload: true)
        let callListController = CallListController(context: self.context, mode: .tab)
        
        var controllers: [ViewController] = []
        
        let contactsController = ContactsController(context: self.context)
        controllers.append(contactsController)
        
        if showCallsTab {
            controllers.append(callListController)
        }
        controllers.append(chatListController)
        
        let restoreSettignsController = self.context.sharedContext.switchingSettingsController
        restoreSettignsController?.updateContext(context: self.context)
        self.context.sharedContext.switchingSettingsController = nil
        
        let accountSettingsController = restoreSettignsController ?? settingsController(context: self.context, accountManager: context.sharedContext.accountManager)
        controllers.append(accountSettingsController)
        
        tabBarController.setControllers(controllers, selectedIndex: restoreSettignsController != nil ? (controllers.count - 1) : (controllers.count - 2))
        
        self.contactsController = contactsController
        self.callListController = callListController
        self.chatListController = chatListController
        self.accountSettingsController = accountSettingsController
        self.rootTabController = tabBarController
        self.pushViewController(tabBarController, animated: false)
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
        presentedLegacyShortcutCamera(context: self.context, saveCapturedMedia: false, saveEditedPhotos: false, mediaGrouping: true, parentController: controller)
    }
}
