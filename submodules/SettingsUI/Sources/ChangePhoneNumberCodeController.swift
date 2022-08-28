import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import AuthorizationUtils
import PhoneNumberFormat

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
    case codeEntry(PresentationTheme, PresentationStrings, String, String)
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
            case let .codeEntry(lhsTheme, lhsStrings, lhsTitle, lhsText):
                if case let .codeEntry(rhsTheme, rhsStrings, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsTitle == rhsTitle, lhsText == rhsText {
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChangePhoneNumberCodeControllerArguments
        switch self {
            case let .codeEntry(_, _, title, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: title, textColor: .black), text: text, placeholder: "", type: .number, spacing: 10.0, tag: ChangePhoneNumberCodeTag.input, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updateEntryText(updatedText)
                }, action: {
                    arguments.next()
                })
            case let .codeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
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

private func changePhoneNumberCodeControllerEntries(presentationData: PresentationData, state: ChangePhoneNumberCodeControllerState, codeData: ChangeAccountPhoneNumberData, timeout: Int32?, strings: PresentationStrings, phoneNumber: String) -> [ChangePhoneNumberCodeEntry] {
    var entries: [ChangePhoneNumberCodeEntry] = []
    
    entries.append(.codeEntry(presentationData.theme, presentationData.strings, presentationData.strings.ChangePhoneNumberCode_CodePlaceholder, state.codeText))
    var text = authorizationCurrentOptionText(codeData.type, phoneNumber: phoneNumber, email: nil, strings: presentationData.strings, primaryColor: presentationData.theme.list.itemPrimaryTextColor, accentColor: presentationData.theme.list.itemAccentColor).string
    if let nextType = codeData.nextType {
        text += "\n\n" + authorizationNextOptionText(currentType: codeData.type, nextType: nextType, timeout: timeout, strings: presentationData.strings, primaryColor: .black, accentColor: .black).0.string
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

public protocol ChangePhoneNumberCodeController: AnyObject {
    func applyCode(_ code: Int)
}

private final class ChangePhoneNumberCodeControllerImpl: ItemListController, ChangePhoneNumberCodeController {
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

func changePhoneNumberCodeController(context: AccountContext, phoneNumber: String, codeData: ChangeAccountPhoneNumberData) -> ViewController {
    let initialState = ChangePhoneNumberCodeControllerState(codeText: "", checking: false)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChangePhoneNumberCodeControllerState) -> ChangePhoneNumberCodeControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
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
                            return context.engine.accountData.requestNextChangeAccountPhoneNumberVerification(phoneNumber: phoneNumber, phoneCodeHash: data.hash).start(next: { next in
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
            changePhoneDisposable.set((context.engine.accountData.requestChangeAccountPhoneNumber(phoneNumber: phoneNumber, phoneCodeHash: codeData.hash, phoneCode: code) |> deliverOnMainQueue).start(error: { error in
                updateState {
                    return $0.withUpdatedChecking(false)
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
                updateState {
                    return $0.withUpdatedChecking(false)
                }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .success), nil)
                
                let _ = dismissServerProvidedSuggestion(account: context.account, suggestion: .validatePhoneNumber).start()
                
                dismissImpl?()
            }))
        }
    }
    
    let arguments = ChangePhoneNumberCodeControllerArguments(updateEntryText: { updatedText in
        var initiateCheck = false
        updateState { state in
            if state.codeText.count < 5 && updatedText.count == 5 {
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
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get() |> deliverOnMainQueue, currentDataPromise.get() |> deliverOnMainQueue, timeout.get() |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, data, timeout -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(formatPhoneNumber(phoneNumber)), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: changePhoneNumberCodeControllerEntries(presentationData: presentationData, state: state, codeData: data, timeout: timeout, strings: presentationData.strings, phoneNumber: phoneNumber), style: .blocks, focusItemTag: ChangePhoneNumberCodeTag.input, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ChangePhoneNumberCodeControllerImpl(context: context, state: signal, applyCodeImpl: { code in
        updateState { state in
            return state.withUpdatedCodeText("\(code)")
        }
        checkCode()
    })
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    dismissImpl = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
    }
    
    return controller
}
