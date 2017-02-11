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
                    let account = strongSelf.account
                    let sendCode = Api.functions.auth.sendCode(flags: 0, phoneNumber: number, currentNumber: nil, apiId: 10840, apiHash: "33c45224029d59cb3ad0c16134215aeb")
                    
                    let signal = account.network.request(sendCode, automaticFloodWait: false)
                        |> map { result in
                            return (result, account)
                        } |> `catch` { error -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
                            switch error.errorDescription {
                            case Regex("(PHONE_|USER_|NETWORK_)MIGRATE_(\\d+)"):
                                let range = error.errorDescription.range(of: "MIGRATE_")!
                                let updatedMasterDatacenterId = Int32(error.errorDescription.substring(from: range.upperBound))!
                                let updatedAccount = account.changedMasterDatacenterId(updatedMasterDatacenterId)
                                return updatedAccount
                                    |> mapToSignalPromotingError { updatedAccount -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
                                        return updatedAccount.network.request(sendCode, automaticFloodWait: false)
                                            |> map { sentCode in
                                                return (sentCode, updatedAccount)
                                        }
                                }
                            case _:
                                return .fail(error)
                            }
                    }
                    
                    strongSelf.actionDisposable.set(signal.start(next: { [weak self] (result, account) in
                        if let strongSelf = self {
                            strongSelf.account = account
                            let masterDatacenterId = account.masterDatacenterId
                            let _ = (strongSelf.account.postbox.modify { modifier -> Void in
                                switch result {
                                    case let .sentCode(_, type, phoneCodeHash, nextType, timeout):
                                        var parsedNextType: AuthorizationCodeNextType?
                                        if let nextType = nextType {
                                            parsedNextType = AuthorizationCodeNextType(apiType: nextType)
                                        }
                                        modifier.setState(UnauthorizedAccountState(masterDatacenterId: masterDatacenterId, contents: .confirmationCodeEntry(number: number, type: SentAuthorizationCodeType(apiType: type), hash: phoneCodeHash, timeout: timeout, nextType: parsedNextType)))
                                }
                            }).start()
                        }
                    }, error: { error in
                        Queue.mainQueue().async {
                            if let controller = controller {
                                controller.inProgress = false
                                
                                var text: String?
                                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                                    text = "You have requested authorization code too many times. Please try again later."
                                } else if error.errorDescription == "PHONE_NUMBER_INVALID" {
                                    text = "The phone number you entered is not valid. Please enter the correct number along with your area code."
                                }
                                if let text = text {
                                    controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window)
                                }
                            }
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
                    
                    let account = strongSelf.account
                    let masterDatacenterId = account.masterDatacenterId
                    let signal = account.postbox.modify { modifier -> Signal<Void, String> in
                        if let state = modifier.getState() as? UnauthorizedAccountState {
                            switch state.contents {
                                case let .confirmationCodeEntry(number, _, hash, _, _):
                                    return account.network.request(Api.functions.auth.signIn(phoneNumber: number, phoneCodeHash: hash, phoneCode: code), automaticFloodWait: false) |> map { authorization in
                                            return AuthorizationCodeResult.Authorization(authorization)
                                        } |> `catch` { error -> Signal<AuthorizationCodeResult, String> in
                                            switch (error.errorCode, error.errorDescription) {
                                                case (401, "SESSION_PASSWORD_NEEDED"):
                                                    return account.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
                                                        |> mapError { error -> String in
                                                            return error.errorDescription
                                                        }
                                                        |> mapToSignal { result -> Signal<AuthorizationCodeResult, String> in
                                                            switch result {
                                                                case .noPassword:
                                                                    return .fail("NO_PASSWORD")
                                                                case let .password(_, _, hint, _, _):
                                                                    return .single(.Password(hint))
                                                            }
                                                        }
                                                case _:
                                                    return .fail(error.errorDescription)
                                            }
                                        }
                                        |> mapToSignal { result -> Signal<Void, String> in
                                            return account.postbox.modify { modifier -> Void in
                                                switch result {
                                                    case let .Password(hint):
                                                        modifier.setState(UnauthorizedAccountState(masterDatacenterId: masterDatacenterId, contents: .passwordEntry(hint: hint)))
                                                    case let .Authorization(authorization):
                                                        switch authorization {
                                                            case let .authorization(_, _, user):
                                                                let user = TelegramUser(user: user)
                                                                let state = AuthorizedAccountState(masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                                                                modifier.setState(state)
                                                        }
                                                }
                                            } |> mapToSignalPromotingError { result -> Signal<Void, String> in
                                                return .complete()
                                            }
                                        }
                                default:
                                    break
                            }
                        }
                        return .complete()
                    }
                    |> mapError { _ -> String in
                        return ""
                    }
                    |> switchToLatest
                    strongSelf.actionDisposable.set(signal.start(error: { error in
                        Queue.mainQueue().async {
                            if let controller = controller {
                                controller.inProgress = false
                                
                                var text: String?
                                if error.hasPrefix("FLOOD_WAIT") {
                                    text = "You have entered invalid code too many times. Please try again later."
                                } else if error == "CODE_INVALID" {
                                    text = "Invalid code."
                                } else {
                                    text = "An error occured.";
                                }
                                if let text = text {
                                    controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window)
                                }
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
                    
                    let account = strongSelf.account
                    let signal = verifyPassword(account, password: password)
                        |> `catch` { error -> Signal<Api.auth.Authorization, String> in
                            return .fail(error.errorDescription)
                        }
                        |> mapToSignal { result -> Signal<Void, String> in
                            return account.postbox.modify { modifier -> Void in
                                switch result {
                                    case let .authorization(_, _, user):
                                        let user = TelegramUser(user: user)
                                        let state = AuthorizedAccountState(masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil)
                                        modifier.setState(state)
                                }
                            }
                            |> mapToSignalPromotingError { _ -> Signal<Void, String> in
                                return .complete()
                            }
                        }
                    strongSelf.actionDisposable.set(signal.start(error: { error in
                        Queue.mainQueue().async {
                            if let controller = controller {
                                controller.inProgress = false
                                
                                var text: String?
                                if error.hasPrefix("FLOOD_WAIT") {
                                    text = "You have entered invalid password too many times. Please try again later."
                                } else if error == "PASSWORD_HASH_INVALID" {
                                    text = "Invalid password."
                                } else {
                                    text = "An error occured.";
                                }
                                if let text = text {
                                    controller.present(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window)
                                }
                            }
                        }
                    }))
                }
            }
        }
        controller.updateData(hint: hint)
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
            }
        } else if let _ = state as? AuthorizedAccountState {
            self._authorizedAccount.set(accountWithId(self.account.id, appGroupPath: self.account.appGroupPath, logger: .instance(self.account.logger), testingEnvironment: self.account.testingEnvironment) |> mapToSignal { account -> Signal<Account, NoError> in
                if case let .right(authorizedAccount) = account {
                    return .single(authorizedAccount)
                } else {
                    return .complete()
                }
            })
        }
    }
}
