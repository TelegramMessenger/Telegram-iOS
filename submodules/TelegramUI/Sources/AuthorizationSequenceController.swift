import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import MtProtoKit
import MessageUI
import CoreTelephony
import TelegramPresentationData
import TextFormat
import AccountContext
import CountrySelectionUI
import SettingsUI
import PhoneNumberFormat
import LegacyComponents
import LegacyMediaPickerUI
import PasswordSetupUI
import TelegramNotices

private enum InnerState: Equatable {
    case state(UnauthorizedAccountStateContents)
    case authorized
}

public final class AuthorizationSequenceController: NavigationController, MFMailComposeViewControllerDelegate {
    static func navigationBarTheme(_ theme: PresentationTheme) -> NavigationBarTheme {
        return NavigationBarTheme(buttonColor: theme.intro.accentTextColor, disabledButtonColor: theme.intro.disabledTextColor, primaryTextColor: theme.intro.primaryTextColor, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: theme.rootController.navigationBar.badgeBackgroundColor, badgeStrokeColor: theme.rootController.navigationBar.badgeStrokeColor, badgeTextColor: theme.rootController.navigationBar.badgeTextColor)
    }
    
    private let sharedContext: SharedAccountContext
    private var account: UnauthorizedAccount
    private let otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])
    private let apiId: Int32
    private let apiHash: String
    public var presentationData: PresentationData
    private let openUrl: (String) -> Void
    private let authorizationCompleted: () -> Void
    
    private var stateDisposable: Disposable?
    private let actionDisposable = MetaDisposable()
    
    private var didPlayPresentationAnimation = false
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    public init(sharedContext: SharedAccountContext, account: UnauthorizedAccount, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]), presentationData: PresentationData, openUrl: @escaping (String) -> Void, apiId: Int32, apiHash: String, authorizationCompleted: @escaping () -> Void) {
        self.sharedContext = sharedContext
        self.account = account
        self.otherAccountPhoneNumbers = otherAccountPhoneNumbers
        self.apiId = apiId
        self.apiHash = apiHash
        self.presentationData = presentationData
        self.openUrl = openUrl
        self.authorizationCompleted = authorizationCompleted
        
        let navigationStatusBar: NavigationStatusBarStyle
        switch presentationData.theme.rootController.statusBarStyle {
        case .black:
            navigationStatusBar = .black
        case .white:
            navigationStatusBar = .white
        }
        
        super.init(mode: .single, theme: NavigationControllerTheme(statusBar: navigationStatusBar, navigationBar: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), emptyAreaColor: .black))
        
        self.stateDisposable = (TelegramEngineUnauthorized(account: self.account).auth.state()
        |> map { state -> InnerState in
            if case .authorized = state {
                return .authorized
            } else if case let .unauthorized(state) = state {
                return .state(state.contents)
            } else {
                return .state(.empty)
            }
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] state in
            self?.updateState(state: state)
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
        self.view.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
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
            controller = AuthorizationSequenceSplashController(accountManager: self.sharedContext.accountManager, account: self.account, theme: self.presentationData.theme)
            controller.nextPressed = { [weak self] strings in
                if let strongSelf = self {
                    if let strings = strings {
                        strongSelf.presentationData = strongSelf.presentationData.withStrings(strings)
                    }
                    let masterDatacenterId = strongSelf.account.masterDatacenterId
                    let isTestingEnvironment = strongSelf.account.testingEnvironment
                    
                    let countryCode = defaultCountryCode()
                    
                    let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: isTestingEnvironment, masterDatacenterId: masterDatacenterId, contents: .phoneEntry(countryCode: countryCode, number: ""))).start()
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
            controller = AuthorizationSequencePhoneEntryController(sharedContext: self.sharedContext, account: self.account, isTestingEnvironment: self.account.testingEnvironment, otherAccountPhoneNumbers: self.otherAccountPhoneNumbers, network: self.account.network, presentationData: self.presentationData, openUrl: { [weak self] url in
                self?.openUrl(url)
            }, back: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.otherAccountPhoneNumbers.1.isEmpty {
                    let _ = (strongSelf.sharedContext.accountManager.transaction { transaction -> Void in
                        transaction.removeAuth()
                    }).start()
                } else {
                    let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .empty)).start()
                }
            })
            controller.accountUpdated = { [weak self] updatedAccount in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.account = updatedAccount
            }
            controller.loginWithNumber = { [weak self, weak controller] number, syncContacts in
                if let strongSelf = self {
                    controller?.inProgress = true
                    strongSelf.actionDisposable.set((sendAuthorizationCode(accountManager: strongSelf.sharedContext.accountManager, account: strongSelf.account, phoneNumber: number, apiId: strongSelf.apiId, apiHash: strongSelf.apiHash, syncContacts: syncContacts) |> deliverOnMainQueue).start(next: { [weak self] account in
                        if let strongSelf = self {
                            controller?.inProgress = false
                            strongSelf.account = account
                        }
                    }, error: { error in
                        if let strongSelf = self, let controller = controller {
                            controller.inProgress = false
                            
                            let text: String
                            var actions: [TextAlertAction] = []
                            switch error {
                                case .limitExceeded:
                                    text = strongSelf.presentationData.strings.Login_CodeFloodError
                                    actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                                case .invalidPhoneNumber:
                                    text = strongSelf.presentationData.strings.Login_InvalidPhoneError
                                    actions.append(TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                                    actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Login_PhoneNumberHelp, action: { [weak controller] in
                                        guard let strongSelf = self, let controller = controller else {
                                            return
                                        }
                                        let formattedNumber = formatPhoneNumber(number)
                                        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
                                        let systemVersion = UIDevice.current.systemVersion
                                        let locale = Locale.current.identifier
                                        let carrier = CTCarrier()
                                        let mnc = carrier.mobileNetworkCode ?? "none"
                                        
                                        strongSelf.presentEmailComposeController(address: "login@stel.com", subject: strongSelf.presentationData.strings.Login_InvalidPhoneEmailSubject(formattedNumber).string, body: strongSelf.presentationData.strings.Login_InvalidPhoneEmailBody(formattedNumber, appVersion, systemVersion, locale, mnc).string, from: controller)
                                    }))
                                case .phoneLimitExceeded:
                                    text = strongSelf.presentationData.strings.Login_PhoneFloodError
                                    actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                                case .phoneBanned:
                                    text = strongSelf.presentationData.strings.Login_PhoneBannedError
                                    actions.append(TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                                    actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Login_PhoneNumberHelp, action: { [weak controller] in
                                        guard let strongSelf = self, let controller = controller else {
                                            return
                                        }
                                        let formattedNumber = formatPhoneNumber(number)
                                        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
                                        let systemVersion = UIDevice.current.systemVersion
                                        let locale = Locale.current.identifier
                                        let carrier = CTCarrier()
                                        let mnc = carrier.mobileNetworkCode ?? "none"
                                        
                                        strongSelf.presentEmailComposeController(address: "login@stel.com", subject: strongSelf.presentationData.strings.Login_PhoneBannedEmailSubject(formattedNumber).string, body: strongSelf.presentationData.strings.Login_PhoneBannedEmailBody(formattedNumber, appVersion, systemVersion, locale, mnc).string, from: controller)
                                    }))
                                case let .generic(info):
                                    text = strongSelf.presentationData.strings.Login_UnknownError
                                    actions.append(TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                                    actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Login_PhoneNumberHelp, action: { [weak controller] in
                                        guard let strongSelf = self, let controller = controller else {
                                            return
                                        }
                                        let formattedNumber = formatPhoneNumber(number)
                                        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
                                        let systemVersion = UIDevice.current.systemVersion
                                        let locale = Locale.current.identifier
                                        let carrier = CTCarrier()
                                        let mnc = carrier.mobileNetworkCode ?? "none"
                                        let errorString: String
                                        if let (code, description) = info {
                                            errorString = "\(code): \(description)"
                                        } else {
                                            errorString = "unknown"
                                        }
                                        
                                        strongSelf.presentEmailComposeController(address: "login@stel.com", subject: strongSelf.presentationData.strings.Login_PhoneGenericEmailSubject(formattedNumber).string, body: strongSelf.presentationData.strings.Login_PhoneGenericEmailBody(formattedNumber, errorString, appVersion, systemVersion, locale, mnc).string, from: controller)
                                    }))
                                case .timeout:
                                    text = strongSelf.presentationData.strings.Login_NetworkError
                                    actions.append(TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {}))
                                    actions.append(TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.ChatSettings_ConnectionType_UseProxy, action: { [weak controller] in
                                        guard let strongSelf = self, let controller = controller else {
                                            return
                                        }
                                        controller.present(proxySettingsController(accountManager: strongSelf.sharedContext.accountManager, postbox: strongSelf.account.postbox, network: strongSelf.account.network, mode: .modal, presentationData: strongSelf.sharedContext.currentPresentationData.with { $0 }, updatedPresentationData: strongSelf.sharedContext.presentationData), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }))
                            }
                            controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: actions), in: .window(.root))
                        }
                    }))
                }
            }
        }
        controller.updateData(countryCode: countryCode, countryName: nil, number: number)
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
            controller = AuthorizationSequenceCodeEntryController(presentationData: self.presentationData, openUrl: { [weak self] url in
                self?.openUrl(url)
            }, back: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let countryCode = defaultCountryCode()
                
                let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .phoneEntry(countryCode: countryCode, number: ""))).start()
            })
            controller.loginWithCode = { [weak self, weak controller] code in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((authorizeWithCode(accountManager: strongSelf.sharedContext.accountManager, account: strongSelf.account, code: code, termsOfService: termsOfService?.0, forcedPasswordSetupNotice: { value in
                        guard let entry = CodableEntry(ApplicationSpecificCounterNotice(value: value)) else {
                            return nil
                        }
                        return (ApplicationSpecificNotice.forcedPasswordSetupKey(), entry)
                    })
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
                                        let alertTheme = AlertControllerTheme(presentationData: strongSelf.presentationData)
                                        let attributedText = stringWithAppliedEntities(termsOfService.text, entities: termsOfService.entities, baseColor: alertTheme.primaryColor, linkColor: alertTheme.accentColor, baseFont: Font.regular(13.0), linkFont: Font.regular(13.0), boldFont: Font.semibold(13.0), italicFont: Font.italic(13.0), boldItalicFont: Font.semiboldItalic(13.0), fixedFont: Font.regular(13.0), blockQuoteFont: Font.regular(13.0))
                                        let contentNode = TextAlertContentNode(theme: alertTheme, title: NSAttributedString(string: strongSelf.presentationData.strings.Login_TermsOfServiceHeader, font: Font.medium(17.0), textColor: alertTheme.primaryColor, paragraphAlignment: .center), text: attributedText, actions: [
                                            TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Login_TermsOfServiceAgree, action: {
                                                dismissImpl?()
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                let _ = beginSignUp(account: strongSelf.account, data: data).start()
                                            }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Login_TermsOfServiceDecline, action: {
                                                dismissImpl?()
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.currentWindow?.present(standardTextAlertController(theme: alertTheme, title: strongSelf.presentationData.strings.Login_TermsOfServiceDecline, text: strongSelf.presentationData.strings.Login_TermsOfServiceSignupDecline, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
                                                    presentAlertAgainImpl?()
                                                }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Login_TermsOfServiceDecline, action: {
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    let account = strongSelf.account
                                                    let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty)).start()
                                                })]), on: .root, blockInteraction: false, completion: {})
                                            })
                                        ], actionLayout: .vertical, dismissOnOutsideTap: true)
                                        contentNode.textAttributeAction = (NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), { value in
                                            if let value = value as? String {
                                                strongSelf.openUrl(value)
                                            }
                                        })
                                        let controller = AlertController(theme: alertTheme, contentNode: contentNode)
                                        dismissImpl = { [weak controller] in
                                            controller?.dismissAnimated()
                                        }
                                        strongSelf.view.endEditing(true)
                                        strongSelf.currentWindow?.present(controller, on: .root, blockInteraction: false, completion: {})
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
                                
                                var resetCode = false
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        resetCode = true
                                        text = strongSelf.presentationData.strings.Login_CodeFloodError
                                    case .invalidCode:
                                        resetCode = true
                                        text = strongSelf.presentationData.strings.Login_InvalidCodeError
                                    case .generic:
                                        text = strongSelf.presentationData.strings.Login_UnknownError
                                    case .codeExpired:
                                        text = strongSelf.presentationData.strings.Login_CodeExpired
                                        let account = strongSelf.account
                                    let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty)).start()
                                }
                                
                                if resetCode {
                                    controller.resetCode()
                                }
                                
                                controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
        }
        controller.requestNextOption = { [weak self, weak controller] in
            if let strongSelf = self {
                if nextType == nil {
                    if MFMailComposeViewController.canSendMail(), let controller = controller {
                        let formattedNumber = formatPhoneNumber(number)
                        strongSelf.presentEmailComposeController(address: "reports@stel.com", subject: strongSelf.presentationData.strings.Login_EmailCodeSubject(formattedNumber).string, body: strongSelf.presentationData.strings.Login_EmailCodeBody(formattedNumber).string, from: controller)
                    } else {
                        controller?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.Login_EmailNotConfiguredError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
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
                                    text = strongSelf.presentationData.strings.Login_CodeFloodError
                                case .invalidPhoneNumber:
                                    text = strongSelf.presentationData.strings.Login_InvalidPhoneError
                                case .phoneLimitExceeded:
                                    text = strongSelf.presentationData.strings.Login_PhoneFloodError
                                case .phoneBanned:
                                    text = strongSelf.presentationData.strings.Login_PhoneBannedError
                                case .generic:
                                    text = strongSelf.presentationData.strings.Login_UnknownError
                                case .timeout:
                                    text = strongSelf.presentationData.strings.Login_NetworkError
                            }
                            
                            controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        }
                    }))
                }
            }
        }
        controller.reset = { [weak self] in
            if let strongSelf = self {
                let account = strongSelf.account
                let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty)).start()
            }
        }
        controller.updateData(number: formatPhoneNumber(number), codeType: type, nextType: nextType, timeout: timeout, termsOfService: termsOfService)
        return controller
    }
    
    private func passwordEntryController(hint: String, suggestReset: Bool, syncContacts: Bool) -> AuthorizationSequencePasswordEntryController {
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
            controller = AuthorizationSequencePasswordEntryController(presentationData: self.presentationData, back: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let countryCode = defaultCountryCode()
                
                let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .phoneEntry(countryCode: countryCode, number: ""))).start()
            })
            controller.loginWithPassword = { [weak self, weak controller] password in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    strongSelf.actionDisposable.set((authorizeWithPassword(accountManager: strongSelf.sharedContext.accountManager, account: strongSelf.account, password: password, syncContacts: syncContacts) |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let strongSelf = self, let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = strongSelf.presentationData.strings.LoginPassword_FloodError
                                    case .invalidPassword:
                                        text = strongSelf.presentationData.strings.LoginPassword_InvalidPasswordError
                                    case .generic:
                                        text = strongSelf.presentationData.strings.Login_UnknownError
                                }
                                
                                controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
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
                strongSelf.actionDisposable.set((TelegramEngineUnauthorized(account: strongSelf.account).auth.requestTwoStepVerificationPasswordRecoveryCode()
                |> deliverOnMainQueue).start(next: { pattern in
                    if let strongSelf = self, let strongController = controller {
                        strongController.inProgress = false

                        let _ = (TelegramEngineUnauthorized(account: strongSelf.account).auth.state()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { state in
                            guard let strongSelf = self else {
                                return
                            }
                            if case let .unauthorized(state) = state, case let .passwordEntry(hint, number, code, _, syncContacts) = state.contents {
                                let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .passwordRecovery(hint: hint, number: number, code: code, emailPattern: pattern, syncContacts: syncContacts))).start()
                            }
                        })
                    }
                }, error: { error in
                    guard let strongController = controller else {
                        return
                    }

                    strongController.inProgress = false

                    strongController.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.TwoStepAuth_RecoveryUnavailable, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    strongController.didForgotWithNoRecovery = true
                }))
            }
        }
        controller.reset = { [weak self, weak controller] in
            if let strongSelf = self, let strongController = controller {
                strongController.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: suggestReset ? strongSelf.presentationData.strings.TwoStepAuth_RecoveryFailed : strongSelf.presentationData.strings.TwoStepAuth_RecoveryUnavailable, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.Login_ResetAccountProtected_Reset, action: {
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
                                            text = strongSelf.presentationData.strings.Login_UnknownError
                                        case .limitExceeded:
                                            text = strongSelf.presentationData.strings.Login_ResetAccountProtected_LimitExceeded
                                    }
                                    strongController.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                }
                            }))
                        }
                    })]), in: .window(.root))
            }
        }
        controller.updateData(hint: hint, suggestReset: suggestReset)
        return controller
    }
    
    private func passwordRecoveryController(emailPattern: String, syncContacts: Bool) -> TwoFactorDataInputScreen {
        var currentController: TwoFactorDataInputScreen?
        for c in self.viewControllers {
            if let c = c as? TwoFactorDataInputScreen {
                currentController = c
                break
            }
        }
        let controller: TwoFactorDataInputScreen
        if let currentController = currentController {
            controller = currentController
        } else {
            controller = TwoFactorDataInputScreen(sharedContext: self.sharedContext, engine: .unauthorized(TelegramEngineUnauthorized(account: self.account)), mode: .passwordRecoveryEmail(emailPattern: emailPattern, mode: .notAuthorized(syncContacts: syncContacts), doneText: self.presentationData.strings.TwoFactorSetup_Done_Action), stateUpdated: { _ in
            }, presentation: .default)
        }
        controller.passwordRecoveryFailed = { [weak self] in
            guard let strongSelf = self else {
                return
            }

            let _ = (TelegramEngineUnauthorized(account: strongSelf.account).auth.state()
            |> take(1)
            |> deliverOnMainQueue).start(next: { state in
                guard let strongSelf = self else {
                    return
                }
                if case let .unauthorized(state) = state, case let .passwordRecovery(hint, number, code, _, syncContacts) = state.contents {
                    let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .passwordEntry(hint: hint, number: number, code: code, suggestReset: true, syncContacts: syncContacts))).start()
                }
            })
        }
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
            controller = AuthorizationSequenceAwaitingAccountResetController(strings: self.presentationData.strings, theme: self.presentationData.theme, back: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let countryCode = defaultCountryCode()
                
                let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .phoneEntry(countryCode: countryCode, number: ""))).start()
            })
            controller.reset = { [weak self, weak controller] in
                if let strongSelf = self, let strongController = controller {
                    strongController.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.TwoStepAuth_ResetAccountConfirmation, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .destructiveAction, title: strongSelf.presentationData.strings.Login_ResetAccountProtected_Reset, action: {
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
                                                    text = strongSelf.presentationData.strings.Login_UnknownError
                                                case .limitExceeded:
                                                    text = strongSelf.presentationData.strings.Login_ResetAccountProtected_LimitExceeded
                                            }
                                            strongController.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                        }
                                    }))
                            }
                        })]), in: .window(.root))
                }
            }
            controller.logout = { [weak self] in
                if let strongSelf = self {
                    let account = strongSelf.account
                    let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty)).start()
                }
            }
        }
        controller.updateData(protectedUntil: protectedUntil, number: number ?? "")
        return controller
    }
    
    private func signUpController(firstName: String, lastName: String, termsOfService: UnauthorizedAccountTermsOfService?, displayCancel: Bool) -> AuthorizationSequenceSignUpController {
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
            controller = AuthorizationSequenceSignUpController(presentationData: self.presentationData, back: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let countryCode = defaultCountryCode()
                
                let _ = TelegramEngineUnauthorized(account: strongSelf.account).auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: strongSelf.account.testingEnvironment, masterDatacenterId: strongSelf.account.masterDatacenterId, contents: .phoneEntry(countryCode: countryCode, number: ""))).start()
            }, displayCancel: displayCancel)
            controller.signUpWithName = { [weak self, weak controller] firstName, lastName, avatarData, avatarAsset, avatarAdjustments in
                if let strongSelf = self {
                    controller?.inProgress = true
                    
                    var videoStartTimestamp: Double? = nil
                    if let adjustments = avatarAdjustments, adjustments.videoStartValue > 0.0 {
                        videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
                    }
                    
                    let avatarVideo: Signal<UploadedPeerPhotoData?, NoError>?
                    if let avatarAsset = avatarAsset as? AVAsset {
                        let account = strongSelf.account
                        avatarVideo = Signal<TelegramMediaResource?, NoError> { subscriber in
                            let entityRenderer: LegacyPaintEntityRenderer? = avatarAdjustments.flatMap { adjustments in
                                if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                                    return LegacyPaintEntityRenderer(account: nil, adjustments: adjustments)
                                } else {
                                    return nil
                                }
                            }
                            
                            let signal = TGMediaVideoConverter.convert(avatarAsset, adjustments: avatarAdjustments, watcher: nil, entityRenderer: entityRenderer)!
                            
                            let signalDisposable = signal.start(next: { next in
                                if let result = next as? TGMediaVideoConversionResult {
                                    var value = stat()
                                    if stat(result.fileURL.path, &value) == 0 {
                                        if let data = try? Data(contentsOf: result.fileURL) {
                                            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                            account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                            subscriber.putNext(resource)
                                        }
                                    }
                                    subscriber.putCompletion()
                                }
                            }, error: { _ in
                            }, completed: nil)
                            
                            let disposable = ActionDisposable {
                                signalDisposable?.dispose()
                            }
                            
                            return ActionDisposable {
                                disposable.dispose()
                            }
                        }
                        |> mapToSignal { resource -> Signal<UploadedPeerPhotoData?, NoError> in
                            if let resource = resource {
                                return TelegramEngineUnauthorized(account: account).auth.uploadedPeerVideo(resource: resource) |> map(Optional.init)
                            } else {
                                return .single(nil)
                            }
                        }
                    } else {
                        avatarVideo = nil
                    }
                    
                    strongSelf.actionDisposable.set((signUpWithName(accountManager: strongSelf.sharedContext.accountManager, account: strongSelf.account, firstName: firstName, lastName: lastName, avatarData: avatarData, avatarVideo: avatarVideo, videoStartTimestamp: videoStartTimestamp, forcedPasswordSetupNotice: { value in
                        guard let entry = CodableEntry(ApplicationSpecificCounterNotice(value: value)) else {
                            return nil
                        }
                        return (ApplicationSpecificNotice.forcedPasswordSetupKey(), entry)
                    })
                    |> deliverOnMainQueue).start(error: { error in
                        Queue.mainQueue().async {
                            if let strongSelf = self, let controller = controller {
                                controller.inProgress = false
                                
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = strongSelf.presentationData.strings.Login_CodeFloodError
                                    case .codeExpired:
                                        text = strongSelf.presentationData.strings.Login_CodeExpiredError
                                    case .invalidFirstName:
                                        text = strongSelf.presentationData.strings.Login_InvalidFirstNameError
                                    case .invalidLastName:
                                        text = strongSelf.presentationData.strings.Login_InvalidLastNameError
                                    case .generic:
                                        text = strongSelf.presentationData.strings.Login_UnknownError
                                }
                                
                                controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }
                    }))
                }
            }
        }
        controller.updateData(firstName: firstName, lastName: lastName, termsOfService: termsOfService)
        return controller
    }
    
    private func updateState(state: InnerState) {
        switch state {
        case .authorized:
            self.authorizationCompleted()
        case let .state(state):
            switch state {
                case .empty:
                    if let _ = self.viewControllers.last as? AuthorizationSequenceSplashController {
                    } else {
                        var controllers: [ViewController] = []
                        if self.otherAccountPhoneNumbers.1.isEmpty {
                            controllers.append(self.splashController())
                        } else {
                            controllers.append(self.phoneEntryController(countryCode: defaultCountryCode(), number: ""))
                        }
                        self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)
                    }
                case let .phoneEntry(countryCode, number):
                    var controllers: [ViewController] = []
                    if !self.otherAccountPhoneNumbers.1.isEmpty {
                        controllers.append(self.splashController())
                    }
                    controllers.append(self.phoneEntryController(countryCode: countryCode, number: number))
                    self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)
                case let .confirmationCodeEntry(number, type, _, timeout, nextType, _):
                    var controllers: [ViewController] = []
                    if !self.otherAccountPhoneNumbers.1.isEmpty {
                        controllers.append(self.splashController())
                    }
                    controllers.append(self.phoneEntryController(countryCode: defaultCountryCode(), number: ""))
                    controllers.append(self.codeEntryController(number: number, type: type, nextType: nextType, timeout: timeout, termsOfService: nil))
                    self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)
                case let .passwordEntry(hint, _, _, suggestReset, syncContacts):
                    var controllers: [ViewController] = []
                    if !self.otherAccountPhoneNumbers.1.isEmpty {
                        controllers.append(self.splashController())
                    }
                    controllers.append(self.passwordEntryController(hint: hint, suggestReset: suggestReset, syncContacts: syncContacts))
                    self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)
                case let .passwordRecovery(_, _, _, emailPattern, syncContacts):
                    var controllers: [ViewController] = []
                    if !self.otherAccountPhoneNumbers.1.isEmpty {
                        controllers.append(self.splashController())
                    }
                    controllers.append(self.passwordRecoveryController(emailPattern: emailPattern, syncContacts: syncContacts))
                    self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)
                case let .awaitingAccountReset(protectedUntil, number, _):
                    var controllers: [ViewController] = []
                    if !self.otherAccountPhoneNumbers.1.isEmpty {
                        controllers.append(self.splashController())
                    }
                    controllers.append(self.awaitingAccountResetController(protectedUntil: protectedUntil, number: number))
                    self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)
                case let .signUp(_, _, firstName, lastName, termsOfService, _):
                    var controllers: [ViewController] = []
                    var displayCancel = false
                    if !self.otherAccountPhoneNumbers.1.isEmpty {
                        controllers.append(self.splashController())
                    } else {
                        displayCancel = true
                    }
                    controllers.append(self.signUpController(firstName: firstName, lastName: lastName, termsOfService: termsOfService, displayCancel: displayCancel))
                    self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)
            }
        }
    }
    
    override public func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        let wasEmpty = self.viewControllers.isEmpty
        super.setViewControllers(viewControllers, animated: animated)
        if wasEmpty {
            self.topViewController?.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        if !self.didSetReady {
            self.didSetReady = true
            self._ready.set(.single(true))
        }
    }
    
    public func applyConfirmationCode(_ code: Int) {
        if let controller = self.viewControllers.last as? AuthorizationSequenceCodeEntryController {
            controller.applyConfirmationCode(code)
        }
    }
    
    private func presentEmailComposeController(address: String, subject: String, body: String, from controller: ViewController) {
        if MFMailComposeViewController.canSendMail() {
            let composeController = MFMailComposeViewController()
            composeController.setToRecipients([address])
            composeController.setSubject(subject)
            composeController.setMessageBody(body, isHTML: false)
            composeController.mailComposeDelegate = self
            
            controller.view.window?.rootViewController?.present(composeController, animated: true, completion: nil)
        } else {
            controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Login_EmailNotConfiguredError, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }
    }
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    private func animateIn() {
        self.view.layer.animatePosition(from: CGPoint(x: self.view.layer.position.x, y: self.view.layer.position.y + self.view.layer.bounds.size.height), to: self.view.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    private func animateOut(completion: (() -> Void)? = nil) {
        self.view.layer.animatePosition(from: self.view.layer.position, to: CGPoint(x: self.view.layer.position.x, y: self.view.layer.position.y + self.view.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.animateIn()
        }
    }
    
    public func dismiss() {
        self.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}

private func defaultCountryCode() -> Int32 {
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
    
    return countryCode
}
