import AccountContext
import AlertComponent
import AlertInputFieldComponent
import ComponentFlow
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import WalletContext

private final class WalletAuthorizedOperation<Value>: Disposable {
    private let context: AccountContext
    private let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private let present: (ViewController) -> Void
    private let operation: (String?) -> Signal<Value, WalletContext.WalletError>
    private let next: (Value) -> Void
    private let failed: (WalletContext.WalletError) -> Void
    private let authorizationRequestDisposable = MetaDisposable()
    private let operationDisposable = MetaDisposable()
    private weak var passwordController: ViewController?
    private var isDisposed = false
    private var isRunning = false
    private var didRetryWithoutRemovedPassword = false

    init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
        present: @escaping (ViewController) -> Void,
        operation: @escaping (String?) -> Signal<Value, WalletContext.WalletError>,
        next: @escaping (Value) -> Void,
        failed: @escaping (WalletContext.WalletError) -> Void
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.present = present
        self.operation = operation
        self.next = next
        self.failed = failed
        self.start(password: nil, inputState: nil, progress: nil)
    }

    func dispose() {
        guard !self.isDisposed else { return }
        self.isDisposed = true
        self.authorizationRequestDisposable.dispose()
        self.operationDisposable.dispose()
        self.passwordController?.dismiss(completion: nil)
    }

    private func cancel() {
        guard !self.isDisposed else { return }
        self.dispose()
        self.failed(.authorizationCancelled)
    }

    private func start(
        password: String?,
        inputState: AlertInputFieldComponent.ExternalState?,
        progress: ValuePromise<Bool>?
    ) {
        guard !self.isDisposed, !self.isRunning else { return }
        self.isRunning = true
        progress?.set(true)
        self.operationDisposable.set((self.operation(password)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self, !self.isDisposed else { return }
            progress?.set(false)
            self.passwordController?.dismiss(completion: nil)
            self.next(value)
        }, error: { [weak self] error in
            guard let self, !self.isDisposed else { return }
            self.isRunning = false
            progress?.set(false)
            switch error {
            case .requestPassword where inputState == nil:
                self.refreshCachedAuthorizationData()
                self.presentPasswordPrompt()
            case .requestPassword, .invalidPassword:
                inputState?.animateError()
            case .twoStepAuthMissing where password != nil && !self.didRetryWithoutRemovedPassword:
                self.retryAfterRemovedPassword(inputState: inputState, progress: progress)
            default:
                self.passwordController?.dismiss(completion: nil)
                self.failed(error)
            }
        }))
    }

    private func refreshCachedAuthorizationData() {
        self.authorizationRequestDisposable.set((self.context.engine.auth.twoStepAuthData()
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self, !self.isDisposed else {
                return
            }
            self.context.twoStepAuthData.set(.single(data))
        }, error: { _ in
        }))
    }

    private func retryAfterRemovedPassword(
        inputState: AlertInputFieldComponent.ExternalState?,
        progress: ValuePromise<Bool>?
    ) {
        self.didRetryWithoutRemovedPassword = true
        self.isRunning = true
        progress?.set(true)
        self.authorizationRequestDisposable.set((self.context.engine.auth.twoStepAuthData()
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self, !self.isDisposed else {
                return
            }
            self.context.twoStepAuthData.set(.single(data))
            self.isRunning = false
            guard data.currentPasswordDerivation == nil else {
                progress?.set(false)
                self.passwordController?.dismiss(completion: nil)
                self.failed(.twoStepAuthMissing)
                return
            }
            self.start(password: nil, inputState: inputState, progress: progress)
        }, error: { [weak self] _ in
            guard let self, !self.isDisposed else {
                return
            }
            self.isRunning = false
            progress?.set(false)
            self.passwordController?.dismiss(completion: nil)
            self.failed(.network)
        }))
    }

    private func presentPasswordPrompt() {
        let strings = (self.updatedPresentationData?.initial ?? self.context.sharedContext.currentPresentationData.with { $0 }).strings
        let inputState = AlertInputFieldComponent.ExternalState()
        let progress = ValuePromise<Bool>(false)
        let enabled = inputState.valueSignal
        |> map { !$0.isEmpty }
        var submit: (() -> Void)?
        let content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
            AnyComponentWithIdentity(
                id: "title",
                component: AnyComponent(AlertTitleComponent(title: strings.Wallet_Authorization_PasswordTitle))
            ),
            AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(AlertTextComponent(content: .plain(
                    strings.Wallet_Authorization_PasswordText
                )))
            ),
            AnyComponentWithIdentity(
                id: "password",
                component: AnyComponent(AlertInputFieldComponent(
                    context: self.context,
                    placeholder: strings.LoginPassword_PasswordPlaceholder,
                    isSecureTextEntry: true,
                    isInitiallyFocused: true,
                    externalState: inputState,
                    returnKeyAction: { submit?() }
                ))
            )
        ]
        let controller = AlertScreen(
            configuration: AlertScreen.Configuration(allowInputInset: true),
            content: content,
            actions: [
                .init(title: strings.Common_Cancel, action: { [weak self] in
                    self?.cancel()
                }),
                .init(
                    title: strings.Wallet_Continue,
                    type: .default,
                    action: { submit?() },
                    autoDismiss: false,
                    isEnabled: enabled,
                    progress: progress.get()
                )
            ],
            updatedPresentationData: self.updatedPresentationData ?? (
                self.context.sharedContext.currentPresentationData.with { $0 },
                self.context.sharedContext.presentationData
            )
        )
        controller.dismissed = { [weak self] byOutsideTap in
            if byOutsideTap { self?.cancel() }
        }
        submit = { [weak self] in
            guard let self else { return }
            self.start(password: inputState.value, inputState: inputState, progress: progress)
        }
        self.passwordController = controller
        self.present(controller)
    }
}

public func performWalletAuthorizedOperation<Value>(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    present: @escaping (ViewController) -> Void,
    operation: @escaping (String?) -> Signal<Value, WalletContext.WalletError>,
    next: @escaping (Value) -> Void,
    failed: @escaping (WalletContext.WalletError) -> Void
) -> Disposable {
    WalletAuthorizedOperation(
        context: context,
        updatedPresentationData: updatedPresentationData,
        present: present,
        operation: operation,
        next: next,
        failed: failed
    )
}

public func walletBackupEnableErrorMessage(_ error: WalletContext.WalletError, strings: PresentationStrings) -> (title: String, text: String) {
    switch error {
    case .walletKeyMismatch, .recoveryPhraseOutdated, .storage(.identityMismatch), .proofInvalid:
        return (strings.Wallet_Backup_VerifyPhraseErrorTitle, strings.Wallet_Backup_VerifyPhraseErrorText)
    case .rotationNotFound:
        return (strings.Wallet_Backup_PhraseUpdatePendingTitle, strings.Wallet_Backup_EnablePhraseUpdatePendingText)
    case .proofExpired:
        return (strings.Wallet_Authorization_VerificationExpiredTitle, strings.Wallet_Backup_EnableVerificationExpiredText)
    case .invalidMnemonic:
        return (strings.Wallet_Import_InvalidPhraseTitle, strings.Wallet_Backup_InvalidPhraseText)
    case .unavailable:
        return (strings.Wallet_Backup_WalletChangedTitle, strings.Wallet_Backup_EnableWalletChangedText)
    default:
        return walletAuthorizationErrorMessage(error, strings: strings) ?? (strings.Wallet_Backup_EnableErrorTitle, strings.Wallet_NetworkError)
    }
}

public func walletAuthorizationErrorMessage(_ error: WalletContext.WalletError, strings: PresentationStrings) -> (title: String, text: String)? {
    switch error {
    case .recoveryPhraseOutdated:
        return (strings.Wallet_Import_PhraseChangedTitle, strings.Wallet_Import_PhraseChangedText)
    case .twoStepAuthMissing:
        return (strings.Wallet_Authorization_TwoStepRequiredTitle, strings.Wallet_Authorization_TwoStepRequiredText)
    case let .passwordTooFresh(timeout):
        return (strings.Wallet_Authorization_PasswordTooNewTitle, strings.Wallet_Authorization_PasswordRetryAfter(timeIntervalString(strings: strings, value: timeout, usage: .afterTime)).string)
    case let .sessionTooFresh(timeout):
        return (strings.Wallet_Authorization_SessionTooNewTitle, strings.Wallet_Authorization_SessionRetryAfter(timeIntervalString(strings: strings, value: timeout, usage: .afterTime)).string)
    case .backupDisabled:
        return (strings.Wallet_Authorization_BackupDisabledTitle, strings.Wallet_Authorization_BackupDisabledText)
    case .backupNotAvailable:
        return (strings.Wallet_Authorization_BackupUnavailableTitle, strings.Wallet_Authorization_BackupUnavailableText)
    case .keyRotationFailed:
        return (
            strings.Wallet_Backup_UpdatePhraseErrorTitle,
            strings.Wallet_Authorization_UpdatePhraseErrorText
        )
    case .proofInvalid:
        return (
            strings.Wallet_Authorization_VerifyWalletErrorTitle,
            strings.Wallet_Authorization_VerifyWalletErrorText
        )
    case .proofExpired:
        return (
            strings.Wallet_Authorization_VerificationExpiredTitle,
            strings.Wallet_Authorization_VerificationExpiredText
        )
    default:
        return nil
    }
}
