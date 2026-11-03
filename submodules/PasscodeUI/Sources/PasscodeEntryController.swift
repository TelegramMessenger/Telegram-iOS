import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import LocalAuth
import TelegramStringFormatting
import PasscodeCore
import LocalAuthentication
import MonotonicTime

public final class PasscodeEntryControllerPresentationArguments {
    let animated: Bool
    let fadeIn: Bool
    let lockIconInitialFrame: () -> CGRect
    let cancel: (() -> Void)?
    let modalPresentation: Bool
    let displayAppLock: Bool
    
    public init(animated: Bool = true, fadeIn: Bool = false, lockIconInitialFrame: @escaping () -> CGRect = { return CGRect() }, cancel: (() -> Void)? = nil, modalPresentation: Bool = false, displayAppLock: Bool = true) {
        self.animated = animated
        self.fadeIn = fadeIn
        self.lockIconInitialFrame = lockIconInitialFrame
        self.cancel = cancel
        self.modalPresentation = modalPresentation
        self.displayAppLock = displayAppLock
    }
}

public enum PasscodeEntryControllerBiometricsMode {
    case none
    case enabled(Data?)
}

public final class PasscodeEntryController: ViewController {
    private var controllerNode: PasscodeEntryControllerNode {
        return self.displayNode as! PasscodeEntryControllerNode
    }
    
    private let applicationBindings: TelegramApplicationBindings
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private var energyUsageSettings: EnergyUsageSettings?
    private let appLockContext: AppLockContext
    private let presentationDataSignal: Signal<PresentationData, NoError>
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
        
    private let challengeData: PostboxAccessChallengeData
    private let authenticationScope: PasscodeSession.Scope
    private let authenticationLifetime: PasscodeSession.Lifetime
    private let biometricReason: String
    private let authenticateBiometrics: ((LAContext) throws -> PasscodeSession)?
    private let biometrics: PasscodeEntryControllerBiometricsMode
    private let arguments: PasscodeEntryControllerPresentationArguments
    
    public var presentationCompleted: (() -> Void)?
    public var completed: (() -> Void)?
    public var authenticated: ((PasscodeSession) -> Void)?
    private var authenticationLifecycle: PasscodeEntryLifecycle
    private var authenticationContext: LAContext?
    private var checkingCode = false
    private var cooldownRequestId: UInt64 = 0
    private let authenticationDismissal = PasscodeAuthenticationDismissal()
    private var removingController = false
    private var leavingNavigation = false
    private var navigationRemovalCompleted: (() -> Void)?
    private var isPasscodeLocked = false
    private let credentialLockDisposable = MetaDisposable()
    
    private let biometricsDisposable = MetaDisposable()
    private let biometricAuthenticationDisposable = MetaDisposable()
    private var hasOngoingBiometricsRequest = false
    private var skipNextBiometricsRequest = false
    private var biometricPresentationFallback: (@MainActor () -> Void)?
    
    private var inBackgroundDisposable: Disposable?
    
    public init(applicationBindings: TelegramApplicationBindings, accountManager: AccountManager<TelegramAccountManagerTypes>, appLockContext: AppLockContext, presentationData: PresentationData, presentationDataSignal: Signal<PresentationData, NoError>, statusBarHost: StatusBarHost?, challengeData: PostboxAccessChallengeData, biometrics: PasscodeEntryControllerBiometricsMode, arguments: PasscodeEntryControllerPresentationArguments, authenticationScope: PasscodeSession.Scope = .appUnlock, authenticationLifetime: PasscodeSession.Lifetime = .standard, biometricReason: String = "", authenticateBiometrics: ((LAContext) throws -> PasscodeSession)? = nil) {
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        self.appLockContext = appLockContext
        self.presentationData = presentationData
        self.presentationDataSignal = presentationDataSignal
        self.challengeData = challengeData
        self.authenticationScope = authenticationScope
        self.authenticationLifetime = authenticationLifetime
        self.biometricReason = biometricReason
        self.authenticateBiometrics = authenticateBiometrics
        self.biometrics = biometrics
        self.arguments = arguments
        self.authenticationLifecycle = PasscodeEntryLifecycle(isMainApp: applicationBindings.isMainApp)
        
        super.init(navigationBarPresentationData: nil)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.updateStatusBarStyle(.White, animated: false)
        
        self.presentationDataDisposable = (presentationDataSignal
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.inBackgroundDisposable = (applicationBindings.applicationInForeground
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.authenticationLifecycle.updateApplicationInForeground(value) {
                strongSelf.skipNextBiometricsRequest = false
                strongSelf.authenticationContext?.invalidate()
                strongSelf.authenticationContext = nil
                strongSelf.biometricsDisposable.set(nil)
                strongSelf.biometricAuthenticationDisposable.set(nil)
                strongSelf.checkingCode = false
                strongSelf.hasOngoingBiometricsRequest = false
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.isUserInteractionEnabled = strongSelf.authenticationDismissal.phase == .active
                    strongSelf.controllerNode.resetInput()
                }
                if strongSelf.authenticated != nil {
                    strongSelf.dismiss()
                }
            }
            if value, strongSelf.applicationBindings.isMainApp, strongSelf.isNodeLoaded {
                strongSelf.refreshCredentialCooldown()
            }
        })
        self.credentialLockDisposable.set((appLockContext.isPasscodeLocked |> deliverOnMainQueue).start(next: { [weak self] locked in
            guard let self else { return }
            self.isPasscodeLocked = locked
            if locked, self.authenticated != nil { self.dismiss() }
        }))
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.biometricsDisposable.dispose()
        self.biometricAuthenticationDisposable.dispose()
        self.inBackgroundDisposable?.dispose()
        self.credentialLockDisposable.dispose()
        self.authenticationLifecycle.dismiss()
        self.authenticationContext?.invalidate()
        let cancelled = self.arguments.cancel
        self.authenticationDismissal.finish(.failure(.cancelled), stopAuthentication: {}, removeController: { $0() }, completed: { _ in cancelled?() })
        self.authenticationDismissal.didRemoveController()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        let passcodeType: PasscodeEntryFieldType
        switch self.challengeData.passcodeKind {
        case .digits4: passcodeType = .digits4
        case .digits6: passcodeType = .digits6
        default: passcodeType = .alphanumeric
        }
        let biometricsType: LocalAuthBiometricAuthentication?
        if case let .enabled(data) = self.biometrics {
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                #if targetEnvironment(simulator)
                biometricsType = .touchId
                #else
                if self.authenticateBiometrics != nil || data == LocalAuth.evaluatedPolicyDomainState || (data == nil && !self.applicationBindings.isMainApp) {
                    biometricsType = LocalAuth.biometricAuthentication
                } else {
                    biometricsType = nil
                }
                #endif
            } else {
                biometricsType = LocalAuth.biometricAuthentication
            }
        } else {
            biometricsType = nil
        }
        self.displayNode = PasscodeEntryControllerNode(accountManager: self.accountManager, presentationData: self.presentationData, theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, passcodeType: passcodeType, biometricsType: biometricsType, arguments: self.arguments, modalPresentation: self.arguments.modalPresentation)
        self.displayNodeDidLoad()
        
        self.refreshCredentialCooldown()
        self.controllerNode.checkPasscode = { [weak self] passcode in
            self?.verifyCode(passcode)
        }
        self.controllerNode.cancelRequested = { [weak self] in
            self?.finishAuthentication(.failure(.cancelled), down: true)
        }
        self.controllerNode.requestBiometrics = { [weak self] in
            if let strongSelf = self {
                strongSelf.requestBiometrics(force: true)
            }
        }
    }
    
    private func refreshCredentialCooldown() {
        guard self.isNodeLoaded, !self.checkingCode, self.authenticationLifecycle.canAuthenticate else { return }
        self.cooldownRequestId &+= 1
        let requestId = self.cooldownRequestId
        let generation = self.authenticationLifecycle.generation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try PasscodeCredentialStore.shared.cooldownRemaining() }
            DispatchQueue.main.async {
                guard let self, self.cooldownRequestId == requestId,
                      self.authenticationLifecycle.acceptsResult(generation: generation) else { return }
                switch result {
                case let .success(remaining):
                    self.updateCredentialCooldown(remaining)
                case .failure:
                    self.controllerNode.updateCredentialError(true)
                }
            }
        }
    }

    private func updateCredentialCooldown(_ remaining: Int) {
        self.controllerNode.updateCredentialError(false)
        if remaining > 0 {
            var boot: Int32 = 0
            let uptime = getDeviceUptimeSeconds(&boot)
            self.controllerNode.updateInvalidAttempts(AccessChallengeAttempts(count: 6, bootTimestamp: boot, uptime: uptime - 60 + Int32(remaining)))
        } else {
            self.controllerNode.updateInvalidAttempts(nil)
        }
    }

    private func verifyCode(_ code: String) {
        guard !self.checkingCode, self.authenticationLifecycle.canAuthenticate else { return }
        self.checkingCode = true
        self.cooldownRequestId &+= 1
        self.controllerNode.updateCredentialError(false)
        self.controllerNode.isUserInteractionEnabled = false
        let generation = self.authenticationLifecycle.generation
        let challenge = self.challengeData
        let scope = self.authenticationScope
        let lifetime = self.authenticationLifetime
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<PasscodeSession, Error> = Result {
                switch challenge {
                case let .numericalPassword(value):
                    _ = try PasscodeCredentialStore.shared.migrateLegacy(code: value, kind: value.count == 6 ? .digits6 : .digits4)
                case let .plaintextPassword(value):
                    _ = try PasscodeCredentialStore.shared.migrateLegacy(code: value, kind: .alphanumeric)
                case .none, .secured: break
                }
                let reference = passcodeCredentialReference(from: challenge)
                return try PasscodeCredentialStore.shared.verify(code, reference: reference, scope: scope, lifetime: lifetime)
            }
            DispatchQueue.main.async {
                guard let self, self.authenticationLifecycle.acceptsResult(generation: generation) else {
                    if case let .success(session) = result { session.invalidate() }
                    return
                }
                self.checkingCode = false
                self.controllerNode.isUserInteractionEnabled = true
                switch result {
                case let .success(session):
                    if self.authenticated != nil {
                        self.finishAuthentication(.success(session))
                    } else {
                        session.invalidate()
                        if self.completed != nil {
                            self.finishAuthentication(.success(nil))
                        } else {
                            self.appLockContext.unlock()
                        }
                        let isMainApp = self.applicationBindings.isMainApp
                        let _ = updatePresentationPasscodeSettingsInteractively(accountManager: self.accountManager, { settings in
                            isMainApp ? settings.withUpdatedBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState) : settings.withUpdatedShareBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState)
                        }).start()
                    }
                case let .failure(error):
                    switch error as? PasscodeError ?? .unavailable {
                    case .invalidCode:
                        self.controllerNode.animateError()
                        self.refreshCredentialCooldown()
                    case let .cooldown(remaining):
                        self.controllerNode.resetInput()
                        self.updateCredentialCooldown(remaining)
                    default:
                        self.controllerNode.resetInput()
                        self.controllerNode.updateCredentialError(true)
                    }
                }
            }
        }
    }

    func requestBiometricsBeforePresentation(fallback: @escaping @MainActor () -> Void) {
        guard self.authenticationDismissal.phase == .active else { return }
        guard self.authenticationLifecycle.canAuthenticate, !self.isPasscodeLocked else {
            self.finishAuthentication(.failure(.cancelled), animated: false)
            return
        }
        // A fallback presentation must not automatically retry biometrics.
        self.presentationCompleted = nil
        guard case .enabled = self.biometrics, self.authenticateBiometrics != nil else {
            fallback()
            return
        }
        self.biometricPresentationFallback = fallback
        self.requestSecureBiometrics()
    }

    private func requestSecureBiometrics() {
        guard !self.hasOngoingBiometricsRequest, self.authenticationLifecycle.canAuthenticate,
              let authenticateBiometrics = self.authenticateBiometrics else { return }
        self.hasOngoingBiometricsRequest = true
        let generation = self.authenticationLifecycle.generation
        let context = LAContext()
        context.localizedReason = self.biometricReason
        context.localizedFallbackTitle = ""
        context.touchIDAuthenticationAllowableReuseDuration = 0
        self.authenticationContext = context
        let scope = self.authenticationScope
        let lifetime = self.authenticationLifetime
        let biometricAuthentication = self.appLockContext.beginBiometricAuthentication()
        self.biometricAuthenticationDisposable.set(biometricAuthentication)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try validatedPasscodeBiometricSession(authenticateBiometrics(context), scope: scope, lifetime: lifetime)
            }
            DispatchQueue.main.async {
                biometricAuthentication.dispose()
                guard let self, self.authenticationLifecycle.acceptsResult(generation: generation) else {
                    if case let .success(session) = result { session.invalidate() }
                    context.invalidate()
                    return
                }
                self.authenticationContext = nil
                self.hasOngoingBiometricsRequest = false
                context.invalidate()
                if case let .success(session) = result, self.authenticated != nil {
                    self.finishAuthentication(.success(session))
                } else {
                    if case let .success(session) = result { session.invalidate() }
                    if let fallback = self.biometricPresentationFallback {
                        self.biometricPresentationFallback = nil
                        fallback()
                    } else {
                        self.controllerNode.animateError()
                        self.ensureInputFocused()
                    }
                }
            }
        }
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard self.authenticationDismissal.phase == .active else {
            // A presentation queued before cancellation must not revive input.
            self.removeController(completion: {})
            return
        }
        if self.authenticated != nil, !self.authenticationLifecycle.canAuthenticate || self.isPasscodeLocked {
            self.finishAuthentication(.failure(.cancelled), animated: false)
            return
        }
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.controllerNode.activateInput()
        if self.arguments.animated {
            self.controllerNode.animateIn(iconFrame: self.arguments.lockIconInitialFrame(), completion: { [weak self] in
                guard let self, self.authenticationLifecycle.canAuthenticate else { return }
                self.presentationCompleted?()
            })
        } else {
            self.controllerNode.initialAppearance(fadeIn: self.arguments.fadeIn)
            self.presentationCompleted?()
        }
    }
    
    public func ensureInputFocused() {
        guard self.authenticationLifecycle.canAuthenticate else { return }
        self.controllerNode.activateInput()
    }
    
    public func requestBiometrics(force: Bool = false) {
        guard self.authenticationLifecycle.canAuthenticate else { return }
        if self.authenticateBiometrics != nil {
            guard case .enabled = self.biometrics else { return }
            self.requestSecureBiometrics()
            return
        }
        guard case let .enabled(data) = self.biometrics, let _ = LocalAuth.biometricAuthentication else {
            return
        }
        
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            if data == nil && self.applicationBindings.isMainApp {
                return
            }
        }
        
        if self.skipNextBiometricsRequest {
            self.skipNextBiometricsRequest = false
            if !force {
                return
            }
        }
        
        if self.hasOngoingBiometricsRequest {
            if !force {
                return
            }
        }
        
        self.hasOngoingBiometricsRequest = true
        let generation = self.authenticationLifecycle.generation
        let biometricAuthentication = self.appLockContext.beginBiometricAuthentication()
        self.biometricAuthenticationDisposable.set(biometricAuthentication)
        
        self.biometricsDisposable.set((LocalAuth.auth(reason: self.presentationData.strings.EnterPasscode_TouchId) |> deliverOnMainQueue).start(next: { [weak self] result, evaluatedPolicyDomainState in
            biometricAuthentication.dispose()
            guard let strongSelf = self, strongSelf.authenticationLifecycle.acceptsResult(generation: generation) else {
                return
            }
            
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                if case let .enabled(storedDomainState) = strongSelf.biometrics, evaluatedPolicyDomainState != nil {
                    if !strongSelf.applicationBindings.isMainApp && storedDomainState == nil {
                        let _ = updatePresentationPasscodeSettingsInteractively(accountManager: strongSelf.accountManager, { settings in
                            return settings.withUpdatedShareBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState)
                        }).start()
                    } else if storedDomainState != evaluatedPolicyDomainState {
                        strongSelf.controllerNode.hideBiometrics()
                        return
                    }
                }
            }
            
            if result {
                strongSelf.controllerNode.animateSuccess()
                
                if strongSelf.completed != nil {
                    Queue.mainQueue().after(1.5) { [weak self] in
                        guard let self, self.authenticationLifecycle.acceptsResult(generation: generation) else {
                            return
                        }
                        self.finishAuthentication(.success(nil))
                    }
                    strongSelf.hasOngoingBiometricsRequest = false
                } else {
                    strongSelf.appLockContext.unlock()
                    strongSelf.hasOngoingBiometricsRequest = false
                }
            } else {
                strongSelf.hasOngoingBiometricsRequest = false
                strongSelf.skipNextBiometricsRequest = true
            }
        }))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        if let completion { self.authenticationDismissal.afterRemoval(completion) }
        self.finishAuthentication(.failure(.cancelled))
    }

    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let completion { self.authenticationDismissal.afterRemoval(completion) }
        self.finishAuthentication(.failure(.cancelled), animated: flag)
    }

    public override func viewWillLeaveNavigation() {
        super.viewWillLeaveNavigation()
        guard !self.removingController,
              let navigation = self.navigationController as? NavigationController,
              !navigation.viewControllers.contains(where: { $0 === self }) else { return }
        self.leavingNavigation = true
        self.finishAuthentication(.failure(.cancelled))
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let completed = self.navigationRemovalCompleted {
            self.navigationRemovalCompleted = nil
            completed()
        } else if self.leavingNavigation {
            self.authenticationDismissal.didRemoveController()
        } else if !self.removingController {
            let navigation = self.navigationController as? NavigationController
            let removedFromNavigation = navigation.map { navigation in
                !navigation.viewControllers.contains(where: { $0 === self })
            } ?? false
            if removedFromNavigation || self.view.superview == nil {
                // The owner has already removed us. Do not ask it to dismiss
                // again (its modal container may still be finishing teardown).
                self.leavingNavigation = true
                self.finishAuthentication(.failure(.cancelled), animated: false)
                self.authenticationDismissal.didRemoveController()
            }
        }
    }

    private func stopAuthentication() {
        self.authenticationLifecycle.dismiss()
        self.biometricPresentationFallback = nil
        self.authenticationContext?.invalidate()
        self.authenticationContext = nil
        self.biometricsDisposable.set(nil)
        self.biometricAuthenticationDisposable.set(nil)
        self.checkingCode = false
        self.hasOngoingBiometricsRequest = false
        if self.isNodeLoaded {
            self.controllerNode.isUserInteractionEnabled = false
            self.view.endEditing(true)
        }
    }

    private func finishAuthentication(_ result: PasscodeAuthenticationDismissal.Outcome, down: Bool = false, animated: Bool = true) {
        let authenticated = self.authenticated
        let completed = self.completed
        let cancelled = self.arguments.cancel
        self.authenticationDismissal.finish(result, stopAuthentication: {
            self.stopAuthentication()
        }, removeController: { completion in
            // Navigation already owns this transition; wait for disappearance.
            guard !self.leavingNavigation else { return }
            if animated, self.isNodeLoaded, self.view.superview != nil {
                self.controllerNode.animateOut(down: down) { [self] in
                    self.removeController(completion: completion)
                }
            } else {
                self.removeController(completion: completion)
            }
        }, completed: { result in
            switch result {
            case let .success(session?):
                if let authenticated { authenticated(session) } else { session.invalidate() }
            case .success(nil):
                completed?()
            case .failure:
                cancelled?()
            }
        })
    }

    private func removeController(completion: @escaping () -> Void) {
        self.removingController = true
        if self.isNodeLoaded { self.view.endEditing(true) }
        if let navigation = self.navigationController as? NavigationController {
            self.navigationRemovalCompleted = completion
            navigation.filterController(self, animated: false)
            // A pending/unloaded controller has no disappearance callback.
            // Otherwise wait for viewDidDisappear, including deferred updates.
            if !self.isNodeLoaded || self.view.superview == nil {
                let completed = self.navigationRemovalCompleted
                self.navigationRemovalCompleted = nil
                completed?()
            }
        } else if let presenting = self.presentingViewController {
            presenting.dismiss(animated: false, completion: completion)
        } else {
            completion()
        }
    }
}

// Ordinary app/Share authorization stays separate from the settings-session flow.
public func passcodeEntryController(
    context: AccountContext,
    animateIn: Bool = true,
    modalPresentation: Bool = false,
    completion: @escaping (Bool) -> Void
) -> Signal<ViewController?, NoError> {
    return passcodeEntryController(
        accountManager: context.sharedContext.accountManager,
        applicationBindings: context.sharedContext.applicationBindings,
        presentationData: context.sharedContext.currentPresentationData.with { $0 },
        updatedPresentationData: context.sharedContext.presentationData,
        statusBarHost: context.sharedContext.mainWindow?.statusBarHost,
        appLockContext: context.sharedContext.appLockContext,
        animateIn: animateIn,
        modalPresentation: modalPresentation,
        completion: completion
    )
}

public func passcodeEntryController(
    accountManager: AccountManager<TelegramAccountManagerTypes>,
    applicationBindings: TelegramApplicationBindings,
    presentationData: PresentationData,
    updatedPresentationData: Signal<PresentationData, NoError>,
    statusBarHost: StatusBarHost?,
    appLockContext: AppLockContext,
    animateIn: Bool = true,
    modalPresentation: Bool = false,
    completion: @escaping (Bool) -> Void
) -> Signal<ViewController?, NoError> {
    return accountManager.transaction { transaction -> PostboxAccessChallengeData in
        return transaction.getAccessChallengeData()
    }
    |> mapToSignal { accessChallengeData -> Signal<(PostboxAccessChallengeData, PresentationPasscodeSettings?), NoError> in
        return accountManager.transaction { transaction -> (PostboxAccessChallengeData, PresentationPasscodeSettings?) in
            let passcodeSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings)?.get(PresentationPasscodeSettings.self)
            return (accessChallengeData, passcodeSettings)
        }
    }
    |> deliverOnMainQueue
    |> map { (challenge, passcodeSettings) -> ViewController? in
        if case .none = challenge {
            completion(true)
            return nil
        } else {
            let biometrics: PasscodeEntryControllerBiometricsMode
            #if targetEnvironment(simulator)
            biometrics = .enabled(nil)
            #else
            if let passcodeSettings = passcodeSettings, passcodeSettings.enableBiometrics {
                biometrics = .enabled(applicationBindings.isMainApp ? passcodeSettings.biometricsDomainState : passcodeSettings.shareBiometricsDomainState)
            } else {
                biometrics = .none
            }
            #endif
            let controller = PasscodeEntryController(applicationBindings: applicationBindings, accountManager: accountManager, appLockContext: appLockContext, presentationData: presentationData, presentationDataSignal: updatedPresentationData, statusBarHost: statusBarHost, challengeData: challenge, biometrics: biometrics, arguments: PasscodeEntryControllerPresentationArguments(animated: false, fadeIn: true, cancel: {
                completion(false)
            }, modalPresentation: modalPresentation))
            controller.presentationCompleted = { [weak controller] in
                Queue.mainQueue().after(0.5, { [weak controller] in
                    controller?.requestBiometrics()
                })
            }
            controller.completed = {
                completion(true)
            }
            return controller
        }
    }
}
