import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import MtProtoKitDynamic

public final class AuthorizationSequenceController: NavigationController {
    private var account: UnauthorizedAccount
    
    private var stateDisposable: Disposable?
    private let actionDisposable = MetaDisposable()
    
    let _authorizedAccount = Promise<Account>()
    public var authorizedAccount: Signal<Account, NoError> {
        return self._authorizedAccount.get()
    }
    
    public init(account: UnauthorizedAccount) {
        self.account = account
        
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
            controller = AuthorizationSequenceSplashController()
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
            controller = AuthorizationSequencePhoneEntryController()
            controller.loginWithNumber = { [weak self, weak controller] number in
                if let strongSelf = self {
                    controller?.inProgress = true
                    strongSelf.actionDisposable.set((sendAuthorizationCode(account: strongSelf.account, phoneNumber: number, apiId: 10840, apiHash: "33c45224029d59cb3ad0c16134215aeb") |> deliverOnMainQueue).start(next: { [weak self] account in
                        if let strongSelf = self {
                            controller?.inProgress = false
                            strongSelf.account = account
                        }
                    }, error: { error in
                        if let controller = controller {
                            controller.inProgress = false
                            
                            let text: String
                            switch error {
                                case .limitExceeded:
                                    text = "You have requested authorization code too many times. Please try again later."
                                case .invalidPhoneNumber:
                                    text = "The phone number you entered is not valid. Please enter the correct number along with your area code."
                                case .generic:
                                    text = "An error occurred. Please try again later."
                            }
                            
                            controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window)
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
            controller = AuthorizationSequenceCodeEntryController()
            controller.loginWithCode = { [weak self, weak controller] code in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((authorizeWithCode(account: strongSelf.account, code: code) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = "You have entered invalid code too many times. Please try again later."
                                    case .invalidCode:
                                        text = "Invalid code. Please try again."
                                    case .generic:
                                        text = "An error occured."
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window)
                            }
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
            controller = AuthorizationSequencePasswordEntryController()
            controller.loginWithPassword = { [weak self, weak controller] password in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((authorizeWithPassword(account: strongSelf.account, password: password) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = "You have entered invalid password too many times. Please try again later."
                                    case .invalidPassword:
                                        text = "Invalid password. Please try again."
                                    case .generic:
                                        text = "An error occured. Please try again later."
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window)
                            }
                        }
                    }))
                }
            }
        }
        controller.updateData(hint: hint)
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
            controller = AuthorizationSequenceSignUpController()
            controller.signUpWithName = { [weak self, weak controller] firstName, lastName in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((signUpWithName(account: strongSelf.account, firstName: firstName, lastName: lastName) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = "You have entered invalid password too many times. Please try again later."
                                    case .codeExpired:
                                        text = "Authorization code has expired. Please start again."
                                    case .invalidFirstName:
                                        text = "Please enter valid first name"
                                    case .invalidLastName:
                                        text = "Please enter valid last name"
                                    case .generic:
                                        text = "An error occured. Please try again later."
                                }
                                
                                controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window)
                            }
                        }
                    }))
                }
            }
        }
        controller.updateData(firstName: firstName, lastName: lastName)
        return controller
    }
    
    private func updateState(state: Coding?) {
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
                case let .passwordEntry(hint):
                    self.setViewControllers([self.splashController(), self.passwordEntryController(hint: hint)], animated: !self.viewControllers.isEmpty)
                case let .signUp(_, _, _, firstName, lastName):
                    self.setViewControllers([self.splashController(), self.signUpController(firstName: firstName, lastName: lastName)], animated: !self.viewControllers.isEmpty)
            }
        } else if let _ = state as? AuthorizedAccountState {
            self._authorizedAccount.set(accountWithId(apiId: self.account.apiId, id: self.account.id, supplementary: false, appGroupPath: self.account.appGroupPath, testingEnvironment: self.account.testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods) |> mapToSignal { account -> Signal<Account, NoError> in
                if case let .right(authorizedAccount) = account {
                    return .single(authorizedAccount)
                } else {
                    return .complete()
                }
            })
        }
    }
}
