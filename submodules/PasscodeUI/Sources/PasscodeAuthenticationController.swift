import Foundation
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import PasscodeCore
import PresentationDataUtils
import LocalAuthentication

private enum PasscodeAuthenticationPresentation {
    static weak var active: ViewController?
}

public func settingsPasscodeSessionController(
    context: AccountContext,
    preferredModalWidth: CGFloat? = nil,
    completion: @escaping (Result<PasscodeSession, PasscodeError>) -> Void
) -> ViewController? {
    weak var source: PasscodeSetupController?
    let lifecycle = PasscodeSettingsSessionState(session: nil)
    var finished = false
    let finish: (Result<PasscodeSession, PasscodeError>) -> Void = { result in
        guard !finished else {
            if case let .success(session) = result { session.invalidate() }
            return
        }
        finished = true
        completion(result)
    }
    let controller = settingsPasscodeAuthenticationController(context: context, scope: .settings, preferredModalWidth: preferredModalWidth, completion: { result in
        guard case let .success(session) = result else {
            if case let .failure(error) = result { finish(.failure(error)) }
            return
        }
        guard !finished, lifecycle.accepts(generation: lifecycle.generation), let source,
              let navigation = source.navigationController as? NavigationController,
              navigation.topViewController === source else {
            session.invalidate()
            finish(.failure(.cancelled))
            return
        }
        source.setupDisposable?.dispose()
        // The caller becomes the owner before replacing or popping this screen.
        finish(.success(session))
    })
    source = controller as? PasscodeSetupController
    source?.setupCancelled = {
        lifecycle.close()
        finish(.failure(.cancelled))
    }
    let accountId = context.account.id
    source?.setupDisposable = (combineLatest(
        context.sharedContext.applicationBindings.applicationInForeground,
        context.sharedContext.appLockContext.isPasscodeLocked,
        context.sharedContext.activeAccountContexts |> map { primary, _, _ in primary?.account.id == accountId }
    ) |> deliverOnMainQueue).start(next: { foreground, locked, current in
        lifecycle.updateEnvironment(foreground: foreground, locked: locked, currentAccount: current)
        if !foreground || locked || !current {
            finish(.failure(.cancelled))
            let remove: () -> Void = {
                guard let source else { return }
                source.view.isHidden = true
                if let navigation = source.navigationController as? NavigationController,
                   navigation.topViewController === source {
                    let _ = navigation.popViewController(animated: false)
                }
            }
            remove()
            // Environment signals may arrive before the caller pushes the screen.
            DispatchQueue.main.async(execute: remove)
        }
    })
    return controller
}

/// PIN-only navigation screen for opening settings and changing the passcode.
public func settingsPasscodeAuthenticationController(
    context: AccountContext,
    scope: PasscodeSession.Scope = .settings,
    preferredModalWidth: CGFloat? = nil,
    completion: @escaping (Result<PasscodeSession, PasscodeError>) -> Void
) -> ViewController? {
    precondition(Thread.isMainThread)
    precondition(scope == .settings || scope == .managePasscode)
    guard PasscodeAuthenticationPresentation.active == nil else { completion(.failure(.cancelled)); return nil }
    let reference: PasscodeCredentialReference
    do {
        guard let value = try PasscodeCredentialStore.shared.protectionSettings().passcode else {
            completion(.failure(.authenticationRequired))
            return nil
        }
        reference = value
    } catch {
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        context.sharedContext.presentGlobalController(textAlertController(context: context, title: nil, text: strings.PasscodeSettings_UpdateError, actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})]), nil)
        completion(.failure(error as? PasscodeError ?? .unavailable))
        return nil
    }
    let controller = PasscodeSetupController(context: context, mode: .entry(accessChallengeData(reference: reference)), authenticationScope: scope, preferredModalWidth: preferredModalWidth)
    var finished = false
    controller.authenticationCompleted = { result in
        guard !finished else {
            if case let .success(session) = result { session.invalidate() }
            return
        }
        finished = true
        PasscodeAuthenticationPresentation.active = nil
        completion(result)
    }
    PasscodeAuthenticationPresentation.active = controller
    return controller
}

/// Reuses the app's keypad to authorize an operation. The caller supplies any
/// biometric authentication that can issue a scoped credential.
public func passcodeAuthenticationController(
    context: AccountContext,
    scope: PasscodeSession.Scope,
    lifetime: PasscodeSession.Lifetime = .standard,
    biometricReason: String = "",
    authenticateBiometrics: ((LAContext) throws -> PasscodeSession)? = nil,
    completion: @escaping (Result<PasscodeSession, PasscodeError>) -> Void
) -> ViewController? {
    precondition(Thread.isMainThread)
    guard PasscodeAuthenticationPresentation.active == nil else { completion(.failure(.cancelled)); return nil }
    let reference: PasscodeCredentialReference?
    do { reference = try PasscodeCredentialStore.shared.protectionSettings().passcode }
    catch { completion(.failure(.unavailable)); return nil }
    guard let reference else { completion(.failure(.authenticationRequired)); return nil }
    let useBiometrics = authenticateBiometrics != nil
    weak var source: PasscodeEntryController?
    var finished = false
    let finish: (Result<PasscodeSession, PasscodeError>) -> Void = { result in
        guard !finished else {
            if case let .success(session) = result { session.invalidate() }
            return
        }
        finished = true
        if PasscodeAuthenticationPresentation.active === source {
            PasscodeAuthenticationPresentation.active = nil
        }
        completion(result)
    }
    let controller = PasscodeEntryController(
        applicationBindings: context.sharedContext.applicationBindings,
        accountManager: context.sharedContext.accountManager,
        appLockContext: context.sharedContext.appLockContext,
        presentationData: context.sharedContext.currentPresentationData.with { $0 },
        presentationDataSignal: context.sharedContext.presentationData,
        statusBarHost: context.sharedContext.mainWindow?.statusBarHost,
        challengeData: accessChallengeData(reference: reference),
        biometrics: useBiometrics ? .enabled(nil) : .none,
        arguments: PasscodeEntryControllerPresentationArguments(cancel: { finish(.failure(.cancelled)) }, modalPresentation: true, displayAppLock: false),
        authenticationScope: scope,
        authenticationLifetime: lifetime,
        biometricReason: biometricReason,
        authenticateBiometrics: authenticateBiometrics
    )
    source = controller
    PasscodeAuthenticationPresentation.active = controller
    controller.authenticated = { session in
        finish(.success(session))
    }
    controller.presentationCompleted = { [weak controller] in
        if useBiometrics { controller?.requestBiometrics() }
    }
    return controller
}

public func requestPasscodeAuthentication(context: AccountContext, scope: PasscodeSession.Scope, lifetime: PasscodeSession.Lifetime = .standard, biometricReason: String = "", authenticateBiometrics: ((LAContext) throws -> PasscodeSession)? = nil) async throws -> PasscodeSession {
    let pending = PendingPasscodeAuthentication<ViewController>(create: { completion in
        passcodeAuthenticationController(context: context, scope: scope, lifetime: lifetime, biometricReason: biometricReason, authenticateBiometrics: authenticateBiometrics, completion: completion)
    }, prepare: { controller, present in
        if authenticateBiometrics != nil, let controller = controller as? PasscodeEntryController {
            controller.requestBiometricsBeforePresentation(fallback: present)
        } else {
            present()
        }
    }, present: { controller in
        context.sharedContext.presentGlobalController(controller, nil)
    }, dismiss: { controller in
        controller.dismiss()
    })
    return try await withTaskCancellationHandler(operation: {
        try await withCheckedThrowingContinuation { continuation in
            pending.start { result in
                continuation.resume(with: result.mapError { $0 as Error })
            }
        }
    }, onCancel: { pending.cancel() })
}
