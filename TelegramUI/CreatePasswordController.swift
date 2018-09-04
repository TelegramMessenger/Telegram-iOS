import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum CreatePasswordField {
    case password
    case passwordConfirmation
    case hint
    case email
}

private final class CreatePasswordControllerArguments {
    let updateFieldText: (CreatePasswordField, String) -> Void
    
    init(updateFieldText: @escaping (CreatePasswordField, String) -> Void) {
        self.updateFieldText = updateFieldText
    }
}

private enum CreatePasswordSection: Int32 {
    case password
    case hint
    case email
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
    case password(PresentationTheme, String, String)
    case passwordConfirmation(PresentationTheme, String, String)
    case passwordInfo(PresentationTheme, String)
    
    case hintHeader(PresentationTheme, String)
    case hint(PresentationTheme, String, String)
    case hintInfo(PresentationTheme, String)
    
    case emailHeader(PresentationTheme, String)
    case email(PresentationTheme, String, String)
    case emailInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .passwordHeader, .password, .passwordConfirmation, .passwordInfo:
                return CreatePasswordSection.password.rawValue
            case .hintHeader, .hint, .hintInfo:
                return CreatePasswordSection.hint.rawValue
            case .emailHeader, .email, .emailInfo:
                return CreatePasswordSection.email.rawValue
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
        }
    }
    
    static func <(lhs: CreatePasswordEntry, rhs: CreatePasswordEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: CreatePasswordControllerArguments) -> ListViewItem {
        switch self {
            case let .passwordHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .password(theme, text, value):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: value, placeholder: text, type: .password, spacing: 0.0, tag: CreatePasswordEntryTag.password, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.password, updatedText)
                }, action: {
                })
            case let .passwordConfirmation(theme, text, value):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: value, placeholder: text, type: .password, spacing: 0.0, tag: CreatePasswordEntryTag.passwordConfirmation, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.passwordConfirmation, updatedText)
                }, action: {
                })
            case let .passwordInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .hintHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .hint(theme, text, value):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: value, placeholder: text, type: .regular(capitalization: true, autocorrection: false), spacing: 0.0, tag: CreatePasswordEntryTag.password, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.password, updatedText)
                }, action: {
                })
            case let .hintInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .emailHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .email(theme, text, value):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: value, placeholder: text, type: .email, spacing: 0.0, tag: CreatePasswordEntryTag.password, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateFieldText(.password, updatedText)
                }, action: {
                })
            case let .emailInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct CreatePasswordControllerState: Equatable {
    var passwordText: String = ""
    var passwordConfirmationText: String = ""
    var hintText: String = ""
    var emailText: String = ""
    var saving: Bool = false
    var pendingEmail: String? = nil
}

private func createPasswordControllerEntries(presentationData: PresentationData, state: CreatePasswordControllerState) -> [CreatePasswordEntry] {
    var entries: [CreatePasswordEntry] = []
    
    entries.append(.passwordHeader(presentationData.theme, presentationData.strings.FastTwoStepSetup_PasswordSection))
    entries.append(.password(presentationData.theme, presentationData.strings.FastTwoStepSetup_PasswordPlaceholder, state.passwordText))
    entries.append(.passwordConfirmation(presentationData.theme, presentationData.strings.FastTwoStepSetup_PasswordConfirmationPlaceholder, state.passwordConfirmationText))
    entries.append(.passwordInfo(presentationData.theme, presentationData.strings.FastTwoStepSetup_PasswordHelp))
    
    entries.append(.hintHeader(presentationData.theme, presentationData.strings.FastTwoStepSetup_HintSection))
    entries.append(.hint(presentationData.theme, presentationData.strings.FastTwoStepSetup_HintPlaceholder, state.hintText))
    entries.append(.hintInfo(presentationData.theme, presentationData.strings.FastTwoStepSetup_HintHelp))
    
    entries.append(.emailHeader(presentationData.theme, presentationData.strings.FastTwoStepSetup_EmailSection))
    entries.append(.email(presentationData.theme, presentationData.strings.FastTwoStepSetup_EmailPlaceholder, state.emailText))
    entries.append(.emailInfo(presentationData.theme, presentationData.strings.FastTwoStepSetup_EmailHelp))
    
    return entries
}

func createPasswordController(account: Account, completion: @escaping (String, String) -> Void) -> ViewController {
    let statePromise = ValuePromise(CreatePasswordControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: CreatePasswordControllerState())
    let updateState: ((CreatePasswordControllerState) -> CreatePasswordControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let saveDisposable = MetaDisposable()
    actionsDisposable.add(saveDisposable)
    
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
    })
    
    var initialFocusImpl: (() -> Void)?
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<CreatePasswordEntry>, CreatePasswordEntry.ItemGenerationArguments)) in
        
        var rightNavigationButton: ItemListNavigationButton?
        if state.saving {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: !state.passwordText.isEmpty, action: {
                var state: CreatePasswordControllerState?
                updateState { s in
                    state = s
                    return s
                }
                if let state = state {
                    if state.passwordText.isEmpty {
                    } else if state.passwordText != state.passwordConfirmationText {
                        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                        presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.TwoStepAuth_SetupPasswordConfirmFailed, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                    } else {
                        let saveImpl: () -> Void = {
                            updateState { state in
                                var state = state
                                state.saving = true
                                return state
                            }
                            saveDisposable.set((updateTwoStepVerificationPassword(network: account.network, currentPassword: nil, updatedPassword: .password(password: state.passwordText, hint: state.hintText, email: state.emailText))
                            |> deliverOnMainQueue).start(next: { update in
                                switch update {
                                    case .none:
                                        break
                                    case let .password(password, pendingEmailPattern):
                                        if let pendingEmailPattern = pendingEmailPattern {
                                            updateState { state in
                                                var state = state
                                                state.saving = false
                                                state.pendingEmail = pendingEmailPattern
                                                return state
                                            }
                                        } else {
                                            completion(password, state.hintText)
                                        }
                                }
                            }, error: { _ in
                                presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                            }))
                        }
                        
                        if state.emailText.isEmpty {
                            presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.TwoStepAuth_EmailSkipAlert, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .destructiveAction, title: presentationData.strings.TwoStepAuth_EmailSkip, action: {
                                saveImpl()
                            })]), nil)
                        } else {
                            saveImpl()
                        }
                    }
                }
            })
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.FastTwoStepSetup_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: createPasswordControllerEntries(presentationData: presentationData, state: state), style: .blocks, focusItemTag: CreatePasswordEntryTag.password, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
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
    controller.didAppear = {
        initialFocusImpl?()
    }
    
    return controller
}
