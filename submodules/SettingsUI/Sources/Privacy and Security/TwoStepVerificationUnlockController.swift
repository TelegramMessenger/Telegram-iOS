import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TextFormat
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import PasswordSetupUI
import Markdown

private final class TwoStepVerificationUnlockSettingsControllerArguments {
    let updatePasswordText: (String) -> Void
    let checkPassword: () -> Void
    let openForgotPassword: () -> Void
    let openSetupPassword: () -> Void
    let openDisablePassword: () -> Void
    let openSetupEmail: () -> Void
    let openResetPendingEmail: () -> Void
    let updateEmailCode: (String) -> Void
    let openConfirmEmail: () -> Void
    
    init(updatePasswordText: @escaping (String) -> Void, checkPassword: @escaping () -> Void, openForgotPassword: @escaping () -> Void, openSetupPassword: @escaping () -> Void, openDisablePassword: @escaping () -> Void, openSetupEmail: @escaping () -> Void, openResetPendingEmail: @escaping () -> Void, updateEmailCode: @escaping (String) -> Void, openConfirmEmail: @escaping () -> Void) {
        self.updatePasswordText = updatePasswordText
        self.checkPassword = checkPassword
        self.openForgotPassword = openForgotPassword
        self.openSetupPassword = openSetupPassword
        self.openDisablePassword = openDisablePassword
        self.openSetupEmail = openSetupEmail
        self.openResetPendingEmail = openResetPendingEmail
        self.updateEmailCode = updateEmailCode
        self.openConfirmEmail = openConfirmEmail
    }
}

private enum TwoStepVerificationUnlockSettingsSection: Int32 {
    case password
    case email
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
    case passwordEntry(PresentationTheme, PresentationStrings, String, String)
    case passwordEntryInfo(PresentationTheme, String)
    
    case passwordSetup(PresentationTheme, String)
    case passwordSetupInfo(PresentationTheme, String)
    
    case changePassword(PresentationTheme, String)
    case turnPasswordOff(PresentationTheme, String)
    case setupRecoveryEmail(PresentationTheme, String)
    case passwordInfo(PresentationTheme, String)
    
    case pendingEmailConfirmInfo(PresentationTheme, String)
    case pendingEmailConfirmCode(PresentationTheme, PresentationStrings, String, String)
    case pendingEmailInfo(PresentationTheme, String)
    case pendingEmailOpenConfirm(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .pendingEmailConfirmInfo, .pendingEmailConfirmCode, .pendingEmailInfo, .pendingEmailOpenConfirm:
                return TwoStepVerificationUnlockSettingsSection.email.rawValue
            default:
                return TwoStepVerificationUnlockSettingsSection.password.rawValue
        }
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
            case .pendingEmailConfirmInfo:
                return 8
            case .pendingEmailConfirmCode:
                return 9
            case .pendingEmailInfo:
                return 10
            case .pendingEmailOpenConfirm:
                return 11
        }
    }
    
    static func <(lhs: TwoStepVerificationUnlockSettingsEntry, rhs: TwoStepVerificationUnlockSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TwoStepVerificationUnlockSettingsControllerArguments
        switch self {
            case let .passwordEntry(theme, strings, text, value):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: text, textColor: theme.list.itemPrimaryTextColor), text: value, placeholder: "", type: .password, spacing: 10.0, tag: TwoStepVerificationUnlockSettingsEntryTag.password, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePasswordText(updatedText)
                }, action: {
                    arguments.checkPassword()
                })
            case let .passwordEntryInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { action in
                    switch action {
                        case .tap:
                            arguments.openForgotPassword()
                    }
                })
            case let .passwordSetup(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupPassword()
                })
            case let .passwordSetupInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .changePassword(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupPassword()
                })
            case let .turnPasswordOff(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openDisablePassword()
                })
            case let .setupRecoveryEmail(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openSetupEmail()
                })
            case let .passwordInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .pendingEmailConfirmInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .pendingEmailConfirmCode(theme, strings, title, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: text, placeholder: title, type: .number, sectionId: self.section, textUpdated: { value in
                    arguments.updateEmailCode(value)
                }, action: {})
            case let .pendingEmailInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { action in
                    switch action {
                        case .tap:
                            arguments.openResetPendingEmail()
                    }
                })
            case let .pendingEmailOpenConfirm(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.openConfirmEmail()
                })
        }
    }
}

private struct TwoStepVerificationUnlockSettingsControllerState: Equatable {
    var passwordText: String = ""
    var checking: Bool = false
    var emailCode: String = ""
}

private func twoStepVerificationUnlockSettingsControllerEntries(presentationData: PresentationData, state: TwoStepVerificationUnlockSettingsControllerState, data: TwoStepVerificationUnlockSettingsControllerData) -> [TwoStepVerificationUnlockSettingsEntry] {
    var entries: [TwoStepVerificationUnlockSettingsEntry] = []
    
    switch data {
        case let .access(configuration):
            if let configuration = configuration {
                switch configuration {
                    case let .notSet(pendingEmail):
                        if let pendingEmail = pendingEmail {
                            entries.append(.pendingEmailConfirmInfo(presentationData.theme, presentationData.strings.TwoStepAuth_SetupPendingEmail(pendingEmail.email.pattern).0))
                            entries.append(.pendingEmailConfirmCode(presentationData.theme, presentationData.strings, presentationData.strings.TwoStepAuth_RecoveryCode, state.emailCode))
                             entries.append(.pendingEmailInfo(presentationData.theme, "[" + presentationData.strings.TwoStepAuth_ConfirmationAbort + "]()"))
                            
                            /*entries.append(.pendingEmailInfo(presentationData.theme, presentationData.strings.TwoStepAuth_ConfirmationText + "\n\n\(pendingEmailAndValue.pendingEmail.pattern)\n\n[" + presentationData.strings.TwoStepAuth_ConfirmationAbort + "]()"))*/
                        } else {
                            entries.append(.passwordSetup(presentationData.theme, presentationData.strings.TwoStepAuth_SetPassword))
                            entries.append(.passwordSetupInfo(presentationData.theme, presentationData.strings.TwoStepAuth_SetPasswordHelp))
                        }
                    case let .set(hint, _, _):
                        entries.append(.passwordEntry(presentationData.theme, presentationData.strings, presentationData.strings.TwoStepAuth_EnterPasswordPassword, state.passwordText))
                        if hint.isEmpty {
                            entries.append(.passwordEntryInfo(presentationData.theme, presentationData.strings.TwoStepAuth_EnterPasswordHelp + "\n\n[" + presentationData.strings.TwoStepAuth_EnterPasswordForgot + "](forgot)"))
                        } else {
                            entries.append(.passwordEntryInfo(presentationData.theme, presentationData.strings.TwoStepAuth_EnterPasswordHint(escapedPlaintextForMarkdown(hint)).0 + "\n\n" + presentationData.strings.TwoStepAuth_EnterPasswordHelp + "\n\n[" + presentationData.strings.TwoStepAuth_EnterPasswordForgot + "](forgot)"))
                        }
                }
            }
        case let .manage(_, emailSet, pendingEmail, _):
            entries.append(.changePassword(presentationData.theme, presentationData.strings.TwoStepAuth_ChangePassword))
            entries.append(.turnPasswordOff(presentationData.theme, presentationData.strings.TwoStepAuth_RemovePassword))
            entries.append(.setupRecoveryEmail(presentationData.theme, emailSet ? presentationData.strings.TwoStepAuth_ChangeEmail : presentationData.strings.TwoStepAuth_SetupEmail))
            if let _ = pendingEmail {
                entries.append(.pendingEmailConfirmInfo(presentationData.theme, presentationData.strings.TwoStepAuth_EmailSent))
                entries.append(.pendingEmailOpenConfirm(presentationData.theme, presentationData.strings.TwoStepAuth_EnterEmailCode))
            } else {
                entries.append(.passwordInfo(presentationData.theme, presentationData.strings.TwoStepAuth_GenericHelp))
            }
    }
    
    return entries
}

enum TwoStepVerificationUnlockSettingsControllerMode {
    case access(intro: Bool, data: Signal<TwoStepVerificationUnlockSettingsControllerData, NoError>?)
    case manage(password: String, email: String, pendingEmail: TwoStepVerificationPendingEmail?, hasSecureValues: Bool)
}

struct TwoStepVerificationPendingEmailState: Equatable {
    let password: String?
    let email: TwoStepVerificationPendingEmail
}

enum TwoStepVerificationAccessConfiguration: Equatable {
    case notSet(pendingEmail: TwoStepVerificationPendingEmailState?)
    case set(hint: String, hasRecoveryEmail: Bool, hasSecureValues: Bool)
    
    init(configuration: TwoStepVerificationConfiguration, password: String?) {
        switch configuration {
            case let .notSet(pendingEmail):
                self = .notSet(pendingEmail: pendingEmail.flatMap({ TwoStepVerificationPendingEmailState(password: password, email: $0) }))
            case let .set(hint, hasRecoveryEmail, _, hasSecureValues):
                self = .set(hint: hint, hasRecoveryEmail: hasRecoveryEmail, hasSecureValues: hasSecureValues)
        }
    }
}

enum TwoStepVerificationUnlockSettingsControllerData: Equatable {
    case access(configuration: TwoStepVerificationAccessConfiguration?)
    case manage(password: String, emailSet: Bool, pendingEmail: TwoStepVerificationPendingEmail?, hasSecureValues: Bool)
}

func twoStepVerificationUnlockSettingsController(context: AccountContext, mode: TwoStepVerificationUnlockSettingsControllerMode, openSetupPasswordImmediately: Bool = false) -> ViewController {
    let initialState = TwoStepVerificationUnlockSettingsControllerState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((TwoStepVerificationUnlockSettingsControllerState) -> TwoStepVerificationUnlockSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController, Bool) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkDisposable = MetaDisposable()
    actionsDisposable.add(checkDisposable)
    
    let setupDisposable = MetaDisposable()
    actionsDisposable.add(setupDisposable)
    
    let setupResultDisposable = MetaDisposable()
    actionsDisposable.add(setupResultDisposable)
    
    let dataPromise = Promise<TwoStepVerificationUnlockSettingsControllerData>()
    let remoteDataPromise = Promise<TwoStepVerificationUnlockSettingsControllerData>()
    
    switch mode {
        case let .access(_, data):
            if let data = data {
                dataPromise.set(data)
            } else {
                dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: nil))
                |> then(remoteDataPromise.get()))
                remoteDataPromise.set(twoStepVerificationConfiguration(account: context.account)
                |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationAccessConfiguration(configuration: $0, password: nil)) })
            }
        case let .manage(password, email, pendingEmail, hasSecureValues):
            dataPromise.set(.single(.manage(password: password, emailSet: !email.isEmpty, pendingEmail: pendingEmail, hasSecureValues: hasSecureValues)))
    }
    
    let checkEmailConfirmation: () -> Void = {
        let _ = (dataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            var pendingEmailData: TwoStepVerificationPendingEmailState?
            switch data {
                case let .access(configuration):
                    guard let configuration = configuration else {
                        return
                    }
                    switch configuration {
                        case let .notSet(pendingEmail):
                            pendingEmailData = pendingEmail
                        case .set:
                            break
                    }
                case let .manage(password, _, pendingEmail, _):
                    if let pendingEmail = pendingEmail {
                        pendingEmailData = TwoStepVerificationPendingEmailState(password: password, email: pendingEmail)
                    }
            }
            if let pendingEmail = pendingEmailData {
                var code: String?
                updateState { state in
                    var state = state
                    if !state.checking {
                        code = state.emailCode
                        state.checking = true
                    }
                    return state
                }
                if let code = code {
                    setupDisposable.set((confirmTwoStepRecoveryEmail(network: context.account.network, code: code)
                    |> deliverOnMainQueue).start(error: { error in
                        updateState { state in
                            var state = state
                            state.checking = false
                            return state
                        }
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let text: String
                        switch error {
                            case .invalidEmail:
                                text = presentationData.strings.TwoStepAuth_EmailInvalid
                            case .invalidCode:
                                text = presentationData.strings.Login_InvalidCodeError
                            case .expired:
                                text = presentationData.strings.TwoStepAuth_EmailCodeExpired
                                let _ = (dataPromise.get()
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { data in
                                    switch data {
                                    case .access:
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmail: nil))))
                                    case let .manage(manage):
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: manage.password, emailSet: false, pendingEmail: nil, hasSecureValues: manage.hasSecureValues)))
                                    }
                                    
                                    updateState { state in
                                        var state = state
                                        state.checking = false
                                        state.emailCode = ""
                                        return state
                                    }
                                })
                            case .flood:
                                text = presentationData.strings.TwoStepAuth_FloodError
                            case .generic:
                                text = presentationData.strings.Login_UnknownError
                        }
                        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                    }, completed: {
                        let _ = (dataPromise.get()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { data in
                            switch data {
                                case .access:
                                    if let password = pendingEmail.password {
                                        dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: password, emailSet: true, pendingEmail: nil, hasSecureValues: false)))
                                    } else {
                                        dataPromise.set(.single(.access(configuration: nil))
                                            |> then(twoStepVerificationConfiguration(account: context.account) |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationAccessConfiguration(configuration: $0, password: pendingEmail.password)) }))
                                    }
                                case let .manage(manage):
                                    dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.manage(password: manage.password, emailSet: true, pendingEmail: nil, hasSecureValues: manage.hasSecureValues)))
                            }
                            
                            updateState { state in
                                var state = state
                                state.checking = false
                                state.emailCode = ""
                                return state
                            }
                        })
                    }))
                }
            }
        })
    }
    
    let arguments = TwoStepVerificationUnlockSettingsControllerArguments(updatePasswordText: { updatedText in
        updateState { state in
            var state = state
            state.passwordText = updatedText
            return state
        }
    }, checkPassword: {
        var wasChecking = false
        var password: String?
        updateState { state in
            var state = state
            wasChecking = state.checking
            password = state.passwordText
            state.checking = true
            return state
        }
        
        if let password = password, !password.isEmpty, !wasChecking {
            checkDisposable.set((requestTwoStepVerifiationSettings(network: context.account.network, password: password)
            |> mapToSignal { settings -> Signal<(TwoStepVerificationSettings, TwoStepVerificationPendingEmail?), AuthorizationPasswordVerificationError> in
                return twoStepVerificationConfiguration(account: context.account)
                |> mapError { _ -> AuthorizationPasswordVerificationError in
                    return .generic
                }
                |> map { configuration in
                    var pendingEmail: TwoStepVerificationPendingEmail?
                    if case let .set(configuration) = configuration {
                        pendingEmail = configuration.pendingEmail
                    }
                    return (settings, pendingEmail)
                }
            }
            |> deliverOnMainQueue).start(next: { settings, pendingEmail in
                updateState { state in
                    var state = state
                    state.checking = false
                    return state
                }
                
                replaceControllerImpl?(twoStepVerificationUnlockSettingsController(context: context, mode: .manage(password: password, email: settings.email, pendingEmail: pendingEmail, hasSecureValues: settings.secureSecret != nil)), true)
            }, error: { error in
                updateState { state in
                    var state = state
                    state.checking = false
                    return state
                }
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.LoginPassword_FloodError
                    case .invalidPassword:
                        text = presentationData.strings.LoginPassword_InvalidPasswordError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                }
                
                presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }))
        }
    }, openForgotPassword: {
        setupDisposable.set((dataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        switch configuration {
                            case let .set(_, hasRecoveryEmail, _):
                                if hasRecoveryEmail {
                                    updateState { state in
                                        var state = state
                                        state.checking = true
                                        return state
                                    }
                                    setupResultDisposable.set((requestTwoStepVerificationPasswordRecoveryCode(network: context.account.network)
                                    |> deliverOnMainQueue).start(next: { emailPattern in
                                        updateState { state in
                                            var state = state
                                            state.checking = false
                                            return state
                                        }
                                        
                                        var completionImpl: (() -> Void)?
                                        let controller = resetPasswordController(context: context, emailPattern: emailPattern, completion: {
                                            completionImpl?()
                                        })
                                        completionImpl = { [weak controller] in
                                            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmail: nil))))
                                            controller?.view.endEditing(true)
                                            controller?.dismiss()
                                            
                                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                            presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.TwoStepAuth_DisableSuccess, false)), nil)
                                        }
                                        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }, error: { _ in
                                        updateState { state in
                                            var state = state
                                            state.checking = false
                                            return state
                                        }
                                        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                    }))
                                } else {
                                    presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.TwoStepAuth_RecoveryUnavailable, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
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
                                let controller = SetupTwoStepVerificationController(context: context, initialState: .createPassword, stateUpdated: { update, shouldDismiss, controller in
                                    switch update {
                                        case .noPassword:
                                            dataPromise.set(.single(.access(configuration: .notSet(pendingEmail: nil))))
                                        case let .awaitingEmailConfirmation(password, pattern, codeLength):
                                            dataPromise.set(.single(.access(configuration: .notSet(pendingEmail: TwoStepVerificationPendingEmailState(password: password, email: TwoStepVerificationPendingEmail(pattern: pattern, codeLength: codeLength))))))
                                        case let .passwordSet(password, hasRecoveryEmail, hasSecureValues):
                                            if let password = password {
                                                dataPromise.set(.single(.manage(password: password, emailSet: hasRecoveryEmail, pendingEmail: nil, hasSecureValues: hasSecureValues)))
                                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                                presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.TwoStepAuth_EnabledSuccess, false)), nil)
                                            } else {
                                                dataPromise.set(.single(.access(configuration: nil))
                                                |> then(twoStepVerificationConfiguration(account: context.account) |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationAccessConfiguration(configuration: $0, password: password)) }))
                                            }
                                    }
                                    if shouldDismiss {
                                        controller.dismiss()
                                    }
                                })
                                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet, completion: {
                                    if case let .access(intro, _) = mode, intro {
                                        let controller = twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: false, data: dataPromise.get()))
                                        replaceControllerImpl?(controller, false)
                                    }
                                }))
                            case .set:
                                break
                        }
                    }
                case let .manage(password, hasRecovery, pendingEmail, hasSecureValues):
                    let controller = SetupTwoStepVerificationController(context: context, initialState: .updatePassword(current: password, hasRecoveryEmail: hasRecovery, hasSecureValues: hasSecureValues), stateUpdated: { update, shouldDismiss, controller in
                        switch update {
                            case .noPassword:
                                dataPromise.set(.single(.access(configuration: .notSet(pendingEmail: nil))))
                            case .awaitingEmailConfirmation:
                                assertionFailure()
                                break
                            case let .passwordSet(password, hasRecoveryEmail, hasSecureValues):
                                if let password = password {
                                    dataPromise.set(.single(.manage(password: password, emailSet: hasRecoveryEmail, pendingEmail: nil, hasSecureValues: hasSecureValues)))
                                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                    presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.TwoStepAuth_PasswordChangeSuccess, false)), nil)
                                } else {
                                    dataPromise.set(.single(.access(configuration: nil))
                                    |> then(twoStepVerificationConfiguration(account: context.account) |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationAccessConfiguration(configuration: $0, password: password)) }))
                                }
                        }
                        if shouldDismiss {
                            controller.dismiss()
                        }
                    })
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }))
    }, openDisablePassword: {
        setupDisposable.set((dataPromise.get() |> take(1) |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .manage(_, _, _, hasSecureValues):
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    var text = presentationData.strings.TwoStepAuth_PasswordRemoveConfirmation
                    if hasSecureValues {
                        text = presentationData.strings.TwoStepAuth_PasswordRemovePassportConfirmation
                    }
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                        var disablePassword = false
                        updateState { state in
                            var state = state
                            if state.checking {
                                return state
                            } else {
                                disablePassword = true
                                state.checking = true
                                return state
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
                                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                    presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.TwoStepAuth_DisableSuccess, false)), nil)
                                    return updateTwoStepVerificationPassword(network: context.account.network, currentPassword: password, updatedPassword: .none)
                                        |> mapToSignal { _ -> Signal<Void, UpdateTwoStepVerificationPasswordError> in
                                            return .complete()
                                        }
                                }
                            }
                            |> deliverOnMainQueue).start(error: { _ in
                                updateState { state in
                                    var state = state
                                    state.checking = false
                                    return state
                                }
                            }, completed: {
                                updateState { state in
                                    var state = state
                                    state.checking = false
                                    return state
                                }
                                //dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmail: nil))))
                                dismissImpl?()
                            }))
                        }
                    })]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                default:
                    break
            }
        }))
    }, openSetupEmail: {
        setupDisposable.set((dataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            switch data {
            case .access:
                break
            case let .manage(password, emailSet, _, hasSecureValues):
                //let controller = TwoFactorDataInputScreen(context: context, mode: .updateEmailAddress(password: password))
                
                let controller = SetupTwoStepVerificationController(context: context, initialState: .addEmail(hadRecoveryEmail: emailSet, hasSecureValues: hasSecureValues, password: password), stateUpdated: { update, shouldDismiss, controller in
                    switch update {
                        case .noPassword:
                            assertionFailure()
                            break
                        case let .awaitingEmailConfirmation(password, pattern, codeLength):
                            let data: TwoStepVerificationUnlockSettingsControllerData = .manage(password: password, emailSet: emailSet, pendingEmail: TwoStepVerificationPendingEmail(pattern: pattern, codeLength: codeLength), hasSecureValues: hasSecureValues)
                            dataPromise.set(.single(data))
                        case let .passwordSet(password, hasRecoveryEmail, hasSecureValues):
                            if let password = password {
                                let data: TwoStepVerificationUnlockSettingsControllerData = .manage(password: password, emailSet: hasRecoveryEmail, pendingEmail: nil, hasSecureValues: hasSecureValues)
                                dataPromise.set(.single(data))
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(emailSet ? presentationData.strings.TwoStepAuth_EmailChangeSuccess : presentationData.strings.TwoStepAuth_EmailAddSuccess, false)), nil)
                            } else {
                                dataPromise.set(.single(.access(configuration: nil))
                                    |> then(twoStepVerificationConfiguration(account: context.account) |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationAccessConfiguration(configuration: $0, password: password)) }))
                            }
                    }
                    if shouldDismiss {
                        controller.dismiss()
                    }
                })
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }))
    }, openResetPendingEmail: {
        updateState { state in
            var state = state
            state.checking = true
            return state
        }
        setupDisposable.set((updateTwoStepVerificationPassword(network: context.account.network, currentPassword: nil, updatedPassword: .none)
        |> deliverOnMainQueue).start(next: { _ in
            updateState { state in
                var state = state
                state.checking = false
                return state
            }
            dataPromise.set(.single(TwoStepVerificationUnlockSettingsControllerData.access(configuration: .notSet(pendingEmail: nil))))
        }, error: { _ in
            updateState { state in
                var state = state
                state.checking = false
                return state
            }
        }))
    }, updateEmailCode: { value in
        var previousValue: String?
        updateState { state in
            var state = state
            previousValue = state.emailCode
            state.emailCode = value
            return state
        }
        let _ = (dataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            switch data {
                case let .access(configuration):
                    if let configuration = configuration {
                        switch configuration {
                            case let .notSet(pendingEmail):
                                if let pendingEmail = pendingEmail, let codeLength = pendingEmail.email.codeLength {
                                    if let previousValue = previousValue, previousValue.count != codeLength && value.count == codeLength {
                                        checkEmailConfirmation()
                                    }
                                }
                            case .set:
                                break
                        }
                    }
                case .manage:
                    break
            }
        })
    }, openConfirmEmail: {
        let _ = (dataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            switch data {
                case .access:
                    break
                case let .manage(password, emailSet, pendingEmail, hasSecureValues):
                    guard let pendingEmail = pendingEmail else {
                        return
                    }
                    let controller = SetupTwoStepVerificationController(context: context, initialState: .confirmEmail(password: password, hasSecureValues: hasSecureValues, pattern: pendingEmail.pattern, codeLength: pendingEmail.codeLength), stateUpdated: { update, shouldDismiss, controller in
                        switch update {
                            case .noPassword:
                                assertionFailure()
                                break
                            case let .awaitingEmailConfirmation(password, pattern, codeLength):
                                let data: TwoStepVerificationUnlockSettingsControllerData = .manage(password: password, emailSet: emailSet, pendingEmail: TwoStepVerificationPendingEmail(pattern: pattern, codeLength: codeLength), hasSecureValues: hasSecureValues)
                                dataPromise.set(.single(data))
                            case let .passwordSet(password, hasRecoveryEmail, hasSecureValues):
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(emailSet ? presentationData.strings.TwoStepAuth_EmailChangeSuccess : presentationData.strings.TwoStepAuth_EmailAddSuccess, false)), nil)
                                if let password = password {
                                    let data: TwoStepVerificationUnlockSettingsControllerData = .manage(password: password, emailSet: hasRecoveryEmail, pendingEmail: nil, hasSecureValues: hasSecureValues)
                                    dataPromise.set(.single(data))
                                } else {
                                    dataPromise.set(.single(.access(configuration: nil))
                                    |> then(twoStepVerificationConfiguration(account: context.account) |> map { TwoStepVerificationUnlockSettingsControllerData.access(configuration: TwoStepVerificationAccessConfiguration(configuration: $0, password: password)) }))
                                }
                        }
                        if shouldDismiss {
                            controller.dismiss()
                        }
                    })
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        })
    })
    
    var initialFocusImpl: (() -> Void)?
    var didAppear = false
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), dataPromise.get() |> deliverOnMainQueue) |> deliverOnMainQueue
    |> map { presentationData, state, data -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
                            case let .notSet(pendingEmail):
                                if let _ = pendingEmail {
                                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Next), style: .bold, enabled: !state.emailCode.isEmpty, action: {
                                        checkEmailConfirmation()
                                    })
                                }
                            case .set:
                                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Next), style: .bold, enabled: true, action: {
                                    arguments.checkPassword()
                                })
                        }
                    }
                } else {
                    emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
                }
            case let .manage(manage):
                title = presentationData.strings.PrivacySettings_TwoStepAuth
                if state.checking {
                    rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
                } else {
                    if let _ = manage.pendingEmail {
                        rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Next), style: .bold, enabled: !state.emailCode.isEmpty, action: {
                            checkEmailConfirmation()
                        })
                    }
                }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: twoStepVerificationUnlockSettingsControllerEntries(presentationData: presentationData, state: state, data: data), style: .blocks, focusItemTag: didAppear ? TwoStepVerificationUnlockSettingsEntryTag.password : nil, emptyStateItem: emptyStateItem, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    replaceControllerImpl = { [weak controller] c, animated in
        (controller?.navigationController as? NavigationController)?.replaceTopController(c, animated: animated)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
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
        didAppear = true
        initialFocusImpl?()
        
        if openSetupPasswordImmediately {
            arguments.openSetupPassword()
        }
    }
    
    if case let .access(intro, _) = mode, intro {
        actionsDisposable.add((remoteDataPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { data in
            if case let .access(configuration) = data, let config = configuration, case let .notSet(pendingEmail) = config, pendingEmail == nil {
                let controller = PrivacyIntroController(context: context, mode: .twoStepVerification, arguments: PrivacyIntroControllerPresentationArguments(fadeIn: true), proceedAction: {
                    arguments.openSetupPassword()
                })
                replaceControllerImpl?(controller, false)
                replaceControllerImpl = { [weak controller] c, animated in
                    (controller?.navigationController as? NavigationController)?.replaceTopController(c, animated: animated)
                }
                presentControllerImpl = { [weak controller] c, p in
                    if let controller = controller {
                        controller.present(c, in: .window(.root), with: p)
                    }
                }
            }
        }))
    }
    
    return controller
}
