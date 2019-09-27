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
import DeviceAccess
import TelegramStringFormatting
import UrlHandling

private let balanceIcon = UIImage(bundleImageName: "Wallet/TransactionGem")?.precomposed()

private final class WalletSendScreenArguments {
    let context: AccountContext
    let updateState: ((WalletSendScreenState) -> WalletSendScreenState) -> Void
    let updateText: (WalletSendScreenEntryTag, String) -> Void
    let selectNextInputItem: (WalletSendScreenEntryTag) -> Void
    let dismissInput: () -> Void
    let openQrScanner: () -> Void
    let proceed: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((WalletSendScreenState) -> WalletSendScreenState) -> Void, updateText: @escaping (WalletSendScreenEntryTag, String) -> Void, selectNextInputItem: @escaping (WalletSendScreenEntryTag) -> Void, dismissInput: @escaping () -> Void, openQrScanner: @escaping () -> Void, proceed: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.updateText = updateText
        self.selectNextInputItem = selectNextInputItem
        self.dismissInput = dismissInput
        self.openQrScanner = openQrScanner
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

private enum WalletSendScreenEntry: ItemListNodeEntry {
    case addressHeader(PresentationTheme, String)
    case address(PresentationTheme, String, String)
    case addressInfo(PresentationTheme, String)
    case amountHeader(PresentationTheme, String, String?, Bool)
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
        case let .amount(lhsTheme, lhsStrings, lhsPlaceholder, lhsAmount):
            if case let .amount(rhsTheme, rhsStrings, rhsPlaceholder, rhsAmount) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsPlaceholder == rhsPlaceholder, lhsAmount == rhsAmount {
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
            return ItemListMultilineInputItem(theme: theme, text: address, placeholder: placeholder, maxLength: .init(value: walletAddressLength, display: false), sectionId: self.section, style: .blocks, capitalization: false, autocorrection: false, returnKeyType: .next, minimalHeight: 68.0, textUpdated: { text in
                arguments.updateText(WalletSendScreenEntryTag.address, text.replacingOccurrences(of: "\n", with: ""))
            }, shouldUpdateText: { text in
                return isValidAddress(text)
            }, processPaste: { text in
                if let url = URL(string: text), let parsedUrl = parseWalletUrl(url) {
                    var focusItemTag: WalletSendScreenEntryTag?
                    arguments.updateState { state in
                        var state = state
                        state.address = parsedUrl.address
                        if let amount = parsedUrl.amount {
                            state.amount = formatBalanceText(amount, decimalSeparator: arguments.context.sharedContext.currentPresentationData.with { $0 }.dateTimeFormat.decimalSeparator)
                        } else if state.amount.isEmpty {
                            focusItemTag = WalletSendScreenEntryTag.address
                        }
                        if let comment = parsedUrl.comment {
                            state.comment = comment
                        } else if state.comment.isEmpty && focusItemTag == nil {
                            focusItemTag = WalletSendScreenEntryTag.amount
                        }
                        return state
                    }
                    if let focusItemTag = focusItemTag {
                        arguments.selectNextInputItem(focusItemTag)
                    } else {
                        arguments.dismissInput()
                    }
                } else if isValidAddress(text) {
                    arguments.updateText(WalletSendScreenEntryTag.address, text)
                    if isValidAddress(text, exactLength: true, url: false) {
                        arguments.selectNextInputItem(WalletSendScreenEntryTag.address)
                    }
                } else if isValidAddress(text, url: true) {
                    arguments.updateText(WalletSendScreenEntryTag.address, convertedAddress(text, url: false))
                    if isValidAddress(text, exactLength: true, url: true) {
                        arguments.selectNextInputItem(WalletSendScreenEntryTag.address)
                    }
                }
            }, tag: WalletSendScreenEntryTag.address, action: {
                arguments.selectNextInputItem(WalletSendScreenEntryTag.address)
            }, inlineAction: ItemListMultilineInputInlineAction(icon: UIImage(bundleImageName: "Wallet/QrIcon")!, action: {
                arguments.openQrScanner()
            }))
        case let .addressInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
        case let .amountHeader(theme, text, balance, insufficient):
            return ItemListSectionHeaderItem(theme: theme, text: text, activityIndicator: balance == nil ? .right : .none, accessoryText: balance.flatMap { ItemListSectionHeaderAccessoryText(value: $0, color: insufficient ? .destructive : .generic, icon: balanceIcon) }, sectionId: self.section)
        case let .amount(theme, strings, placeholder, text):
            return ItemListSingleLineInputItem(theme: theme, strings: strings, title: NSAttributedString(string: ""), text: text, placeholder: placeholder, type: .decimal, returnKeyType: .next, tag: WalletSendScreenEntryTag.amount, sectionId: self.section, textUpdated: { text in
                let text = formatAmountText(text, decimalSeparator: arguments.context.sharedContext.currentPresentationData.with { $0 }.dateTimeFormat.decimalSeparator)
                arguments.updateText(WalletSendScreenEntryTag.amount, text)
            }, shouldUpdateText: { text in
                return isValidAmount(text)
            }, processPaste: { pastedText in
                if isValidAmount(pastedText) {
                    let presentationData = arguments.context.sharedContext.currentPresentationData.with { $0 }
                    return normalizedStringForGramsString(pastedText, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
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
            return ItemListMultilineInputItem(theme: theme, text: value, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: 124, display: true), sectionId: self.section, style: .blocks, returnKeyType: .send, textUpdated: { text in
                arguments.updateText(WalletSendScreenEntryTag.comment, text)
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

    entries.append(.addressHeader(presentationData.theme, presentationData.strings.Wallet_Send_AddressHeader))
    entries.append(.address(presentationData.theme, presentationData.strings.Wallet_Send_AddressText, state.address))
    entries.append(.addressInfo(presentationData.theme, presentationData.strings.Wallet_Send_AddressInfo))
    
    let amount = amountValue(state.amount)
    entries.append(.amountHeader(presentationData.theme, presentationData.strings.Wallet_Receive_AmountHeader, balance.flatMap { presentationData.strings.Wallet_Send_Balance(formatBalanceText($0, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)).0 }, amount > 0 && (balance ?? 0) < amount))
    entries.append(.amount(presentationData.theme, presentationData.strings, presentationData.strings.Wallet_Send_AmountText, state.amount ?? ""))
    
    entries.append(.commentHeader(presentationData.theme, presentationData.strings.Wallet_Receive_CommentHeader))
    entries.append(.comment(presentationData.theme, presentationData.strings.Wallet_Receive_CommentInfo, state.comment))
    return entries
}

protocol WalletSendScreen {
    
}

private final class WalletSendScreenImpl: ItemListController<WalletSendScreenEntry>, WalletSendScreen {
    
}

public func walletSendScreen(context: AccountContext, tonContext: TonContext, randomId: Int64, walletInfo: WalletInfo, address: String? = nil, amount: Int64? = nil, comment: String? = nil) -> ViewController {    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
   
    let initialState = WalletSendScreenState(address: address ?? "", amount: amount.flatMap { formatBalanceText($0, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) } ?? "", comment: comment ?? "")
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((WalletSendScreenState) -> WalletSendScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var popImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var selectNextInputItemImpl: ((WalletSendScreenEntryTag) -> Void)?
    var ensureItemVisibleImpl: ((WalletSendScreenEntryTag) -> Void)?
    
    let arguments = WalletSendScreenArguments(context: context, updateState: { f in
        updateState(f)
    }, updateText: { tag, value in
        updateState { state in
            var state = state
            switch tag {
            case .address:
                state.address = value
            case .amount:
                state.amount = value
            case .comment:
                state.comment = value
            }
            return state
        }
        ensureItemVisibleImpl?(tag)
    }, selectNextInputItem: { tag in
        selectNextInputItemImpl?(tag)
    }, dismissInput: {
        dismissInputImpl?()
    }, openQrScanner: {
        dismissInputImpl?()
        
        DeviceAccess.authorizeAccess(to: .camera, presentationData: presentationData, present: { c, a in
            presentControllerImpl?(c, a)
        }, openSettings: {
            context.sharedContext.applicationBindings.openSettings()
        }, { granted in
            guard granted else {
                return
            }
            pushImpl?(WalletQrScanScreen(context: context, completion: { parsedUrl in
                var updatedState: WalletSendScreenState?
                updateState { state in
                    var state = state
                    state.address = parsedUrl.address
                    if let amount = parsedUrl.amount {
                        state.amount = formatBalanceText(amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                    }
                    if let comment = parsedUrl.comment {
                        state.comment = comment
                    }
                    updatedState = state
                    return state
                }
                popImpl?()
                if let updatedState = updatedState {
                    if updatedState.amount.isEmpty {
                        selectNextInputItemImpl?(WalletSendScreenEntryTag.address)
                    } else if updatedState.comment.isEmpty {
                        selectNextInputItemImpl?(WalletSendScreenEntryTag.amount)
                    }
                }
            }))
        })
    }, proceed: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let state = stateValue.with { $0 }
        let amount = amountValue(state.amount)
        
        updateState { state in
            var state = state
            state.amount = formatBalanceText(amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
            return state
        }
        
        let title = NSAttributedString(string: presentationData.strings.Wallet_Send_Confirmation, font: Font.semibold(17.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        
        let address = state.address[state.address.startIndex..<state.address.index(state.address.startIndex, offsetBy: walletAddressLength / 2)] + " \n " + state.address[state.address.index(state.address.startIndex, offsetBy: walletAddressLength / 2)..<state.address.endIndex]
        
        let text = presentationData.strings.Wallet_Send_ConfirmationText(formatBalanceText(amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), String(address)).0
        let bodyAttributes = MarkdownAttributeSet(font: Font.regular(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        let boldAttributes = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: presentationData.theme.actionSheet.primaryTextColor)
        let attributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }), textAlignment: .center))
        attributedText.addAttribute(.font, value: Font.monospace(14.0), range: NSMakeRange(attributedText.string.count - address.count - 1, address.count))
        
        var dismissAlertImpl: ((Bool) -> Void)?
        let controller = richTextAlertController(context: context, title: title, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
            dismissAlertImpl?(true)
        }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Wallet_Send_ConfirmationConfirm, action: {
            dismissAlertImpl?(false)
            pushImpl?(WalletSplashScreen(context: context, tonContext: tonContext, mode: .sending(walletInfo, state.address, amount, state.comment, randomId), walletCreatedPreloadState: nil))
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
    
    let walletState: Signal<WalletState?, NoError> = getCombinedWalletState(postbox: context.account.postbox, walletInfo: walletInfo, tonInstance: tonContext.instance)
    |> map { combinedState in
        var state: WalletState?
        switch combinedState {
        case let .cached(combinedState):
            state = combinedState?.walletState
        case let .updated(combinedState):
            state = combinedState.walletState
        }
        return state
    }
    |> `catch` { _ in
        return .single(nil)
    }

    var focusItemTag: ItemListItemTag?
    if address == nil {
        focusItemTag = WalletSendScreenEntryTag.address
    } else if amount == nil {
        focusItemTag = WalletSendScreenEntryTag.amount
    }
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, walletState, statePromise.get())
    |> map { presentationData, balance, state -> (ItemListControllerState, (ItemListNodeState<WalletSendScreenEntry>, WalletSendScreenEntry.ItemGenerationArguments)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let amount = amountValue(state.amount)
        var sendEnabled = false
        if let balance = balance {
            sendEnabled = isValidAddress(state.address, exactLength: true) && amount > 0 && amount <= balance.balance && state.comment.count <= 124
        }
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Send_Send), style: .bold, enabled: sendEnabled, action: {
            arguments.proceed()
        })
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_Send_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletSendScreenEntries(presentationData: presentationData, balance: balance?.balance, state: state), style: .blocks, focusItemTag: focusItemTag, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletSendScreenImpl(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    presentInGlobalOverlayImpl = { [weak controller] c, a in
        controller?.presentInGlobalOverlay(c, with: a)
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    popImpl = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        let _ = controller?.dismiss()
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
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
    ensureItemVisibleImpl = { [weak controller] targetTag in
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
                controller.ensureItemNodeVisible(resultItemNode)
            }
        })
    }
    return controller
}
