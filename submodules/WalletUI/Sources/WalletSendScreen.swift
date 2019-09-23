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
import AlertUI
import TextFormat

private let walletAddressLength: Int = 48

private final class WalletSendScreenArguments {
    let context: AccountContext
    let updateState: ((WalletSendScreenState) -> WalletSendScreenState) -> Void
    let selectNextInputItem: (WalletSendScreenEntryTag) -> Void
    let proceed: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((WalletSendScreenState) -> WalletSendScreenState) -> Void, selectNextInputItem: @escaping (WalletSendScreenEntryTag) -> Void, proceed: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.selectNextInputItem = selectNextInputItem
        self.proceed = proceed
    }
}

private enum WalletSendScreenSection: Int32 {
    case address
    case amount
    case comment
}

private enum WalletSendScreenEntryTag: ItemListItemTag {
    case address
    case amount
    case comment
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? WalletSendScreenEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private let invalidAddressCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=").inverted
private func isValidAddress(_ address: String, exactLength: Bool = false) -> Bool {
    if address.count > walletAddressLength || address.rangeOfCharacter(from: invalidAddressCharacters) != nil {
        return false
    }
    if exactLength && address.count != walletAddressLength {
        return false
    }
    return true
}

private let invalidAmountCharacters = CharacterSet(charactersIn: "01234567890.,").inverted
private func isValidAmount(_ amount: String) -> Bool {
    if amount.rangeOfCharacter(from: invalidAmountCharacters) != nil {
        return false
    }
    var hasDecimalSeparator = false
    var hasLeadingZero = false
    var index = 0
    for c in amount {
        if c == "." || c == "," {
            if !hasDecimalSeparator {
                hasDecimalSeparator = true
            } else {
                return false
            }
        }
        index += 1
    }
    
    var decimalIndex: String.Index?
    if let index = amount.firstIndex(of: ".") {
        decimalIndex = index
    } else if let index = amount.firstIndex(of: ",") {
        decimalIndex = index
    }
    
    if let decimalIndex = decimalIndex, amount.distance(from: decimalIndex, to: amount.endIndex) > 4 {
        return false
    }
    
    return true
}

private func stringForGramsAmount(_ amount: Int64, decimalSeparator: String = ".") -> String {
    if amount < 1000 {
        return "0\(decimalSeparator)\(String(amount).rightJustified(width: 3, pad: "0"))"
    } else {
        var string = String(amount)
        string.insert(contentsOf: decimalSeparator, at: string.index(string.endIndex, offsetBy: -3))
        return string
    }
}

private func amountValue(_ string: String) -> Int64 {
    return Int64((Double(string) ?? 0.0) * 1000.0)
}

private func normalizedStringForGramsString(_ string: String, decimalSeparator: String = ".") -> String {
    return stringForGramsAmount(amountValue(string), decimalSeparator: decimalSeparator)
}

private enum WalletSendScreenEntry: ItemListNodeEntry {
    case addressHeader(PresentationTheme, String)
    case address(PresentationTheme, String, String)
    case addressInfo(PresentationTheme, String)
    
    case amountHeader(PresentationTheme, String, String, Bool)
    case amount(PresentationTheme, PresentationStrings, String, String)
    
    case commentHeader(PresentationTheme, String)
    case comment(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
        case .addressHeader, .address, .addressInfo:
            return WalletSendScreenSection.address.rawValue
        case .amountHeader, .amount:
            return WalletSendScreenSection.amount.rawValue
        case .commentHeader, .comment:
            return WalletSendScreenSection.comment.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .addressHeader:
            return 0
        case .address:
            return 1
        case .addressInfo:
            return 2
        case .amountHeader:
            return 3
        case .amount:
            return 4
        case .commentHeader:
            return 5
        case .comment:
            return 6
        }
    }
    
    static func ==(lhs: WalletSendScreenEntry, rhs: WalletSendScreenEntry) -> Bool {
        switch lhs {
        case let .addressHeader(lhsTheme, lhsText):
            if case let .addressHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .address(lhsTheme, lhsPlaceholder, lhsAddress):
            if case let .address(rhsTheme, rhsPlaceholder, rhsAddress) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsAddress == rhsAddress {
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
        case let .amountHeader(lhsTheme, lhsText, lhsBalance, lhsInsufficient):
            if case let .amountHeader(rhsTheme, rhsText, rhsBalance, rhsInsufficient) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsBalance == rhsBalance, lhsInsufficient == rhsInsufficient {
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
    
    static func <(lhs: WalletSendScreenEntry, rhs: WalletSendScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: WalletSendScreenArguments) -> ListViewItem {
        switch self {
        case let .addressHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .address(theme, placeholder, address):
            return ItemListMultilineInputItem(theme: theme, text: address, placeholder: "Enter wallet address...", maxLength: .init(value: walletAddressLength, display: false), sectionId: self.section, style: .blocks, capitalization: false, autocorrection: false, returnKeyType: .next, minimalHeight: 68.0, textUpdated: { address in
                arguments.updateState { state in
                    var state = state
                    state.address = address
                    return state
                }
            }, shouldUpdateText: { text in
                return isValidAddress(text)
            }, tag: WalletSendScreenEntryTag.address, action: {
                arguments.selectNextInputItem(WalletSendScreenEntryTag.address)
            })
        case let .addressInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
        case let .amountHeader(theme, text, balance, insufficient):
            return ItemListSectionHeaderItem(theme: theme, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: balance, color: insufficient ? .destructive : .generic), sectionId: self.section)
        case let .amount(theme, strings, placeholder, text):
            return ItemListSingleLineInputItem(theme: theme, strings: strings, title: NSAttributedString(string: ""), text: text, placeholder: placeholder, type: .decimal, returnKeyType: .next, tag: WalletSendScreenEntryTag.amount, sectionId: self.section, textUpdated: { text in
                arguments.updateState { state in
                    var state = state
                    state.amount = text
                    return state
                }
            }, shouldUpdateText: { text in
                return isValidAmount(text)
            }, processPaste: { pastedText in
                if isValidAmount(pastedText) {
                    return normalizedStringForGramsString(pastedText)
                } else {
                    return text
                }
            }, updatedFocus: { focus in
                if !focus {
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
                arguments.selectNextInputItem(WalletSendScreenEntryTag.amount)
            })
        case let .commentHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .comment(theme, placeholder, value):
            return ItemListMultilineInputItem(theme: theme, text: value, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, returnKeyType: .send, textUpdated: { comment in
                arguments.updateState { state in
                    var state = state
                    state.comment = comment
                    return state
                }
            }, tag: WalletSendScreenEntryTag.comment, action: {
                arguments.proceed()
            })
        }
    }
}

private struct WalletSendScreenState: Equatable {
    var address: String
    var amount: String
    var comment: String
}

private func walletSendScreenEntries(presentationData: PresentationData, balance: Int64?, state: WalletSendScreenState) -> [WalletSendScreenEntry] {
    var entries: [WalletSendScreenEntry] = []
    entries.append(.addressHeader(presentationData.theme, "RECIPIENT WALLET ADDRESS"))
    entries.append(.address(presentationData.theme, "Enter wallet address...", state.address))
    entries.append(.addressInfo(presentationData.theme, "Copy the 48-letter address of the recipient here or ask them to send you a ton:// link."))
    
    let amount = amountValue(state.amount)
    entries.append(.amountHeader(presentationData.theme, "AMOUNT", "BALANCE: \(stringForGramsAmount(balance ?? 0, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))💎", amount > 0 && (balance ?? 0) < amount))
    entries.append(.amount(presentationData.theme, presentationData.strings, "Grams to send", state.amount ?? ""))
    
    entries.append(.commentHeader(presentationData.theme, "COMMENT"))
    entries.append(.comment(presentationData.theme, "Optional description of the payment", state.comment))
    return entries
}

protocol WalletSendScreen {
    
}

private final class WalletSendScreenImpl: ItemListController<WalletSendScreenEntry>, WalletSendScreen {
    
}

func walletSendScreen(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, address: String? = nil, amount: Int64? = nil) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let initialState = WalletSendScreenState(address: address ?? "", amount: amount.flatMap { stringForGramsAmount($0, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) } ?? "", comment: "")
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((WalletSendScreenState) -> WalletSendScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var selectNextInputItemImpl: ((WalletSendScreenEntryTag) -> Void)?
    
    let arguments = WalletSendScreenArguments(context: context, updateState: { f in
        updateState(f)
    }, selectNextInputItem: { tag in
        selectNextInputItemImpl?(tag)
    }, proceed: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let state = stateValue.with { $0 }
        let amount = amountValue(state.amount)
        
        updateState { state in
            var state = state
            state.amount = stringForGramsAmount(amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
            return state
        }
        
        let title = NSAttributedString(string: "Confirmation", font: Font.semibold(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
        let address = state.address[state.address.startIndex..<state.address.index(state.address.startIndex, offsetBy: walletAddressLength / 2)] + " \n " + state.address[state.address.index(state.address.startIndex, offsetBy: walletAddressLength / 2)..<state.address.endIndex]
        
        let text = "Do you want to send **\(stringForGramsAmount(amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))** Grams to\n\(address)?"
        let bodyAttributes = MarkdownAttributeSet(font: Font.regular(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        let boldAttributes = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        let attributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }), textAlignment: .center))
        attributedText.addAttribute(.font, value: Font.monospace(14.0), range: NSMakeRange(attributedText.string.count - address.count - 1, address.count))
        
        var dismissAlertImpl: ((Bool) -> Void)?
        let controller = richTextAlertController(context: context, title: title, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
            dismissAlertImpl?(true)
        }), TextAlertAction(type: .defaultAction, title: "Confirm", action: {
            dismissAlertImpl?(false)
            pushImpl?(WalletPasscodeScreen(context: context, tonContext: tonContext, mode: .authorizeTransfer(walletInfo, state.address, amount, state.comment)))
        })], dismissAutomatically: false)
        presentInGlobalOverlayImpl?(controller, nil)
        
        dismissAlertImpl = { [weak controller] animated in
            if animated {
                controller?.dismissAnimated()
            } else {
                controller?.dismiss()
            }
        }
    })
    
    let balance: Signal<WalletState?, NoError> = Signal.single(WalletState(balance: 2500, lastTransactionId: nil))
    
    var focusItemTag: ItemListItemTag?
    if address == nil {
        focusItemTag = WalletSendScreenEntryTag.address
    } else if amount == nil {
        focusItemTag = WalletSendScreenEntryTag.amount
    }
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, balance, statePromise.get())
    |> map { presentationData, balance, state -> (ItemListControllerState, (ItemListNodeState<WalletSendScreenEntry>, WalletSendScreenEntry.ItemGenerationArguments)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let amount = amountValue(state.amount)
        var sendEnabled = false
        if let balance = balance {
            sendEnabled = isValidAddress(state.address, exactLength: true) && amount > 0 && amount <= balance.balance
        }
        let rightNavigationButton = ItemListNavigationButton(content: .text("Send"), style: .bold, enabled: sendEnabled, action: {
            arguments.proceed()
        })
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Send Grams"), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletSendScreenEntries(presentationData: presentationData, balance: balance?.balance, state: state), style: .blocks, focusItemTag: focusItemTag, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletSendScreenImpl(context: context, state: signal)
    controller.navigationPresentation = .modalInLargeLayout
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    presentInGlobalOverlayImpl = { [weak controller] c, a in
        controller?.presentInGlobalOverlay(c, with: a)
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
    return controller
}
