import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramCore
import AnimatedStickerNode

public enum TwoFactorDataInputMode {
    case password
    case emailAddress(password: String, hint: String)
    case updateEmailAddress(password: String)
    case emailConfirmation(passwordAndHint: (String, String)?, emailPattern: String, codeLength: Int?)
    case passwordHint(password: String)
}

public final class TwoFactorDataInputScreen: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let mode: TwoFactorDataInputMode
    private let stateUpdated: (SetupTwoStepVerificationStateUpdate) -> Void
    
    public init(context: AccountContext, mode: TwoFactorDataInputMode, stateUpdated: @escaping (SetupTwoStepVerificationStateUpdate) -> Void) {
        self.context = context
        self.mode = mode
        self.stateUpdated = stateUpdated
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let defaultTheme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Common_Back, close: self.presentationData.strings.Common_Close)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TwoFactorDataInputScreenNode(presentationData: self.presentationData, mode: self.mode, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case .password:
                let values = (strongSelf.displayNode as! TwoFactorDataInputScreenNode).inputText
                if values.count != 2 {
                    return
                }
                if values[0] != values[1] {
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.TwoStepAuth_SetupPasswordConfirmFailed, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})
                    ]), in: .window(.root))
                    return
                }
                if values[0].isEmpty {
                    return
                }
                guard let navigationController = strongSelf.navigationController as? NavigationController else {
                    return
                }
                var controllers = navigationController.viewControllers.filter { controller in
                    if controller is TwoFactorAuthSplashScreen {
                        return false
                    }
                    if controller is TwoFactorDataInputScreen && controller !== strongSelf {
                        return false
                    }
                    return true
                }
                controllers.append(TwoFactorDataInputScreen(context: strongSelf.context, mode: .passwordHint(password: values[0]), stateUpdated: strongSelf.stateUpdated))
                navigationController.setViewControllers(controllers, animated: true)
            case let .emailAddress(password, hint):
                guard let text = (strongSelf.displayNode as! TwoFactorDataInputScreenNode).inputText.first, !text.isEmpty else {
                    return
                }
                let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                strongSelf.present(statusController, in: .window(.root))
                
                let _ = (updateTwoStepVerificationPassword(network: strongSelf.context.account.network, currentPassword: "", updatedPassword: .password(password: password, hint: hint, email: text))
                |> deliverOnMainQueue).start(next: { [weak statusController] result in
                    statusController?.dismiss()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    switch result {
                    case .none:
                        break
                    case let .password(_, pendingEmail):
                        if let pendingEmail = pendingEmail {
                            guard let navigationController = strongSelf.navigationController as? NavigationController else {
                                return
                            }
                            var controllers = navigationController.viewControllers.filter { controller in
                                if controller is TwoFactorAuthSplashScreen {
                                    return false
                                }
                                if controller is TwoFactorDataInputScreen {
                                    return false
                                }
                                return true
                            }
                            controllers.append(TwoFactorDataInputScreen(context: strongSelf.context, mode: .emailConfirmation(passwordAndHint: (password, hint), emailPattern: text, codeLength: pendingEmail.codeLength.flatMap(Int.init)), stateUpdated: strongSelf.stateUpdated))
                            navigationController.setViewControllers(controllers, animated: true)
                        } else {
                            guard let navigationController = strongSelf.navigationController as? NavigationController else {
                                return
                            }
                            var controllers = navigationController.viewControllers.filter { controller in
                                if controller is TwoFactorAuthSplashScreen {
                                    return false
                                }
                                if controller is TwoFactorDataInputScreen {
                                    return false
                                }
                                return true
                            }
                            controllers.append(TwoFactorAuthSplashScreen(context: strongSelf.context, mode: .done))
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }
                }, error: { [weak statusController] error in
                    statusController?.dismiss()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let presentationData = strongSelf.presentationData
                    let alertText: String
                    switch error {
                    case .generic:
                        alertText = presentationData.strings.Login_UnknownError
                    case .invalidEmail:
                        alertText = presentationData.strings.TwoStepAuth_EmailInvalid
                    }
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: alertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                })
            case let .updateEmailAddress(password):
                guard let text = (strongSelf.displayNode as! TwoFactorDataInputScreenNode).inputText.first, !text.isEmpty else {
                    return
                }
                let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                strongSelf.present(statusController, in: .window(.root))
                
                let _ = (updateTwoStepVerificationEmail(network: strongSelf.context.account.network, currentPassword: password, updatedEmail: text)
                |> deliverOnMainQueue).start(next: { [weak statusController] result in
                    statusController?.dismiss()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    switch result {
                    case .none:
                        break
                    case let .password(_, pendingEmail):
                        if let pendingEmail = pendingEmail {
                            guard let navigationController = strongSelf.navigationController as? NavigationController else {
                                return
                            }
                            var controllers = navigationController.viewControllers.filter { controller in
                                if controller is TwoFactorAuthSplashScreen {
                                    return false
                                }
                                if controller is TwoFactorDataInputScreen {
                                    return false
                                }
                                return true
                            }
                            controllers.append(TwoFactorDataInputScreen(context: strongSelf.context, mode: .emailConfirmation(passwordAndHint: (password, ""), emailPattern: text, codeLength: pendingEmail.codeLength.flatMap(Int.init)), stateUpdated: strongSelf.stateUpdated))
                            navigationController.setViewControllers(controllers, animated: true)
                        } else {
                            guard let navigationController = strongSelf.navigationController as? NavigationController else {
                                return
                            }
                            var controllers = navigationController.viewControllers.filter { controller in
                                if controller is TwoFactorAuthSplashScreen {
                                    return false
                                }
                                if controller is TwoFactorDataInputScreen {
                                    return false
                                }
                                return true
                            }
                            controllers.append(TwoFactorAuthSplashScreen(context: strongSelf.context, mode: .done))
                            navigationController.setViewControllers(controllers, animated: true)
                        }
                    }
                }, error: { [weak statusController] error in
                    statusController?.dismiss()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let presentationData = strongSelf.presentationData
                    let alertText: String
                    switch error {
                    case .generic:
                        alertText = presentationData.strings.Login_UnknownError
                    case .invalidEmail:
                        alertText = presentationData.strings.TwoStepAuth_EmailInvalid
                    }
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: alertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                })
            case .emailConfirmation:
                guard let text = (strongSelf.displayNode as! TwoFactorDataInputScreenNode).inputText.first, !text.isEmpty else {
                    return
                }
                let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                strongSelf.present(statusController, in: .window(.root))
                
                let _ = (confirmTwoStepRecoveryEmail(network: strongSelf.context.account.network, code: text)
                |> deliverOnMainQueue).start(error: { [weak statusController] error in
                    statusController?.dismiss()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let presentationData = strongSelf.presentationData
                    let text: String
                    switch error {
                    case .invalidEmail:
                        text = presentationData.strings.TwoStepAuth_EmailInvalid
                    case .invalidCode:
                        text = presentationData.strings.Login_InvalidCodeError
                    case .expired:
                        text = presentationData.strings.TwoStepAuth_EmailCodeExpired
                    case .flood:
                        text = presentationData.strings.TwoStepAuth_FloodError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                    }
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }, completed: { [weak statusController] in
                    statusController?.dismiss()
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    guard let navigationController = strongSelf.navigationController as? NavigationController else {
                        return
                    }
                    var controllers = navigationController.viewControllers.filter { controller in
                        if controller is TwoFactorAuthSplashScreen {
                            return false
                        }
                        if controller is TwoFactorDataInputScreen {
                            return false
                        }
                        return true
                    }
                    controllers.append(TwoFactorAuthSplashScreen(context: strongSelf.context, mode: .done))
                    navigationController.setViewControllers(controllers, animated: true)
                })
            case let .passwordHint(password):
                guard let value = (strongSelf.displayNode as! TwoFactorDataInputScreenNode).inputText.first, !value.isEmpty else {
                    return
                }
                
                strongSelf.push(TwoFactorDataInputScreen(context: strongSelf.context, mode: .emailAddress(password: password, hint: value), stateUpdated: strongSelf.stateUpdated))
            }
        }, skipAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case let .emailAddress(password, hint):
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.TwoFactorSetup_Email_SkipConfirmationTitle, text: strongSelf.presentationData.strings.TwoFactorSetup_Email_SkipConfirmationText, actions: [
                    TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.TwoFactorSetup_Email_SkipConfirmationSkip, action: {
                        guard let strongSelf = self else {
                            return
                        }
                        let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                        strongSelf.present(statusController, in: .window(.root))
                        
                        let _ = (updateTwoStepVerificationPassword(network: strongSelf.context.account.network, currentPassword: "", updatedPassword: .password(password: password, hint: hint, email: nil))
                        |> deliverOnMainQueue).start(next: { [weak statusController] result in
                            statusController?.dismiss()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            
                            switch result {
                            case .none:
                                break
                            case .password:
                                guard let navigationController = strongSelf.navigationController as? NavigationController else {
                                    return
                                }
                                var controllers = navigationController.viewControllers.filter { controller in
                                    if controller is TwoFactorAuthSplashScreen {
                                        return false
                                    }
                                    if controller is TwoFactorDataInputScreen {
                                        return false
                                    }
                                    return true
                                }
                                controllers.append(TwoFactorAuthSplashScreen(context: strongSelf.context, mode: .done))
                                navigationController.setViewControllers(controllers, animated: true)
                            }
                        }, error: { [weak statusController] error in
                            statusController?.dismiss()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            
                            let presentationData = strongSelf.presentationData
                            let alertText: String
                            switch error {
                            case .generic:
                                alertText = presentationData.strings.Login_UnknownError
                            case .invalidEmail:
                                alertText = presentationData.strings.TwoStepAuth_EmailInvalid
                            }
                            strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: alertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        })
                    }),
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {})
                ]), in: .window(.root))
            case let .passwordHint(password):
                strongSelf.push(TwoFactorDataInputScreen(context: strongSelf.context, mode: .emailAddress(password: password, hint: ""), stateUpdated: strongSelf.stateUpdated))
            default:
                break
            }
        }, changeEmailAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case let .emailConfirmation(passwordAndHint, _, _):
                if let (password, hint) = passwordAndHint {
                    guard let navigationController = strongSelf.navigationController as? NavigationController else {
                        return
                    }
                    var controllers = navigationController.viewControllers.filter { controller in
                        if controller is TwoFactorAuthSplashScreen {
                            return false
                        }
                        if controller is TwoFactorDataInputScreen {
                            return false
                        }
                        return true
                    }
                    controllers.append(TwoFactorDataInputScreen(context: strongSelf.context, mode: .emailAddress(password: password, hint: hint), stateUpdated: strongSelf.stateUpdated))
                    navigationController.setViewControllers(controllers, animated: true)
                } else {
                }
            default:
                break
            }
        }, resendCodeAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
            strongSelf.present(statusController, in: .window(.root))
            
            let _ = (resendTwoStepRecoveryEmail(network: strongSelf.context.account.network)
            |> deliverOnMainQueue).start(error: { [weak statusController] error in
                statusController?.dismiss()
                
                guard let strongSelf = self else {
                    return
                }
                
                let text: String
                switch error {
                case .flood:
                    text = strongSelf.presentationData.strings.TwoStepAuth_FloodError
                case .generic:
                    text = strongSelf.presentationData.strings.Login_UnknownError
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }, completed: { [weak statusController] in
                statusController?.dismiss()
            })
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! TwoFactorDataInputScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private enum TwoFactorDataInputTextNodeType {
    case password(confirmation: Bool)
    case email
    case code
    case hint
}

private func generateClearImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        context.setStrokeColor(UIColor.clear.cgColor)
        context.setLineCap(.round)
        context.setLineWidth(1.66)
        context.move(to: CGPoint(x: 5.5, y: 5.5))
        context.addLine(to: CGPoint(x: 10.5, y: 10.5))
        context.strokePath()
        context.move(to: CGPoint(x: size.width - 5.5, y: 5.5))
        context.addLine(to: CGPoint(x: size.width - 10.5, y: 10.5))
        context.strokePath()
    })
}

private func generateTextHiddenImage(color: UIColor, on: Bool) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 18.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        guard let image = generateTintedImage(image: UIImage(bundleImageName: "PasswordSetup/TextHidden"), color: color) else {
            return
        }
        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - size.width) / 2.0), y: floor((size.height - size.height) / 2.0)), size: size))
        if !on {
            context.setLineCap(.round)
            
            context.setBlendMode(.copy)
            context.setStrokeColor(UIColor.clear.cgColor)
            context.setLineWidth(4.0)
            context.move(to: CGPoint(x: 2.0, y: 3.0))
            context.addLine(to: CGPoint(x: 18.0, y: 17.0))
            context.strokePath()
            
            context.setBlendMode(.normal)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: 2.0, y: 3.0))
            context.addLine(to: CGPoint(x: 18.0, y: 17.0))
            context.strokePath()
        }
    })
}

private final class TwoFactorDataInputTextNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    let mode: TwoFactorDataInputTextNodeType
    private let focusUpdated: (TwoFactorDataInputTextNode, Bool) -> Void
    private let next: (TwoFactorDataInputTextNode) -> Void
    private let updated: (TwoFactorDataInputTextNode) -> Void
    private let toggleTextHidden: (TwoFactorDataInputTextNode) -> Void
    
    private let backgroundNode: ASImageNode
    private let inputNode: TextFieldNode
    private let hideButtonNode: HighlightableButtonNode
    private let clearButtonNode: HighlightableButtonNode
    
    fileprivate var ignoreTextChanged: Bool = false
    
    var isFocused: Bool {
        return self.inputNode.textField.isFirstResponder
    }
    
    var text: String {
        get {
            return self.inputNode.textField.text ?? ""
        } set(value) {
            self.inputNode.textField.text = value
            self.textFieldChanged(self.inputNode.textField)
        }
    }
    
    init(theme: PresentationTheme, mode: TwoFactorDataInputTextNodeType, placeholder: String, focusUpdated: @escaping (TwoFactorDataInputTextNode, Bool) -> Void, next: @escaping (TwoFactorDataInputTextNode) -> Void, updated: @escaping (TwoFactorDataInputTextNode) -> Void, toggleTextHidden: @escaping (TwoFactorDataInputTextNode) -> Void) {
        self.theme = theme
        self.mode = mode
        self.focusUpdated = focusUpdated
        self.next = next
        self.updated = updated
        self.toggleTextHidden = toggleTextHidden
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: theme.list.freePlainInputField.backgroundColor)
        
        self.inputNode = TextFieldNode()
        self.inputNode.textField.font = Font.regular(17.0)
        self.inputNode.textField.textColor = theme.list.freePlainInputField.primaryColor
        self.inputNode.textField.attributedPlaceholder = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: theme.list.freePlainInputField.placeholderColor)
        
        self.hideButtonNode = HighlightableButtonNode()
        
        switch mode {
        case let .password(confirmation):
            self.inputNode.textField.keyboardType = .default
            self.inputNode.textField.isSecureTextEntry = true
            if confirmation {
                self.inputNode.textField.returnKeyType = .done
            } else {
                self.inputNode.textField.returnKeyType = .next
            }
            self.hideButtonNode.isHidden = confirmation
        case .email:
            self.inputNode.textField.keyboardType = .emailAddress
            self.inputNode.textField.returnKeyType = .done
            self.hideButtonNode.isHidden = true
        case .code:
            self.inputNode.textField.keyboardType = .numberPad
            self.inputNode.textField.returnKeyType = .done
            self.hideButtonNode.isHidden = true
        case .hint:
            self.inputNode.textField.keyboardType = .asciiCapable
            self.inputNode.textField.returnKeyType = .done
            self.hideButtonNode.isHidden = true
        }
        
        self.inputNode.textField.autocorrectionType = .no
        self.inputNode.textField.autocapitalizationType = .none
        self.inputNode.textField.spellCheckingType = .no
        if #available(iOS 11.0, *) {
            self.inputNode.textField.smartQuotesType = .no
            self.inputNode.textField.smartDashesType = .no
            self.inputNode.textField.smartInsertDeleteType = .no
        }
        self.inputNode.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        
        self.hideButtonNode.setImage(generateTextHiddenImage(color: theme.list.freePlainInputField.controlColor, on: false), for: [])
        
        self.clearButtonNode = HighlightableButtonNode()
        self.clearButtonNode.setImage(generateClearImage(color: theme.list.freePlainInputField.controlColor), for: [])
        self.clearButtonNode.isHidden = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.inputNode)
        self.addSubnode(self.hideButtonNode)
        
        self.inputNode.textField.delegate = self
        self.inputNode.textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
        
        self.hideButtonNode.addTarget(self, action: #selector(self.hidePressed), forControlEvents: .touchUpInside)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let text = self.text
        
        if self.inputNode.textField.isSecureTextEntry {
            let previousIgnoreTextChanged = self.ignoreTextChanged
            self.ignoreTextChanged = true
            self.inputNode.textField.text = ""
            self.inputNode.textField.insertText(text + " ")
            self.inputNode.textField.deleteBackward()
            self.ignoreTextChanged = previousIgnoreTextChanged
        }
        
        self.focusUpdated(self, true)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.focusUpdated(self, false)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.next(self)
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return true
    }
    
    @objc private func textFieldChanged(_ textField: UITextField) {
        if !self.ignoreTextChanged {
            switch self.mode {
            case .password:
                break
            default:
                self.clearButtonNode.isHidden = self.text.isEmpty
            }
            self.updated(self)
        }
    }
    
    @objc private func hidePressed() {
        switch self.mode {
        case .password:
            self.toggleTextHidden(self)
        default:
            break
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let leftInset: CGFloat = 16.0
        let rightInset: CGFloat = 38.0
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.inputNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: size.width - leftInset - rightInset, height: size.height)))
        transition.updateFrame(node: self.hideButtonNode, frame: CGRect(origin: CGPoint(x: size.width - rightInset - 4.0, y: 0.0), size: CGSize(width: rightInset + 4.0, height: size.height)))
        transition.updateFrame(node: self.clearButtonNode, frame: CGRect(origin: CGPoint(x: size.width - rightInset - 4.0, y: 0.0), size: CGSize(width: rightInset + 4.0, height: size.height)))
    }
    
    func focus() {
        self.inputNode.textField.becomeFirstResponder()
    }
    
    func updateTextHidden(_ value: Bool) {
        self.hideButtonNode.setImage(generateTextHiddenImage(color: self.theme.actionSheet.inputClearButtonColor, on: !value), for: [])
        let text = self.inputNode.textField.text ?? ""
        self.inputNode.textField.isSecureTextEntry = value
        if value {
            if self.inputNode.textField.isFirstResponder {
                let previousIgnoreTextChanged = self.ignoreTextChanged
                self.ignoreTextChanged = true
                self.inputNode.textField.text = ""
                self.inputNode.textField.becomeFirstResponder()
                self.inputNode.textField.insertText(text + " ")
                self.inputNode.textField.deleteBackward()
                self.ignoreTextChanged = previousIgnoreTextChanged
            }
        }
    }
}

private final class TwoFactorDataInputScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private var presentationData: PresentationData
    private let mode: TwoFactorDataInputMode
    private let action: () -> Void
    private let skipAction: () -> Void
    private let changeEmailAction: () -> Void
    private let resendCodeAction: () -> Void
    
    private let navigationBackgroundNode: ASDisplayNode
    private let navigationSeparatorNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    private var animatedStickerNode: AnimatedStickerNode?
    private var monkeyNode: ManagedMonkeyAnimationNode?
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let skipActionTitleNode: ImmediateTextNode
    private let skipActionButtonNode: HighlightTrackingButtonNode
    private let changeEmailActionTitleNode: ImmediateTextNode
    private let changeEmailActionButtonNode: HighlightTrackingButtonNode
    private let resendCodeActionTitleNode: ImmediateTextNode
    private let resendCodeActionButtonNode: HighlightTrackingButtonNode
    private let inputNodes: [TwoFactorDataInputTextNode]
    private let buttonNode: SolidRoundedButtonNode
    
    private var navigationHeight: CGFloat?
    
    var inputText: [String] {
        return self.inputNodes.map { $0.text }
    }
    
    init(presentationData: PresentationData, mode: TwoFactorDataInputMode, action: @escaping () -> Void, skipAction: @escaping () -> Void, changeEmailAction: @escaping () -> Void, resendCodeAction: @escaping () -> Void) {
        self.presentationData = presentationData
        self.mode = mode
        self.action = action
        self.skipAction = skipAction
        self.changeEmailAction = changeEmailAction
        self.resendCodeAction = resendCodeAction
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.navigationBackgroundNode.alpha = 0.0
        self.navigationSeparatorNode = ASDisplayNode()
        self.navigationSeparatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.canCancelAllTouchesInViews = true
        
        switch mode {
        case .password, .emailAddress, .updateEmailAddress:
            self.monkeyNode = ManagedMonkeyAnimationNode()
        case .emailConfirmation:
            if let path = getAppBundle().path(forResource: "TwoFactorSetupMail", ofType: "tgs") {
                let animatedStickerNode = AnimatedStickerNode()
                animatedStickerNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 272, height: 272, playbackMode: .once, mode: .direct)
                animatedStickerNode.visibility = true
                self.animatedStickerNode = animatedStickerNode
            }
        case .passwordHint:
            if let path = getAppBundle().path(forResource: "TwoFactorSetupHint", ofType: "tgs") {
                let animatedStickerNode = AnimatedStickerNode()
                animatedStickerNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 272, height: 272, playbackMode: .once, mode: .direct)
                animatedStickerNode.visibility = true
                self.animatedStickerNode = animatedStickerNode
            }
        }
        
        let title: String
        let text: NSAttributedString
        let buttonText: String
        let skipActionText: String
        let changeEmailActionText: String
        let resendCodeActionText: String
        
        var inputNodes: [TwoFactorDataInputTextNode] = []
        var next: ((TwoFactorDataInputTextNode) -> Void)?
        var focusUpdated: ((TwoFactorDataInputTextNode, Bool) -> Void)?
        var updated: ((TwoFactorDataInputTextNode) -> Void)?
        var toggleTextHidden: ((TwoFactorDataInputTextNode) -> Void)?
        
        switch mode {
        case .password:
            title = presentationData.strings.TwoFactorSetup_Password_Title
            text = NSAttributedString(string: "", font: Font.regular(16.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            buttonText = presentationData.strings.TwoFactorSetup_Password_Action
            skipActionText = ""
            changeEmailActionText = ""
            resendCodeActionText = ""
            inputNodes = [
                TwoFactorDataInputTextNode(theme: presentationData.theme, mode: .password(confirmation: false), placeholder: presentationData.strings.TwoFactorSetup_Password_PlaceholderPassword, focusUpdated: { node, focused in
                    focusUpdated?(node, focused)
                }, next: { node in
                    next?(node)
                }, updated: { node in
                    updated?(node)
                }, toggleTextHidden: { node in
                    toggleTextHidden?(node)
                }),
                TwoFactorDataInputTextNode(theme: presentationData.theme, mode: .password(confirmation: true), placeholder: presentationData.strings.TwoFactorSetup_Password_PlaceholderConfirmPassword, focusUpdated: { node, focused in
                    focusUpdated?(node, focused)
                }, next: { node in
                    next?(node)
                }, updated: { node in
                    updated?(node)
                }, toggleTextHidden: { node in
                    toggleTextHidden?(node)
                })
            ]
        case .emailAddress, .updateEmailAddress:
            title = presentationData.strings.TwoFactorSetup_Email_Title
            text = NSAttributedString(string: presentationData.strings.TwoFactorSetup_Email_Text, font: Font.regular(16.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            buttonText = presentationData.strings.TwoFactorSetup_Email_Action
            skipActionText = presentationData.strings.TwoFactorSetup_Email_SkipAction
            changeEmailActionText = ""
            resendCodeActionText = ""
            inputNodes = [
                TwoFactorDataInputTextNode(theme: presentationData.theme, mode: .email, placeholder: presentationData.strings.TwoFactorSetup_Email_Placeholder, focusUpdated: { node, focused in
                    focusUpdated?(node, focused)
                }, next: { node in
                    next?(node)
                }, updated: { node in
                    updated?(node)
                }, toggleTextHidden: { node in
                    toggleTextHidden?(node)
                }),
            ]
        case let .emailConfirmation(_, emailPattern, _):
            title = presentationData.strings.TwoFactorSetup_EmailVerification_Title
            let (rawText, ranges) = presentationData.strings.TwoFactorSetup_EmailVerification_Text(emailPattern)

            let string = NSMutableAttributedString()
            string.append(NSAttributedString(string: rawText, font: Font.regular(16.0), textColor: presentationData.theme.list.itemPrimaryTextColor))
            for (_, range) in ranges {
                string.addAttribute(.font, value: Font.semibold(16.0), range: range)
            }
            
            text = string
            
            buttonText = presentationData.strings.TwoFactorSetup_EmailVerification_Action
            skipActionText = ""
            changeEmailActionText = presentationData.strings.TwoFactorSetup_EmailVerification_ChangeAction
            resendCodeActionText = presentationData.strings.TwoFactorSetup_EmailVerification_ResendAction
            inputNodes = [
                TwoFactorDataInputTextNode(theme: presentationData.theme, mode: .code, placeholder: presentationData.strings.TwoFactorSetup_EmailVerification_Placeholder, focusUpdated: { node, focused in
                    focusUpdated?(node, focused)
                }, next: { node in
                    next?(node)
                }, updated: { node in
                    updated?(node)
                }, toggleTextHidden: { node in
                    toggleTextHidden?(node)
                }),
            ]
        case .passwordHint:
            title = presentationData.strings.TwoFactorSetup_Hint_Title
            
            text = NSAttributedString(string: presentationData.strings.TwoFactorSetup_Hint_Text, font: Font.regular(16.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            
            buttonText = presentationData.strings.TwoFactorSetup_Hint_Action
            skipActionText = presentationData.strings.TwoFactorSetup_Hint_SkipAction
            changeEmailActionText = ""
            resendCodeActionText = ""
            inputNodes = [
                TwoFactorDataInputTextNode(theme: presentationData.theme, mode: .hint, placeholder: presentationData.strings.TwoFactorSetup_Hint_Placeholder, focusUpdated: { node, focused in
                    focusUpdated?(node, focused)
                }, next: { node in
                    next?(node)
                }, updated: { node in
                    updated?(node)
                }, toggleTextHidden: { node in
                    toggleTextHidden?(node)
                }),
            ]
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(28.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = text
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.skipActionTitleNode = ImmediateTextNode()
        self.skipActionTitleNode.isUserInteractionEnabled = false
        self.skipActionTitleNode.displaysAsynchronously = false
        self.skipActionTitleNode.attributedText = NSAttributedString(string: skipActionText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemAccentColor)
        self.skipActionButtonNode = HighlightTrackingButtonNode()
        self.skipActionTitleNode.isHidden = skipActionText.isEmpty
        self.skipActionButtonNode.isHidden = skipActionText.isEmpty
        
        self.changeEmailActionTitleNode = ImmediateTextNode()
        self.changeEmailActionTitleNode.isUserInteractionEnabled = false
        self.changeEmailActionTitleNode.displaysAsynchronously = false
        self.changeEmailActionTitleNode.attributedText = NSAttributedString(string: changeEmailActionText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemAccentColor)
        self.changeEmailActionButtonNode = HighlightTrackingButtonNode()
        self.changeEmailActionButtonNode.isHidden = changeEmailActionText.isEmpty
        self.changeEmailActionButtonNode.isHidden = changeEmailActionText.isEmpty
        
        self.resendCodeActionTitleNode = ImmediateTextNode()
        self.resendCodeActionTitleNode.isUserInteractionEnabled = false
        self.resendCodeActionTitleNode.displaysAsynchronously = false
        self.resendCodeActionTitleNode.attributedText = NSAttributedString(string: resendCodeActionText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemAccentColor)
        self.resendCodeActionButtonNode = HighlightTrackingButtonNode()
        self.resendCodeActionTitleNode.isHidden = resendCodeActionText.isEmpty
        self.resendCodeActionButtonNode.isHidden = resendCodeActionText.isEmpty
        
        self.inputNodes = inputNodes
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.scrollNode)
        
        self.animatedStickerNode.flatMap(self.scrollNode.addSubnode)
        self.monkeyNode.flatMap(self.scrollNode.addSubnode)
        self.scrollNode.addSubnode(self.titleNode)
        self.scrollNode.addSubnode(self.textNode)
        self.scrollNode.addSubnode(self.skipActionTitleNode)
        self.scrollNode.addSubnode(self.skipActionButtonNode)
        self.scrollNode.addSubnode(self.changeEmailActionTitleNode)
        self.scrollNode.addSubnode(self.changeEmailActionButtonNode)
        self.scrollNode.addSubnode(self.resendCodeActionTitleNode)
        self.scrollNode.addSubnode(self.resendCodeActionButtonNode)
        self.scrollNode.addSubnode(self.buttonNode)
        
        for (inputNode) in self.inputNodes {
            self.scrollNode.addSubnode(inputNode)
        }
        
        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.addSubnode(self.navigationBackgroundNode)
        
        self.buttonNode.pressed = {
            action()
        }
        
        self.skipActionButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.skipActionTitleNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.skipActionTitleNode.alpha = 0.4
            } else {
                strongSelf.skipActionTitleNode.alpha = 1.0
                strongSelf.skipActionTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.skipActionButtonNode.addTarget(self, action: #selector(self.skipActionPressed), forControlEvents: .touchUpInside)
        
        self.changeEmailActionButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.changeEmailActionTitleNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.changeEmailActionTitleNode.alpha = 0.4
            } else {
                strongSelf.changeEmailActionTitleNode.alpha = 1.0
                strongSelf.changeEmailActionTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.changeEmailActionButtonNode.addTarget(self, action: #selector(self.changeEmailActionPressed), forControlEvents: .touchUpInside)
        
        self.resendCodeActionButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.resendCodeActionTitleNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.resendCodeActionTitleNode.alpha = 0.4
            } else {
                strongSelf.resendCodeActionTitleNode.alpha = 1.0
                strongSelf.resendCodeActionTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.resendCodeActionButtonNode.addTarget(self, action: #selector(self.resendCodeActionPressed), forControlEvents: .touchUpInside)
        
        next = { [weak self] node in
            guard let strongSelf = self else {
                return
            }
            if let index = strongSelf.inputNodes.index(where: { $0 === node }) {
                if index == strongSelf.inputNodes.count - 1 {
                    strongSelf.action()
                } else if strongSelf.buttonNode.isUserInteractionEnabled {
                    strongSelf.inputNodes[index + 1].focus()
                }
            }
        }
        var textHidden = true
        let updateAnimations: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case .password:
                if strongSelf.inputNodes[1].isFocused {
                    let textLength = strongSelf.inputNodes[1].text.count
                    let maxWidth = strongSelf.inputNodes[1].bounds.width
                    
                    let textNode = ImmediateTextNode()
                    textNode.attributedText = NSAttributedString(string: strongSelf.inputNodes[1].text, font: Font.regular(17.0), textColor: .black)
                    let textSize = textNode.updateLayout(CGSize(width: 1000.0, height: 100.0))
                    
                    let maxTextLength = 20
                    var trackingOffset = textSize.width / maxWidth
                    trackingOffset = max(0.0, min(1.0, trackingOffset))
                    strongSelf.monkeyNode?.setState(.tracking(trackingOffset))
                } else if strongSelf.inputNodes[0].isFocused {
                    let hasText = !strongSelf.inputNodes[0].text.isEmpty
                    if !hasText {
                        strongSelf.monkeyNode?.setState(.idle(.still))
                    } else if textHidden {
                        strongSelf.monkeyNode?.setState(.eyesClosed)
                    } else {
                        strongSelf.monkeyNode?.setState(.peeking)
                    }
                } else {
                    strongSelf.monkeyNode?.setState(.idle(.still))
                }
            case .emailAddress:
                if strongSelf.inputNodes[0].isFocused {
                    let textLength = strongSelf.inputNodes[0].text.count
                    let maxWidth = strongSelf.inputNodes[0].bounds.width
                    
                    let textNode = ImmediateTextNode()
                    textNode.attributedText = NSAttributedString(string: strongSelf.inputNodes[0].text, font: Font.regular(17.0), textColor: .black)
                    let textSize = textNode.updateLayout(CGSize(width: 1000.0, height: 100.0))
                    
                    let maxTextLength = 20
                    var trackingOffset = textSize.width / maxWidth
                    trackingOffset = max(0.0, min(1.0, trackingOffset))
                    strongSelf.monkeyNode?.setState(.tracking(trackingOffset))
                } else {
                    strongSelf.monkeyNode?.setState(.idle(.still))
                }
            default:
                break
            }
        }
        focusUpdated = { [weak self] node, _ in
            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                updateAnimations()
            }
        }
        updated = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case .emailAddress, .updateEmailAddress:
                let hasText = strongSelf.inputNodes.contains(where: { !$0.text.isEmpty })
                strongSelf.buttonNode.isHidden = !hasText
                strongSelf.skipActionTitleNode.isHidden = hasText
                strongSelf.skipActionButtonNode.isHidden = hasText
            case let .emailConfirmation(_, _, codeLength):
                let text = strongSelf.inputNodes[0].text
                let hasText = !text.isEmpty
                strongSelf.buttonNode.isHidden = !hasText
                strongSelf.changeEmailActionTitleNode.isHidden = hasText
                strongSelf.changeEmailActionButtonNode.isHidden = hasText
                strongSelf.resendCodeActionTitleNode.isHidden = hasText
                strongSelf.resendCodeActionButtonNode.isHidden = hasText
                
                if let codeLength = codeLength, text.count == codeLength {
                    action()
                }
            case .passwordHint:
                let hasText = strongSelf.inputNodes.contains(where: { !$0.text.isEmpty })
                strongSelf.buttonNode.isHidden = !hasText
                strongSelf.skipActionTitleNode.isHidden = hasText
                strongSelf.skipActionButtonNode.isHidden = hasText
            case .password:
                break
            }
            updateAnimations()
        }
        toggleTextHidden = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case .password:
                textHidden = !textHidden
                for node in strongSelf.inputNodes {
                    node.updateTextHidden(textHidden)
                }
            default:
                break
            }
            updateAnimations()
        }
        self.inputNodes.first.flatMap { updated?($0) }
    }
    
    @objc private func skipActionPressed() {
        self.skipAction()
    }
    
    @objc private func changeEmailActionPressed() {
        self.changeEmailAction()
    }
    
    @objc private func resendCodeActionPressed() {
        self.resendCodeAction()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.keyboardDismissMode = .none
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        //self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.delegate = self
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.navigationHeight = navigationHeight
        
        let contentAreaSize = layout.size
        let availableAreaSize = CGSize(width: layout.size.width, height: layout.size.height - layout.insets(options: [.input]).bottom)
        
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat
        switch self.mode {
        case .passwordHint, .emailConfirmation:
            iconSpacing = 6.0
        default:
            iconSpacing = 2.0
        }
        let titleSpacing: CGFloat = 19.0
        let titleInputSpacing: CGFloat = 26.0
        let textSpacing: CGFloat = 30.0
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 20.0
        let rowSpacing: CGFloat = 20.0
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: contentAreaSize.width, height: navigationHeight)))
        transition.updateFrame(node: self.navigationSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: contentAreaSize.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: contentAreaSize))
        
        let iconSize: CGSize
        if let animatedStickerNode = self.animatedStickerNode {
            iconSize = CGSize(width: 136.0, height: 136.0)
        } else if let monkeyNode = self.monkeyNode {
            iconSize = monkeyNode.intrinsicSize
        } else {
            iconSize = CGSize(width: 100.0, height: 100.0)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        let textSize = self.textNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        let skipActionSize = self.skipActionTitleNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        let changeEmailActionSize = self.changeEmailActionTitleNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        let resendCodeActionSize = self.resendCodeActionTitleNode.updateLayout(CGSize(width: contentAreaSize.width - sideInset * 2.0, height: contentAreaSize.height))
        
        var calculatedContentHeight = iconSize.height + iconSpacing + titleSize.height
        if textSize.width.isZero {
            calculatedContentHeight += titleInputSpacing
        } else {
            calculatedContentHeight += titleSpacing + textSize.height + textSpacing
        }
        for i in 0 ..< self.inputNodes.count {
            if i != 0 {
                calculatedContentHeight += rowSpacing
            }
            calculatedContentHeight += 50.0
        }
        calculatedContentHeight += buttonHeight + buttonSpacing
        
        var contentHeight: CGFloat = 0.0
        
        let insets = layout.insets(options: [.input])
        let areaHeight = layout.size.height - insets.top - insets.bottom
        let contentVerticalOrigin = max(layout.statusBarHeight ?? 0.0, floor((areaHeight - calculatedContentHeight) / 2.0))
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize)
        if let animatedStickerNode = self.animatedStickerNode {
            animatedStickerNode.updateLayout(size: iconFrame.size)
            transition.updateFrame(node: animatedStickerNode, frame: iconFrame)
        } else if let monkeyNode = self.monkeyNode {
            transition.updateFrame(node: monkeyNode, frame: iconFrame)
        }
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        let textFrame: CGRect
        if textSize.width.isZero {
            textFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - textSize.width) / 2.0), y: titleFrame.maxY), size: textSize)
        } else {
            textFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        }
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        contentHeight = textFrame.maxY
        if textSize.width.isZero {
            contentHeight += titleInputSpacing
        } else {
            contentHeight += textSpacing
        }
        
        let rowWidth = contentAreaSize.width - buttonSideInset * 2.0
        
        for i in 0 ..< self.inputNodes.count {
            let inputNode = self.inputNodes[i]
            if i != 0 {
                contentHeight += rowSpacing
            }
            let inputNodeSize = CGSize(width: rowWidth, height: 50.0)
            transition.updateFrame(node: inputNode, frame: CGRect(origin: CGPoint(x: buttonSideInset, y: contentHeight), size: inputNodeSize))
            inputNode.updateLayout(size: inputNodeSize, transition: transition)
            contentHeight += inputNodeSize.height
        }
        
        let minimalBottomInset: CGFloat = 74.0
        let buttonBottomInset = layout.intrinsicInsets.bottom + minimalBottomInset
        let bottomInset = layout.intrinsicInsets.bottom + buttonSpacing
        
        let buttonWidth = contentAreaSize.width - buttonSideInset * 2.0
        
        let maxButtonY = min(areaHeight - buttonSpacing, layout.size.height - buttonBottomInset) - buttonHeight
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((contentAreaSize.width - buttonWidth) / 2.0), y: max(contentHeight + buttonSpacing, maxButtonY)), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        transition.updateFrame(node: self.skipActionButtonNode, frame: buttonFrame)
        transition.updateFrame(node: self.skipActionTitleNode, frame: CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - skipActionSize.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - skipActionSize.height) / 2.0)), size: skipActionSize))
        
        let changeEmailActionFrame: CGRect
        let changeEmailActionButtonFrame: CGRect
        let resendCodeActionFrame: CGRect
        let resendCodeActionButtonFrame: CGRect
        if changeEmailActionSize.width + resendCodeActionSize.width > layout.size.width - 24.0 {
            changeEmailActionButtonFrame = CGRect(origin: CGPoint(x: buttonFrame.minX, y: buttonFrame.minY), size: CGSize(width: buttonFrame.width, height: buttonFrame.height))
            changeEmailActionFrame = CGRect(origin: CGPoint(x: changeEmailActionButtonFrame.minX + floor((changeEmailActionButtonFrame.width - changeEmailActionSize.width) / 2.0), y: changeEmailActionButtonFrame.minY + floor((changeEmailActionButtonFrame.height - changeEmailActionSize.height) / 2.0)), size: changeEmailActionSize)
            resendCodeActionButtonFrame = CGRect(origin: CGPoint(x: buttonFrame.minX, y: buttonFrame.maxY), size: CGSize(width: buttonFrame.width, height: buttonFrame.height))
            resendCodeActionFrame = CGRect(origin: CGPoint(x: resendCodeActionButtonFrame.minX + floor((resendCodeActionButtonFrame.width - resendCodeActionSize.width) / 2.0), y: resendCodeActionButtonFrame.minY + floor((resendCodeActionButtonFrame.height - resendCodeActionSize.height) / 2.0)), size: resendCodeActionSize)
        } else {
            changeEmailActionButtonFrame = CGRect(origin: CGPoint(x: buttonFrame.minX, y: buttonFrame.minY), size: CGSize(width: floor(buttonFrame.width / 2.0), height: buttonFrame.height))
            changeEmailActionFrame = CGRect(origin: CGPoint(x: changeEmailActionButtonFrame.minX, y: changeEmailActionButtonFrame.minY + floor((changeEmailActionButtonFrame.height - changeEmailActionSize.height) / 2.0)), size: changeEmailActionSize)
            resendCodeActionButtonFrame = CGRect(origin: CGPoint(x: buttonFrame.maxX - floor(buttonFrame.width / 2.0), y: buttonFrame.minY), size: CGSize(width: floor(buttonFrame.width / 2.0), height: buttonFrame.height))
            resendCodeActionFrame = CGRect(origin: CGPoint(x: resendCodeActionButtonFrame.maxX - resendCodeActionSize.width, y: resendCodeActionButtonFrame.minY + floor((resendCodeActionButtonFrame.height - resendCodeActionSize.height) / 2.0)), size: resendCodeActionSize)
        }
        
        transition.updateFrame(node: self.changeEmailActionButtonNode, frame: changeEmailActionButtonFrame)
        transition.updateFrame(node: self.resendCodeActionButtonNode, frame: resendCodeActionButtonFrame)
        
        transition.updateFrame(node: self.changeEmailActionTitleNode, frame: changeEmailActionFrame)
        transition.updateFrame(node: self.resendCodeActionTitleNode, frame: resendCodeActionFrame)
        
        transition.animateView {
            self.scrollNode.view.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.insets(options: [.input]).bottom, right: 0.0)
            self.scrollNode.view.contentSize = CGSize(width: contentAreaSize.width, height: max(availableAreaSize.height, buttonFrame.maxY + bottomInset))
        }
    }
}

