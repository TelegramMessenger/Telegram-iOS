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
import AuthorizationUtils
import PhoneNumberFormat

private final class ConfirmPhoneNumberCodeControllerArguments {
    let updateEntryText: (String) -> Void
    let next: () -> Void
    
    init(updateEntryText: @escaping (String) -> Void, next: @escaping () -> Void) {
        self.updateEntryText = updateEntryText
        self.next = next
    }
}

private enum ConfirmPhoneNumberCodeSection: Int32 {
    case code
}

private enum ConfirmPhoneNumberCodeTag: ItemListItemTag {
    case input
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ConfirmPhoneNumberCodeTag {
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

private enum ConfirmPhoneNumberCodeEntry: ItemListNodeEntry {
    case codeEntry(PresentationTheme, PresentationStrings, String, String)
    case codeInfo(PresentationTheme, PresentationStrings, String, String)
    
    var section: ItemListSectionId {
        return ConfirmPhoneNumberCodeSection.code.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .codeEntry:
                return 1
            case .codeInfo:
                return 2
        }
    }
    
    static func ==(lhs: ConfirmPhoneNumberCodeEntry, rhs: ConfirmPhoneNumberCodeEntry) -> Bool {
        switch lhs {
            case let .codeEntry(lhsTheme, lhsStrings, lhsTitle, lhsText):
                if case let .codeEntry(rhsTheme, rhsStrings, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .codeInfo(lhsTheme, lhsStrings, lhsPhoneNumber, lhsText):
                if case let .codeInfo(rhsTheme, rhsStrings, rhsPhoneNumber, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPhoneNumber == rhsPhoneNumber, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ConfirmPhoneNumberCodeEntry, rhs: ConfirmPhoneNumberCodeEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ConfirmPhoneNumberCodeControllerArguments
        switch self {
            case let .codeEntry(_, _, title, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: title, textColor: .black), text: text, placeholder: "", type: .number, spacing: 10.0, tag: ConfirmPhoneNumberCodeTag.input, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateEntryText(updatedText)
                }, action: {
                    arguments.next()
                })
            case let .codeInfo(_, strings, phoneNumber, nextOptionText):
                let formattedNumber = formatPhoneNumber(phoneNumber)
                let stringAndRanges = strings.CancelResetAccount_TextSMS(formattedNumber)
                var result = ""
                result += stringAndRanges.string
                if let range = result.range(of: formattedNumber) {
                    result.insert("*", at: range.upperBound)
                    result.insert("*", at: range.upperBound)
                    result.insert("*", at: range.lowerBound)
                    result.insert("*", at: range.lowerBound)
                }
                if !nextOptionText.isEmpty {
                    result += "\n\n" + nextOptionText
                }
                return ItemListTextItem(presentationData: presentationData, text: .markdown(result), sectionId: self.section)
        }
    }
}

private struct ConfirmPhoneNumberCodeControllerState: Equatable {
    var codeText: String
    var checking: Bool
    
    init(codeText: String, checking: Bool) {
        self.codeText = codeText
        self.checking = checking
    }
}

private func confirmPhoneNumberCodeControllerEntries(presentationData: PresentationData, state: ConfirmPhoneNumberCodeControllerState, phoneNumber: String, codeData: CancelAccountResetData, timeout: Int32?, strings: PresentationStrings, theme: PresentationTheme) -> [ConfirmPhoneNumberCodeEntry] {
    var entries: [ConfirmPhoneNumberCodeEntry] = []
    
    entries.append(.codeEntry(presentationData.theme, presentationData.strings, presentationData.strings.ChangePhoneNumberCode_CodePlaceholder, state.codeText))
    var text = ""
    if let nextType = codeData.nextType {
        text += authorizationNextOptionText(currentType: codeData.type, nextType: nextType, timeout: timeout, strings: presentationData.strings, primaryColor: .black, accentColor: .black).0.string
    }
    entries.append(.codeInfo(presentationData.theme, presentationData.strings, phoneNumber, text))
    
    return entries
}

private func timeoutSignal(codeData: CancelAccountResetData) -> Signal<Int32?, NoError> {
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

protocol ConfirmPhoneNumberCodeController: AnyObject {
    func applyCode(_ code: Int)
}

private final class ConfirmPhoneNumberCodeControllerImpl: ItemListController, ConfirmPhoneNumberCodeController {
    private let applyCodeImpl: (Int) -> Void
    
    init(context: AccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError>, applyCodeImpl: @escaping (Int) -> Void) {
        self.applyCodeImpl = applyCodeImpl
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(presentationData: ItemListPresentationData(presentationData), updatedPresentationData: context.sharedContext.presentationData |> map(ItemListPresentationData.init(_:)), state: state, tabBarItem: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func applyCode(_ code: Int) {
        self.applyCodeImpl(code)
    }
}

public func confirmPhoneNumberCodeController(context: AccountContext, phoneNumber: String, codeData: CancelAccountResetData) -> ViewController {
    let initialState = ConfirmPhoneNumberCodeControllerState(codeText: "", checking: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ConfirmPhoneNumberCodeControllerState) -> ConfirmPhoneNumberCodeControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let confirmPhoneDisposable = MetaDisposable()
    actionsDisposable.add(confirmPhoneDisposable)
    
    let nextTypeDisposable = MetaDisposable()
    actionsDisposable.add(nextTypeDisposable)
    
    let currentDataPromise = Promise<CancelAccountResetData>()
    currentDataPromise.set(.single(codeData))
    
    let timeout = Promise<Int32?>()
    timeout.set(currentDataPromise.get()
    |> mapToSignal(timeoutSignal))
    
    let resendCode = currentDataPromise.get()
    |> mapToSignal { [weak currentDataPromise] data -> Signal<Void, NoError> in
        if let _ = data.nextType {
            return timeout.get()
            |> filter { $0 == 0 }
            |> take(1)
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return Signal { subscriber in
                    return context.engine.auth.requestNextCancelAccountResetOption(phoneNumber: phoneNumber, phoneCodeHash: data.hash).start(next: { next in
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
            var state = state
            if state.checking || state.codeText.isEmpty {
                return state
            } else {
                code = state.codeText
                state.checking = true
                return state
            }
        }
        if let code = code {
            confirmPhoneDisposable.set((context.engine.auth.requestCancelAccountReset(phoneCodeHash: codeData.hash, phoneCode: code)
            |> deliverOnMainQueue).start(error: { error in
                updateState { state in
                    var state = state
                    state.checking = false
                    return state
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let alertText: String
                switch error {
                    case .generic:
                        alertText = presentationData.strings.Login_UnknownError
                    case .invalidCode:
                        alertText = presentationData.strings.Login_InvalidCodeError
                    case .codeExpired:
                        alertText = presentationData.strings.Login_CodeExpiredError
                    case .limitExceeded:
                        alertText = presentationData.strings.Login_CodeFloodError
                }
                presentControllerImpl?(textAlertController(context: context, title: nil, text: alertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, completed: {
                updateState { state in
                    var state = state
                    state.checking = false
                    return state
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.CancelResetAccount_Success(formatPhoneNumber(phoneNumber)).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                dismissImpl?()
            }))
        }
    }
    
    let arguments = ConfirmPhoneNumberCodeControllerArguments(updateEntryText: { updatedText in
        var initiateCheck = false
        updateState { state in
            var state = state
            if state.codeText.count < 5 && updatedText.count == 5 {
                initiateCheck = true
            }
            state.codeText = updatedText
            return state
        }
        if initiateCheck {
            checkCode()
        }
    }, next: {
        checkCode()
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get() |> deliverOnMainQueue, currentDataPromise.get() |> deliverOnMainQueue, timeout.get() |> deliverOnMainQueue)
    |> deliverOnMainQueue
    |> map { presentationData, state, data, timeout -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        var rightNavigationButton: ItemListNavigationButton?
        if state.checking {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            var nextEnabled = true
            if state.codeText.isEmpty {
                nextEnabled = false
            }
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Next), style: .bold, enabled: nextEnabled, action: {
                checkCode()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.CancelResetAccount_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: confirmPhoneNumberCodeControllerEntries(presentationData: presentationData, state: state, phoneNumber: phoneNumber, codeData: data, timeout: timeout, strings: presentationData.strings, theme: presentationData.theme), style: .blocks, focusItemTag: ConfirmPhoneNumberCodeTag.input, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ConfirmPhoneNumberCodeControllerImpl(context: context, state: signal, applyCodeImpl: { code in
        updateState { state in
            var state = state
            state.codeText = "\(code)"
            return state
        }
        checkCode()
    })
    
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
