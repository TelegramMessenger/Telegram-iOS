import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import ProgressNavigationButtonNode

final class AuthorizationSequenceCodeEntryController: ViewController {
    private var controllerNode: AuthorizationSequenceCodeEntryControllerNode {
        return self.displayNode as! AuthorizationSequenceCodeEntryControllerNode
    }
    
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    private let openUrl: (String) -> Void
    
    var loginWithCode: ((String) -> Void)?
    var reset: (() -> Void)?
    var requestNextOption: (() -> Void)?
    
    var data: (String, SentAuthorizationCodeType, AuthorizationCodeNextType?, Int32?)?
    var termsOfService: (UnauthorizedAccountTermsOfService, Bool)?
    
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
    
    init(presentationData: PresentationData, openUrl: @escaping (String) -> Void, back: @escaping () -> Void) {
        self.strings = presentationData.strings
        self.theme = presentationData.theme
        self.openUrl = openUrl
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = theme.intro.statusBarStyle.style
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = { [weak self] in
            self?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Login_CancelPhoneVerification, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Login_CancelPhoneVerificationContinue, action: {
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Login_CancelPhoneVerificationStop, action: {
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
        
        self.controllerNode.requestNextOption = { [weak self] in
            self?.requestNextOption?()
        }
        
        self.controllerNode.requestAnotherOption = { [weak self] in
            self?.requestNextOption?()
        }
        
        self.controllerNode.updateNextEnabled = { [weak self] value in
            self?.navigationItem.rightBarButtonItem?.isEnabled = value
        }
        
        if let (number, codeType, nextType, timeout) = self.data {
            self.controllerNode.updateData(number: number, codeType: codeType, nextType: nextType, timeout: timeout)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func resetCode() {
        self.controllerNode.resetCode()
    }
    
    func updateData(number: String, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?, termsOfService: (UnauthorizedAccountTermsOfService, Bool)?) {
        self.termsOfService = termsOfService
        if self.data?.0 != number || self.data?.1 != codeType || self.data?.2 != nextType || self.data?.3 != timeout {
            switch codeType {
            case .otherSession, .missedCall:
                self.title = number
            default:
                self.title = nil
            }
            self.data = (number, codeType, nextType, timeout)
            if self.isNodeLoaded {
                self.controllerNode.updateData(number: number, codeType: codeType, nextType: nextType, timeout: timeout)
                self.requestLayout(transition: .immediate)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func nextPressed() {
        guard let (_, type, _, _) = self.data else {
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
            case .flashCall:
                break
            case let .missedCall(_, length):
                minimalCodeLength = Int(length)
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
