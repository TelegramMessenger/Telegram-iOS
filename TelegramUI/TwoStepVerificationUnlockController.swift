import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class TwoStepVerificationUnlockSettingsControllerArguments {
    let updatePasswordText: (String) -> Void
    let openForgotPassword: () -> Void
    let openSetupPassword: () -> Void
    let openDisablePassword: () -> Void
    let openSetupEmail: () -> Void
    let openResetPendingEmail: () -> Void
    
    init(updatePasswordText: @escaping (String) -> Void, openForgotPassword: @escaping () -> Void, openSetupPassword: @escaping () -> Void, openDisablePassword: @escaping () -> Void, openSetupEmail: @escaping () -> Void, openResetPendingEmail: @escaping () -> Void) {
        self.updatePasswordText = updatePasswordText
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
    case passwordEntry(String)
    case passwordEntryInfo(String)
    
    case passwordSetup
    case passwordSetupInfo(String)
    
    case changePassword
    case turnPasswordOff
    case setupRecoveryEmail(Bool)
    case passwordInfo(String)
    
    case pendingEmailInfo(String)
    
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
            case let .passwordEntry(text):
                if case .passwordEntry(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .passwordEntryInfo(text):
                if case .passwordEntryInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .passwordSetupInfo(text):
                if case .passwordSetupInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .setupRecoveryEmail(exists):
                if case .setupRecoveryEmail(exists) = rhs {
                    return true
                } else {
                    return false
                }
            case let .passwordInfo(text):
                if case .passwordInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .pendingEmailInfo(text):
                if case .pendingEmailInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case .passwordSetup, .changePassword, .turnPasswordOff:
                return lhs.stableId == rhs.stableId
        }
    }
    
    static func <(lhs: TwoStepVerificationUnlockSettingsEntry, rhs: TwoStepVerificationUnlockSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: TwoStepVerificationUnlockSettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .passwordEntry(text):
                return ItemListSingleLineInputItem(title: NSAttributedString(string: "Password", textColor: .black), text: text, placeholder: "", type: .password, spacing: 10.0, tag: TwoStepVerificationUnlockSettingsEntryTag.password, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePasswordText(updatedText)
                }, action: {
                })
            case let .passwordEntryInfo(text):
                return ItemListTextItem(text: .markdown(text), sectionId: self.section, linkAction: { action in
                    switch action {
                        case .tap:
                            arguments.openForgotPassword()
                    }
                })
            case .passwordSetup:
                return ItemListActionItem(title: "Set Additional Password", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupPassword()
                })
            case let .passwordSetupInfo(text):
                return ItemListTextItem(text: .markdown(text), sectionId: self.section)
            case .changePassword:
                return ItemListActionItem(title: "Change Password", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupPassword()
                })
            case .turnPasswordOff:
                return ItemListActionItem(title: "Turn Password Off", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openDisablePassword()
                })
            case let .setupRecoveryEmail(exists):
                let title: String
                if exists {
                    title = "Change Recovery E-Mail"
                } else {
                    title = "Set Recovery E-Mail"
                }
                return ItemListActionItem(title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupEmail()
                })
            case let .passwordInfo(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
            case let .pendingEmailInfo(text):
                return ItemListTextItem(text: .markdown(text), sectionId: self.section, linkAction: { action in
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

private func twoStepVerificationUnlockSettingsControllerEntries(state: TwoStepVerificationUnlockSettingsControllerState,data: TwoStepVerificationUnlockSettingsControllerData) -> [TwoStepVerificationUnlockSettingsEntry] {
    var entries: [TwoStepVerificationUnlockSettingsEntry] = []
    
    switch data {
        case let .access(configuration):
            if let configuration = configuration {
                switch configuration {
                case let .notSet(pendingEmailPattern):
                    if pendingEmailPattern.isEmpty {
                        entries.append(.passwordSetup)
                        entries.append(.passwordSetupInfo("You can set a password that will be required when you log in on a new device in addition to the code you cat in the SMS."))
                    } else {
                        entries.append(.pendingEmailInfo("Please check your e-mail and click on the validation link to complete Two-Step verification setup. Be sure to check the spam folder as well.\n\n\(pendingEmailPattern)\n\n[Abort Two-Step Verification Setup]()"))
                    }
                case let .set(hint, _, _):
                    entries.append(.passwordEntry(state.passwordText))
                    if hint.isEmpty {
                        entries.append(.passwordEntryInfo("You have enabled Two-Step verification, so your account is protected with an additional password.\n\n[Forgot password?](forgot)"))
                    } else {
                        entries.append(.passwordEntryInfo("hint: \(escapedPlaintextForMarkdown(hint))\n\nYou have enabled Two-Step verification, so your account is protected with an additional password.\n\n[Forgot password?](forgot)"))
                    }
                }
            }
        case let .manage(_, emailSet, pendingEmailPattern):
            entries.append(.changePassword)
            entries.append(.turnPasswordOff)
            entries.append(.setupRecoveryEmail(emailSet))
            if pendingEmailPattern.isEmpty {
                entries.append(.passwordInfo("You have enabled Two-Step verification.\nYou'll need the password you set up here to log in to your Telegram account."))
            } else {
                entries.append(.passwordInfo("Your recovery e-mail \(pendingEmailPattern) is not yet active and pending confirmation."))
            }
    }
    
    return entries
}

enum TwoStepVerificationUnlockSettingsControllerMode {
    case access
    case manage(password: String, email: String, pendingEmailPattern: String)
}

private enum TwoStepVerificationUnlockSettingsControllerData {
    case access(configuration: TwoStepVerificationConfiguration?)
    case manage(password: String, emailSet: Bool, pendingEmailPattern: String)
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
        case let .manage(password, email, pendingEmailPattern):
            dataPromise.set(.single(.manage(password: password, emailSet: !email.isEmpty, pendingEmailPattern: pendingEmailPattern)))
    }
    
    let arguments = TwoStepVerificationUnlockSettingsControllerArguments(updatePasswordText: { updatedText in
        updateState {
            $0.withUpdatedPasswordText(updatedText)
        }
    }, openForgotPassword: {
        setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        switch configuration {
                            case let .set(_, hasRecoveryEmail, _):
                                if hasRecoveryEmail {
                                    updateState {
                                        $0.withUpdatedChecking(true)
                                    }
                                    setupResultDisposable.set((requestTwoStepVerificationPasswordRecoveryCode(account: account) |> deliverOnMainQueue).start(next: { emailPattern in
                                        updateState {
                                            $0.withUpdatedChecking(false)
                                        }
                                        let result = Promise<Bool>()
                                        let controller = twoStepVerificationResetController(account: account, emailPattern: emailPattern, result: result)
                                        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                        setupDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] _ in
                                                dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationConfiguration.notSet(pendingEmailPattern: ""))))
                                                controller?.dismiss()
                                        }))
                                    }, error: { _ in
                                        updateState {
                                            $0.withUpdatedChecking(false)
                                        }
                                        presentControllerImpl?(standardTextAlertController(title: nil, text: "An error occured. Please try again later.", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }))
                                } else {
                                    presentControllerImpl?(standardTextAlertController(title: nil, text: "Since you haven't provided a recovery e-mail when setting up your password, your remaining options are either to remember your password or to reset your account.", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
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
        setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        switch configuration {
                            case .notSet:
                                let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                                let controller = twoStepVerificationPasswordEntryController(account: account, mode: .setup, result: result)
                                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                                    if let updatedPassword = updatedPassword {
                                        if let pendingEmailPattern = updatedPassword.pendingEmailPattern {
                                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationConfiguration.notSet(pendingEmailPattern: pendingEmailPattern))))
                                        } else {
                                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: false, pendingEmailPattern: "")))
                                        }
                                        controller?.dismiss()
                                    }
                                }))
                            case .set:
                                break
                        }
                    }
                case let .manage(password, emailSet, pendingEmailPattern):
                    let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                    let controller = twoStepVerificationPasswordEntryController(account: account, mode: .change(current: password), result: result)
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                        if let updatedPassword = updatedPassword {
                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: emailSet, pendingEmailPattern: pendingEmailPattern)))
                            controller?.dismiss()
                        }
                    }))
            }
        }))
    }, openDisablePassword: {
        presentControllerImpl?(standardTextAlertController(title: nil, text: "Are you sure you want to disable your password?", actions: [TextAlertAction(type: .defaultAction, title: "Cancel", action: {}), TextAlertAction(type: .genericAction, title: "OK", action: {
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
                            case let .manage(password, _, _):
                                return updateTwoStepVerificationPassword(account: account, currentPassword: password, updatedPassword: .none)
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
    }, openSetupEmail: {
        setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
            switch data {
                case .access:
                    break
                case let .manage(password, _, _):
                    let result = Promise<TwoStepVerificationPasswordEntryResult?>()
                    let controller = twoStepVerificationPasswordEntryController(account: account, mode: .setupEmail(password: password), result: result)
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    setupResultDisposable.set((result.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] updatedPassword in
                        if let updatedPassword = updatedPassword {
                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: updatedPassword.password, emailSet: true, pendingEmailPattern: updatedPassword.pendingEmailPattern ?? "")))
                            controller?.dismiss()
                        }
                    }))
            }
        }))
    }, openResetPendingEmail: {
        updateState { state in
            return state.withUpdatedChecking(true)
        }
        setupDisposable.set((updateTwoStepVerificationPassword(account: account, currentPassword: nil, updatedPassword: .none) |> deliverOnMainQueue).start(next: { _ in
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
    
    let signal = combineLatest(statePromise.get(), dataPromise.get() |> deliverOnMainQueue) |> deliverOnMainQueue
        |> map { state, data -> (ItemListControllerState, (ItemListNodeState<TwoStepVerificationUnlockSettingsEntry>, TwoStepVerificationUnlockSettingsEntry.ItemGenerationArguments)) in
            
            var rightNavigationButton: ItemListNavigationButton?
            var emptyStateItem: ItemListControllerEmptyStateItem?
            let title: String
            switch data {
                case let .access(configuration):
                    title = "Password"
                    if let configuration = configuration {
                        if state.checking {
                            rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
                        } else {
                            switch configuration {
                                case .notSet:
                                    break
                                case .set:
                                    rightNavigationButton = ItemListNavigationButton(title: "Next", style: .bold, enabled: true, action: {
                                        var wasChecking = false
                                        var password: String?
                                        updateState { state in
                                            wasChecking = state.checking
                                            password = state.passwordText
                                            return state.withUpdatedChecking(true)
                                        }
                                        
                                        if let password = password, !wasChecking {
                                            checkDisposable.set((requestTwoStepVerifiationSettings(account: account, password: password) |> deliverOnMainQueue).start(next: { settings in
                                                updateState {
                                                    $0.withUpdatedChecking(false)
                                                }
                                                
                                                replaceControllerImpl?(twoStepVerificationUnlockSettingsController(account: account, mode: .manage(password: password, email: settings.email, pendingEmailPattern: "")))
                                            }, error: { error in
                                                updateState {
                                                    $0.withUpdatedChecking(false)
                                                }
                                                
                                                let text: String
                                                switch error {
                                                    case .limitExceeded:
                                                        text = "You have entered invalid password too many times. Please try again later."
                                                    case .invalidPassword:
                                                        text = "Invalid password. Please try again."
                                                    case .generic:
                                                        text = "An error occured. Please try again later."
                                                }
                                                
                                                presentControllerImpl?(standardTextAlertController(title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                            }))
                                        }
                                    })
                            }
                        }
                    } else {
                        emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
                    }
                case .manage:
                    title = "Two-Step Verification"
                    if state.checking {
                        rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
                    }
            }
            
            let controllerState = ItemListControllerState(title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: false)
            let listState = ItemListNodeState(entries: twoStepVerificationUnlockSettingsControllerEntries(state: state, data: data), style: .blocks, focusItemTag: TwoStepVerificationUnlockSettingsEntryTag.password, emptyStateItem: emptyStateItem, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    replaceControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.replaceTopController(c, animated: true)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    
    return controller
}
