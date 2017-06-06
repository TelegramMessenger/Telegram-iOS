import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChangePhoneNumberCodeControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void) {
        self.updateEntryText = updateEntryText
        self.next = next
    }
}

private enum ChangePhoneNumberCodeSection: Int32 {
    case code
}

private enum ChangePhoneNumberCodeTag: ItemListItemTag {
    case input
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ChangePhoneNumberCodeTag {
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

private enum ChangePhoneNumberCodeEntry: ItemListNodeEntry {
    case codeEntry(PresentationTheme, String)
    case codeInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return ChangePhoneNumberCodeSection.code.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .codeEntry:
                return 1
            case .codeInfo:
                return 2
        }
    }
    
    static func ==(lhs: ChangePhoneNumberCodeEntry, rhs: ChangePhoneNumberCodeEntry) -> Bool {
        switch lhs {
            case let .codeEntry(lhsTheme, lhsText):
                if case let .codeEntry(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .codeInfo(lhsTheme, lhsText):
                if case let .codeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChangePhoneNumberCodeEntry, rhs: ChangePhoneNumberCodeEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ChangePhoneNumberCodeControllerArguments) -> ListViewItem {
        switch self {
            case let .codeEntry(theme, text):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(string: "Code", textColor: .black), text: text, placeholder: "", type: .number, spacing: 10.0, tag: ChangePhoneNumberCodeTag.input, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateEntryText(updatedText)
                }, action: {
                    arguments.next()
                })
            case let .codeInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct ChangePhoneNumberCodeControllerState: Equatable {
    let codeText: String
    let checking: Bool
    
    init(codeText: String, checking: Bool) {
        self.codeText = codeText
        self.checking = checking
    }
    
    static func ==(lhs: ChangePhoneNumberCodeControllerState, rhs: ChangePhoneNumberCodeControllerState) -> Bool {
        if lhs.codeText != rhs.codeText {
            return false
        }
        if lhs.checking != rhs.checking {
            return false
        }
        
        return true
    }
    
    func withUpdatedCodeText(_ codeText: String) -> ChangePhoneNumberCodeControllerState {
        return ChangePhoneNumberCodeControllerState(codeText: codeText, checking: self.checking)
    }
    
    func withUpdatedChecking(_ checking: Bool) -> ChangePhoneNumberCodeControllerState {
        return ChangePhoneNumberCodeControllerState(codeText: self.codeText, checking: checking)
    }
    
    func withUpdatedNextMethodTimeout(_ nextMethodTimeout: Int32?) -> ChangePhoneNumberCodeControllerState {
        return ChangePhoneNumberCodeControllerState(codeText: self.codeText, checking: self.checking)
    }
    
    func withUpdatedCodeData(_ codeData: ChangeAccountPhoneNumberData) -> ChangePhoneNumberCodeControllerState {
        return ChangePhoneNumberCodeControllerState(codeText: self.codeText, checking: self.checking)
    }
}

private func changePhoneNumberCodeControllerEntries(presentationData: PresentationData, state: ChangePhoneNumberCodeControllerState, codeData: ChangeAccountPhoneNumberData, timeout: Int32?) -> [ChangePhoneNumberCodeEntry] {
    var entries: [ChangePhoneNumberCodeEntry] = []
    
    entries.append(.codeEntry(presentationData.theme, state.codeText))
    var text = authorizationCurrentOptionText(codeData.type).string
    if let nextType = codeData.nextType {
        text += "\n\n" + authorizationNextOptionText(nextType, timeout: timeout).string
    }
    entries.append(.codeInfo(presentationData.theme, text))
    
    return entries
}

private func timeoutSignal(codeData: ChangeAccountPhoneNumberData) -> Signal<Int32?, NoError> {
    if let _ = codeData.nextType, let timeout = codeData.timeout {
        return Signal { subscriber in
            let value = Atomic<Int32>(value: timeout)
            subscriber.putNext(timeout)
            
            let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: {
                subscriber.putNext(value.modify { value in
                    return max(0, value - 1)
                })
            }, queue: Queue.mainQueue())
            timer.start()
            
            return ActionDisposable {
                timer.invalidate()
            }
        }
    } else {
        return .single(nil)
    }
}

func changePhoneNumberCodeController(account: Account, phoneNumber: String, codeData: ChangeAccountPhoneNumberData) -> ViewController {
    let initialState = ChangePhoneNumberCodeControllerState(codeText: "", checking: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChangePhoneNumberCodeControllerState) -> ChangePhoneNumberCodeControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let changePhoneDisposable = MetaDisposable()
    actionsDisposable.add(changePhoneDisposable)
    
    let nextTypeDisposable = MetaDisposable()
    actionsDisposable.add(nextTypeDisposable)
    
    let currentDataPromise = Promise<ChangeAccountPhoneNumberData>()
    currentDataPromise.set(.single(codeData))
    
    let timeout = Promise<Int32?>()
    timeout.set(timeoutSignal(codeData: codeData))
    
    let resendCode = currentDataPromise.get()
        |> mapToSignal { [weak currentDataPromise] data -> Signal<Void, NoError> in
            if let _ = data.nextType {
                return timeout.get()
                    |> filter { $0 == 0 }
                    |> take(1)
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return Signal { subscriber in
                            return requestNextChangeAccountPhoneNumberVerification(account: account, phoneNumber: phoneNumber, phoneCodeHash: data.hash).start(next: { next in
                                currentDataPromise?.set(.single(next))
                            }, error: { error in
                                
                            })
                        }
                    }
            } else {
                return .complete()
            }
        }
    nextTypeDisposable.set(resendCode.start())
    
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
            changePhoneDisposable.set((requestChangeAccountPhoneNumber(account: account, phoneNumber: phoneNumber, phoneCodeHash: codeData.hash, phoneCode: code) |> deliverOnMainQueue).start(error: { error in
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
                presentControllerImpl?(standardTextAlertController(title: nil, text: "You have changed your phone number to \(formatPhoneNumber(phoneNumber)).", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                dismissImpl?()
            }))
        }
    }
    
    let arguments = ChangePhoneNumberCodeControllerArguments(updateEntryText: { updatedText in
        var initiateCheck = false
        updateState { state in
            if state.codeText.characters.count < 5 && updatedText.characters.count == 5 {
                initiateCheck = true
            }
            return state.withUpdatedCodeText(updatedText)
        }
        if initiateCheck {
            checkCode()
        }
    }, next: {
        checkCode()
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get() |> deliverOnMainQueue, currentDataPromise.get() |> deliverOnMainQueue, timeout.get() |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, data, timeout -> (ItemListControllerState, (ItemListNodeState<ChangePhoneNumberCodeEntry>, ChangePhoneNumberCodeEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if state.checking {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            } else {
                var nextEnabled = true
                if state.codeText.isEmpty {
                    nextEnabled = false
                }
                rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Next, style: .bold, enabled: nextEnabled, action: {
                    checkCode()
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(formatPhoneNumber(phoneNumber)), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: changePhoneNumberCodeControllerEntries(presentationData: presentationData, state: state, codeData: data, timeout: timeout), style: .blocks, focusItemTag: ChangePhoneNumberCodeTag.input, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    dismissImpl = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
    }
    
    return controller
}
