import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class TwoStepVerificationUnlockSettingsControllerArguments {
    let updatePasswordText: (String) -> Void
    let checkPassword: () -> Void
    let openForgotPassword: () -> Void
    let openSetupPassword: () -> Void
    let openDisablePassword: () -> Void
    let openSetupEmail: () -> Void
    let openResetPendingEmail: () -> Void
    
    init(updatePasswordText: @escaping (String) -> Void, checkPassword: @escaping () -> Void, openForgotPassword: @escaping () -> Void, openSetupPassword: @escaping () -> Void, openDisablePassword: @escaping () -> Void, openSetupEmail: @escaping () -> Void, openResetPendingEmail: @escaping () -> Void) {
        self.updatePasswordText = updatePasswordText
        self.checkPassword = checkPassword
        self.openForgotPassword = openForgotPassword
        self.openSetupPassword = openSetupPassword
        self.openDisablePassword = openDisablePassword
        self.openSetupEmail = openSetupEmail
        self.openResetPendingEmail = openResetPendingEmail
    }
}

private enum TwoStepVerificationUnlockSettingsSection: Int32 {
    case password
}

private enum TwoStepVerificationUnlockSettingsEntryTag: ItemListItemTag {
    case password
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? TwoStepVerificationUnlockSettingsEntryTag {
            switch self {
                case .password:
                    if case .password = other {
                        return true
                    } else {
                        return false
                    }
            }
        } else {
            return false
        }
    }
}

private enum TwoStepVerificationUnlockSettingsEntry: ItemListNodeEntry {
    case passwordEntry(PresentationTheme, String, String)
    case passwordEntryInfo(PresentationTheme, String)
    
    case passwordSetup(PresentationTheme, String)
    case passwordSetupInfo(PresentationTheme, String)
    
    case changePassword(PresentationTheme, String)
    case turnPasswordOff(PresentationTheme, String)
    case setupRecoveryEmail(PresentationTheme, String)
    case passwordInfo(PresentationTheme, String)
    
    case pendingEmailInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return TwoStepVerificationUnlockSettingsSection.password.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .passwordEntry:
                return 0
            case .passwordEntryInfo:
                return 1
            case .passwordSetup:
                return 2
            case .passwordSetupInfo:
                return 3
            case .changePassword:
                return 4
            case .turnPasswordOff:
                return 5
            case .setupRecoveryEmail:
                return 6
            case .passwordInfo:
                return 7
            case .pendingEmailInfo:
                return 8
        }
    }
    
    static func ==(lhs: TwoStepVerificationUnlockSettingsEntry, rhs: TwoStepVerificationUnlockSettingsEntry) -> Bool {
        switch lhs {
            case let .passwordEntry(lhsTheme, lhsText, lhsValue):
                if case let .passwordEntry(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .passwordEntryInfo(lhsTheme, lhsText):
                if case let .passwordEntryInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .passwordSetupInfo(lhsTheme, lhsText):
                if case let .passwordSetupInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .setupRecoveryEmail(lhsTheme, lhsText):
                if case let .setupRecoveryEmail(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .passwordInfo(lhsTheme, lhsText):
                if case let .passwordInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .pendingEmailInfo(lhsTheme, lhsText):
                if case let .pendingEmailInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .passwordSetup(lhsTheme, lhsText):
                if case let .passwordSetup(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .changePassword(lhsTheme, lhsText):
                if case let .changePassword(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .turnPasswordOff(lhsTheme, lhsText):
                if case let .turnPasswordOff(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: TwoStepVerificationUnlockSettingsEntry, rhs: TwoStepVerificationUnlockSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: TwoStepVerificationUnlockSettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .passwordEntry(theme, text, value):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(string: text, textColor: theme.list.itemPrimaryTextColor), text: value, placeholder: "", type: .password, spacing: 10.0, tag: TwoStepVerificationUnlockSettingsEntryTag.password, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePasswordText(updatedText)
                }, action: {
                    arguments.checkPassword()
                })
            case let .passwordEntryInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section, linkAction: { action in
                    switch action {
                        case .tap:
                            arguments.openForgotPassword()
                    }
                })
            case let .passwordSetup(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupPassword()
                })
            case let .passwordSetupInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
            case let .changePassword(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupPassword()
                })
            case let .turnPasswordOff(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openDisablePassword()
                })
            case let .setupRecoveryEmail(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupEmail()
                })
            case let .passwordInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .pendingEmailInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section, linkAction: { action in
                    switch action {
                        case .tap:
                            arguments.openResetPendingEmail()
                    }
                })
        }
    }
}

private struct TwoStepVerificationUnlockSettingsControllerState: Equatable {
    let passwordText: String
    let checking: Bool
    
    init(passwordText: String, checking: Bool) {
        self.passwordText = passwordText
        self.checking = checking
    }
    
    static func ==(lhs: TwoStepVerificationUnlockSettingsControllerState, rhs: TwoStepVerificationUnlockSettingsControllerState) -> Bool {
        if lhs.passwordText != rhs.passwordText {
            return false
        }
        if lhs.checking != rhs.checking {
            return false
        }
        
        return true
    }
    
    func withUpdatedPasswordText(_ passwordText: String) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: passwordText, checking: self.checking)
    }
    
    func withUpdatedChecking(_ cheking: Bool) -> TwoStepVerificationUnlockSettingsControllerState {
        return TwoStepVerificationUnlockSettingsControllerState(passwordText: self.passwordText, checking: cheking)
    }
}

private func twoStepVerificationUnlockSettingsControllerEntries(presentationData: PresentationData, state: TwoStepVerificationUnlockSettingsControllerState, data: TwoStepVerificationUnlockSettingsControllerData) -> [TwoStepVerificationUnlockSettingsEntry] {
    var entries: [TwoStepVerificationUnlockSettingsEntry] = []
    
    switch data {
        case let .access(configuration):
            if let configuration = configuration {
                switch configuration {
                    case let .notSet(pendingEmailPattern):
                        if pendingEmailPattern.isEmpty {
                            entries.append(.passwordSetup(presentationData.theme, presentationData.strings.TwoStepAuth_SetPassword))
                            entries.append(.passwordSetupInfo(presentationData.theme, presentationData.strings.TwoStepAuth_SetPasswordHelp))
                        } else {
                            entries.append(.pendingEmailInfo(presentationData.theme, presentationData.strings.TwoStepAuth_ConfirmationText + "\n\n\(pendingEmailPattern)\n\n[" + presentationData.strings.TwoStepAuth_ConfirmationAbort + "]()"))
                        }
                    case let .set(hint, _, _, _):
                        entries.append(.passwordEntry(presentationData.theme, presentationData.strings.TwoStepAuth_EnterPasswordPassword, state.passwordText))
                        if hint.isEmpty {
                            entries.append(.passwordEntryInfo(presentationData.theme, presentationData.strings.TwoStepAuth_EnterPasswordHelp + "\n\n[" + presentationData.strings.TwoStepAuth_EnterPasswordForgot + "](forgot)"))
                        } else {
                            entries.append(.passwordEntryInfo(presentationData.theme, presentationData.strings.TwoStepAuth_EnterPasswordHint(escapedPlaintextForMarkdown(hint)).0 + "\n\n" + presentationData.strings.TwoStepAuth_EnterPasswordHelp + "\n\n[" + presentationData.strings.TwoStepAuth_EnterPasswordForgot + "](forgot)"))
                        }
                }
            }
        case let .manage(_, emailSet, pendingEmailPattern, _):
            entries.append(.changePassword(presentationData.theme, presentationData.strings.TwoStepAuth_ChangePassword))
            entries.append(.turnPasswordOff(presentationData.theme, presentationData.strings.TwoStepAuth_RemovePassword))
            entries.append(.setupRecoveryEmail(presentationData.theme, emailSet ? presentationData.strings.TwoStepAuth_ChangeEmail : presentationData.strings.TwoStepAuth_SetupEmail))
            if pendingEmailPattern.isEmpty {
                entries.append(.passwordInfo(presentationData.theme, presentationData.strings.TwoStepAuth_EnterPasswordHelp))
            } else {
                entries.append(.passwordInfo(presentationData.theme, presentationData.strings.TwoStepAuth_PendingEmailHelp(pendingEmailPattern).0))
            }
    }
    
    return entries
}

enum TwoStepVerificationUnlockSettingsControllerMode {
    case access
    case manage(password: String, email: String, pendingEmailPattern: String, hasSecureValues: Bool)
}

private enum TwoStepVerificationUnlockSettingsControllerData {
    case access(configuration: TwoStepVerificationConfiguration?)
    case manage(password: String, emailSet: Bool, pendingEmailPattern: String, hasSecureValues: Bool)
}

func twoStepVerificationUnlockSettingsController(account: Account, mode: TwoStepVerificationUnlockSettingsControllerMode) -> ViewController {
    let initialState = TwoStepVerificationUnlockSettingsControllerState(passwordText: "", checking: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((TwoStepVerificationUnlockSettingsControllerState) -> TwoStepVerificationUnlockSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkDisposable = MetaDisposable()
    actionsDisposable.add(checkDisposable)
    
    let setupDisposable = MetaDisposable()
    actionsDisposable.add(setupDisposable)
    
    let setupResultDisposable = MetaDisposable()
    actionsDisposable.add(setupResultDisposable)
    
    let dataPromise = Promise<TwoStepVerificationUnlockSettingsControllerData>()
    
    switch mode {
        case .access:
            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: nil)) |> then(twoStepVerificationConfiguration(account: account) |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: $0) }))
        case let .manage(password, email, pendingEmailPattern, hasSecureValues):
            dataPromise.set(.single(.manage(password: password, emailSet: !email.isEmpty, pendingEmailPattern: pendingEmailPattern, hasSecureValues: hasSecureValues)))
    }
    
    let arguments = TwoStepVerificationUnlockSettingsControllerArguments(updatePasswordText: { updatedText in
        updateState {
            $0.withUpdatedPasswordText(updatedText)
        }
    }, checkPassword: {
        var wasChecking = false
        var password: String?
        updateState { state in
            wasChecking = state.checking
            password = state.passwordText
            return state.withUpdatedChecking(true)
        }
        
        if let password = password, !password.isEmpty, !wasChecking {
            checkDisposable.set((requestTwoStepVerifiationSettings(network: account.network, password: password) |> deliverOnMainQueue).start(next: { settings in
                updateState {
                    $0.withUpdatedChecking(false)
                }
                
                replaceControllerImpl?(twoStepVerificationUnlockSettingsController(account: account, mode: .manage(password: password, email: settings.email, pendingEmailPattern: "", hasSecureValues: settings.secureSecret != nil)))
            }, error: { error in
                updateState {
                    $0.withUpdatedChecking(false)
                }
                
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.LoginPassword_FloodError
                    case .invalidPassword:
                        text = presentationData.strings.LoginPassword_InvalidPasswordError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                }
                
                presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }))
        }
    }, openForgotPassword: {
        setupDisposable.set((dataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                        switch configuration {
                            case let .set(_, hasRecoveryEmail, _, _):
                                if hasRecoveryEmail {
                                    updateState {
                                        $0.withUpdatedChecking(true)
                                    }
                                    setupResultDisposable.set((requestTwoStepVerificationPasswordRecoveryCode(network: account.network)
                                    |> deliverOnMainQueue).start(next: { emailPattern in
                                        updateState {
                                            $0.withUpdatedChecking(false)
                                        }
                                        
                                        var completionImpl: (() -> Void)?
                                        let controller = resetPasswordController(account: account, emailPattern: emailPattern, completion: {
                                            completionImpl?()
                                        })
                                        completionImpl = { [weak controller] in
                                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationConfiguration.notSet(pendingEmailPattern: ""))))
                                            controller?.view.endEditing(true)
                                            controller?.dismiss()
                                        }
                                        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }, error: { _ in
                                        updateState {
                                            $0.withUpdatedChecking(false)
                                        }
                                        presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }))
                                } else {
                                    presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.TwoStepAuth_RecoveryUnavailable, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                }
                            case .notSet:
                                break
                        }
                    }
                case .manage:
                    break
            }
        }))
    }, openSetupPassword: {
        setupDisposable.set((dataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        switch configuration {
                            case .notSet:
                                var completionImpl: ((String, String, Bool) -> Void)?
                                var updatePatternImpl: ((String?) -> Void)?
                                let controller = createPasswordController(account: account, state: .setup(currentPassword: nil), completion: { password, hint, emailPattern in
                                    completionImpl?(password, hint, emailPattern)
                                }, updatePasswordEmailConfirmation: { pattern in
                                    updatePatternImpl?(pattern)
                                }, processPasswordEmailConfirmation: false)
                                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                completionImpl = { [weak controller] password, hint, hasRecovery in
                                    dataPromise.set(.single(.manage(password: password, emailSet: hasRecovery, pendingEmailPattern: "", hasSecureValues: false)))
                                    controller?.view.endEditing(true)
                                    controller?.dismiss()
                                }
                            
                                updatePatternImpl = { [weak controller] pattern in
                                    if let pattern = pattern {
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: pattern))))
                                    } else {
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: ""))))
                                    }
                                    controller?.view.endEditing(true)
                                    controller?.dismiss()
                                }
                                
                                /*let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                                let controller = twoStepVerificationPasswordEntryController(account: account, mode: .setup, result: result)
                                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                                    if let updatedPassword = updatedPassword {
                                        if let pendingEmailPattern = updatedPassword.pendingEmailPattern {
                                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationConfiguration.notSet(pendingEmailPattern: pendingEmailPattern))))
                                        } else {
                                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: false, pendingEmailPattern: "", hasSecureValues: false)))
                                        }
                                        controller?.dismiss()
                                    }
                                }))*/
                            case .set:
                                break
                        }
                    }
                case let .manage(password, hasRecovery, pendingEmailPattern, hasSecureValues):
                    var completionImpl: ((String, String, Bool) -> Void)?
                    var updatePatternImpl: ((String?) -> Void)?
                    let controller = createPasswordController(account: account, state: .setup(currentPassword: password), completion: { password, hint, emailPattern in
                        completionImpl?(password, hint, emailPattern)
                    }, updatePasswordEmailConfirmation: { pattern in
                        updatePatternImpl?(pattern)
                    }, processPasswordEmailConfirmation: false)
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    completionImpl = { [weak controller] password, hint, _ in
                        dataPromise.set(.single(.manage(password: password, emailSet: hasRecovery, pendingEmailPattern: pendingEmailPattern, hasSecureValues: hasSecureValues)))
                        controller?.view.endEditing(true)
                        controller?.dismiss()
                    }
                    
                    updatePatternImpl = { [weak controller] pattern in
                        if let pattern = pattern {
                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: pattern))))
                        } else {
                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: ""))))
                        }
                        controller?.view.endEditing(true)
                        controller?.dismiss()
                    }
                    /*
                    let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                    let controller = twoStepVerificationPasswordEntryController(account: account, mode: .change(current: password), result: result)
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                        if let updatedPassword = updatedPassword {
                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: emailSet, pendingEmailPattern: pendingEmailPattern, hasSecureValues: hasSecureValues)))
                            controller?.dismiss()
                        }
                    }))*/
            }
        }))
    }, openDisablePassword: {
        setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .manage(_, _, _, hasSecureValues):
                    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                    var text = presentationData.strings.TwoStepAuth_PasswordRemoveConfirmation
                    if hasSecureValues {
                        text = presentationData.strings.TwoStepAuth_PasswordRemovePassportConfirmation
                    }
                    presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                        var disablePassword = false
                        updateState { state in
                            if state.checking {
                                return state
                            } else {
                                disablePassword = true
                                return state.withUpdatedChecking(true)
                            }
                        }
                        if disablePassword {
                            setupDisposable.set((dataPromise.get()
                                |> take(1)
                                |> mapError { _ -> UpdateTwoStepVerificationPasswordError in return .generic }
                                |> mapToSignal { data -> Signal<Void, UpdateTwoStepVerificationPasswordError> in
                                    switch data {
                                    case .access:
                                        return .complete()
                                    case let .manage(password, _, _, _):
                                        return updateTwoStepVerificationPassword(network: account.network, currentPassword: password, updatedPassword: .none)
                                            |> mapToSignal { _ -> Signal<Void, UpdateTwoStepVerificationPasswordError> in
                                                return .complete()
                                        }
                                    }
                                }
                                |> deliverOnMainQueue).start(error: { _ in
                                    updateState {
                                        $0.withUpdatedChecking(false)
                                    }
                                }, completed: {
                                    updateState {
                                        $0.withUpdatedChecking(false)
                                    }
                                    dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: ""))))
                                }))
                        }
                    })]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                default:
                    break
            }
        }))
    }, openSetupEmail: {
        setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
            switch data {
                case .access:
                    break
                case let .manage(password, _, _, hasSecureValues):
                    let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                    let controller = twoStepVerificationPasswordEntryController(account: account, mode: .setupEmail(password: password), result: result)
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                        if let updatedPassword = updatedPassword {
                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: true, pendingEmailPattern: updatedPassword.pendingEmailPattern ?? "", hasSecureValues: hasSecureValues)))
                            controller?.dismiss()
                        }
                    }))
            }
        }))
    }, openResetPendingEmail: {
        updateState { state in
            return state.withUpdatedChecking(true)
        }
        setupDisposable.set((updateTwoStepVerificationPassword(network: account.network, currentPassword: nil, updatedPassword: .none) |> deliverOnMainQueue).start(next: { _ in
            updateState { state in
                return state.withUpdatedChecking(false)
            }
            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmailPattern: ""))))
        }, error: { _ in
            updateState { state in
                return state.withUpdatedChecking(false)
            }
        }))
    })
    
    var initialFocusImpl: (() -> Void)?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), dataPromise.get() |> deliverOnMainQueue) |> deliverOnMainQueue
        |> map { presentationData, state, data -> (ItemListControllerState, (ItemListNodeState<TwoStepVerificationUnlockSettingsEntry>, TwoStepVerificationUnlockSettingsEntry.ItemGenerationArguments)) in
            
            var rightNavigationButton: ItemListNavigationButton?
            var emptyStateItem: ItemListControllerEmptyStateItem?
            let title: String
            switch data {
                case let .access(configuration):
                    title = presentationData.strings.TwoStepAuth_Title
                    if let configuration = configuration {
                        if state.checking {
                            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
                        } else {
                            switch configuration {
                                case .notSet:
                                    break
                                case let .set(_, _, _, hasSecureValues):
                                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Next), style: .bold, enabled: true, action: {
                                        arguments.checkPassword()
                                    })
                            }
                        }
                    } else {
                        emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
                    }
                case .manage:
                    title = presentationData.strings.PrivacySettings_TwoStepAuth
                    if state.checking {
                        rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
                    }
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: twoStepVerificationUnlockSettingsControllerEntries(presentationData: presentationData, state: state, data: data), style: .blocks, focusItemTag: TwoStepVerificationUnlockSettingsEntryTag.password, emptyStateItem: emptyStateItem, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    replaceControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.replaceTopController(c, animated: true)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    initialFocusImpl = { [weak controller] in
        guard let controller = controller, controller.didAppearOnce else {
            return
        }
        var resultItemNode: ItemListSingleLineInputItemNode?
        let _ = controller.frameForItemNode({ itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode, let tag = itemNode.tag, tag.isEqual(to: TwoStepVerificationUnlockSettingsEntryTag.password) {
                resultItemNode = itemNode
                return true
            }
            return false
        })
        if let resultItemNode = resultItemNode {
            resultItemNode.focus()
        }
    }
    controller.didAppear = { firstTime in
        if !firstTime {
            return
        }
        initialFocusImpl?()
    }
    
    return controller
}
