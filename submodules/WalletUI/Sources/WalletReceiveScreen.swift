import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import ItemListUI
import SwiftSignalKit
import OverlayStatusController
import ShareController

private final class WalletReceiveScreenArguments {
    let context: AccountContext
    let updateState: ((WalletReceiveScreenState) -> WalletReceiveScreenState) -> Void
    let updateText: (WalletReceiveScreenEntryTag, String) -> Void
    let selectNextInputItem: (WalletReceiveScreenEntryTag) -> Void
    let dismissInput: () -> Void
    let copyAddress: () -> Void
    let shareAddressLink: () -> Void
    let openQrCode: () -> Void
    let displayQrCodeContextMenu: () -> Void
    let scrollToBottom: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((WalletReceiveScreenState) -> WalletReceiveScreenState) -> Void, updateText: @escaping (WalletReceiveScreenEntryTag, String) -> Void, selectNextInputItem: @escaping (WalletReceiveScreenEntryTag) -> Void, dismissInput: @escaping () -> Void, copyAddress: @escaping () -> Void, shareAddressLink: @escaping () -> Void, openQrCode: @escaping () -> Void, displayQrCodeContextMenu: @escaping () -> Void, scrollToBottom: @escaping () -> Void) {
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

private enum WalletReceiveScreenSection: Int32 {
    case address
    case amount
    case comment
}

private enum WalletReceiveScreenEntryTag: ItemListItemTag {
    case amount
    case comment
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? WalletReceiveScreenEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum WalletReceiveScreenEntry: ItemListNodeEntry {
    case addressCode(PresentationTheme, String)
    case addressHeader(PresentationTheme, String)
    case address(PresentationTheme, String, Bool)
    case copyAddress(PresentationTheme, String)
    case shareAddressLink(PresentationTheme, String)
    case addressInfo(PresentationTheme, String)
    case amountHeader(PresentationTheme, String)
    case amount(PresentationTheme, PresentationStrings, String, String)
    case commentHeader(PresentationTheme, String)
    case comment(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
        case .addressCode, .addressHeader, .address, .copyAddress, .shareAddressLink, .addressInfo:
            return WalletReceiveScreenSection.address.rawValue
        case .amountHeader, .amount:
            return WalletReceiveScreenSection.amount.rawValue
        case .commentHeader, .comment:
            return WalletReceiveScreenSection.comment.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .addressCode:
            return 0
        case .addressHeader:
            return 1
        case .address:
            return 2
        case .copyAddress:
            return 3
        case .shareAddressLink:
            return 4
        case .addressInfo:
            return 5
        case .amountHeader:
            return 6
        case .amount:
            return 7
        case .commentHeader:
            return 8
        case .comment:
            return 9
        }
    }
    
    static func ==(lhs: WalletReceiveScreenEntry, rhs: WalletReceiveScreenEntry) -> Bool {
        switch lhs {
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
        }
    }
    
    static func <(lhs: WalletReceiveScreenEntry, rhs: WalletReceiveScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: WalletReceiveScreenArguments) -> ListViewItem {
        switch self {
        case let .addressCode(theme, text):
            return WalletQrCodeItem(theme: theme, address: text, sectionId: self.section, style: .blocks, action: {
                arguments.openQrCode()
            }, longTapAction: {
                arguments.displayQrCodeContextMenu()
            })
        case let .addressHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .address(theme, text, monospace):
            return ItemListMultilineTextItem(theme: theme, text: text, enabledEntityTypes: [], font: monospace ? .monospace : .default, sectionId: self.section, style: .blocks)
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
        case let .amountHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .amount(theme, strings, placeholder, text):
            return ItemListSingleLineInputItem(theme: theme, strings: strings, title: NSAttributedString(string: ""), text: text, placeholder: placeholder, type: .decimal, returnKeyType: .next, tag: WalletReceiveScreenEntryTag.amount, sectionId: self.section, textUpdated: { text in
                let text = formatAmountText(text, decimalSeparator: arguments.context.sharedContext.currentPresentationData.with { $0 }.dateTimeFormat.decimalSeparator)
                arguments.updateText(WalletReceiveScreenEntryTag.amount, text)
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
                    state.focusItemTag = focus ? WalletReceiveScreenEntryTag.amount : nil
                    return state
                }
                if focus {
                    arguments.scrollToBottom()
                } else {
                    let presentationData = arguments.context.sharedContext.currentPresentationData.with { $0 }
                    arguments.updateState { state in
                        var state = state
                        if !state.amount.isEmpty {
                            state.amount = normalizedStringForGramsString(state.amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                        }
                        return state
                    }
                }
            }, action: {
                arguments.selectNextInputItem(WalletReceiveScreenEntryTag.amount)
            })
        case let .commentHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .comment(theme, placeholder, value):
            return ItemListMultilineInputItem(theme: theme, text: value, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: 128, display: true), sectionId: self.section, style: .blocks, returnKeyType: .done, textUpdated: { text in
                arguments.updateText(WalletReceiveScreenEntryTag.comment, text)
            }, shouldUpdateText: { text in
                return text.count <= 128
            }, updatedFocus: { focus in
                arguments.updateState { state in
                    var state = state
                    state.focusItemTag = focus ? WalletReceiveScreenEntryTag.comment : nil
                    return state
                }
                if focus {
                    arguments.scrollToBottom()
                }
            }, tag: WalletReceiveScreenEntryTag.comment, action: {
                arguments.dismissInput()
            })
        }
    }
}

private struct WalletReceiveScreenState: Equatable {
    var amount: String
    var comment: String
    var focusItemTag: WalletReceiveScreenEntryTag?
    
    var isEmpty: Bool {
        return self.amount.isEmpty && self.comment.isEmpty
    }
}

private func walletReceiveScreenEntries(presentationData: PresentationData, address: String, state: WalletReceiveScreenState) -> [WalletReceiveScreenEntry] {
    var entries: [WalletReceiveScreenEntry] = []
    entries.append(.addressCode(presentationData.theme, invoiceUrl(address: address, state: state, escapeComment: true)))
    entries.append(.addressHeader(presentationData.theme, state.isEmpty ? "YOUR WALLET ADDRESS" : "INVOICE URL"))
    
    let addressText: String
    var addressMonospace = false
    if state.isEmpty {
        addressText = formatAddress(address)
        addressMonospace = true
    } else {
        addressText = invoiceUrl(address: address, state: state, escapeComment: false)
    }
    entries.append(.address(presentationData.theme, addressText, addressMonospace))
    entries.append(.copyAddress(presentationData.theme, state.isEmpty ? "Copy Wallet Address" : "Copy Invoice URL"))
    entries.append(.shareAddressLink(presentationData.theme, state.isEmpty ? "Share Wallet Address" : "Share Invoice URL"))
    entries.append(.addressInfo(presentationData.theme, "Share this link with other Gram wallet owners to receive Grams from them."))
    
    let amount = amountValue(state.amount)
    entries.append(.amountHeader(presentationData.theme, "AMOUNT"))
    entries.append(.amount(presentationData.theme, presentationData.strings, "Grams to receive", state.amount ?? ""))
    
    entries.append(.commentHeader(presentationData.theme, "COMMENT (OPTIONAL)"))
    entries.append(.comment(presentationData.theme, "Description of the payment", state.comment))
    
    return entries
}

protocol WalletReceiveScreen {
    
}

private final class WalletReceiveScreenImpl: ItemListController<WalletReceiveScreenEntry>, WalletSendScreen {
    
}

private func invoiceUrl(address: String, state: WalletReceiveScreenState, escapeComment: Bool = true) -> String {
    let escapedAddress = address.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    var arguments = ""
    if !state.amount.isEmpty {
        arguments += arguments.isEmpty ? "/?" : "&"
        arguments += "amount=\(amountValue(state.amount))"
    }
    if !state.comment.isEmpty, let escapedComment = state.comment.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        arguments += arguments.isEmpty ? "/?" : "&"
        if escapeComment {
            arguments += "text=\(escapedComment)"
        } else {
            arguments += "text=\(state.comment)"
        }
    }
    return "ton://\(escapedAddress)\(arguments)"
}

func walletReceiveScreen(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, address: String) -> ViewController {
    let initialState = WalletReceiveScreenState(amount: "", comment: "", focusItemTag: nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((WalletReceiveScreenState) -> WalletReceiveScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var selectNextInputItemImpl: ((WalletReceiveScreenEntryTag) -> Void)?
    var dismissInputImpl: (() -> Void)?
    var ensureItemVisibleImpl: ((WalletReceiveScreenEntryTag, Bool) -> Void)?
    var displayQrCodeContextMenuImpl: (() -> Void)?
    
    weak var currentStatusController: ViewController?
    let arguments = WalletReceiveScreenArguments(context: context, updateState: { f in
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
        ensureItemVisibleImpl?(tag, false)
    }, selectNextInputItem: { tag in
        selectNextInputItemImpl?(tag)
    }, dismissInput: {
        dismissInputImpl?()
    }, copyAddress: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let state = stateValue.with { $0 }
        
        let successText: String
        if state.isEmpty {
            UIPasteboard.general.string = address
            successText = "Address copied to clipboard."
        } else {
            UIPasteboard.general.string = invoiceUrl(address: address, state: state)
            successText = "Invoice URL copied to clipboard."
        }
        
        if currentStatusController == nil {
            let statusController = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .genericSuccess(successText, false))
            presentControllerImpl?(statusController, nil)
            currentStatusController = statusController
        }
    }, shareAddressLink: {
        dismissInputImpl?()
        let state = stateValue.with { $0 }
        let url = invoiceUrl(address: address, state: state)
        let controller = ShareController(context: context, subject: .url(url), preferredAction: .default)
        presentControllerImpl?(controller, nil)
    }, openQrCode: {
        dismissInputImpl?()
        let state = stateValue.with { $0 }
        let url = invoiceUrl(address: address, state: state)
        pushImpl?(WalletQrViewScreen(context: context, invoice: url))
    }, displayQrCodeContextMenu: {
        dismissInputImpl?()
        displayQrCodeContextMenuImpl?()
    }, scrollToBottom: {
        ensureItemVisibleImpl?(WalletReceiveScreenEntryTag.comment, true)
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<WalletReceiveScreenEntry>, WalletReceiveScreenEntry.ItemGenerationArguments)) in
        
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        var ensureVisibleItemTag: ItemListItemTag?
        if let focusItemTag = state.focusItemTag {
            ensureVisibleItemTag = focusItemTag
        }
    
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Receive Grams"), leftNavigationButton: ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {}), rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletReceiveScreenEntries(presentationData: presentationData, address: address, state: state), style: .blocks, ensureVisibleItemTag: ensureVisibleItemTag, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletReceiveScreenImpl(context: context, state: signal)
    controller.navigationPresentation = .modal
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
        let url = invoiceUrl(address: address, state: state)
        shareInvoiceQrCode(context: context, invoice: url)
    }
    return controller
}
