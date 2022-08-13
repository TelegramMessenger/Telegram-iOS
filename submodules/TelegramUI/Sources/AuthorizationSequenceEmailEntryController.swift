import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ProgressNavigationButtonNode

final class AuthorizationSequenceEmailEntryController: ViewController {
    private var controllerNode: AuthorizationSequenceEmailEntryControllerNode {
        return self.displayNode as! AuthorizationSequenceEmailEntryControllerNode
    }
    
    private let presentationData: PresentationData
    
    var proceedWithEmail: ((String) -> Void)?
    var signInWithApple: (() -> Void)?
        
    private let hapticFeedback = HapticFeedback()
    
    private var appleSignInAllowed = false
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
            }
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
        
//        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceEmailEntryControllerNode(strings: self.presentationData.strings, theme: self.presentationData.theme)
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.proceedWithEmail = { [weak self] _ in
            self?.nextPressed()
        }
        
        self.controllerNode.signInWithApple = { [weak self] in
            self?.signInWithApple?()
        }
        
        self.controllerNode.updateData(appleSignInAllowed: self.appleSignInAllowed)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateData(appleSignInAllowed: Bool) {
        var appleSignInAllowed = appleSignInAllowed
        if #available(iOS 13.0, *) {
        } else {
            appleSignInAllowed = false
        }
        if self.appleSignInAllowed != appleSignInAllowed {
            self.appleSignInAllowed = appleSignInAllowed
            if self.isNodeLoaded {
                self.controllerNode.updateData(appleSignInAllowed: appleSignInAllowed)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func nextPressed() {
        if self.controllerNode.currentEmail.isEmpty {
            if self.appleSignInAllowed {
                self.signInWithApple?()
            } else {
                self.hapticFeedback.error()
                self.controllerNode.animateError()
            }
        } else {
            self.proceedWithEmail?(self.controllerNode.currentEmail)
        }
    }
}
