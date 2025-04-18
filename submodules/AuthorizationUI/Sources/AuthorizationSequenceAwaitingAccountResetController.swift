import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ProgressNavigationButtonNode

final class AuthorizationSequenceAwaitingAccountResetController: ViewController {
    private var controllerNode: AuthorizationSequenceAwaitingAccountResetControllerNode {
        return self.displayNode as! AuthorizationSequenceAwaitingAccountResetControllerNode
    }
    
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    var logout: (() -> Void)?
    var reset: (() -> Void)?
    
    var protectedUntil: Int32?
    var number: String?
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.theme.rootController.navigationBar.accentTextColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.logoutPressed))
            }
        }
    }
    
    init(strings: PresentationStrings, theme: PresentationTheme, back: @escaping () -> Void) {
        self.strings = strings
        self.theme = theme
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = theme.intro.statusBarStyle.style
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: " ", style: .plain, target: self, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Settings_Logout, style: .plain, target: self, action: #selector(self.logoutPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceAwaitingAccountResetControllerNode(strings: self.strings, theme: self.theme)
        self.displayNodeDidLoad()
        
        self.controllerNode.reset = { [weak self] in
            self?.reset?()
        }
        
        if let protectedUntil = self.protectedUntil, let number = self.number {
            self.controllerNode.updateData(protectedUntil: protectedUntil, number: number)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func updateData(protectedUntil: Int32, number: String) {
        if self.protectedUntil != protectedUntil || self.number != number {
            self.protectedUntil = protectedUntil
            self.number = number
            if self.isNodeLoaded {
                self.controllerNode.updateData(protectedUntil: protectedUntil, number: number)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func logoutPressed() {
        self.logout?()
    }
}
