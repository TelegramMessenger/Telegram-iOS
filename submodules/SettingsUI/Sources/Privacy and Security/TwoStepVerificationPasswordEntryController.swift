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
import AccountContext
import AlertUI
import PresentationDataUtils

private final class TwoStepVerificationPasswordEntryControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void) {
        self.updateEntryText = updateEntryText
        self.next = next
    }
}

private enum TwoStepVerificationPasswordEntrySection: Int32 {
    case password
}

private enum TwoStepVerificationPasswordEntryTag: ItemListItemTag {
    case input
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? TwoStepVerificationPasswordEntryTag {
            switch self {
                case .input:
                    if case .input = other {
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

private enum TwoStepVerificationPasswordEntryEntry: ItemListNodeEntry {
    case passwordEntryTitle(PresentationTheme, String)
    case passwordEntry(PresentationTheme, PresentationStrings, String)
    
    case hintTitle(PresentationTheme, String)
    case hintEntry(PresentationTheme, PresentationStrings, String)
    
    case emailEntry(PresentationTheme, PresentationStrings, String)
    case emailInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return TwoStepVerificationPasswordEntrySection.password.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .passwordEntryTitle:
                return 0
            case .passwordEntry:
                return 1
            case .hintTitle:
                return 2
            case .hintEntry:
                return 3
            case .emailEntry:
                return 5
            case .emailInfo:
                return 6
        }
    }
    
    static func ==(lhs: TwoStepVerificationPasswordEntryEntry, rhs: TwoStepVerificationPasswordEntryEntry) -> Bool {
        switch lhs {
            case let .passwordEntryTitle(lhsTheme, lhsText):
                if case let .passwordEntryTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .passwordEntry(lhsTheme, lhsStrings, lhsText):
                if case let .passwordEntry(rhsTheme, rhsStrings, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .hintTitle(lhsTheme, lhsText):
                if case let .hintTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .hintEntry(lhsTheme, lhsStrings, lhsText):
                if case let .hintEntry(rhsTheme, rhsStrings, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .emailEntry(lhsTheme, lhsStrings, lhsText):
                if case let .emailEntry(rhsTheme, rhsStrings, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .emailInfo(lhsTheme, lhsText):
                if case let .emailInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: TwoStepVerificationPasswordEntryEntry, rhs: TwoStepVerificationPasswordEntryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TwoStepVerificationPasswordEntryControllerArguments
        switch self {
            case let .passwordEntryTitle(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .passwordEntry(theme, strings, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "", textColor: .black), text: text, placeholder: "", type: .password, spacing: 0.0, tag: TwoStepVerificationPasswordEntryTag.input, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateEntryText(updatedText)
                }, action: {
                    arguments.next()
                })
            case let .hintTitle(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .hintEntry(theme, strings, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "", textColor: .black), text: text, placeholder: "", type: .password, spacing: 0.0, tag: TwoStepVerificationPasswordEntryTag.input, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateEntryText(updatedText)
                }, action: {
                    arguments.next()
                })
            case let .emailEntry(theme, strings, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: strings.TwoStepAuth_Email, textColor: .black), text: text, placeholder: "", type: .email, spacing: 10.0, tag: TwoStepVerificationPasswordEntryTag.input, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateEntryText(updatedText)
                }, action: {
                    arguments.next()
                })
            case let .emailInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private enum PasswordEntryStage: Equatable {
    case entry(text: String)
    case reentry(first: String, text: String)
    case hint(password: String, text: String)
    case email(password: String, hint: String, text: String)
    
    func updateCurrentText(_ text: String) -> PasswordEntryStage {
        switch self {
            case .entry:
                return .entry(text: text)
            case let .reentry(first, _):
                return .reentry(first: first, text: text)
            case let .hint(password, _):
                return .hint(password: password, text: text)
            case let .email(password, hint, _):
                return .email(password: password, hint: hint, text: text)
        }
    }
    
    static func ==(lhs: PasswordEntryStage, rhs: PasswordEntryStage) -> Bool {
        switch lhs {
            case let .entry(text):
                if case .entry(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .reentry(first, text):
                if case .reentry(first, text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .hint(password, text):
                if case .hint(password, text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .email(password, hint, text):
                if case .email(password, hint, text) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private struct TwoStepVerificationPasswordEntryControllerState: Equatable {
    let stage: PasswordEntryStage
    let updating: Bool
    
    init(stage: PasswordEntryStage, updating: Bool) {
        self.stage = stage
        self.updating = updating
    }
    
    static func ==(lhs: TwoStepVerificationPasswordEntryControllerState, rhs: TwoStepVerificationPasswordEntryControllerState) -> Bool {
        if lhs.stage != rhs.stage {
            return false
        }
        if lhs.updating != rhs.updating {
            return false
        }
        
        return true
    }
    
    func withUpdatedStage(_ stage: PasswordEntryStage) -> TwoStepVerificationPasswordEntryControllerState {
        return TwoStepVerificationPasswordEntryControllerState(stage: stage, updating: self.updating)
    }
    
    func withUpdatedUpdating(_ updating: Bool) -> TwoStepVerificationPasswordEntryControllerState {
        return TwoStepVerificationPasswordEntryControllerState(stage: self.stage, updating: updating)
    }
}

private func twoStepVerificationPasswordEntryControllerEntries(presentationData: PresentationData, state: TwoStepVerificationPasswordEntryControllerState, mode: TwoStepVerificationPasswordEntryMode) -> [TwoStepVerificationPasswordEntryEntry] {
    var entries: [TwoStepVerificationPasswordEntryEntry] = []
    
    switch state.stage {
        case let .entry(text):
            entries.append(.passwordEntryTitle(presentationData.theme, presentationData.strings.TwoStepAuth_SetupPasswordEnterPasswordNew))
            entries.append(.passwordEntry(presentationData.theme, presentationData.strings, text))
        case let .reentry(_, text):
            entries.append(.passwordEntryTitle(presentationData.theme, presentationData.strings.TwoStepAuth_SetupPasswordConfirmPassword))
            entries.append(.passwordEntry(presentationData.theme, presentationData.strings, text))
        case let .hint(_, text):
            entries.append(.hintTitle(presentationData.theme, presentationData.strings.TwoStepAuth_SetupHint))
            entries.append(.hintEntry(presentationData.theme, presentationData.strings, text))
        case let .email(_, _, text):
            entries.append(.emailEntry(presentationData.theme, presentationData.strings, text))
            entries.append(.emailInfo(presentationData.theme, presentationData.strings.TwoStepAuth_EmailHelp))
    }
    
    return entries
}

enum TwoStepVerificationPasswordEntryMode {
    case setup
    case change(current: String)
    case setupEmail(password: String)
}

struct TwoStepVerificationPasswordEntryResult {
    let password: String
    let pendingEmail: TwoStepVerificationPendingEmail?
}

func twoStepVerificationPasswordEntryController(context: AccountContext, mode: TwoStepVerificationPasswordEntryMode, result: Promise<TwoStepVerificationPasswordEntryResult?>) -> ViewController {
    let initialStage: PasswordEntryStage
    switch mode {
        case .setup, .change:
            initialStage = .entry(text: "")
        case .setupEmail:
            initialStage = .email(password: "", hint: "", text: "")
    }
    let initialState = TwoStepVerificationPasswordEntryControllerState(stage: initialStage, updating: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((TwoStepVerificationPasswordEntryControllerState) -> TwoStepVerificationPasswordEntryControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updatePasswordDisposable = MetaDisposable()
    actionsDisposable.add(updatePasswordDisposable)
    
    let checkPassword: () -> Void = {
        var passwordHintEmail: (String, String, String)?
        var invalidReentry = false
        updateState { state in
            if state.updating {
                return state
            } else {
                switch state.stage {
                    case let .entry(text):
                        if text.isEmpty {
                            return state
                        } else {
                            return state.withUpdatedStage(.reentry(first: text, text: ""))
                        }
                    case let .reentry(first, text):
                        if text.isEmpty {
                            return state
                        } else if text != first {
                            invalidReentry = true
                            return state.withUpdatedStage(.entry(text: ""))
                        } else {
                            return state.withUpdatedStage(.hint(password: text, text: ""))
                        }
                    case let .hint(password, text):
                        switch mode {
                            case .setup:
                                return state.withUpdatedStage(.email(password: password, hint: text, text: ""))
                            case .change:
                                passwordHintEmail = (password, text, "")
                                return state.withUpdatedUpdating(true)
                            case .setupEmail:
                                preconditionFailure()
                        }
                    case let .email(password, hint, text):
                        passwordHintEmail = (password, hint, text)
                        return state.withUpdatedUpdating(true)
                }
            }
        }
        if let (password, hint, email) = passwordHintEmail {
            switch mode {
                case .setup, .change:
                    var currentPassword: String?
                    if case let .change(current) = mode {
                        currentPassword = current
                    }
                    updatePasswordDisposable.set((updateTwoStepVerificationPassword(network: context.account.network, currentPassword: currentPassword, updatedPassword: .password(password: password, hint: hint, email: email)) |> deliverOnMainQueue).start(next: { update in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        switch update {
                            case let .password(password, pendingEmail):
                                result.set(.single(TwoStepVerificationPasswordEntryResult(password: password, pendingEmail: pendingEmail)))
                            case .none:
                                break
                        }
                    }, error: { error in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let alertText: String
                        switch error {
                            case .generic:
                                alertText = presentationData.strings.Login_UnknownError
                            case .invalidEmail:
                                alertText = presentationData.strings.TwoStepAuth_EmailInvalid
                        }
                        presentControllerImpl?(textAlertController(context: context, title: nil, text: alertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }))
                case let .setupEmail(password):
                    updatePasswordDisposable.set((updateTwoStepVerificationEmail(network: context.account.network, currentPassword: password, updatedEmail: email) |> deliverOnMainQueue).start(next: { update in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        switch update {
                            case let .password(password, pendingEmail):
                                result.set(.single(TwoStepVerificationPasswordEntryResult(password: password, pendingEmail: pendingEmail)))
                            case .none:
                                break
                        }
                    }, error: { error in
                        updateState {
                            $0.withUpdatedUpdating(false)
                        }
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let alertText: String
                        switch error {
                            case .generic:
                                alertText = presentationData.strings.Login_UnknownError
                            case .invalidEmail:
                                alertText = presentationData.strings.TwoStepAuth_EmailInvalid
                        }
                        presentControllerImpl?(textAlertController(context: context, title: nil, text: alertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }))
            }
        } else if invalidReentry {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.TwoStepAuth_SetupPasswordConfirmFailed, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }
    }
    
    let arguments = TwoStepVerificationPasswordEntryControllerArguments(updateEntryText: { updatedText in
        updateState {
            $0.withUpdatedStage($0.stage.updateCurrentText(updatedText))
        }
    }, next: {
        checkPassword()
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            var rightNavigationButton: ItemListNavigationButton?
            if state.updating {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            } else {
                var nextEnabled = true
                switch state.stage {
                    case let .entry(text):
                        if text.isEmpty {
                            nextEnabled = false
                        }
                    case let.reentry(_, text):
                        if text.isEmpty {
                            nextEnabled = false
                        }
                    case .hint, .email:
                        break
                }
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Next), style: .bold, enabled: nextEnabled, action: {
                    checkPassword()
                })
            }
            
            let title: String
            switch mode {
                case .setup, .change:
                    title = presentationData.strings.TwoStepAuth_EnterPasswordTitle
                case .setupEmail:
                    title = presentationData.strings.TwoStepAuth_EmailTitle
            }
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: twoStepVerificationPasswordEntryControllerEntries(presentationData: presentationData, state: state, mode: mode), style: .blocks, focusItemTag: TwoStepVerificationPasswordEntryTag.input, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    
    return controller
}
