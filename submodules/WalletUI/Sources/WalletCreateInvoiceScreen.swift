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
    let selectNextInputItem: (WalletCreateInvoiceScreenEntryTag) -> Void
    let dismissInput: () -> Void
    let copyAddress: () -> Void
    let shareAddressLink: () -> Void
    let openQrCode: () -> Void
    let displayQrCodeContextMenu: () -> Void
    let scrollToBottom: () -> Void
    
    init(context: WalletContext, updateState: @escaping ((WalletCreateInvoiceScreenState) -> WalletCreateInvoiceScreenState) -> Void, updateText: @escaping (WalletCreateInvoiceScreenEntryTag, String) -> Void, selectNextInputItem: @escaping (WalletCreateInvoiceScreenEntryTag) -> Void, dismissInput: @escaping () -> Void, copyAddress: @escaping () -> Void, shareAddressLink: @escaping () -> Void, openQrCode: @escaping () -> Void, displayQrCodeContextMenu: @escaping () -> Void, scrollToBottom: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.updateText = updateText
        self.selectNextInputItem = selectNextInputItem
        self.dismissInput = dismissInput
        self.copyAddress = copyAddress
        self.shareAddressLink = shareAddressLink
        self.openQrCode = openQrCode
        self.displayQrCodeContextMenu = displayQrCodeContextMenu
        self.scrollToBottom = scrollToBottom
    }
}

private enum WalletCreateInvoiceScreenSection: Int32 {
    case amount
    case comment
    case address
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
    case amountHeader(WalletTheme, String)
    case amount(WalletTheme, WalletStrings, String, String)
    case commentHeader(WalletTheme, String)
    case comment(WalletTheme, String, String)
    case addressCode(WalletTheme, String)
    case addressHeader(WalletTheme, String)
    case address(WalletTheme, String, Bool)
    case copyAddress(WalletTheme, String)
    case shareAddressLink(WalletTheme, String)
    case addressInfo(WalletTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .amountHeader, .amount:
            return WalletCreateInvoiceScreenSection.amount.rawValue
        case .commentHeader, .comment:
            return WalletCreateInvoiceScreenSection.comment.rawValue
        case .addressCode, .addressHeader, .address, .copyAddress, .shareAddressLink, .addressInfo:
            return WalletCreateInvoiceScreenSection.address.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .amountHeader:
            return 0
        case .amount:
            return 1
        case .commentHeader:
            return 2
        case .comment:
            return 3
        case .addressCode:
            return 4
        case .addressHeader:
            return 5
        case .address:
            return 6
        case .copyAddress:
            return 7
        case .shareAddressLink:
            return 8
        case .addressInfo:
            return 9
        }
    }
    
    static func ==(lhs: WalletCreateInvoiceScreenEntry, rhs: WalletCreateInvoiceScreenEntry) -> Bool {
        switch lhs {
        case let .amountHeader(lhsTheme, lhsText):
            if case let .amountHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .amount(lhsTheme, lhsStrings, lhsPlaceholder, lhsBalance):
            if case let .amount(rhsTheme, rhsStrings, rhsPlaceholder, rhsBalance) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPlaceholder == rhsPlaceholder, lhsBalance == rhsBalance {
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
        case let .addressCode(lhsTheme, lhsAddress):
            if case let .addressCode(rhsTheme, rhsAddress) = rhs, lhsTheme === rhsTheme, lhsAddress == rhsAddress {
                return true
            } else {
                return false
            }
        case let .addressHeader(lhsTheme, lhsText):
            if case let .addressHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .address(lhsTheme, lhsAddress, lhsMonospace):
            if case let .address(rhsTheme, rhsAddress, rhsMonospace) = rhs, lhsTheme === rhsTheme, lhsAddress == rhsAddress, lhsMonospace == rhsMonospace {
                return true
            } else {
                return false
            }
        case let .copyAddress(lhsTheme, lhsText):
            if case let .copyAddress(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .shareAddressLink(lhsTheme, lhsText):
            if case let .shareAddressLink(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .addressInfo(lhsTheme, lhsText):
            if case let .addressInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
        case let .amountHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .amount(theme, strings, placeholder, text):
            return ItemListSingleLineInputItem(theme: theme, strings: strings, title: NSAttributedString(string: ""), text: text, placeholder: placeholder, type: .decimal, returnKeyType: .next, clearType: .onFocus, tag: WalletCreateInvoiceScreenEntryTag.amount, sectionId: self.section, textUpdated: { text in
                let text = formatAmountText(text, decimalSeparator: arguments.context.presentationData.dateTimeFormat.decimalSeparator)
                arguments.updateText(WalletCreateInvoiceScreenEntryTag.amount, text)
            }, shouldUpdateText: { text in
                return isValidAmount(text)
            }, processPaste: { pastedText in
                if isValidAmount(pastedText) {
                    return normalizedStringForGramsString(pastedText)
                } else {
                    return text
                }
            }, updatedFocus: { focus in
                arguments.updateState { state in
                    var state = state
                    state.focusItemTag = focus ? WalletCreateInvoiceScreenEntryTag.amount : nil
                    return state
                }
                if focus {
                    arguments.scrollToBottom()
                } else {
                    let presentationData = arguments.context.presentationData
                    arguments.updateState { state in
                        var state = state
                        if !state.amount.isEmpty {
                            state.amount = normalizedStringForGramsString(state.amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                        }
                        return state
                    }
                }
            }, action: {
                arguments.selectNextInputItem(WalletCreateInvoiceScreenEntryTag.amount)
            })
        case let .commentHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .comment(theme, placeholder, value):
            return ItemListMultilineInputItem(theme: theme, text: value, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: walletTextLimit, display: true), sectionId: self.section, style: .blocks, returnKeyType: .done, textUpdated: { text in
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
        case let .addressCode(theme, text):
            return WalletQrCodeItem(theme: theme, address: text, sectionId: self.section, style: .blocks, action: {
                arguments.openQrCode()
            }, longTapAction: {
                arguments.displayQrCodeContextMenu()
            })
        case let .addressHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .address(theme, text, monospace):
            return ItemListMultilineTextItem(theme: theme, text: text, font: monospace ? .monospace : .default, sectionId: self.section, style: .blocks)
        case let .copyAddress(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.copyAddress()
            })
        case let .shareAddressLink(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.shareAddressLink()
            })
        case let .addressInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
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
    
    let amount = amountValue(state.amount)
    entries.append(.amountHeader(presentationData.theme, presentationData.strings.Wallet_Receive_AmountHeader))
    entries.append(.amount(presentationData.theme, presentationData.strings, presentationData.strings.Wallet_Receive_AmountText, state.amount ?? ""))
    
    entries.append(.commentHeader(presentationData.theme, presentationData.strings.Wallet_Receive_CommentHeader))
    entries.append(.comment(presentationData.theme, presentationData.strings.Wallet_Receive_CommentInfo, state.comment))
    
    let url = walletInvoiceUrl(address: address, amount: state.amount, comment: state.comment)
    entries.append(.addressCode(presentationData.theme, url))
    entries.append(.addressHeader(presentationData.theme, presentationData.strings.Wallet_Receive_InvoiceUrlHeader))
    
    entries.append(.address(presentationData.theme, url, false))
    entries.append(.copyAddress(presentationData.theme, presentationData.strings.Wallet_Receive_CopyInvoiceUrl))
    entries.append(.shareAddressLink(presentationData.theme, presentationData.strings.Wallet_Receive_ShareInvoiceUrl))
    entries.append(.addressInfo(presentationData.theme, presentationData.strings.Wallet_Receive_ShareUrlInfo))
    
    return entries
}

protocol WalletCreateInvoiceScreen {
    
}

private final class WalletCreateInvoiceScreenImpl: ItemListController, WalletCreateInvoiceScreen {
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
    var selectNextInputItemImpl: ((WalletCreateInvoiceScreenEntryTag) -> Void)?
    var dismissInputImpl: (() -> Void)?
    var ensureItemVisibleImpl: ((WalletCreateInvoiceScreenEntryTag, Bool) -> Void)?
    var displayQrCodeContextMenuImpl: (() -> Void)?
    
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
        ensureItemVisibleImpl?(WalletCreateInvoiceScreenEntryTag.comment, false)
    }, selectNextInputItem: { tag in
        selectNextInputItemImpl?(tag)
    }, dismissInput: {
        dismissInputImpl?()
    }, copyAddress: {
        let presentationData = context.presentationData
        let state = stateValue.with { $0 }
        
        UIPasteboard.general.string = walletInvoiceUrl(address: address, amount: state.amount, comment: state.comment)
    
        if currentStatusController == nil {
            let statusController = OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.Wallet_Receive_InvoiceUrlCopied, false))
            presentControllerImpl?(statusController, nil)
            currentStatusController = statusController
        }
    }, shareAddressLink: {
        dismissInputImpl?()
        let state = stateValue.with { $0 }
        let url = walletInvoiceUrl(address: address, amount: state.amount, comment: state.comment)
        context.shareUrl(url)
    }, openQrCode: {
        dismissInputImpl?()
        let state = stateValue.with { $0 }
        let url = walletInvoiceUrl(address: address, amount: state.amount, comment: state.comment)
        pushImpl?(WalletQrViewScreen(context: context, invoice: url))
    }, displayQrCodeContextMenu: {
        dismissInputImpl?()
        displayQrCodeContextMenuImpl?()
    }, scrollToBottom: {
        ensureItemVisibleImpl?(WalletCreateInvoiceScreenEntryTag.comment, true)
    })
    
    let signal = combineLatest(queue: .mainQueue(), .single(context.presentationData), statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            var ensureVisibleItemTag: ItemListItemTag?
            if let focusItemTag = state.focusItemTag {
                ensureVisibleItemTag = focusItemTag
            }
            
            let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Navigation_Done), style: .bold, enabled: true, action: {
                dismissImpl?()
            })
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_CreateInvoice_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Wallet_Navigation_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: walletCreateInvoiceScreenEntries(presentationData: presentationData, address: address, state: state), style: .blocks, ensureVisibleItemTag: ensureVisibleItemTag, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = WalletCreateInvoiceScreenImpl(theme: context.presentationData.theme, strings: context.presentationData.strings, updatedPresentationData: .single((context.presentationData.theme, context.presentationData.strings)), state: signal, tabBarItem: nil)
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    controller.experimentalSnapScrollToItem = true
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
    selectNextInputItemImpl = { [weak controller] currentTag in
        guard let controller = controller else {
            return
        }
        var resultItemNode: ItemListItemFocusableNode?
        var focusOnNext = false
        let _ = controller.frameForItemNode({ itemNode in
            if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag, let focusableItemNode = itemNode as? ItemListItemFocusableNode {
                if focusOnNext && resultItemNode == nil {
                    resultItemNode = focusableItemNode
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
    displayQrCodeContextMenuImpl = { [weak controller] in
        let state = stateValue.with { $0 }
        let url = walletInvoiceUrl(address: address, amount: state.amount, comment: state.comment)
        shareInvoiceQrCode(context: context, invoice: url)
    }
    return controller
}
