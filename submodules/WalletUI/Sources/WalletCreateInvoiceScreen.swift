import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SwiftSignalKit
import OverlayStatusController

private final class WalletCreateInvoiceScreenArguments {
    let context: WalletContext
    let updateState: ((WalletCreateInvoiceScreenState) -> WalletCreateInvoiceScreenState) -> Void
    let updateText: (WalletCreateInvoiceScreenEntryTag, String) -> Void
    let dismissInput: () -> Void
    let scrollToBottom: () -> Void
    
    init(context: WalletContext, updateState: @escaping ((WalletCreateInvoiceScreenState) -> WalletCreateInvoiceScreenState) -> Void, updateText: @escaping (WalletCreateInvoiceScreenEntryTag, String) -> Void, dismissInput: @escaping () -> Void, scrollToBottom: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.updateText = updateText
        self.dismissInput = dismissInput
        self.scrollToBottom = scrollToBottom
    }
}

private enum WalletCreateInvoiceScreenSection: Int32 {
    case amount
    case comment
}

private enum WalletCreateInvoiceScreenEntryTag: ItemListItemTag {
    case amount
    case comment
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? WalletCreateInvoiceScreenEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum WalletCreateInvoiceScreenEntry: ItemListNodeEntry {
    case amount(WalletTheme, String)
    case amountInfo(WalletTheme, String)
    case commentHeader(WalletTheme, String)
    case comment(WalletTheme, String, String)
   
    var section: ItemListSectionId {
        switch self {
        case .amount, .amountInfo:
            return WalletCreateInvoiceScreenSection.amount.rawValue
        case .commentHeader, .comment:
            return WalletCreateInvoiceScreenSection.comment.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .amount:
            return 0
        case .amountInfo:
            return 1
        case .commentHeader:
            return 2
        case .comment:
            return 3
        }
    }
    
    static func ==(lhs: WalletCreateInvoiceScreenEntry, rhs: WalletCreateInvoiceScreenEntry) -> Bool {
        switch lhs {
        case let .amount(lhsTheme, lhsAmount):
            if case let .amount(rhsTheme, rhsAmount) = rhs, lhsTheme === rhsTheme, lhsAmount == rhsAmount {
                return true
            } else {
                return false
            }
        case let .amountInfo(lhsTheme, lhsText):
            if case let .amountInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .commentHeader(lhsTheme, lhsText):
            if case let .commentHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .comment(lhsTheme, lhsPlaceholder, lhsText):
            if case let .comment(rhsTheme, rhsPlaceholder, rhsText) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsText == rhsText {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: WalletCreateInvoiceScreenEntry, rhs: WalletCreateInvoiceScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: Any) -> ListViewItem {
        let arguments = arguments as! WalletCreateInvoiceScreenArguments
        switch self {
        case let .amount(theme, amount):
            return WalletAmountItem(theme: theme, amount: amount, sectionId: self.section, textUpdated: { text in
                let text = formatAmountText(text, decimalSeparator: arguments.context.presentationData.dateTimeFormat.decimalSeparator)
                arguments.updateText(WalletCreateInvoiceScreenEntryTag.amount, text)
            }, shouldUpdateText: { text in
                return isValidAmount(text)
            }, processPaste: { pastedText in
                if isValidAmount(pastedText) {
                    return normalizedStringForGramsString(pastedText)
                } else {
                    return amount
                }
            }, updatedFocus: { focus in
                arguments.updateState { state in
                    var state = state
                    state.focusItemTag = focus ? WalletCreateInvoiceScreenEntryTag.amount : nil
                    return state
                }
                if !focus {
                    let presentationData = arguments.context.presentationData
                    arguments.updateState { state in
                        var state = state
                        if !state.amount.isEmpty {
                            state.amount = normalizedStringForGramsString(state.amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                        }
                        return state
                    }
                }
            }, tag: WalletCreateInvoiceScreenEntryTag.amount)
        case let .amountInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
        case let .commentHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .comment(theme, placeholder, value):
            return ItemListMultilineInputItem(theme: theme, text: value, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: walletTextLimit, display: true, mode: .bytes), sectionId: self.section, style: .blocks, returnKeyType: .done, textUpdated: { text in
                arguments.updateText(WalletCreateInvoiceScreenEntryTag.comment, text)
            }, shouldUpdateText: { text in
                let textLength: Int = text.data(using: .utf8, allowLossyConversion: true)?.count ?? 0
                return text.count <= walletTextLimit
            }, updatedFocus: { focus in
                arguments.updateState { state in
                    var state = state
                    state.focusItemTag = focus ? WalletCreateInvoiceScreenEntryTag.comment : nil
                    return state
                }
                if focus {
                    arguments.scrollToBottom()
                }
            }, tag: WalletCreateInvoiceScreenEntryTag.comment, action: {
                arguments.dismissInput()
            })
        }
    }
}

private struct WalletCreateInvoiceScreenState: Equatable {
    var amount: String
    var comment: String
    var focusItemTag: WalletCreateInvoiceScreenEntryTag?
    
    var isEmpty: Bool {
        return self.amount.isEmpty && self.comment.isEmpty
    }
}

private func walletCreateInvoiceScreenEntries(presentationData: WalletPresentationData, address: String, state: WalletCreateInvoiceScreenState) -> [WalletCreateInvoiceScreenEntry] {
    var entries: [WalletCreateInvoiceScreenEntry] = []
    entries.append(.amount(presentationData.theme, state.amount ?? ""))
    entries.append(.amountInfo(presentationData.theme, presentationData.strings.Wallet_Receive_CreateInvoiceInfo))
    entries.append(.commentHeader(presentationData.theme, presentationData.strings.Wallet_Receive_CommentHeader))
    entries.append(.comment(presentationData.theme, presentationData.strings.Wallet_Receive_CommentInfo, state.comment))
    return entries
}

protocol WalletCreateInvoiceScreen {
    
}

private final class WalletCreateInvoiceScreenImpl: ItemListController, WalletCreateInvoiceScreen {
    override func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        return CGSize(width: layout.size.width, height: min(674.0, layout.size.height))
    }
}

func walletCreateInvoiceScreen(context: WalletContext, address: String) -> ViewController {
    let initialState = WalletCreateInvoiceScreenState(amount: "", comment: "", focusItemTag: nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((WalletCreateInvoiceScreenState) -> WalletCreateInvoiceScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var ensureItemVisibleImpl: ((WalletCreateInvoiceScreenEntryTag, Bool) -> Void)?
    
    weak var currentStatusController: ViewController?
    let arguments = WalletCreateInvoiceScreenArguments(context: context, updateState: { f in
        updateState(f)
    }, updateText: { tag, value in
        updateState { state in
            var state = state
            switch tag {
            case .amount:
                state.amount = value
            case .comment:
                state.comment = value
            }
            return state
        }
        ensureItemVisibleImpl?(tag, true)
    }, dismissInput: {
        dismissInputImpl?()
    }, scrollToBottom: {
        ensureItemVisibleImpl?(WalletCreateInvoiceScreenEntryTag.comment, true)
    })
    
    let signal = combineLatest(queue: .mainQueue(), .single(context.presentationData), statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var ensureVisibleItemTag: ItemListItemTag?
        if let focusItemTag = state.focusItemTag {
            ensureVisibleItemTag = focusItemTag
        }
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Navigation_Done), style: .bold, enabled: !state.isEmpty, action: {
            pushImpl?(WalletReceiveScreen(context: context, mode: .invoice(address: address, amount: state.amount, comment: state.comment)))
        })
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_CreateInvoice_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Wallet_Navigation_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletCreateInvoiceScreenEntries(presentationData: presentationData, address: address, state: state), style: .blocks, focusItemTag: ensureVisibleItemTag, ensureVisibleItemTag: ensureVisibleItemTag, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletCreateInvoiceScreenImpl(theme: context.presentationData.theme, strings: context.presentationData.strings, updatedPresentationData: .single((context.presentationData.theme, context.presentationData.strings)), state: signal, tabBarItem: nil, hasNavigationBarSeparator: false)
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    controller.experimentalSnapScrollToItem = true
    controller.didAppear = { _ in
        updateState { state in
            var state = state
            state.focusItemTag = .amount
            return state
        }
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        let _ = controller?.dismiss()
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    ensureItemVisibleImpl = { [weak controller] targetTag, animated in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            var resultItemNode: ListViewItemNode?
            let state = stateValue.with({ $0 })
            let _ = controller.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListItemNode {
                    if let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                        resultItemNode = itemNode as? ListViewItemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode, animated: animated)
            }
        })
    }
    return controller
}
