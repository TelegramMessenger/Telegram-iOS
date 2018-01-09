import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import MtProtoKitDynamic
import MessageUI

public final class AuthorizationSequenceController: NavigationController {
    static func navigationBarTheme(_ theme: AuthorizationTheme) -> NavigationBarTheme {
        return NavigationBarTheme(buttonColor: theme.accentColor, primaryTextColor: .black, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
    }
    
    private var account: UnauthorizedAccount
    private let apiId: Int32
    private let apiHash: String
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    
    private var stateDisposable: Disposable?
    private let actionDisposable = MetaDisposable()
    
    public init(account: UnauthorizedAccount, strings: PresentationStrings, apiId: Int32, apiHash: String) {
        self.account = account
        self.apiId = apiId
        self.apiHash = apiHash
        self.strings = strings
        self.theme = defaultAuthorizationTheme
        
        super.init(nibName: nil, bundle: nil)
        
        self.stateDisposable = (account.postbox.stateView() |> deliverOnMainQueue).start(next: { [weak self] view in
            self?.updateState(state: view.state ?? UnauthorizedAccountState(masterDatacenterId: account.masterDatacenterId, contents: .empty))
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stateDisposable?.dispose()
        self.actionDisposable.dispose()
    }
    
    private func splashController() -> AuthorizationSequenceSplashController {
        var currentController: AuthorizationSequenceSplashController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequenceSplashController {
                currentController = c
                break
            }
        }
        let controller: AuthorizationSequenceSplashController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequenceSplashController(theme: self.theme)
            controller.nextPressed = { [weak self] in
                if let strongSelf = self {
                    let masterDatacenterId = strongSelf.account.masterDatacenterId
                    let _ = (strongSelf.account.postbox.modify { modifier -> Void in
                        modifier.setState(UnauthorizedAccountState(masterDatacenterId: masterDatacenterId, contents: .phoneEntry(countryCode: 1, number: "")))
                    }).start()
                }
            }
        }
        return controller
    }
    
    private func phoneEntryController(countryCode: Int32, number: String) -> AuthorizationSequencePhoneEntryController {
        var currentController: AuthorizationSequencePhoneEntryController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequencePhoneEntryController {
                currentController = c
                break
            }
        }
        let controller: AuthorizationSequencePhoneEntryController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequencePhoneEntryController(strings: self.strings, theme: self.theme)
            controller.loginWithNumber = { [weak self, weak controller] number in
                if let strongSelf = self {
                    controller?.inProgress = true
                    strongSelf.actionDisposable.set((sendAuthorizationCode(account: strongSelf.account, phoneNumber: number, apiId: strongSelf.apiId, apiHash: strongSelf.apiHash) |> deliverOnMainQueue).start(next: { [weak self] account in
                        if let strongSelf = self {
                            controller?.inProgress = false
                            strongSelf.account = account
                        }
                    }, error: { error in
                        if let strongSelf = self, let controller = controller {
                            controller.inProgress = false
                            
                            let text: String
                            switch error {
                                case .limitExceeded:
                                    text = strongSelf.strings.Login_CodeFloodError
                                case .invalidPhoneNumber:
                                    text = strongSelf.strings.Login_InvalidPhoneError
                                case .phoneLimitExceeded:
                                    text = strongSelf.strings.Login_PhoneFloodError
                                case .phoneBanned:
                                    text = strongSelf.strings.Login_PhoneBannedError
                                case .generic:
                                    text = strongSelf.strings.Login_UnknownError
                            }
                            
                            controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                        }
                    }))
                }
            }
        }
        controller.updateData(countryCode: countryCode, number: number)
        return controller
    }
    
    private func codeEntryController(number: String, type: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?) -> AuthorizationSequenceCodeEntryController {
        var currentController: AuthorizationSequenceCodeEntryController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequenceCodeEntryController {
                currentController = c
                break
            }
        }
        let controller: AuthorizationSequenceCodeEntryController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequenceCodeEntryController(strings: self.strings, theme: self.theme)
            controller.loginWithCode = { [weak self, weak controller] code in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((authorizeWithCode(account: strongSelf.account, code: code) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let strongSelf = self, let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = strongSelf.strings.Login_CodeFloodError
                                    case .invalidCode:
                                        text = strongSelf.strings.Login_InvalidCodeError
                                    case .generic:
                                        text = strongSelf.strings.Login_UnknownError
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
        }
        controller.requestNextOption = { [weak self, weak controller] in
            if let strongSelf = self {
                if nextType == nil {
                    if MFMailComposeViewController.canSendMail() {
                        let phoneFormatted = formatPhoneNumber(number)
                        
                        let composeController = MFMailComposeViewController()
                        //composeController.mailComposeDelegate = strongSelf
                        composeController.setToRecipients(["sms@stel.com"])
                        composeController.setSubject(strongSelf.strings.Login_EmailCodeSubject(phoneFormatted).0)
                        composeController.setMessageBody(strongSelf.strings.Login_EmailCodeBody(phoneFormatted).0, isHTML: false)
                        
                        controller?.view.window?.rootViewController?.present(composeController, animated: true, completion: nil)
                    } else {
                        controller?.present(standardTextAlertController(title: nil, text: strongSelf.strings.Login_EmailNotConfiguredError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                } else {
                    controller?.inProgress = true
                    strongSelf.actionDisposable.set((resendAuthorizationCode(account: strongSelf.account)
                        |> deliverOnMainQueue).start(next: { result in
                            controller?.inProgress = false
                        }, error: { error in
                            if let strongSelf = self, let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = strongSelf.strings.Login_CodeFloodError
                                    case .invalidPhoneNumber:
                                        text = strongSelf.strings.Login_InvalidPhoneError
                                    case .phoneLimitExceeded:
                                        text = strongSelf.strings.Login_PhoneFloodError
                                    case .phoneBanned:
                                        text = strongSelf.strings.Login_PhoneBannedError
                                    case .generic:
                                        text = strongSelf.strings.Login_UnknownError
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }))
                }
            }
        }
        controller.updateData(number: formatPhoneNumber(number), codeType: type, nextType: nextType, timeout: timeout)
        return controller
    }
    
    private func passwordEntryController(hint: String) -> AuthorizationSequencePasswordEntryController {
        var currentController: AuthorizationSequencePasswordEntryController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequencePasswordEntryController {
                currentController = c
                break
            }
        }
        let controller: AuthorizationSequencePasswordEntryController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequencePasswordEntryController(strings: self.strings, theme: self.theme)
            controller.loginWithPassword = { [weak self, weak controller] password in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((authorizeWithPassword(account: strongSelf.account, password: password) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let strongSelf = self, let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = strongSelf.strings.LoginPassword_FloodError
                                    case .invalidPassword:
                                        text = strongSelf.strings.LoginPassword_InvalidPasswordError
                                    case .generic:
                                        text = strongSelf.strings.Login_UnknownError
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
        }
        controller.forgot = { [weak self, weak controller] in
            if let strongSelf = self, let strongController = controller {
                strongController.inProgress = true
                strongSelf.actionDisposable.set((requestPasswordRecovery(account: strongSelf.account)
                |> deliverOnMainQueue).start(next: { option in
                    if let strongSelf = self, let strongController = controller {
                        strongController.inProgress = false
                        switch option {
                            case let .email(pattern):
                                let _ = (strongSelf.account.postbox.modify { modifier -> Void in
                                    if let state = modifier.getState() as? UnauthorizedAccountState, case let .passwordEntry(hint, number, code) = state.contents {
                                        modifier.setState(UnauthorizedAccountState(masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .passwordRecovery(hint: hint, number: number, code: code, emailPattern: pattern)))
                                    }
                                }).start()
                            case .none:
                                strongController.present(standardTextAlertController(title: nil, text: strongSelf.strings.TwoStepAuth_RecoveryUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                                strongController.didForgotWithNoRecovery = true
                        }
                    }
                }, error: { error in
                    if let strongSelf = self, let strongController = controller {
                        strongController.inProgress = false
                    }
                }))
            }
        }
        controller.reset = { [weak self, weak controller] in
            if let strongSelf = self, let strongController = controller {
                strongController.present(standardTextAlertController(title: nil, text: strongSelf.strings.TwoStepAuth_RecoveryUnavailable, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .destructiveAction, title: strongSelf.strings.Login_ResetAccountProtected_Reset, action: {
                        if let strongSelf = self, let strongController = controller {
                            strongController.inProgress = true
                            strongSelf.actionDisposable.set((performAccountReset(account: strongSelf.account)
                            |> deliverOnMainQueue).start(next: {
                                if let strongController = controller {
                                    strongController.inProgress = false
                                }
                            }, error: { error in
                                if let strongSelf = self, let strongController = controller {
                                    strongController.inProgress = false
                                    let text: String
                                    switch error {
                                        case .generic:
                                            text = strongSelf.strings.Login_UnknownError
                                    }
                                    strongController.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                                }
                            }))
                        }
                    })]), in: .window(.root))
            }
        }
        controller.updateData(hint: hint)
        return controller
    }
    
    private func passwordRecoveryController(emailPattern: String) -> AuthorizationSequencePasswordRecoveryController {
        var currentController: AuthorizationSequencePasswordRecoveryController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequencePasswordRecoveryController {
                currentController = c
                break
            }
        }
        let controller: AuthorizationSequencePasswordRecoveryController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequencePasswordRecoveryController(strings: self.strings, theme: self.theme)
            controller.recoverWithCode = { [weak self, weak controller] code in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((performPasswordRecovery(account: strongSelf.account, code: code) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let strongSelf = self, let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = strongSelf.strings.LoginPassword_FloodError
                                    case .invalidCode:
                                        text = strongSelf.strings.Login_InvalidCodeError
                                    case .expired:
                                        text = strongSelf.strings.Login_CodeExpiredError
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
            controller.noAccess = { [weak self, weak controller] in
                if let strongSelf = self, let controller = controller {
                    controller.present(standardTextAlertController(title: nil, text: strongSelf.strings.TwoStepAuth_RecoveryFailed, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                    let account = strongSelf.account
                    let _ = (strongSelf.account.postbox.modify { modifier -> Void in
                        if let state = modifier.getState() as? UnauthorizedAccountState, case let .passwordRecovery(hint, number, code, _) = state.contents {
                            modifier.setState(UnauthorizedAccountState(masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: hint, number: number, code: code)))
                        }
                    }).start()
                }
            }
        }
        controller.updateData(emailPattern: emailPattern)
        return controller
    }
    
    private func awaitingAccountResetController(protectedUntil: Int32, number: String?) -> AuthorizationSequenceAwaitingAccountResetController {
        var currentController: AuthorizationSequenceAwaitingAccountResetController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequenceAwaitingAccountResetController {
                currentController = c
                break
            }
        }
        let controller: AuthorizationSequenceAwaitingAccountResetController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequenceAwaitingAccountResetController(strings: self.strings, theme: self.theme)
            controller.reset = { [weak self, weak controller] in
                if let strongSelf = self, let strongController = controller {
                    strongController.present(standardTextAlertController(title: nil, text: strongSelf.strings.TwoStepAuth_ResetAccountConfirmation, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .destructiveAction, title: strongSelf.strings.Login_ResetAccountProtected_Reset, action: {
                            if let strongSelf = self, let strongController = controller {
                                strongController.inProgress = true
                                strongSelf.actionDisposable.set((performAccountReset(account: strongSelf.account)
                                    |> deliverOnMainQueue).start(next: {
                                        if let strongController = controller {
                                            strongController.inProgress = false
                                        }
                                    }, error: { error in
                                        if let strongSelf = self, let strongController = controller {
                                            strongController.inProgress = false
                                            let text: String
                                            switch error {
                                            case .generic:
                                                text = strongSelf.strings.Login_UnknownError
                                            }
                                            strongController.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                                        }
                                    }))
                            }
                        })]), in: .window(.root))
                }
            }
            controller.logout = { [weak self] in
                if let strongSelf = self {
                    let account = strongSelf.account
                    let _ = (strongSelf.account.postbox.modify { modifier -> Void in
                        modifier.setState(UnauthorizedAccountState(masterDatacenterId: account.masterDatacenterId, contents: .empty))
                    }).start()
                }
            }
        }
        controller.updateData(protectedUntil: protectedUntil, number: number ?? "")
        return controller
    }
    
    private func signUpController(firstName: String, lastName: String) -> AuthorizationSequenceSignUpController {
        var currentController: AuthorizationSequenceSignUpController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequenceSignUpController {
                currentController = c
                break
            }
        }
        let controller: AuthorizationSequenceSignUpController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequenceSignUpController(strings: self.strings, theme: self.theme)
            controller.signUpWithName = { [weak self, weak controller] firstName, lastName in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((signUpWithName(account: strongSelf.account, firstName: firstName, lastName: lastName) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let strongSelf = self, let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = strongSelf.strings.Login_CodeFloodError
                                    case .codeExpired:
                                        text = strongSelf.strings.Login_CodeExpiredError
                                    case .invalidFirstName:
                                        text = strongSelf.strings.Login_InvalidFirstNameError
                                    case .invalidLastName:
                                        text = strongSelf.strings.Login_InvalidLastNameError
                                    case .generic:
                                        text = strongSelf.strings.Login_UnknownError
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
        }
        controller.updateData(firstName: firstName, lastName: lastName)
        return controller
    }
    
    private func updateState(state: PostboxCoding?) {
        if let state = state as? UnauthorizedAccountState {
            switch state.contents {
                case .empty:
                    if let _ = self.viewControllers.last as? AuthorizationSequenceSplashController {
                    } else {
                        self.setViewControllers([self.splashController()], animated: !self.viewControllers.isEmpty)
                    }
                case let .phoneEntry(countryCode, number):
                    self.setViewControllers([self.splashController(), self.phoneEntryController(countryCode: countryCode, number: number)], animated: !self.viewControllers.isEmpty)
                case let .confirmationCodeEntry(number, type, _, timeout, nextType):
                    self.setViewControllers([self.splashController(), self.codeEntryController(number: number, type: type, nextType: nextType, timeout: timeout)], animated: !self.viewControllers.isEmpty)
                case let .passwordEntry(hint, _, _):
                    self.setViewControllers([self.splashController(), self.passwordEntryController(hint: hint)], animated: !self.viewControllers.isEmpty)
                case let .passwordRecovery(_, _, _, emailPattern):
                    self.setViewControllers([self.splashController(), self.passwordRecoveryController(emailPattern: emailPattern)], animated: !self.viewControllers.isEmpty)
                case let .awaitingAccountReset(protectedUntil, number):
                    self.setViewControllers([self.splashController(), self.awaitingAccountResetController(protectedUntil: protectedUntil, number: number)], animated: !self.viewControllers.isEmpty)
                case let .signUp(_, _, _, firstName, lastName):
                    self.setViewControllers([self.splashController(), self.signUpController(firstName: firstName, lastName: lastName)], animated: !self.viewControllers.isEmpty)
            }
        } else if let _ = state as? AuthorizedAccountState {
        }
    }
}
