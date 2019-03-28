import Foundation
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

import TelegramUIPrivateModule

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
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(mode: .automaticMasterDetail, theme: NavigationControllerTheme(presentationTheme: self.presentationData.theme))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
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
        chatListController.tabBarItem.badgeValue = self.context.sharedContext.switchingData.chatListBadge
        let callListController = CallListController(context: self.context, mode: .tab)
        
        var controllers: [ViewController] = []
        
        let contactsController = ContactsController(context: self.context)
        contactsController.switchToChatsController = {  [weak self] in
            self?.openChatsController(activateSearch: false)
        }
        controllers.append(contactsController)
        
        if showCallsTab {
            controllers.append(callListController)
        }
        controllers.append(chatListController)
        
        let restoreSettignsController = self.context.sharedContext.switchingData.settingsController
        restoreSettignsController?.updateContext(context: self.context)
        self.context.sharedContext.switchingData = (nil, nil, nil)
        
        let accountSettingsController = restoreSettignsController ?? settingsController(context: self.context, accountManager: context.sharedContext.accountManager)
        controllers.append(accountSettingsController)
        
        tabBarController.setControllers(controllers, selectedIndex: restoreSettignsController != nil ? (controllers.count - 1) : (controllers.count - 2))
        
        self.contactsController = contactsController
        self.callListController = callListController
        self.chatListController = chatListController
        self.accountSettingsController = accountSettingsController
        self.rootTabController = tabBarController
        self.pushViewController(tabBarController, animated: false)
        
        
        
        
//        guard let controller = self.viewControllers.last as? ViewController else {
//            return
//        }
//        
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
//            let wrapperNode = ASDisplayNode()
//            let bounds = controller.displayNode.bounds
//            wrapperNode.frame = bounds
//            wrapperNode.backgroundColor = .gray
//            //controller.displayNode.addSubnode(wrapperNode)
//            
//            let label = TGMarqLabel(frame: CGRect())
//            label.textColor = .white
//            label.font = Font.regular(28.0)
//            label.scrollDuration = 15.0
//            label.fadeLength = 25.0
//            label.trailingBuffer = 60.0
//            label.animationDelay = 2.0
//            label.text = "Lorem ipsum dolor sir amet, consecteur"
//            label.sizeToFit()
//            label.frame = CGRect(x: bounds.width / 2.0 - 100.0, y: 100.0, width: 200.0, height: label.frame.height)
//            //wrapperNode.view.addSubview(label)
//            
//            let data = testLineChartData()
//            let node = LineChartContainerNode(data: data)
//            node.frame = CGRect(x: 0.0, y: 100.0, width: bounds.width, height: 280.0)
//            node.updateLayout(size: node.frame.size)
//            wrapperNode.addSubnode(node)
//        
//            self.wNode = wrapperNode
//            
//            let gesture = UITapGestureRecognizer(target: self, action: #selector(self.closeIt))
//            wrapperNode.view.addGestureRecognizer(gesture)
//        }
    }
    
    @objc func closeIt() {
        self.wNode?.removeFromSupernode()
    }
    
    private var wNode: ASDisplayNode?
    
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
    
    public func openChatsController(activateSearch: Bool) {
        guard let rootTabController = self.rootTabController else {
            return
        }
        
        if activateSearch {
            self.popToRoot(animated: false)
        }
        
        if let index = rootTabController.controllers.index(where: { $0 is ChatListController}) {
            rootTabController.selectedIndex = index
        }
        
        if activateSearch {
            self.chatListController?.activateSearch()
        }
    }
    
    public func openRootCompose() {
        self.chatListController?.composePressed()
    }
    
    public func openRootCamera() {
        guard let controller = self.viewControllers.last as? ViewController else {
            return
        }
        controller.view.endEditing(true)
        presentedLegacyShortcutCamera(context: self.context, saveCapturedMedia: false, saveEditedPhotos: false, mediaGrouping: true, parentController: controller)
    }
}
