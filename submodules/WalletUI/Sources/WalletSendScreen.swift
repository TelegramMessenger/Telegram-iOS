import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AlertUI
import OverlayStatusController
import WalletUrl
import WalletCore
import Markdown

private let balanceIcon = UIImage(bundleImageName: "Wallet/TransactionGem")?.precomposed()

private final class WalletSendScreenArguments {
    let context: WalletContext
    let updateState: ((WalletSendScreenState) -> WalletSendScreenState) -> Void
    let updateText: (WalletSendScreenEntryTag, String) -> Void
    let selectInputItem: (WalletSendScreenEntryTag) -> Void
    let scrollToBottom: () -> Void
    let dismissInput: () -> Void
    let openQrScanner: () -> Void
    let proceed: () -> Void
    
    init(context: WalletContext, updateState: @escaping ((WalletSendScreenState) -> WalletSendScreenState) -> Void, updateText: @escaping (WalletSendScreenEntryTag, String) -> Void, selectInputItem: @escaping (WalletSendScreenEntryTag) -> Void, scrollToBottom: @escaping () -> Void, dismissInput: @escaping () -> Void, openQrScanner: @escaping () -> Void, proceed: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.updateText = updateText
        self.selectInputItem = selectInputItem
        self.scrollToBottom = scrollToBottom
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
    case amount(WalletTheme, String)
    case balance(WalletTheme, String, String, Bool)
    case addressHeader(WalletTheme, String)
    case address(WalletTheme, String, String)
    case addressInfo(WalletTheme, String)
    case commentHeader(WalletTheme, String)
    case comment(WalletTheme, String, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .amount, .balance:
            return WalletSendScreenSection.amount.rawValue
        case .addressHeader, .address, .addressInfo:
            return WalletSendScreenSection.address.rawValue
        case .commentHeader, .comment:
            return WalletSendScreenSection.comment.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .amount:
            return 0
        case .balance:
            return 1
        case .addressHeader:
            return 2
        case .address:
            return 3
        case .addressInfo:
            return 4
        case .commentHeader:
            return 5
        case .comment:
            return 6
        }
    }
    
    static func ==(lhs: WalletSendScreenEntry, rhs: WalletSendScreenEntry) -> Bool {
        switch lhs {
        case let .amount(lhsTheme, lhsAmount):
            if case let .amount(rhsTheme, rhsAmount) = rhs, lhsTheme === rhsTheme, lhsAmount == rhsAmount {
                return true
            } else {
                return false
            }
        case let .balance(lhsTheme, lhsTitle, lhsBalance, lhsInsufficient):
            if case let .balance(rhsTheme, rhsTitle, rhsBalance, rhsInsufficient) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsBalance == rhsBalance, lhsInsufficient == rhsInsufficient {
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
        case let .commentHeader(lhsTheme, lhsText):
            if case let .commentHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .comment(lhsTheme, lhsPlaceholder, lhsText, lhsSendEnabled):
            if case let .comment(rhsTheme, rhsPlaceholder, rhsText, rhsSendEnabled) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsText == rhsText, lhsSendEnabled == rhsSendEnabled {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: WalletSendScreenEntry, rhs: WalletSendScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: Any) -> ListViewItem {
        let arguments = arguments as! WalletSendScreenArguments
        switch self {
        case let .amount(theme, text):
            return WalletAmountItem(theme: theme, amount: text, sectionId: self.section, textUpdated: { text in
                let text = formatAmountText(text, decimalSeparator: arguments.context.presentationData.dateTimeFormat.decimalSeparator)
                arguments.updateText(WalletSendScreenEntryTag.amount, text)
            }, shouldUpdateText: { text in
                return isValidAmount(text)
            }, processPaste: { pastedText in
                if isValidAmount(pastedText) {
                    let presentationData = arguments.context.presentationData
                    return normalizedStringForGramsString(pastedText, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                } else {
                    return text
                }
            }, updatedFocus: { focus in
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
            }, tag: WalletSendScreenEntryTag.amount)
        case let .balance(theme, title, balance, insufficient):
            return WalletBalanceItem(theme: theme, title: title, value: balance, insufficient: insufficient, sectionId: self.section)
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
                            state.amount = formatBalanceText(amount, decimalSeparator: arguments.context.presentationData.dateTimeFormat.decimalSeparator)
                        } else if state.amount.isEmpty {
                            focusItemTag = WalletSendScreenEntryTag.amount
                        }
                        if let comment = parsedUrl.comment {
                            state.comment = comment
                        } else if state.comment.isEmpty && focusItemTag == nil {
                            focusItemTag = WalletSendScreenEntryTag.comment
                        }
                        return state
                    }
                    if let focusItemTag = focusItemTag {
                        arguments.selectInputItem(focusItemTag)
                    } else {
                        arguments.dismissInput()
                    }
                } else if isValidAddress(text) {
                    arguments.updateText(WalletSendScreenEntryTag.address, text)
                    if isValidAddress(text, exactLength: true) {
                        var focusItemTag: WalletSendScreenEntryTag? = .comment
                        arguments.updateState { state in
                            if state.amount.isEmpty {
                                focusItemTag = .amount
                            } else if state.comment.isEmpty  {
                                focusItemTag = .comment
                            }
                            return state
                        }
                        if let focusItemTag = focusItemTag {
                            arguments.selectInputItem(focusItemTag)
                        } else {
                            arguments.dismissInput()
                        }
                    }
                }
            }, tag: WalletSendScreenEntryTag.address, action: {
                var focusItemTag: WalletSendScreenEntryTag?
                arguments.updateState { state in
                    if state.amount.isEmpty {
                        focusItemTag = .amount
                    } else if state.comment.isEmpty {
                        focusItemTag = .comment
                    }
                    return state
                }
                if let focusItemTag = focusItemTag {
                    arguments.selectInputItem(focusItemTag)
                } else {
                    arguments.dismissInput()
                }
            }, inlineAction: ItemListMultilineInputInlineAction(icon: UIImage(bundleImageName: "Wallet/QrIcon")!, action: {
                arguments.openQrScanner()
            }))
        case let .addressInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
        case let .commentHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .comment(theme, placeholder, value, sendEnabled):
            return ItemListMultilineInputItem(theme: theme, text: value, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: walletTextLimit, display: true, mode: .bytes), sectionId: self.section, style: .blocks, returnKeyType: .send, textUpdated: { text in
                arguments.updateText(WalletSendScreenEntryTag.comment, text)
            }, updatedFocus: { focus in
                if focus {
                    arguments.scrollToBottom()
                }
            }, tag: WalletSendScreenEntryTag.comment, action: {
                if sendEnabled {
                    arguments.proceed()
                }
            })
        }
    }
}

private struct WalletSendScreenState: Equatable {
    var address: String
    var amount: String
    var comment: String
}

private func walletSendScreenEntries(presentationData: WalletPresentationData, balance: Int64?, state: WalletSendScreenState, sendEnabled: Bool) -> [WalletSendScreenEntry] {
    if balance == nil {
        return []
    }
    var entries: [WalletSendScreenEntry] = []

    let amount = amountValue(state.amount)
    let balance = max(0, balance ?? 0)
    entries.append(.amount(presentationData.theme, state.amount))
    entries.append(.balance(presentationData.theme, presentationData.strings.Wallet_Send_Balance("").0, formatBalanceText(balance, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), balance == 0 || (amount > 0 && balance < amount)))
    
    entries.append(.addressHeader(presentationData.theme, presentationData.strings.Wallet_Send_AddressHeader))
    entries.append(.address(presentationData.theme, presentationData.strings.Wallet_Send_AddressText, state.address))
    entries.append(.addressInfo(presentationData.theme, presentationData.strings.Wallet_Send_AddressInfo))
        
    entries.append(.commentHeader(presentationData.theme, presentationData.strings.Wallet_Receive_CommentHeader))
    entries.append(.comment(presentationData.theme, presentationData.strings.Wallet_Receive_CommentInfo, state.comment, sendEnabled))
    
    return entries
}

protocol WalletSendScreen {
    
}

private final class WalletSendScreenImpl: ItemListController, WalletSendScreen {
    
}

public func walletSendScreen(context: WalletContext, randomId: Int64, walletInfo: WalletInfo, address: String? = nil, amount: Int64? = nil, comment: String? = nil) -> ViewController {    
    let presentationData = context.presentationData
   
    let initialState = WalletSendScreenState(address: address ?? "", amount: amount.flatMap { formatBalanceText($0, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) } ?? "", comment: comment ?? "")
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((WalletSendScreenState) -> WalletSendScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let serverSaltValue = Promise<Data?>()
    serverSaltValue.set(context.getServerSalt()
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Data?, NoError> in
        return .single(nil)
    })
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var popImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var selectInputItemImpl: ((WalletSendScreenEntryTag) -> Void)?
    var ensureItemVisibleImpl: ((WalletSendScreenEntryTag, Bool) -> Void)?
    
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
        ensureItemVisibleImpl?(tag, false)
    }, selectInputItem: { tag in
        selectInputItemImpl?(tag)
    }, scrollToBottom: {
        ensureItemVisibleImpl?(WalletSendScreenEntryTag.comment, true)
    }, dismissInput: {
        dismissInputImpl?()
    }, openQrScanner: {
        dismissInputImpl?()
        
        context.authorizeAccessToCamera(completion: {
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
                        selectInputItemImpl?(WalletSendScreenEntryTag.amount)
                    } else if updatedState.comment.isEmpty {
                        selectInputItemImpl?(WalletSendScreenEntryTag.comment)
                    }
                }
            }))
        })
    }, proceed: {
        let proceed: () -> Void = {
            let presentationData = context.presentationData
            let state = stateValue.with { $0 }
            let amount = amountValue(state.amount)
            guard amount > 0 else {
                return
            }
            
            let commentData = state.comment.data(using: .utf8)
            let formattedAddress = String(state.address[state.address.startIndex..<state.address.index(state.address.startIndex, offsetBy: walletAddressLength / 2)] + " \n " + state.address[state.address.index(state.address.startIndex, offsetBy: walletAddressLength / 2)..<state.address.endIndex])
            let destinationAddress = state.address
            
            updateState { state in
                var state = state
                state.amount = formatBalanceText(amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                return state
            }
            
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            presentControllerImpl?(controller, nil)
            
            let _ = (verifySendGramsRequestAndEstimateFees(tonInstance: context.tonInstance, walletInfo: walletInfo, toAddress: destinationAddress, amount: amount, comment: commentData ?? Data(), encryptComment: true, timeout: 0)
            |> deliverOnMainQueue).start(next: { [weak controller] verificationResult in
                controller?.dismiss()
                
                let presentationData = context.presentationData
                
                let title = NSAttributedString(string: presentationData.strings.Wallet_Send_Confirmation, font: Font.semibold(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
                
                let feeAmount = verificationResult.fees.inFwdFee + verificationResult.fees.storageFee + verificationResult.fees.gasFee + verificationResult.fees.fwdFee
                
                let (text, ranges) = presentationData.strings.Wallet_Send_ConfirmationText(formatBalanceText(amount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator), formattedAddress, "\(formatBalanceText(feeAmount, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))")
                let bodyAttributes = MarkdownAttributeSet(font: Font.regular(13.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
                let boldAttributes = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
                let attributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }), textAlignment: .center))
                for (index, range) in ranges {
                    if index == 1 {
                        attributedText.addAttribute(.font, value: Font.monospace(14.0), range: range)
                    }
                }
                
                if verificationResult.canNotEncryptComment {
                    //TODO:localize
                    attributedText.append(NSAttributedString(string: "\n\nThe destination wallet is not initialized. The comment will be sent unencrypted.", font: Font.regular(13.0), textColor: presentationData.theme.list.itemDestructiveColor))
                }
                
                var dismissAlertImpl: ((Bool) -> Void)?
                let theme = context.presentationData.theme
                let controller = richTextAlertController(alertContext: AlertControllerContext(theme: theme.alert, themeSignal: .single(theme.alert)), title: title, text: attributedText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Wallet_Navigation_Cancel, action: {
                    dismissAlertImpl?(true)
                }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Wallet_Send_ConfirmationConfirm, action: {
                    dismissAlertImpl?(false)
                    dismissInputImpl?()
                    
                    let presentationData = context.presentationData
                    let progressSignal = Signal<Never, NoError> { subscriber in
                        let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: nil))
                        presentControllerImpl?(controller, nil)
                        return ActionDisposable { [weak controller] in
                            Queue.mainQueue().async() {
                                controller?.dismiss()
                            }
                        }
                    }
                    |> runOn(Queue.mainQueue())
                    |> delay(0.15, queue: Queue.mainQueue())
                    let progressDisposable = progressSignal.start()
                    
                    var serverSaltSignal = serverSaltValue.get()
                    |> take(1)
                    
                    serverSaltSignal = serverSaltSignal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                    }
                    
                    let _ = (serverSaltSignal
                    |> deliverOnMainQueue).start(next: { serverSalt in
                        if let serverSalt = serverSalt {
                            if let commentData = state.comment.data(using: .utf8) {
                                pushImpl?(WalletSplashScreen(context: context, mode: .sending(WalletSplashModeSending(walletInfo: walletInfo, address: state.address, amount: amount, comment: commentData, encryptComment: !verificationResult.canNotEncryptComment, randomId: randomId, serverSalt: serverSalt)), walletCreatedPreloadState: nil))
                            }
                        }
                    })
                })], allowInputInset: false, dismissAutomatically: false)
                presentInGlobalOverlayImpl?(controller, nil)
                
                dismissAlertImpl = { [weak controller] animated in
                    if animated {
                        controller?.dismissAnimated()
                    } else {
                        controller?.dismiss()
                    }
                }
            }, error: { [weak controller] error in
                controller?.dismiss()
                
                let presentationData = context.presentationData
                
                var title: String?
                let text: String
                switch error {
                case .generic:
                    text = presentationData.strings.Wallet_UnknownError
                case .network:
                    title = presentationData.strings.Wallet_Send_NetworkErrorTitle
                    text = presentationData.strings.Wallet_Send_NetworkErrorText
                case .notEnoughFunds:
                    title = presentationData.strings.Wallet_Send_ErrorNotEnoughFundsTitle
                    text = presentationData.strings.Wallet_Send_ErrorNotEnoughFundsText
                case .messageTooLong:
                    text = presentationData.strings.Wallet_UnknownError
                case .invalidAddress:
                    text = presentationData.strings.Wallet_Send_ErrorInvalidAddress
                case .secretDecryptionFailed:
                    text = presentationData.strings.Wallet_Send_ErrorDecryptionFailed
                case .destinationIsNotInitialized:
                    text = presentationData.strings.Wallet_UnknownError
                }
                let theme = presentationData.theme
                let controller = textAlertController(alertContext: AlertControllerContext(theme: theme.alert, themeSignal: .single(theme.alert)), title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Wallet_Alert_OK, action: {
                })])
                presentControllerImpl?(controller, nil)
            })
        }
        
        let _ = (walletAddress(walletInfo: walletInfo, tonInstance: context.tonInstance)
        |> deliverOnMainQueue).start(next: { walletAddress in
            let presentationData = context.presentationData
            let state = stateValue.with { $0 }
            let destinationAddress = state.address
            
            if destinationAddress == walletAddress {
                presentControllerImpl?(standardTextAlertController(theme: presentationData.theme.alert, title: presentationData.strings.Wallet_Send_OwnAddressAlertTitle, text: presentationData.strings.Wallet_Send_OwnAddressAlertText, actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Wallet_Alert_Cancel, action: {
                    }),
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Wallet_Send_OwnAddressAlertProceed, action: {
                        proceed()
                    })
                ]), nil)
            } else {
                proceed()
            }
        })
    })
    
    let walletState: Signal<WalletState?, NoError> = getCombinedWalletState(storage: context.storage, subject: .wallet(walletInfo), tonInstance: context.tonInstance, onlyCached: true)
    |> map { combinedState -> WalletState? in
        var state: WalletState?
        switch combinedState {
        case let .cached(combinedState):
            state = combinedState?.walletState
        case let .updated(combinedState):
            state = combinedState.walletState
        }
        return state
    }
    |> `catch` { _ -> Signal<WalletState?, NoError> in
        return .single(nil)
        |> then(
            getCombinedWalletState(storage: context.storage, subject: .wallet(walletInfo), tonInstance: context.tonInstance, onlyCached: false)
            |> map { combinedState -> WalletState? in
                var state: WalletState?
                switch combinedState {
                case let .cached(combinedState):
                    state = combinedState?.walletState
                case let .updated(combinedState):
                    state = combinedState.walletState
                }
                return state
            }
            |> `catch` { _ -> Signal<WalletState?, NoError> in
                return .single(nil)
            }
        )
    }

    var focusItemTag: ItemListItemTag?
    if amount == nil {
        focusItemTag = WalletSendScreenEntryTag.amount
    } else if address == nil {
        focusItemTag = WalletSendScreenEntryTag.address
    }
    
    let signal = combineLatest(queue: .mainQueue(), .single(context.presentationData), walletState, statePromise.get())
    |> map { presentationData, walletState, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Navigation_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let rightNavigationButton: ItemListNavigationButton?
        
        let amount = amountValue(state.amount)
        var sendEnabled = false
        var emptyItem: ItemListControllerEmptyStateItem?
        if let walletState = walletState {
            let textLength: Int = state.comment.data(using: .utf8, allowLossyConversion: true)?.count ?? 0
            sendEnabled = isValidAddress(state.address, exactLength: true) && amount > 0 && amount <= walletState.effectiveAvailableBalance && textLength <= walletTextLimit

            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Send_Send), style: .bold, enabled: sendEnabled, action: {
                arguments.proceed()
            })
        } else {
            rightNavigationButton = nil
            emptyItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }

        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_Send_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Wallet_Navigation_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletSendScreenEntries(presentationData: presentationData, balance: walletState?.effectiveAvailableBalance, state: state, sendEnabled: sendEnabled), style: .blocks, focusItemTag: focusItemTag, emptyStateItem: emptyItem, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletSendScreenImpl(theme: context.presentationData.theme, strings: context.presentationData.strings, updatedPresentationData: .single((context.presentationData.theme, context.presentationData.strings)), state: signal, tabBarItem: nil, hasNavigationBarSeparator: false)
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
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        let _ = controller?.dismiss()
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    selectInputItemImpl = { [weak controller] nextTag in
        guard let controller = controller else {
            return
        }
        var resultItemNode: ItemListItemFocusableNode?
        let _ = controller.frameForItemNode({ itemNode in
            if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag, let focusableItemNode = itemNode as? ItemListItemFocusableNode {
                if nextTag.isEqual(to: tag) {
                    resultItemNode = focusableItemNode
                    return true
                }
            }
            return false
        })
        if let resultItemNode = resultItemNode {
            resultItemNode.focus()
        }
    }
    ensureItemVisibleImpl = { [weak controller] targetTag, animated in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
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
