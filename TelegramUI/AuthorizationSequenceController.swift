import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import MtProtoKitDynamic
import MessageUI
import CoreTelephony

public final class AuthorizationSequenceController: NavigationController {
    static func navigationBarTheme(_ theme: AuthorizationTheme) -> NavigationBarTheme {
        return NavigationBarTheme(buttonColor: theme.accentColor, disabledButtonColor: UIColor(rgb: 0xd0d0d0), primaryTextColor: .black, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
    }
    
    private var account: UnauthorizedAccount
    private let apiId: Int32
    private let apiHash: String
    private var strings: PresentationStrings
    public let theme: AuthorizationTheme
    private let openUrl: (String) -> Void
    
    private var stateDisposable: Disposable?
    private let actionDisposable = MetaDisposable()
    
    public init(account: UnauthorizedAccount, strings: PresentationStrings, openUrl: @escaping (String) -> Void, apiId: Int32, apiHash: String) {
        self.account = account
        self.apiId = apiId
        self.apiHash = apiHash
        self.strings = strings
        self.openUrl = openUrl
        self.theme = defaultLightAuthorizationTheme
        
        super.init(mode: .single, theme: NavigationControllerTheme(navigationBar: AuthorizationSequenceController.navigationBarTheme(theme), emptyAreaColor: .black, emptyDetailIcon: nil))
        
        self.stateDisposable = (account.postbox.stateView()
        |> deliverOnMainQueue).start(next: { [weak self] view in
            self?.updateState(state: view.state ?? UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty))
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stateDisposable?.dispose()
        self.actionDisposable.dispose()
    }
    
    override public func loadView() {
        super.loadView()
        self.view.backgroundColor = self.theme.backgroundColor
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
            controller = AuthorizationSequenceSplashController(postbox: self.account.postbox, network: self.account.network, theme: self.theme)
            controller.nextPressed = { [weak self] strings in
                if let strongSelf = self {
                    if let strings = strings {
                        strongSelf.strings = strings
                    }
                    let masterDatacenterId = strongSelf.account.masterDatacenterId
                    let isTestingEnvironment = strongSelf.account.testingEnvironment
                    
                    var countryId: String? = nil
                    let networkInfo = CTTelephonyNetworkInfo()
                    if let carrier = networkInfo.subscriberCellularProvider {
                        countryId = carrier.isoCountryCode
                    }
                    
                    if countryId == nil {
                        countryId = (Locale.current as NSLocale).object(forKey: .countryCode) as? String
                    }
                    
                    var countryCode: Int32 = 1
                    
                    if let countryId = countryId {
                        let normalizedId = countryId.uppercased()
                        for (code, idAndName) in countryCodeToIdAndName {
                            if idAndName.0 == normalizedId {
                                countryCode = Int32(code)
                                break
                            }
                        }
                    }
                    
                    let _ = (strongSelf.account.postbox.transaction { transaction -> Void in
                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: isTestingEnvironment, masterDatacenterId: masterDatacenterId, contents: .phoneEntry(countryCode: countryCode, number: "")))
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
            controller = AuthorizationSequencePhoneEntryController(network: self.account.network, strings: self.strings, theme: self.theme, openUrl: { [weak self] url in
                self?.openUrl(url)
            })
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
                            var actions: [TextAlertAction] = [
                                TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})
                            ]
                            switch error {
                                case .limitExceeded:
                                    text = strongSelf.strings.Login_CodeFloodError
                                case .invalidPhoneNumber:
                                    text = strongSelf.strings.Login_InvalidPhoneError
                                    actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.strings.Login_PhoneNumberHelp, action: {
                                        
                                    }))
                                case .phoneLimitExceeded:
                                    text = strongSelf.strings.Login_PhoneFloodError
                                case .phoneBanned:
                                    text = strongSelf.strings.Login_PhoneBannedError
                                case .generic:
                                    text = strongSelf.strings.Login_UnknownError
                                case .timeout:
                                    text = strongSelf.strings.Login_NetworkError
                                    actions.append(TextAlertAction(type: .genericAction, title: strongSelf.strings.ChatSettings_ConnectionType_UseProxy, action: { [weak controller] in
                                        guard let strongSelf = self, let controller = controller else {
                                            return
                                        }
                                        controller.present(proxySettingsController(postbox: strongSelf.account.postbox, network: strongSelf.account.network, mode: .modal, theme: defaultPresentationTheme, strings: strongSelf.strings, updatedPresentationData: .single((defaultPresentationTheme, strongSelf.strings))), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }))
                            }
                            controller.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: actions), in: .window(.root))
                        }
                    }))
                }
            }
        }
        controller.updateData(countryCode: countryCode, number: number)
        return controller
    }
    
    private func codeEntryController(number: String, type: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?, termsOfService: (UnauthorizedAccountTermsOfService, Bool)?) -> AuthorizationSequenceCodeEntryController {
        var currentController: AuthorizationSequenceCodeEntryController?
        for c in self.viewControllers {
            if let c = c as? AuthorizationSequenceCodeEntryController {
                if c.data?.1 == type {
                    currentController = c
                }
                break
            }
        }
        let controller: AuthorizationSequenceCodeEntryController
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = AuthorizationSequenceCodeEntryController(strings: self.strings, theme: self.theme, openUrl: { [weak self] url in
                self?.openUrl(url)
            })
            controller.loginWithCode = { [weak self, weak controller] code in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    /*
                     if let (termsOfService, exclusuve) = self.termsOfService, exclusuve {
                     
                     var acceptImpl: (() -> Void)?
                     var declineImpl: (() -> Void)?
                     let controller = TermsOfServiceController(theme: TermsOfServiceControllerTheme(authTheme: self.theme), strings: self.strings, text: termsOfService.text, entities: termsOfService.entities, ageConfirmation: termsOfService.ageConfirmation, signingUp: true, accept: { _ in
                     acceptImpl?()
                     }, decline: {
                     declineImpl?()
                     }, openUrl: { [weak self] url in
                     self?.openUrl(url)
                     })
                     acceptImpl = { [weak self, weak controller] in
                     controller?.dismiss()
                     if let strongSelf = self {
                     strongSelf.termsOfService = nil
                     strongSelf.loginWithCode?(code)
                     }
                     }
                     declineImpl = { [weak self, weak controller] in
                     controller?.dismiss()
                     self?.reset?()
                     self?.controllerNode.activateInput()
                     }
                     self.view.endEditing(true)
                     self.present(controller, in: .window(.root))
                     } else {
                     */
                    
                    strongSelf.actionDisposable.set((authorizeWithCode(account: strongSelf.account, code: code, termsOfService: termsOfService?.0)
                    |> deliverOnMainQueue).start(next: { result in
                        guard let strongSelf = self else {
                            return
                        }
                        controller?.inProgress = false
                        switch result {
                            case let .signUp(data):
                                if let (termsOfService, explicit) = termsOfService, explicit {
                                    var presentAlertAgainImpl: (() -> Void)?
                                    let presentAlertImpl: () -> Void = {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        var dismissImpl: (() -> Void)?
                                        let alertTheme = AlertControllerTheme(authTheme: strongSelf.theme)
                                        let attributedText = stringWithAppliedEntities(termsOfService.text, entities: termsOfService.entities, baseColor: alertTheme.primaryColor, linkColor: alertTheme.accentColor, baseFont: Font.regular(13.0), linkFont: Font.regular(13.0), boldFont: Font.semibold(13.0), italicFont: Font.italic(13.0), fixedFont: Font.regular(13.0))
                                        let contentNode = TextAlertContentNode(theme: alertTheme, title: NSAttributedString(string: strongSelf.strings.Login_TermsOfServiceHeader, font: Font.medium(17.0), textColor: alertTheme.primaryColor, paragraphAlignment: .center), text: attributedText, actions: [
                                            TextAlertAction(type: .defaultAction, title: strongSelf.strings.Login_TermsOfServiceAgree, action: {
                                                dismissImpl?()
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                let _ = beginSignUp(account: strongSelf.account, data: data).start()
                                            }), TextAlertAction(type: .genericAction, title: strongSelf.strings.Login_TermsOfServiceDecline, action: {
                                                dismissImpl?()
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.currentWindow?.present(standardTextAlertController(theme: alertTheme, title: strongSelf.strings.Login_TermsOfServiceDecline, text: strongSelf.strings.Login_TermsOfServiceSignupDecline, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_Cancel, action: {
                                                    presentAlertAgainImpl?()
                                                }), TextAlertAction(type: .genericAction, title: strongSelf.strings.Login_TermsOfServiceDecline, action: {
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    let account = strongSelf.account
                                                    let _ = (strongSelf.account.postbox.transaction { transaction -> Void in
                                                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty))
                                                    }).start()
                                                })]), on: .root, blockInteraction: false)
                                            })
                                        ], actionLayout: .vertical)
                                        contentNode.textAttributeAction = (NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), { value in
                                            if let value = value as? String {
                                                strongSelf.openUrl(value)
                                            }
                                        })
                                        let controller = AlertController(theme: alertTheme, contentNode: contentNode)
                                        dismissImpl = { [weak controller] in
                                            controller?.dismissAnimated()
                                        }
                                        strongSelf.view.endEditing(true)
                                        strongSelf.currentWindow?.present(controller, on: .root, blockInteraction: false)
                                    }
                                    presentAlertAgainImpl = {
                                        presentAlertImpl()
                                    }
                                    presentAlertImpl()
                                } else {
                                    let _ = beginSignUp(account: strongSelf.account, data: data).start()
                                }
                            case .loggedIn:
                                break
                        }
                    }, error: { error in
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
                                
                                controller.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
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
                        controller?.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: strongSelf.strings.Login_EmailNotConfiguredError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
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
                                case .timeout:
                                    text = strongSelf.strings.Login_NetworkError
                            }
                            
                            controller.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                        }
                    }))
                }
            }
        }
        controller.reset = { [weak self] in
            if let strongSelf = self {
                let account = strongSelf.account
                let _ = (strongSelf.account.postbox.transaction { transaction -> Void in
                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty))
                }).start()
            }
        }
        controller.updateData(number: formatPhoneNumber(number), codeType: type, nextType: nextType, timeout: timeout, termsOfService: termsOfService)
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
                                
                                controller.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                                controller.passwordIsInvalid()
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
                                let _ = (strongSelf.account.postbox.transaction { transaction -> Void in
                                    if let state = transaction.getState() as? UnauthorizedAccountState, case let .passwordEntry(hint, number, code) = state.contents {
                                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .passwordRecovery(hint: hint, number: number, code: code, emailPattern: pattern)))
                                    }
                                }).start()
                            case .none:
                                strongController.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: strongSelf.strings.TwoStepAuth_RecoveryUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
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
                strongController.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: strongSelf.strings.TwoStepAuth_RecoveryUnavailable, actions: [
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
                                        case .limitExceeded:
                                            text = strongSelf.strings.Login_ResetAccountProtected_LimitExceeded
                                    }
                                    strongController.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
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
                                
                                controller.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
            controller.noAccess = { [weak self, weak controller] in
                if let strongSelf = self, let controller = controller {
                    controller.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: strongSelf.strings.TwoStepAuth_RecoveryFailed, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                    let account = strongSelf.account
                    let _ = (strongSelf.account.postbox.transaction { transaction -> Void in
                        if let state = transaction.getState() as? UnauthorizedAccountState, case let .passwordRecovery(hint, number, code, _) = state.contents {
                            transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: hint, number: number, code: code)))
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
                    strongController.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: strongSelf.strings.TwoStepAuth_ResetAccountConfirmation, actions: [
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
                                                case .limitExceeded:
                                                    text = strongSelf.strings.Login_ResetAccountProtected_LimitExceeded
                                            }
                                            strongController.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                                        }
                                    }))
                            }
                        })]), in: .window(.root))
                }
            }
            controller.logout = { [weak self] in
                if let strongSelf = self {
                    let account = strongSelf.account
                    let _ = (strongSelf.account.postbox.transaction { transaction -> Void in
                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty))
                    }).start()
                }
            }
        }
        controller.updateData(protectedUntil: protectedUntil, number: number ?? "")
        return controller
    }
    
    private func signUpController(firstName: String, lastName: String, termsOfService: UnauthorizedAccountTermsOfService?) -> AuthorizationSequenceSignUpController {
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
            controller.signUpWithName = { [weak self, weak controller] firstName, lastName, avatarData in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((signUpWithName(account: strongSelf.account, firstName: firstName, lastName: lastName, avatarData: avatarData)
                    |> deliverOnMainQueue).start(error: { error in
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
                                
                                controller.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: strongSelf.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
        }
        controller.updateData(firstName: firstName, lastName: lastName, termsOfService: termsOfService)
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
                case let .confirmationCodeEntry(number, type, _, timeout, nextType, termsOfService):
                    self.setViewControllers([self.splashController(), self.codeEntryController(number: number, type: type, nextType: nextType, timeout: timeout, termsOfService: termsOfService)], animated: !self.viewControllers.isEmpty)
                case let .passwordEntry(hint, _, _):
                    self.setViewControllers([self.splashController(), self.passwordEntryController(hint: hint)], animated: !self.viewControllers.isEmpty)
                case let .passwordRecovery(_, _, _, emailPattern):
                    self.setViewControllers([self.splashController(), self.passwordRecoveryController(emailPattern: emailPattern)], animated: !self.viewControllers.isEmpty)
                case let .awaitingAccountReset(protectedUntil, number):
                    self.setViewControllers([self.splashController(), self.awaitingAccountResetController(protectedUntil: protectedUntil, number: number)], animated: !self.viewControllers.isEmpty)
                case let .signUp(_, _, _, firstName, lastName, termsOfService):
                    self.setViewControllers([self.splashController(), self.signUpController(firstName: firstName, lastName: lastName, termsOfService: termsOfService)], animated: !self.viewControllers.isEmpty)
            }
        } else if let _ = state as? AuthorizedAccountState {
        }
    }
    
    override public func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        let wasEmpty = self.viewControllers.isEmpty
        super.setViewControllers(viewControllers, animated: animated)
        if wasEmpty {
            self.topViewController?.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
    }
}
