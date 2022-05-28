import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TextFormat
import ProgressNavigationButtonNode
import AccountContext
import AlertUI
import PresentationDataUtils
import PasswordSetupUI

public enum SecureIdRequestResult: String {
    case success = "success"
    case cancel = "cancel"
    case error = "error"
}

public func secureIdCallbackUrl(with baseUrl: String, peerId: PeerId, result: SecureIdRequestResult, parameters: [String : String]) -> String {
    var query = (parameters.compactMap({ (key, value) -> String in
        return "\(key)=\(value)"
    }) as Array).joined(separator: "&")
    
    if !query.isEmpty {
        query = "?" + query
    }
    
    let url: String
    if baseUrl.hasPrefix("tgbot") {
        url = "tgbot\(peerId.id)://passport/" + result.rawValue + query
    } else {
        url = baseUrl + (baseUrl.range(of: "?") != nil ? "&" : "?") + "tg_passport=" + result.rawValue + query
    }
    return url
}

final class SecureIdAuthControllerInteraction {
    let updateState: ((SecureIdAuthControllerState) -> SecureIdAuthControllerState) -> Void
    let present: (ViewController, Any?) -> Void
    let push: (ViewController) -> Void
    let checkPassword: (String) -> Void
    let openPasswordHelp: () -> Void
    let setupPassword: () -> Void
    let grant: () -> Void
    let openUrl: (String) -> Void
    let openMention: (TelegramPeerMention) -> Void
    let deleteAll: () -> Void
    
    fileprivate init(updateState: @escaping ((SecureIdAuthControllerState) -> SecureIdAuthControllerState) -> Void, present: @escaping (ViewController, Any?) -> Void, push: @escaping (ViewController) -> Void, checkPassword: @escaping (String) -> Void, openPasswordHelp: @escaping () -> Void, setupPassword: @escaping () -> Void, grant: @escaping () -> Void, openUrl: @escaping (String) -> Void, openMention: @escaping (TelegramPeerMention) -> Void, deleteAll: @escaping () -> Void) {
        self.updateState = updateState
        self.present = present
        self.push = push
        self.checkPassword = checkPassword
        self.openPasswordHelp = openPasswordHelp
        self.setupPassword = setupPassword
        self.grant = grant
        self.openUrl = openUrl
        self.openMention = openMention
        self.deleteAll = deleteAll
    }
}

public enum SecureIdAuthControllerMode {
    case form(peerId: PeerId, scope: String, publicKey: String, callbackUrl: String?, opaquePayload: Data, opaqueNonce: Data)
    case list
}

public final class SecureIdAuthController: ViewController, StandalonePresentableController {
    private var controllerNode: SecureIdAuthControllerNode {
        return self.displayNode as! SecureIdAuthControllerNode
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private let mode: SecureIdAuthControllerMode
    
    private var didPlayPresentationAnimation = false
    
    private let challengeDisposable = MetaDisposable()
    private let authenthicateDisposable = MetaDisposable()
    private var formDisposable: Disposable?
    private let deleteDisposable = MetaDisposable()
    private let recoveryDisposable = MetaDisposable()
    
    private var state: SecureIdAuthControllerState
    
    private let hapticFeedback = HapticFeedback()
    
    public init(context: AccountContext, mode: SecureIdAuthControllerMode) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.mode = mode
        
        switch mode {
            case .form:
                self.state = .form(SecureIdAuthControllerFormState(twoStepEmail: nil, encryptedFormData: nil, formData: nil, verificationState: nil, removingValues: false))
            case .list:
                self.state = .list(SecureIdAuthControllerListState(accountPeer: nil, twoStepEmail: nil, verificationState: nil, encryptedValues: nil, primaryLanguageByCountry: [:], values: nil, removingValues: false))
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        if case .list = mode {
            self.navigationPresentation = .modal
        }
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Passport_Title
        switch mode {
            case .form:
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
            case .list:
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.cancelPressed))
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationInfoIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.infoPressed))
        
        self.challengeDisposable.set((context.engine.auth.twoStepAuthData()
        |> deliverOnMainQueue).start(next: { [weak self] data in
            if let strongSelf = self {
                let storedPassword = context.getStoredSecureIdPassword()
                if data.currentPasswordDerivation != nil, let storedPassword = storedPassword {
                    strongSelf.authenthicateDisposable.set((strongSelf.context.engine.secureId.accessSecureId(password: storedPassword)
                    |> deliverOnMainQueue).start(next: { context in
                        guard let strongSelf = self, strongSelf.state.verificationState == nil else {
                            return
                        }
                        
                        strongSelf.updateState(animated: true, { state in
                            var state = state
                            state.verificationState = .verified(context.context)
                            state.twoStepEmail = !context.settings.email.isEmpty ? context.settings.email : nil
                            switch state {
                                case var .form(form):
                                    form.formData = form.encryptedFormData.flatMap({ decryptedSecureIdForm(context: context.context, form: $0.form) })
                                    state = .form(form)
                                case var .list(list):
                                    list.values = list.encryptedValues.flatMap({ decryptedAllSecureIdValues(context: context.context, encryptedValues: $0) })
                                    state = .list(list)
                            }
                            return state
                        })
                    }, error: { [weak self] error in
                        guard let strongSelf = self else {
                            return
                        }
                        if strongSelf.state.verificationState == nil {
                            strongSelf.updateState(animated: true, { state in
                                var state = state
                                state.verificationState = .passwordChallenge(hint: data.currentHint ?? "", state: .none, hasRecoveryEmail: data.hasRecovery)
                                return state
                            })
                        }
                    }))
                } else {
                    strongSelf.updateState { state in
                        var state = state
                        if data.currentPasswordDerivation != nil {
                            state.verificationState = .passwordChallenge(hint: data.currentHint ?? "", state: .none, hasRecoveryEmail: data.hasRecovery)
                        } else if let unconfirmedEmailPattern = data.unconfirmedEmailPattern {
                            state.verificationState = .noChallenge(.awaitingConfirmation(password: nil, emailPattern: unconfirmedEmailPattern, codeLength: nil))
                        } else {
                            state.verificationState = .noChallenge(.notSet)
                        }
                        return state
                    }
                }
            }
        }))
        
        let handleError: (Any, String?, PeerId?) -> Void = { [weak self] error, callbackUrl, peerId in
            if let strongSelf = self {
                var passError: String?
                var appUpdateRequired = false
                switch error {
                    case let error as RequestSecureIdFormError:
                        if case let .serverError(error) = error, ["BOT_INVALID", "PUBLIC_KEY_REQUIRED", "PUBLIC_KEY_INVALID", "SCOPE_EMPTY", "PAYLOAD_EMPTY", "NONCE_EMPTY"].contains(error) {
                            passError = error
                        } else if case .versionOutdated = error {
                            appUpdateRequired = true
                        }
                        break
                    case let error as GetAllSecureIdValuesError:
                        if case .versionOutdated = error {
                            appUpdateRequired = true
                        }
                        break
                    default:
                        break
                }
                
                if appUpdateRequired {
                    let errorText = strongSelf.presentationData.strings.Passport_UpdateRequiredError
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Application_Update, action: {
                        context.sharedContext.applicationBindings.openAppStorePage()
                    })]), in: .window(.root))
                } else if let callbackUrl = callbackUrl, let peerId = peerId {
                    let errorText = strongSelf.presentationData.strings.Login_UnknownError
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        if let error = passError {
                            strongSelf.openUrl(secureIdCallbackUrl(with: callbackUrl, peerId: peerId, result: .error, parameters: ["error": error]))
                        }
                    })]), in: .window(.root))
                }
                strongSelf.dismiss()
            }
        }
        
        switch self.mode {
            case let .form(peerId, scope, publicKey, callbackUrl, _, _):
                self.formDisposable = (combineLatest(requestSecureIdForm(postbox: context.account.postbox, network: context.account.network, peerId: peerId, scope: scope, publicKey: publicKey), secureIdConfiguration(postbox: context.account.postbox, network: context.account.network) |> castError(RequestSecureIdFormError.self))
                |> mapToSignal { form, configuration -> Signal<SecureIdEncryptedFormData, RequestSecureIdFormError> in
                    return context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                        TelegramEngine.EngineData.Item.Peer.Peer(id: form.peerId)
                    )
                    |> castError(RequestSecureIdFormError.self)
                    |> mapToSignal { accountPeer, servicePeer -> Signal<SecureIdEncryptedFormData, RequestSecureIdFormError> in
                        guard let accountPeer = accountPeer, let servicePeer = servicePeer else {
                            return .fail(.generic)
                        }
                        
                        let primaryLanguageByCountry = configuration.nativeLanguageByCountry
                        return .single(SecureIdEncryptedFormData(form: form, primaryLanguageByCountry: primaryLanguageByCountry, accountPeer: accountPeer._asPeer(), servicePeer: servicePeer._asPeer()))
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] formData in
                    if let strongSelf = self {
                        strongSelf.updateState { state in
                            var state = state
                            switch state {
                                case var .form(form):
                                    form.encryptedFormData = formData
                                    state = .form(form)
                                case .list:
                                    break
                            }
                            return state
                        }
                    }
                }, error: { error in
                    handleError(error, callbackUrl, peerId)
                })
            case .list:
                self.formDisposable = (combineLatest(
                    getAllSecureIdValues(network: self.context.account.network),
                    secureIdConfiguration(postbox: context.account.postbox, network: context.account.network) |> castError(GetAllSecureIdValuesError.self),
                    context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)) |> castError(GetAllSecureIdValuesError.self) |> mapToSignal { accountPeer -> Signal<EnginePeer, GetAllSecureIdValuesError> in
                        guard let accountPeer = accountPeer else {
                            return .fail(.generic)
                        }
                        return .single(accountPeer)
                    }
                )
                |> deliverOnMainQueue).start(next: { [weak self] values, configuration, accountPeer in
                    if let strongSelf = self {
                        strongSelf.updateState { state in
                            let state = state
                            let primaryLanguageByCountry = configuration.nativeLanguageByCountry
                            
                            switch state {
                            case .form:
                                break
                            case var .list(list):
                                list.accountPeer = accountPeer._asPeer()
                                list.primaryLanguageByCountry = primaryLanguageByCountry
                                list.encryptedValues = values
                                return .list(list)
                            }
                            return state
                        }
                    }
                }, error: { error in
                    handleError(error, nil, nil)
                })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.challengeDisposable.dispose()
        self.authenthicateDisposable.dispose()
        self.formDisposable?.dispose()
        self.deleteDisposable.dispose()
        self.recoveryDisposable.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if case .form = self.mode, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func loadDisplayNode() {
        let interaction = SecureIdAuthControllerInteraction(updateState: { [weak self] f in
            self?.updateState(f)
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, push: { [weak self] c in
            self?.push(c)
        }, checkPassword: { [weak self] password in
            self?.checkPassword(password: password, inBackground: false, completion: {})
        }, openPasswordHelp: { [weak self] in
            self?.openPasswordHelp()
        }, setupPassword: { [weak self] in
            self?.setupPassword()
        }, grant: { [weak self] in
            self?.grantAccess()
        }, openUrl: { [weak self] url in
            if let strongSelf = self {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: false, presentationData: strongSelf.presentationData, navigationController: strongSelf.navigationController as? NavigationController, dismissInput: {
                    self?.view.endEditing(true)
                })
            }
        }, openMention: { [weak self] mention in
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.account.postbox.loadedPeerWithId(mention.peerId)
            |> deliverOnMainQueue).start(next: { peer in
                guard let strongSelf = self else {
                    return
                }
                if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                }
            })
        }, deleteAll: { [weak self] in
            guard let strongSelf = self, case let .list(list) = strongSelf.state, let values = list.values else {
                return
            }
            
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.presentationData.theme.rootController.navigationBar.controlColor))
            strongSelf.navigationItem.rightBarButtonItem = item
            strongSelf.deleteDisposable.set((deleteSecureIdValues(network: strongSelf.context.account.network, keys: Set(values.map({ $0.value.key })))
            |> deliverOnMainQueue).start(completed: {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationInfoIcon(strongSelf.presentationData.theme), style: .plain, target: self, action: #selector(strongSelf.infoPressed))
                strongSelf.updateState { state in
                    if case var .list(list) = state {
                        list.values = []
                        return .list(list)
                    }
                    return state
                }
            }))
        })
        
        self.displayNode = SecureIdAuthControllerNode(context: self.context, presentationData: presentationData, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        }, interaction: interaction)
        self.controllerNode.updateState(self.state, transition: .immediate)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if case .form = self.mode {
            self.controllerNode.animateOut(completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
                completion?()
            })
        } else {
            super.dismiss(completion: completion)
        }
    }
    
    private func updateState(animated: Bool = true, _ f: (SecureIdAuthControllerState) -> SecureIdAuthControllerState) {
        let state = f(self.state)
        if state != self.state {
            var previousHadProgress = false
            if let verificationState = self.state.verificationState, case .passwordChallenge(_, .checking, _) = verificationState {
                previousHadProgress = true
            }
            if self.state.removingValues {
                previousHadProgress = true
            }
            var updatedHasProgress = false
            if let verificationState = state.verificationState, case .passwordChallenge(_, .checking, _) = verificationState {
                updatedHasProgress = true
            }
            if state.removingValues {
                updatedHasProgress = true
            }
            
            self.state = state
            if self.isNodeLoaded {
                self.controllerNode.updateState(self.state, transition: animated ? .animated(duration: 0.3, curve: .spring) : .immediate)
            }
            
            if previousHadProgress != updatedHasProgress {
                if updatedHasProgress {
                    let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.controlColor))
                    self.navigationItem.rightBarButtonItem = item
                } else {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationInfoIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.infoPressed))
                }
            }
        }
    }
    
    private func openUrl(_ url: String) {
        self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: self.presentationData, navigationController: nil, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        })
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
        
        if case let .form(peerId, _, _, maybeCallbackUrl, _, _) = self.mode, let callbackUrl = maybeCallbackUrl {
            self.openUrl(secureIdCallbackUrl(with: callbackUrl, peerId: peerId, result: .cancel, parameters: [:]))
        }
    }
    
    @objc private func checkPassword(password: String, inBackground: Bool, completion: @escaping () -> Void) {
        if let verificationState = self.state.verificationState, case let .passwordChallenge(hint, challengeState, hasRecoveryEmail) = verificationState {
            switch challengeState {
                case .none, .invalid:
                    break
                case .checking:
                    return
            }
            self.updateState(animated: !inBackground, { state in
                var state = state
                state.verificationState = .passwordChallenge(hint: hint, state: .checking, hasRecoveryEmail: hasRecoveryEmail)
                return state
            })
            self.challengeDisposable.set((self.context.engine.secureId.accessSecureId(password: password)
            |> deliverOnMainQueue).start(next: { [weak self] context in
                guard let strongSelf = self, let verificationState = strongSelf.state.verificationState, case .passwordChallenge(_, .checking, _) = verificationState else {
                    return
                }
                strongSelf.context.storeSecureIdPassword(password: password)
                strongSelf.updateState(animated: !inBackground, { state in
                    var state = state
                    state.verificationState = .verified(context.context)
                    state.twoStepEmail = !context.settings.email.isEmpty ? context.settings.email : nil
                    switch state {
                        case var .form(form):
                            form.formData = form.encryptedFormData.flatMap({ decryptedSecureIdForm(context: context.context, form: $0.form) })
                            state = .form(form)
                        case var .list(list):
                            list.values = list.encryptedValues.flatMap({ decryptedAllSecureIdValues(context: context.context, encryptedValues: $0) })
                            state = .list(list)
                    }
                    return state
                })
                completion()
            }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                let errorText: String
                switch error {
                    case let .passwordError(passwordError):
                        switch passwordError {
                            case .invalidPassword:
                                errorText = strongSelf.presentationData.strings.LoginPassword_InvalidPasswordError
                            case .limitExceeded:
                                errorText = strongSelf.presentationData.strings.LoginPassword_FloodError
                            case .generic:
                                errorText = strongSelf.presentationData.strings.Login_UnknownError
                        }
                    case .generic:
                        errorText = strongSelf.presentationData.strings.Login_UnknownError
                    case .secretPasswordMismatch:
                        errorText = strongSelf.presentationData.strings.Login_UnknownError
                }
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                
                if let verificationState = strongSelf.state.verificationState, case let .passwordChallenge(hint, .checking, hasRecoveryEmail) = verificationState {
                    strongSelf.updateState(animated: !inBackground, { state in
                        var state = state
                        state.verificationState = .passwordChallenge(hint: hint, state: .invalid, hasRecoveryEmail: hasRecoveryEmail)
                        return state
                    })
                }
                completion()
            }))
        }
    }
    
    private func openPasswordHelp() {
        guard let verificationState = self.state.verificationState, case let .passwordChallenge(_, state, hasRecoveryEmail) = verificationState else {
            return
        }
        switch state {
            case .checking:
                return
            case .none, .invalid:
                break
        }
        
        if hasRecoveryEmail {
            self.present(textAlertController(context: self.context, title: self.presentationData.strings.Passport_ForgottenPassword, text: self.presentationData.strings.Passport_PasswordReset, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Login_ResetAccountProtected_Reset, action: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.recoveryDisposable.set((strongSelf.context.engine.auth.requestTwoStepVerificationPasswordRecoveryCode()
                |> deliverOnMainQueue).start(next: { emailPattern in
                    guard let strongSelf = self else {
                        return
                    }
                    var completionImpl: (() -> Void)?
                    let controller = resetPasswordController(context: strongSelf.context, emailPattern: emailPattern, completion: { _ in
                        completionImpl?()
                    })
                    completionImpl = { [weak controller] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateState(animated: false, { state in
                            var state = state
                            state.verificationState = .noChallenge(.notSet)
                            return state
                        })
                        controller?.view.endEditing(true)
                        controller?.dismiss()
                        strongSelf.setupPassword()
                    }
                    strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }))
            })]), in: .window(.root))
        } else {
            self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.TwoStepAuth_RecoveryUnavailable, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }
    }
    
    private func setupPassword() {
        guard let verificationState = self.state.verificationState, case let .noChallenge(noChallengeState) = verificationState else {
            return
        }
        let initialState: SetupTwoStepVerificationInitialState
        switch noChallengeState {
            case .notSet:
                initialState = .createPassword
            case let .awaitingConfirmation(password, emailPattern, codeLength):
                initialState = .confirmEmail(password: password, hasSecureValues: false, pattern: emailPattern, codeLength: codeLength)
        }
        let controller = SetupTwoStepVerificationController(context: self.context, initialState: initialState, stateUpdated: { [weak self] update, shouldDismiss, controller in
            guard let strongSelf = self else {
                return
            }
            switch update {
                case .noPassword, .pendingPasswordReset:
                    strongSelf.updateState(animated: false, { state in
                        var state = state
                        if let verificationState = state.verificationState, case .noChallenge = verificationState {
                            state.verificationState = .noChallenge(.notSet)
                        }
                        return state
                    })
                    if shouldDismiss {
                        controller.dismiss()
                    }
                case let .awaitingEmailConfirmation(password, pattern, codeLength):
                    strongSelf.updateState(animated: false, { state in
                        var state = state
                        if let verificationState = state.verificationState, case .noChallenge = verificationState {
                            state.verificationState = .noChallenge(.awaitingConfirmation(password: password, emailPattern: pattern, codeLength: codeLength))
                        }
                        return state
                    })
                    if shouldDismiss {
                        controller.dismiss()
                    }
                case let .passwordSet(password, hasRecoveryEmail, _):
                    strongSelf.updateState(animated: false, { state in
                        var state = state
                        state.verificationState = .passwordChallenge(hint: "", state: .none, hasRecoveryEmail: hasRecoveryEmail)
                        return state
                    })
                    if let password = password {
                        strongSelf.checkPassword(password: password, inBackground: true, completion: { [weak controller] in
                            controller?.dismiss()
                        })
                    } else if shouldDismiss {
                        controller.dismiss()
                    }
            }
        })
        self.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        
        /*var completionImpl: ((String, String, Bool) -> Void)?
        let state: CreatePasswordState
        if let emailPattern = emailPattern {
            state = .pendingVerification(emailPattern: emailPattern)
        } else {
            state = .setup(currentPassword: nil)
        }
        let controller = createPasswordController(account: self.account, context: .secureId, state: state, completion: { password, hint, hasRecoveryEmail in
            completionImpl?(password, hint, hasRecoveryEmail)
        }, updatePasswordEmailConfirmation: { [weak self] pattern in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateState(animated: false, { state in
                var state = state
                if let verificationState = state.verificationState, case .noChallenge = verificationState {
                    state.verificationState = .noChallenge(pattern?.1)
                }
                return state
            })
        })
        completionImpl = { [weak self, weak controller] password, hint, hasRecoveryEmail in
            guard let strongSelf = self else {
                controller?.dismiss()
                return
            }
            strongSelf.updateState(animated: false, { state in
                var state = state
                state.verificationState = .passwordChallenge(hint: hint, state: .none, hasRecoveryEmail: hasRecoveryEmail)
                return state
            })
            strongSelf.checkPassword(password: password, inBackground: true, completion: {
                controller?.view.endEditing(true)
                controller?.dismiss()
            })
        }
        self.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))*/
    }
    
    @objc private func grantAccess() {
        switch self.state {
            case let .form(form):
                if case let .form(peerId, scope, publicKey, callbackUrl, opaquePayload, opaqueNonce) = self.mode, let encryptedFormData = form.encryptedFormData, let formData = form.formData {
                    let values = parseRequestedFormFields(formData.requestedFields, values: formData.values, primaryLanguageByCountry: encryptedFormData.primaryLanguageByCountry).map({ $0.1 }).flatMap({ $0 })
                    
                    let _ = (grantSecureIdAccess(network: self.context.account.network, peerId: encryptedFormData.servicePeer.id, publicKey: publicKey, scope: scope, opaquePayload: opaquePayload, opaqueNonce: opaqueNonce, values: values, requestedFields: formData.requestedFields)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        self?.dismiss()
                        if let callbackUrl = callbackUrl {
                            self?.openUrl(secureIdCallbackUrl(with: callbackUrl, peerId: peerId, result: .success, parameters: [:]))
                        }
                    })
                }
            case .list:
                break
        }
    }
    
    @objc private func infoPressed() {
        self.present(textAlertController(context: self.context, title: self.presentationData.strings.Passport_InfoTitle, text: self.presentationData.strings.Passport_InfoText.replacingOccurrences(of: "**", with: ""), actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {}), TextAlertAction(type: .genericAction, title: self.presentationData.strings.Passport_InfoLearnMore, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: strongSelf.presentationData.strings.Passport_InfoFAQ_URL, forceExternal: false, presentationData: strongSelf.presentationData, navigationController: strongSelf.navigationController as? NavigationController, dismissInput: {
                self?.view.endEditing(true)
            })
        })]), in: .window(.root))
    }
}
