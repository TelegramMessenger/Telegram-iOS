import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import AuthorizationUI
import AuthenticationServices
import UndoUI

final class LoginEmailSetupDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var authorizationCompletion: ((Any) -> Void)?
    
    private var context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        self.authorizationCompletion?(authorization.credential)
    }
    
    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Logger.shared.log("AppleSignIn", "Failed with error: \(error.localizedDescription)")
    }
    
    @available(iOS 13.0, *)
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.context.sharedContext.mainWindow!.viewController!.view.window!
    }
}

public func loginEmailSetupController(context: AccountContext, blocking: Bool, emailPattern: String?, canAutoDismissIfNeeded: Bool = false, navigationController: NavigationController?, completion: @escaping () -> Void, dismiss: @escaping () -> Void) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var dismissEmailControllerImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let delegate = LoginEmailSetupDelegate(context: context)
    
    let emailChangeCompletion: (AuthorizationSequenceCodeEntryController?) -> Void = { codeController in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        codeController?.animateSuccess()
        
        completion()
        
        Queue.mainQueue().after(0.75) {
            if let navigationController {
                let controllers = navigationController.viewControllers.filter { controller in
                    if controller is AuthorizationSequenceEmailEntryController || controller is AuthorizationSequenceCodeEntryController {
                        return false
                    } else {
                        return true
                    }
                }
                navigationController.setViewControllers(controllers, animated: true)
                
                Queue.mainQueue().after(0.5, {
                    navigationController.presentOverlay(controller: UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: presentationData.strings.LoginEmail_Success_Title, text: presentationData.strings.LoginEmail_Success_Text, cancel: nil, destructive: false), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                        return false
                    }))
                })
            }
        }
    }
    
    let emailController = AuthorizationSequenceEmailEntryController(context: canAutoDismissIfNeeded ? context : nil, presentationData: presentationData, mode: emailPattern != nil ? .change : .setup, blocking: blocking, back: {
        dismissEmailControllerImpl?()
    })
    emailController.proceedWithEmail = { [weak emailController] email in
        emailController?.inProgress = true
        
        let _ = (sendLoginEmailChangeCode(account: context.account, email: email)
        |> deliverOnMainQueue).start(next: { data in
            var dismissCodeControllerImpl: (() -> Void)?
            var presentControllerImpl: ((ViewController) -> Void)?
            
            let codeController = AuthorizationSequenceCodeEntryController(sharedContext: context.sharedContext, presentationData: presentationData, back: {
                dismissCodeControllerImpl?()
                dismiss()
            })
            
            presentControllerImpl = { [weak codeController] c in
                codeController?.present(c, in: .window(.root), with: nil)
            }
             
            codeController.loginWithCode = { [weak codeController] code in
                let _ = (verifyLoginEmailChange(account: context.account, code: .emailCode(code))
                |> deliverOnMainQueue).start(error: { error in
                    Queue.mainQueue().async {
                        codeController?.inProgress = false
                        
                        if case .invalidCode = error {
                            codeController?.animateError(text: presentationData.strings.Login_WrongCodeError)
                        } else {
                            var resetCode = false
                            let text: String
                            switch error {
                                case .limitExceeded:
                                    resetCode = true
                                    text = presentationData.strings.Login_CodeFloodError
                                case .invalidCode:
                                    resetCode = true
                                    text = presentationData.strings.Login_InvalidCodeError
                                case .generic:
                                    text = presentationData.strings.Login_UnknownError
                                case .codeExpired:
                                    text = presentationData.strings.Login_CodeExpired
                                case .timeout:
                                    text = presentationData.strings.Login_NetworkError
                                case .invalidEmailToken:
                                    text = presentationData.strings.Login_InvalidEmailTokenError
                                case .emailNotAllowed:
                                    text = presentationData.strings.Login_EmailNotAllowedError
                            }
                            
                            if resetCode {
                                codeController?.resetCode()
                            }
                                
                            presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                        }
                    }
                }, completed: { [weak codeController] in
                   emailChangeCompletion(codeController)
                })
            }
            codeController.updateData(number: "", email: email, codeType: .email(emailPattern: "", length: data.length, resetAvailablePeriod: nil, resetPendingDate: nil, appleSignInAllowed: false, setup: true), nextType: nil, timeout: nil, termsOfService: nil, previousCodeType: nil, isPrevious: false)
            navigationController?.pushViewController(codeController)
            dismissCodeControllerImpl = { [weak codeController] in
                codeController?.dismiss()
            }
        }, error: { [weak emailController] error in
            emailController?.inProgress = false
            
            let text: String
            switch error {
                case .limitExceeded:
                    text = presentationData.strings.Login_CodeFloodError
                case .generic, .codeExpired:
                    text = presentationData.strings.Login_UnknownError
                case .timeout:
                    text = presentationData.strings.Login_NetworkError
                case .invalidEmail:
                    text = presentationData.strings.Login_InvalidEmailError
                case .emailNotAllowed:
                    text = presentationData.strings.Login_EmailNotAllowedError
            }
            
            presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
        }, completed: { [weak emailController] in
            emailController?.inProgress = false
        })
    }
    emailController.signInWithApple = { [weak emailController] in
        if #available(iOS 13.0, *) {
            let appleIdProvider = ASAuthorizationAppleIDProvider()
            let request = appleIdProvider.createRequest()
            request.requestedScopes = [.email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            authorizationController.performRequests()
            emailController?.authorization = authorizationController
            emailController?.authorizationDelegate = delegate
            
            delegate.authorizationCompletion = { [weak emailController] credential in
                guard let credential = credential as? ASAuthorizationCredential else {
                    return
                }
                switch credential {
                    case let appleIdCredential as ASAuthorizationAppleIDCredential:
                        guard let tokenData = appleIdCredential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                            emailController?.present(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            return
                        }
                        let _ = (verifyLoginEmailChange(account: context.account, code: .appleToken(token))
                        |> deliverOnMainQueue).start(error: { error in
                            let text: String
                            switch error {
                                case .limitExceeded:
                                    text = presentationData.strings.Login_CodeFloodError
                                case .generic, .codeExpired:
                                    text = presentationData.strings.Login_UnknownError
                                case .invalidCode:
                                    text = presentationData.strings.Login_InvalidCodeError
                                case .timeout:
                                    text = presentationData.strings.Login_NetworkError
                                case .invalidEmailToken:
                                    text = presentationData.strings.Login_InvalidEmailTokenError
                                case .emailNotAllowed:
                                    text = presentationData.strings.Login_EmailNotAllowedError
                            }
                            emailController?.present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        }, completed: { [weak emailController] in
                            emailController?.authorization = nil
                            emailController?.authorizationDelegate = nil
                            
                            emailChangeCompletion(nil)
                        })
                    default:
                        break
                }
            }
        }
    }
    emailController.updateData(appleSignInAllowed: true)
    presentControllerImpl = { [weak emailController] c in
        emailController?.present(c, in: .window(.root), with: nil)
    }
    
    dismissEmailControllerImpl = { [weak emailController] in
        dismiss()
        emailController?.dismiss()
    }
    return emailController
}
