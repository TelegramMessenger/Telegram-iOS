import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class PermissionController : ViewController {
    private var controllerNode: PermissionControllerNode {
        return self.displayNode as! PermissionControllerNode
    }
    
    private let account: Account
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    
    init(account: Account) {
        self.account = account
        self.strings = account.telegramApplicationContext.currentPresentationData.with { $0 }.strings
        self.theme = defaultLightAuthorizationTheme
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = self.theme.statusBarStyle
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = PermissionControllerNode(theme: self.theme, strings: self.strings)
        self.displayNodeDidLoad()
        
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.allow = { [weak self] in
            self?.account.telegramApplicationContext.applicationBindings.openSettings()
        }
        self.controllerNode.next = { [weak self] in
            self?.dismiss(completion: nil)
        }
        self.controllerNode.openPrivacyPolicy = {
            
        }
    }
    
    override func dismiss(completion: (() -> Void)?) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    func updateData(subject: DeviceAccessSubject, currentStatus: AccessType) {
        self.controllerNode.updateData(subject: .notifications, currentStatus: currentStatus)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
