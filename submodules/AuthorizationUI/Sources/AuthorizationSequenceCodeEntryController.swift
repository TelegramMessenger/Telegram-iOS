import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import ProgressNavigationButtonNode

public final class AuthorizationSequenceCodeEntryController: ViewController {
    private var controllerNode: AuthorizationSequenceCodeEntryControllerNode {
        return self.displayNode as! AuthorizationSequenceCodeEntryControllerNode
    }
    
    private var validLayout: ContainerViewLayout?
    
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    private let openUrl: (String) -> Void
    
    public var loginWithCode: ((String) -> Void)?
    public var signInWithApple: (() -> Void)?
    
    var reset: (() -> Void)?
    var requestNextOption: (() -> Void)?
    
    var data: (String, String?, SentAuthorizationCodeType, AuthorizationCodeNextType?, Int32?)?
    var termsOfService: (UnauthorizedAccountTermsOfService, Bool)?
    
    private let hapticFeedback = HapticFeedback()
    
    private var appleSignInAllowed = false
    
    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    public init(presentationData: PresentationData, openUrl: @escaping (String) -> Void, back: @escaping () -> Void) {
        self.strings = presentationData.strings
        self.theme = presentationData.theme
        self.openUrl = openUrl
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = theme.intro.statusBarStyle.style
                
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = { [weak self] in
            let text: String
            let proceed: String
            let stop: String
            
            if let (_, _, type, _, _) = self?.data, case .email = type {
                text = presentationData.strings.Login_CancelEmailVerification
                proceed = presentationData.strings.Login_CancelEmailVerificationContinue
                stop = presentationData.strings.Login_CancelEmailVerificationStop
            } else {
                text = presentationData.strings.Login_CancelPhoneVerification
                proceed = presentationData.strings.Login_CancelPhoneVerificationContinue
                stop = presentationData.strings.Login_CancelPhoneVerificationStop
            }
            
            self?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: proceed, action: {
            }), TextAlertAction(type: .defaultAction, title: stop, action: {
                back()
            })]), in: .window(.root))
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceCodeEntryControllerNode(strings: self.strings, theme: self.theme)
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.loginWithCode = { [weak self] code in
            self?.continueWithCode(code)
        }
        
        self.controllerNode.signInWithApple = { [weak self] in
            self?.signInWithApple?()
        }
        
        self.controllerNode.requestNextOption = { [weak self] in
            self?.requestNextOption?()
        }
        
        self.controllerNode.requestAnotherOption = { [weak self] in
            self?.requestNextOption?()
        }
        
        self.controllerNode.updateNextEnabled = { [weak self] value in
            self?.navigationItem.rightBarButtonItem?.isEnabled = value
        }
        
        if let (number, email, codeType, nextType, timeout) = self.data {
            var appleSignInAllowed = false
            if case let .email(_, _, _, appleSignInAllowedValue, _) = codeType {
                appleSignInAllowed = appleSignInAllowedValue
            }
            self.controllerNode.updateData(number: number, email: email, codeType: codeType, nextType: nextType, timeout: timeout, appleSignInAllowed: appleSignInAllowed)
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    public func resetCode() {
        self.controllerNode.resetCode()
    }
    
    public func animateSuccess() {
        self.controllerNode.animateSuccess()
    }
    
    public func animateError(text: String) {
        self.hapticFeedback.error()
        self.controllerNode.animateError(text: text)
    }
    
    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }
                
        if self.inProgress {
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.theme.rootController.navigationBar.accentTextColor))
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        }
    }
    
    public func updateData(number: String, email: String?, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?, termsOfService: (UnauthorizedAccountTermsOfService, Bool)?) {
        self.termsOfService = termsOfService
        if self.data?.0 != number || self.data?.1 != email || self.data?.2 != codeType || self.data?.3 != nextType || self.data?.4 != timeout {
            self.data = (number, email, codeType, nextType, timeout)
                        
            var appleSignInAllowed = false
            if case let .email(_, _, _, appleSignInAllowedValue, _) = codeType {
                appleSignInAllowed = appleSignInAllowedValue
            }
            
            if self.isNodeLoaded {
                self.controllerNode.updateData(number: number, email: email, codeType: codeType, nextType: nextType, timeout: timeout, appleSignInAllowed: appleSignInAllowed)
                self.requestLayout(transition: .immediate)
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        if !hadLayout {
            self.updateNavigationItems()
        }
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func nextPressed() {
        guard let (_, _, type, _, _) = self.data else {
            return
        }
        
        var minimalCodeLength = 1
        
        switch type {
            case let .otherSession(length):
                minimalCodeLength = Int(length)
            case let .sms(length):
                minimalCodeLength = Int(length)
            case let .call(length):
                minimalCodeLength = Int(length)
            case let .missedCall(_, length):
                minimalCodeLength = Int(length)
            case let .email(_, length, _, _, _):
                minimalCodeLength = Int(length)
            case .flashCall, .emailSetupRequired:
                break
        }
        
        if self.controllerNode.currentCode.count < minimalCodeLength {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            self.continueWithCode(self.controllerNode.currentCode)
        }
    }
    
    private func continueWithCode(_ code: String) {
        self.loginWithCode?(code)
    }
    
    func applyConfirmationCode(_ code: Int) {
        self.controllerNode.updateCode("\(code)")
    }
}
