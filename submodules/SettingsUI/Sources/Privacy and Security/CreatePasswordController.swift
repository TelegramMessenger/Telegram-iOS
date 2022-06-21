import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils

private enum CreatePasswordField {
    case password
    case passwordConfirmation
    case hint
    case email
}

private final class CreatePasswordControllerArguments {
    let updateFieldText: (CreatePasswordField, String) -> Void
    let selectNextInputItem: (CreatePasswordEntryTag) -> Void
    let save: () -> Void
    let cancelEmailConfirmation: () -> Void
    
    init(updateFieldText: @escaping (CreatePasswordField, String) -> Void, selectNextInputItem: @escaping (CreatePasswordEntryTag) -> Void, save: @escaping () -> Void, cancelEmailConfirmation: @escaping () -> Void) {
        self.updateFieldText = updateFieldText
        self.selectNextInputItem = selectNextInputItem
        self.save = save
        self.cancelEmailConfirmation = cancelEmailConfirmation
    }
}

private enum CreatePasswordSection: Int32 {
    case password
    case hint
    case email
    case emailCancel
}

private enum CreatePasswordEntryTag: ItemListItemTag {
    case password
    case passwordConfirmation
    case hint
    case email
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CreatePasswordEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum CreatePasswordEntry: ItemListNodeEntry, Equatable {
    case passwordHeader(PresentationTheme, String)
    case password(PresentationTheme, PresentationStrings, String, String)
    case passwordConfirmation(PresentationTheme, PresentationStrings, String, String)
    case passwordInfo(PresentationTheme, String)
    
    case hintHeader(PresentationTheme, String)
    case hint(PresentationTheme, PresentationStrings, String, String, Bool)
    case hintInfo(PresentationTheme, String)
    
    case emailHeader(PresentationTheme, String)
    case email(PresentationTheme, PresentationStrings, String, String)
    case emailInfo(PresentationTheme, String)
    
    case emailConfirmation(PresentationTheme, String)
    case emailCancel(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .passwordHeader, .password, .passwordConfirmation, .passwordInfo:
                return CreatePasswordSection.password.rawValue
            case .hintHeader, .hint, .hintInfo:
                return CreatePasswordSection.hint.rawValue
            case .emailHeader, .email, .emailInfo, .emailConfirmation:
                return CreatePasswordSection.email.rawValue
            case .emailCancel:
                return CreatePasswordSection.emailCancel.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .passwordHeader:
                return 0
            case .password:
                return 1
            case .passwordConfirmation:
                return 2
            case .passwordInfo:
                return 3
            case .hintHeader:
                return 4
            case .hint:
                return 5
            case .hintInfo:
                return 6
            case .emailHeader:
                return 7
            case .email:
                return 8
            case .emailInfo:
                return 9
            case .emailConfirmation:
                return 10
            case .emailCancel:
                return 11
        }
    }
    
    static func <(lhs: CreatePasswordEntry, rhs: CreatePasswordEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CreatePasswordControllerArguments
        switch self {
            case let .passwordHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .password(_, _, text, value):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: text, type: .password, returnKeyType: .next, spacing: 0.0, tag: CreatePasswordEntryTag.password, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.password, updatedText)
                }, action: {
                    arguments.selectNextInputItem(CreatePasswordEntryTag.password)
                })
            case let .passwordConfirmation(_, _, text, value):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: text, type: .password, returnKeyType: .next, spacing: 0.0, tag: CreatePasswordEntryTag.passwordConfirmation, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.passwordConfirmation, updatedText)
                }, action: {
                    arguments.selectNextInputItem(CreatePasswordEntryTag.passwordConfirmation)
                })
            case let .passwordInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .hintHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .hint(_, _, text, value, last):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: text, type: .regular(capitalization: true, autocorrection: false), returnKeyType: last ? .done : .next, spacing: 0.0, tag: CreatePasswordEntryTag.hint, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.hint, updatedText)
                }, action: {
                    if last {
                        arguments.save()
                    } else {
                        arguments.selectNextInputItem(CreatePasswordEntryTag.hint)
                    }
                })
            case let .hintInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .emailHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .email(_, _, text, value):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: text, type: .email, returnKeyType: .done, spacing: 0.0, tag: CreatePasswordEntryTag.email, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.email, updatedText)
                }, action: {
                    arguments.save()
                })
            case let .emailInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .emailConfirmation(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .emailCancel(_, text, enabled):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.cancelEmailConfirmation()
                })
        }
    }
}

private struct CreatePasswordControllerState: Equatable {
    var state: CreatePasswordState
    var passwordText: String = ""
    var passwordConfirmationText: String = ""
    var hintText: String = ""
    var emailText: String = ""
    var saving: Bool = false
    
    init(state: CreatePasswordState) {
        self.state = state
    }
}

private func createPasswordControllerEntries(presentationData: PresentationData, context: CreatePasswordContext, state: CreatePasswordControllerState) -> [CreatePasswordEntry] {
    var entries: [CreatePasswordEntry] = []
    
    switch state.state {
        case let .setup(currentPassword):
            entries.append(.passwordHeader(presentationData.theme, presentationData.strings.FastTwoStepSetup_PasswordSection))
            entries.append(.password(presentationData.theme, presentationData.strings, presentationData.strings.FastTwoStepSetup_PasswordPlaceholder, state.passwordText))
            entries.append(.passwordConfirmation(presentationData.theme, presentationData.strings, presentationData.strings.FastTwoStepSetup_PasswordConfirmationPlaceholder, state.passwordConfirmationText))
           
            if case .paymentInfo = context {
                entries.append(.passwordInfo(presentationData.theme, presentationData.strings.FastTwoStepSetup_PasswordHelp))
            }
            
            let showEmail = currentPassword == nil
            
            entries.append(.hintHeader(presentationData.theme, presentationData.strings.FastTwoStepSetup_HintSection))
            entries.append(.hint(presentationData.theme, presentationData.strings, presentationData.strings.FastTwoStepSetup_HintPlaceholder, state.hintText, !showEmail))
            entries.append(.hintInfo(presentationData.theme, presentationData.strings.FastTwoStepSetup_HintHelp))
            
            if showEmail {
                entries.append(.emailHeader(presentationData.theme, presentationData.strings.FastTwoStepSetup_EmailSection))
                entries.append(.email(presentationData.theme, presentationData.strings, presentationData.strings.FastTwoStepSetup_EmailPlaceholder, state.emailText))
                entries.append(.emailInfo(presentationData.theme, presentationData.strings.FastTwoStepSetup_EmailHelp))
            }
        case let .pendingVerification(emailPattern):
            entries.append(.emailConfirmation(presentationData.theme, presentationData.strings.TwoStepAuth_ConfirmationText + "\n\(emailPattern)"))
            entries.append(.emailCancel(presentationData.theme, presentationData.strings.TwoStepAuth_ConfirmationAbort, !state.saving))
    }
    
    return entries
}

enum CreatePasswordContext {
    case account
    case secureId
    case paymentInfo
}

enum CreatePasswordState: Equatable {
    case setup(currentPassword: String?)
    case pendingVerification(emailPattern: String)
}

func createPasswordController(context: AccountContext, createPasswordContext: CreatePasswordContext, state: CreatePasswordState, completion: @escaping (String, String, Bool) -> Void, updatePasswordEmailConfirmation: @escaping ((String, String)?) -> Void, processPasswordEmailConfirmation: Bool = true) -> ViewController {
    let statePromise = ValuePromise(CreatePasswordControllerState(state: state), ignoreRepeated: true)
    let stateValue = Atomic(value: CreatePasswordControllerState(state: state))
    let updateState: ((CreatePasswordControllerState) -> CreatePasswordControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let saveDisposable = MetaDisposable()
    actionsDisposable.add(saveDisposable)
    
    var initialFocusImpl: (() -> Void)?
    
    var selectNextInputItemImpl: ((CreatePasswordEntryTag) -> Void)?
    
    let saveImpl = {
        var state: CreatePasswordControllerState?
        updateState { s in
            state = s
            return s
        }
        if let state = state {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if state.passwordText.isEmpty {
            } else if state.passwordText != state.passwordConfirmationText {
                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.TwoStepAuth_SetupPasswordConfirmFailed, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            } else {
                let saveImpl: () -> Void = {
                    var currentPassword: String?
                    var email: String?
                    updateState { state in
                        var state = state
                        if case let .setup(password) = state.state {
                            currentPassword = password
                            if password != nil {
                                email = nil
                            } else {
                                email = state.emailText
                            }
                        }
                        state.saving = true
                        return state
                    }
                    saveDisposable.set((context.engine.auth.updateTwoStepVerificationPassword(currentPassword: currentPassword, updatedPassword: .password(password: state.passwordText, hint: state.hintText, email: email))
                        |> deliverOnMainQueue).start(next: { update in
                            switch update {
                            case .none:
                                break
                            case let .password(password, pendingEmail):
                                if let pendingEmail = pendingEmail, let email = email {
                                    if processPasswordEmailConfirmation {
                                        updateState { state in
                                            var state = state
                                            state.saving = false
                                            state.state = .pendingVerification(emailPattern: pendingEmail.pattern)
                                            
                                            return state
                                        }
                                    }
                                    updatePasswordEmailConfirmation((email, pendingEmail.pattern))
                                } else {
                                    completion(password, state.hintText, !state.emailText.isEmpty)
                                }
                            }
                        }, error: { _ in
                            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                        }))
                }
                
                var emailAlert = false
                switch state.state {
                case let .setup(currentPassword):
                    if currentPassword != nil {
                        emailAlert = false
                    } else {
                        emailAlert = state.emailText.isEmpty
                    }
                case .pendingVerification:
                    break
                }
                
                if emailAlert {
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.TwoStepAuth_EmailSkipAlert, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .destructiveAction, title: presentationData.strings.TwoStepAuth_EmailSkip, action: {
                        saveImpl()
                    })]), nil)
                } else {
                    saveImpl()
                }
            }
        }
    }
    
    let arguments = CreatePasswordControllerArguments(updateFieldText: { field, updatedText in
        updateState { state in
            var state = state
            switch field {
            case .password:
                state.passwordText = updatedText
            case .passwordConfirmation:
                state.passwordConfirmationText = updatedText
            case .hint:
                state.hintText = updatedText
            case .email:
                state.emailText = updatedText
            }
            return state
        }
    }, selectNextInputItem: { tag in
        selectNextInputItemImpl?(tag)
    }, save: {
        saveImpl()
    }, cancelEmailConfirmation: {
        var currentPassword: String?
        updateState { state in
            var state = state
            switch state.state {
            case let .setup(password):
                currentPassword = password
            case .pendingVerification:
                currentPassword = nil
            }
            state.saving = true
            return state
        }
        
        saveDisposable.set((context.engine.auth.updateTwoStepVerificationPassword(currentPassword: currentPassword, updatedPassword: .none)
            |> deliverOnMainQueue).start(next: { _ in
                updateState { state in
                    var state = state
                    state.saving = false
                    state.state = .setup(currentPassword: nil)
                    return state
                }
                updatePasswordEmailConfirmation(nil)
            }, error: { _ in
                updateState { state in
                    var state = state
                    state.saving = false
                    return state
                }
            }))
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        var rightNavigationButton: ItemListNavigationButton?
        if state.saving {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            switch state.state {
                case .setup:
                    rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: !state.passwordText.isEmpty, action: {
                        saveImpl()
                    })
                case .pendingVerification:
                    break
            }
        }
        
        let title: String
        switch state.state {
            case let .setup(currentPassword):
                if currentPassword != nil {
                    title = presentationData.strings.TwoStepAuth_ChangePassword
                } else {
                    title = presentationData.strings.FastTwoStepSetup_Title
                }
            case .pendingVerification:
                title = presentationData.strings.FastTwoStepSetup_Title
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createPasswordControllerEntries(presentationData: presentationData, context: createPasswordContext, state: state), style: .blocks, focusItemTag: CreatePasswordEntryTag.password, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
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
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode, let tag = itemNode.tag, tag.isEqual(to: CreatePasswordEntryTag.password) {
                resultItemNode = itemNode
                return true
            }
            return false
        })
        if let resultItemNode = resultItemNode {
            resultItemNode.focus()
        }
    }
    selectNextInputItemImpl = { [weak controller] currentTag in
        guard let controller = controller else {
            return
        }
        
        var resultItemNode: ItemListSingleLineInputItemNode?
        var focusOnNext = false
        let _ = controller.frameForItemNode({ itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode, let tag = itemNode.tag {
                if focusOnNext && resultItemNode == nil {
                    resultItemNode = itemNode
                    return true
                } else if currentTag.isEqual(to: tag) {
                    focusOnNext = true
                }
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
