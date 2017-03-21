import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class TwoStepVerificationResetControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    let openEmailInaccessible: () -> Void
    
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void, openEmailInaccessible: @escaping () -> Void) {
        self.updateEntryText = updateEntryText
        self.next = next
        self.openEmailInaccessible = openEmailInaccessible
    }
}

private enum TwoStepVerificationResetSection: Int32 {
    case password
}

private enum TwoStepVerificationResetTag: ItemListItemTag {
    case input
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? TwoStepVerificationResetTag {
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

private enum TwoStepVerificationResetEntry: ItemListNodeEntry {
    case codeEntry(String)
    case codeInfo(String)
    
    var section: ItemListSectionId {
        return TwoStepVerificationResetSection.password.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .codeEntry:
                return 0
            case .codeInfo:
                return 1
        }
    }
    
    static func ==(lhs: TwoStepVerificationResetEntry, rhs: TwoStepVerificationResetEntry) -> Bool {
        switch lhs {
            case let .codeEntry(text):
                if case .codeEntry(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .codeInfo(text):
                if case .codeInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: TwoStepVerificationResetEntry, rhs: TwoStepVerificationResetEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: TwoStepVerificationResetControllerArguments) -> ListViewItem {
        switch self {
            case let .codeEntry(text):
                return ItemListSingleLineInputItem(title: NSAttributedString(string: "Code", textColor: .black), text: text, placeholder: "", type: .password, spacing: 10.0, tag: TwoStepVerificationResetTag.input, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateEntryText(updatedText)
                }, action: {
                    arguments.next()
                })
            case let .codeInfo(text):
                return ItemListSectionHeaderItem(text: text, sectionId: self.section)
        }
    }
}

private struct TwoStepVerificationResetControllerState: Equatable {
    let codeText: String
    let checking: Bool
    
    init(codeText: String, checking: Bool) {
        self.codeText = codeText
        self.checking = checking
    }
    
    static func ==(lhs: TwoStepVerificationResetControllerState, rhs: TwoStepVerificationResetControllerState) -> Bool {
        if lhs.codeText != rhs.codeText {
            return false
        }
        if lhs.checking != rhs.checking {
            return false
        }
        
        return true
    }
    
    func withUpdatedCodeText(_ codeText: String) -> TwoStepVerificationResetControllerState {
        return TwoStepVerificationResetControllerState(codeText: codeText, checking: self.checking)
    }
    
    func withUpdatedChecking(_ checking: Bool) -> TwoStepVerificationResetControllerState {
        return TwoStepVerificationResetControllerState(codeText: self.codeText, checking: checking)
    }
}

private func twoStepVerificationResetControllerEntries(state: TwoStepVerificationResetControllerState, emailPattern: String) -> [TwoStepVerificationResetEntry] {
    var entries: [TwoStepVerificationResetEntry] = []

    entries.append(.codeEntry(state.codeText))
    entries.append(.codeInfo("Please check your e-mail and enter the 6-digit code we've sent there to deactivate your cloud password.\n\n[Having trouble accessing your e-mail \(escapedPlaintextForMarkdown(emailPattern))?]()"))
    
    return entries
}

func twoStepVerificationResetController(account: Account, emailPattern: String, result: Promise<Bool>) -> ViewController {
    let initialState = TwoStepVerificationResetControllerState(codeText: "", checking: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((TwoStepVerificationResetControllerState) -> TwoStepVerificationResetControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let resetPasswordDisposable = MetaDisposable()
    actionsDisposable.add(resetPasswordDisposable)
    
    let checkCode: () -> Void = {
        var code: String?
        updateState { state in
            if state.checking || state.codeText.isEmpty {
                return state
            } else {
                code = state.codeText
                return state.withUpdatedChecking(true)
            }
        }
        if let code = code {
            resetPasswordDisposable.set((recoverTwoStepVerificationPassword(account: account, code: code) |> deliverOnMainQueue).start(error: { error in
                updateState {
                    return $0.withUpdatedChecking(false)
                }
                let alertText: String
                switch error {
                    case .generic:
                        alertText = "An error occurred."
                    case .invalidCode:
                        alertText = "Invalid code. Please try again."
                    case .codeExpired:
                        alertText = "Code expired."
                    case .limitExceeded:
                        alertText = "You have entered invalid code too many times. Please try again later."
                }
                presentControllerImpl?(standardTextAlertController(title: nil, text: alertText, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, completed: {
                updateState {
                    return $0.withUpdatedChecking(false)
                }
                result.set(.single(true))
            }))
        }
    }
    
    let arguments = TwoStepVerificationResetControllerArguments(updateEntryText: { updatedText in
        updateState {
            $0.withUpdatedCodeText(updatedText)
        }
    }, next: {
        checkCode()
    }, openEmailInaccessible: {
        presentControllerImpl?(standardTextAlertController(title: nil, text: "Your remaining options are either to remember your password or to reset your account.", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue
        |> map { state -> (ItemListControllerState, (ItemListNodeState<TwoStepVerificationResetEntry>, TwoStepVerificationResetEntry.ItemGenerationArguments)) in
            
            let leftNavigationButton = ItemListNavigationButton(title: "Cancel", style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            var rightNavigationButton: ItemListNavigationButton?
            if state.checking {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            } else {
                var nextEnabled = true
                if state.codeText.isEmpty {
                    nextEnabled = false
                }
                rightNavigationButton = ItemListNavigationButton(title: "Next", style: .bold, enabled: nextEnabled, action: {
                    checkCode()
                })
            }
            
            let controllerState = ItemListControllerState(title: "E-Mail Code", leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, animateChanges: false)
            let listState = ItemListNodeState(entries: twoStepVerificationResetControllerEntries(state: state, emailPattern: emailPattern), style: .blocks, focusItemTag: TwoStepVerificationResetTag.input, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
