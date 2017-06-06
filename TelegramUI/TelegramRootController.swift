import Foundation
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

public final class TelegramRootController: NavigationController {
    private let account: Account
    
    public var rootTabController: TabBarController?
    public var chatListController: ChatListController?
    
    private var presentationDataDisposable: Disposable?
    private var presentationData: PresentationData
    
    public init(account: Account) {
        self.account = account
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init()
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData
                if previousTheme !== presentationData.theme {
                    strongSelf.rootTabController?.updateTheme(navigationBarTheme: NavigationBarTheme(rootControllerTheme: presentationData.theme), theme: TabBarControllerTheme(rootControllerTheme: presentationData.theme))
                    strongSelf.rootTabController?.statusBar.statusBarStyle = presentationData.theme.rootController.statusBar.style.style
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    public func addRootControllers() {
        let tabBarController = TabBarController(navigationBarTheme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme), theme: TabBarControllerTheme(rootControllerTheme: self.presentationData.theme))
        let chatListController = ChatListController(account: self.account)
        let callListController = CallListController(account: self.account)
        tabBarController.controllers = [ContactsController(account: self.account), callListController, chatListController, settingsController(account: self.account, accountManager: self.account.telegramApplicationContext.accountManager)]
        self.chatListController = chatListController
        self.rootTabController = tabBarController
        self.pushViewController(tabBarController, animated: false)
    }
}
