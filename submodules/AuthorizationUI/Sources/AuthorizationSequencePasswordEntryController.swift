import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ProgressNavigationButtonNode

final class AuthorizationSequencePasswordEntryController: ViewController {
    private var controllerNode: AuthorizationSequencePasswordEntryControllerNode {
        return self.displayNode as! AuthorizationSequencePasswordEntryControllerNode
    }
    
    private var validLayout: ContainerViewLayout?
    
    private let presentationData: PresentationData
    
    var loginWithPassword: ((String) -> Void)?
    var forgot: (() -> Void)?
    var reset: (() -> Void)?
    var hint: String?
    
    var didForgotWithNoRecovery: Bool = false {
        didSet {
            if self.didForgotWithNoRecovery != oldValue {
                if self.isNodeLoaded, let hint = self.hint {
                    self.controllerNode.updateData(hint: hint, didForgotWithNoRecovery: didForgotWithNoRecovery, suggestReset: self.suggestReset)
                }
            }
        }
    }
    
    var suggestReset: Bool = false
    
    private let hapticFeedback = HapticFeedback()
    
    var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    init(presentationData: PresentationData, back: @escaping () -> Void) {
        self.presentationData = presentationData
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequencePasswordEntryControllerNode(strings: self.presentationData.strings, theme: self.presentationData.theme)
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.loginWithCode = { [weak self] _ in
            self?.nextPressed()
        }
        
        self.controllerNode.forgot = { [weak self] in
            self?.forgotPressed()
        }
        
        self.controllerNode.reset = { [weak self] in
            self?.resetPressed()
        }
        
        if let hint = self.hint {
            self.controllerNode.updateData(hint: hint, didForgotWithNoRecovery: self.didForgotWithNoRecovery, suggestReset: self.suggestReset)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }
                
        if self.inProgress {
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        }
    }
    
    func updateData(hint: String, suggestReset: Bool) {
        if self.hint != hint || self.suggestReset != suggestReset {
            self.hint = hint
            self.suggestReset = suggestReset
            if self.isNodeLoaded {
                self.controllerNode.updateData(hint: hint, didForgotWithNoRecovery: self.didForgotWithNoRecovery, suggestReset: self.suggestReset)
            }
        }
    }
    
    func passwordIsInvalid() {
        if self.isNodeLoaded {
            self.hapticFeedback.error()
            self.controllerNode.passwordIsInvalid()
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        if !hadLayout {
            self.updateNavigationItems()
        }
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func nextPressed() {
        if self.controllerNode.currentPassword.isEmpty {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            self.loginWithPassword?(self.controllerNode.currentPassword)
        }
    }
    
    func forgotPressed() {
        /*if self.suggestReset {
            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.TwoStepAuth_RecoveryFailed, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        } else*/ if self.didForgotWithNoRecovery {
            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.TwoStepAuth_RecoveryUnavailable, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        } else {
            self.forgot?()
        }
    }
    
    func resetPressed() {
        self.reset?()
    }
}
