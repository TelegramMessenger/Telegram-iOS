import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ProgressNavigationButtonNode

final class AuthorizationSequencePasswordRecoveryController: ViewController {
    private var controllerNode: AuthorizationSequencePasswordRecoveryControllerNode {
        return self.displayNode as! AuthorizationSequencePasswordRecoveryControllerNode
    }
    
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    var recoverWithCode: ((String) -> Void)?
    var noAccess: (() -> Void)?
    
    var emailPattern: String?
    
    private let hapticFeedback = HapticFeedback()
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.theme.rootController.navigationBar.accentTextColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    init(strings: PresentationStrings, theme: PresentationTheme, back: @escaping () -> Void) {
        self.strings = strings
        self.theme = theme
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = theme.intro.statusBarStyle.style
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePasswordRecoveryControllerNode(strings: self.strings, theme: self.theme)
        self.displayNodeDidLoad()
        
        self.controllerNode.recoverWithCode = { [weak self] _ in
            self?.nextPressed()
        }
        
        self.controllerNode.noAccess = { [weak self] in
            self?.noAccess?()
        }
        
        if let emailPattern = self.emailPattern {
            self.controllerNode.updateData(emailPattern: emailPattern)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateData(emailPattern: String) {
        if self.emailPattern != emailPattern {
            self.emailPattern = emailPattern
            if self.isNodeLoaded {
                self.controllerNode.updateData(emailPattern: emailPattern)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func nextPressed() {
        if self.controllerNode.currentCode.isEmpty {
            hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            self.recoverWithCode?(self.controllerNode.currentCode)
        }
    }
}

