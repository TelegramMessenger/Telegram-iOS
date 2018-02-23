import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import PassKit

import TelegramUIPrivateModule

final class BotCheckoutControllerArguments {
    fileprivate let account: Account
    fileprivate let openInfo: (BotCheckoutInfoControllerFocus) -> Void
    fileprivate let openPaymentMethod: () -> Void
    fileprivate let openShippingMethod: () -> Void
    
    fileprivate init(account: Account, openInfo: @escaping (BotCheckoutInfoControllerFocus) -> Void, openPaymentMethod: @escaping () -> Void, openShippingMethod: @escaping () -> Void) {
        self.account = account
        self.openInfo = openInfo
        self.openPaymentMethod = openPaymentMethod
        self.openShippingMethod = openShippingMethod
    }
}

private enum BotCheckoutSection: Int32 {
    case header
    case prices
    case info
}

enum BotCheckoutEntry: ItemListNodeEntry {
    case header(PresentationTheme, TelegramMediaInvoice, String)
    case price(Int, PresentationTheme, String, String, Bool)
    case paymentMethod(PresentationTheme, String, String)
    case shippingInfo(PresentationTheme, String, String)
    case shippingMethod(PresentationTheme, String, String)
    case nameInfo(PresentationTheme, String, String)
    case emailInfo(PresentationTheme, String, String)
    case phoneInfo(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return BotCheckoutSection.header.rawValue
            case .price:
                return BotCheckoutSection.prices.rawValue
            default:
                return BotCheckoutSection.info.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .header:
                return 0
            case let .price(index, _, _, _, _):
                return 1 + Int32(index)
            case .paymentMethod:
                return 10000 + 0
            case .shippingInfo:
                return 10000 + 1
            case .shippingMethod:
                return 10000 + 2
            case .nameInfo:
                return 10000 + 3
            case .emailInfo:
                return 10000 + 4
            case .phoneInfo:
                return 10000 + 5
        }
    }
    
    static func ==(lhs: BotCheckoutEntry, rhs: BotCheckoutEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsInvoice, lhsName):
                if case let .header(rhsTheme, rhsInvoice, rhsName) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if !lhsInvoice.isEqual(rhsInvoice) {
                        return false
                    }
                    if lhsName != rhsName {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .price(lhsIndex, lhsTheme, lhsText, lhsValue, lhsFinal):
                if case let .price(rhsIndex, rhsTheme, rhsText, rhsValue, rhsFinal) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsText != rhsText {
                        return false
                    }
                    if lhsValue != rhsValue {
                        return false
                    }
                    if lhsFinal != rhsFinal {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .paymentMethod(lhsTheme, lhsText, lhsValue):
                if case let .paymentMethod(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .shippingInfo(lhsTheme, lhsText, lhsValue):
                if case let .shippingInfo(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .shippingMethod(lhsTheme, lhsText, lhsValue):
                if case let .shippingMethod(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .nameInfo(lhsTheme, lhsText, lhsValue):
                if case let .nameInfo(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .emailInfo(lhsTheme, lhsText, lhsValue):
                if case let .emailInfo(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .phoneInfo(lhsTheme, lhsText, lhsValue):
                if case let .phoneInfo(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: BotCheckoutEntry, rhs: BotCheckoutEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: BotCheckoutControllerArguments) -> ListViewItem {
        switch self {
            case let .header(theme, invoice, botName):
                return BotCheckoutHeaderItem(account: arguments.account, theme: theme, invoice: invoice, botName: botName, sectionId: self.section)
            case let .price(_, theme, text, value, isFinal):
                return BotCheckoutPriceItem(theme: theme, title: text, label: value, isFinal: isFinal, sectionId: self.section)
            case let .paymentMethod(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openPaymentMethod()
                })
            case let .shippingInfo(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.address)
                })
            case let .shippingMethod(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openShippingMethod()
                })
            case let .nameInfo(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.name)
                })
            case let .emailInfo(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.email)
                })
            case let .phoneInfo(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.phone)
                })
        }
    }
}

private struct BotCheckoutControllerState: Equatable {
    init() {
    }
    
    static func ==(lhs: BotCheckoutControllerState, rhs: BotCheckoutControllerState) -> Bool {
        return true
    }
}

private func botCheckoutControllerEntries(presentationData: PresentationData, state: BotCheckoutControllerState, invoice: TelegramMediaInvoice, paymentForm: BotPaymentForm?, formInfo: BotPaymentRequestedInfo?, validatedFormInfo: BotPaymentValidatedFormInfo?, currentShippingOptionId: String?, currentPaymentMethod: BotCheckoutPaymentMethod?, botPeer: Peer?) -> [BotCheckoutEntry] {
    var entries: [BotCheckoutEntry] = []
    
    var botName = ""
    if let botPeer = botPeer {
        botName = botPeer.displayTitle
    }
    entries.append(.header(presentationData.theme, invoice, botName))
    
    if let paymentForm = paymentForm {
        var totalPrice: Int64 = 0
        
        var index = 0
        for price in paymentForm.invoice.prices {
            entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: paymentForm.invoice.currency), false))
            totalPrice += price.amount
            index += 1
        }
        
        var shippingOptionString: String?
        if let validatedFormInfo = validatedFormInfo, let shippingOptions = validatedFormInfo.shippingOptions {
            shippingOptionString = ""
            if let currentShippingOptionId = currentShippingOptionId {
                for option in shippingOptions {
                    if option.id == currentShippingOptionId {
                        shippingOptionString = option.title
                        
                        for price in option.prices {
                            entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: paymentForm.invoice.currency), false))
                            totalPrice += price.amount
                            index += 1
                        }
                        
                        break
                    }
                }
            }
        }
        
        entries.append(.price(index, presentationData.theme, presentationData.strings.Checkout_TotalAmount, formatCurrencyAmount(totalPrice, currency: paymentForm.invoice.currency), true))
        
        var paymentMethodTitle = ""
        if let currentPaymentMethod = currentPaymentMethod {
            paymentMethodTitle = currentPaymentMethod.title
        }
        entries.append(.paymentMethod(presentationData.theme, presentationData.strings.Checkout_PaymentMethod, paymentMethodTitle))
        if paymentForm.invoice.requestedFields.contains(.shippingAddress) {
            var addressString = ""
            if let address = formInfo?.shippingAddress {
                let components: [String] = [
                    address.city,
                    address.streetLine1,
                    address.streetLine2,
                    address.state
                ]
                for component in components {
                    if !component.isEmpty {
                        if !addressString.isEmpty {
                            addressString.append(", ")
                        }
                        addressString.append(component)
                    }
                }
            }
            entries.append(.shippingInfo(presentationData.theme, presentationData.strings.Checkout_ShippingAddress, addressString))
            
            if let shippingOptionString = shippingOptionString {
                entries.append(.shippingMethod(presentationData.theme, presentationData.strings.Checkout_ShippingMethod, shippingOptionString))
            }
        }
        
        if paymentForm.invoice.requestedFields.contains(.name) {
            entries.append(.nameInfo(presentationData.theme, presentationData.strings.Checkout_Name, formInfo?.name ?? ""))
        }
        
        if paymentForm.invoice.requestedFields.contains(.email) {
            entries.append(.emailInfo(presentationData.theme, presentationData.strings.Checkout_Email, formInfo?.email ?? ""))
        }
        
        if paymentForm.invoice.requestedFields.contains(.phone) {
            entries.append(.phoneInfo(presentationData.theme, presentationData.strings.Checkout_Phone, formInfo?.phone ?? ""))
        }
    }
    
    return entries
}

private let hasApplePaySupport: Bool = PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex])

private func availablePaymentMethods(current: BotCheckoutPaymentMethod?, supportsApplePay: Bool) -> [BotCheckoutPaymentMethod] {
    var methods: [BotCheckoutPaymentMethod] = []
    if hasApplePaySupport {
        methods.append(.applePayStripe)
    }
    if let current = current {
        if !methods.contains(current) {
            methods.append(current)
        }
    }
    return methods
}

final class BotCheckoutControllerNode: ItemListControllerNode<BotCheckoutEntry>, PKPaymentAuthorizationViewControllerDelegate {
    private let account: Account
    private let messageId: MessageId
    private let present: (ViewController, Any?) -> Void
    private let dismissAnimated: () -> Void
    
    private var stateValue = BotCheckoutControllerState()
    private let state = ValuePromise(BotCheckoutControllerState(), ignoreRepeated: true)
    private var arguments: BotCheckoutControllerArguments?
    
    private var presentationData: PresentationData
    
    private let paymentFormAndInfo = Promise<(BotPaymentForm, BotPaymentRequestedInfo, BotPaymentValidatedFormInfo?, String?, BotCheckoutPaymentMethod?)?>(nil)
    private var paymentFormValue: BotPaymentForm?
    private var currentFormInfo: BotPaymentRequestedInfo?
    private var currentValidatedFormInfo: BotPaymentValidatedFormInfo?
    private var currentShippingOptionId: String?
    private var currentPaymentMethod: BotCheckoutPaymentMethod?
    private var formRequestDisposable: Disposable?
    
    private let actionButton: BotCheckoutActionButton
    private let inProgressDimNode: ASDisplayNode
    
    private let payDisposable = MetaDisposable()
    private let paymentAuthDisposable = MetaDisposable()
    private var applePayAuthrorizationCompletion: ((PKPaymentAuthorizationStatus) -> Void)?
    private var applePayController: PKPaymentAuthorizationViewController?
    
    init(navigationBar: NavigationBar, updateNavigationOffset: @escaping (CGFloat) -> Void, account: Account, invoice: TelegramMediaInvoice, messageId: MessageId, present: @escaping (ViewController, Any?) -> Void, dismissAnimated: @escaping () -> Void) {
        self.account = account
        self.messageId = messageId
        self.present = present
        self.dismissAnimated = dismissAnimated
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        var openInfoImpl: ((BotCheckoutInfoControllerFocus) -> Void)?
        var openPaymentMethodImpl: (() -> Void)?
        var openShippingMethodImpl: (() -> Void)?
        
        let arguments = BotCheckoutControllerArguments(account: account, openInfo: { item in
            openInfoImpl?(item)
        }, openPaymentMethod: {
            openPaymentMethodImpl?()
        }, openShippingMethod: {
            openShippingMethodImpl?()
        })
        
        let signal: Signal<(PresentationTheme, (ItemListNodeState<BotCheckoutEntry>, BotCheckoutEntry.ItemGenerationArguments)), NoError> = combineLatest(account.telegramApplicationContext.presentationData, self.state.get(), paymentFormAndInfo.get(), account.postbox.loadedPeerWithId(messageId.peerId))
            |> map { presentationData, state, paymentFormAndInfo, botPeer -> (PresentationTheme, (ItemListNodeState<BotCheckoutEntry>, BotCheckoutEntry.ItemGenerationArguments)) in
                let nodeState = ItemListNodeState(entries: botCheckoutControllerEntries(presentationData: presentationData, state: state, invoice: invoice, paymentForm: paymentFormAndInfo?.0, formInfo: paymentFormAndInfo?.1, validatedFormInfo: paymentFormAndInfo?.2, currentShippingOptionId: paymentFormAndInfo?.3, currentPaymentMethod: paymentFormAndInfo?.4, botPeer: botPeer), style: .plain, focusItemTag: nil, emptyStateItem: nil, animateChanges: false)
                
                return (presentationData.theme, (nodeState, arguments))
            }
        
        self.actionButton = BotCheckoutActionButton(inactiveFillColor: self.presentationData.theme.list.plainBackgroundColor, activeFillColor: self.presentationData.theme.list.itemAccentColor, foregroundColor: self.presentationData.theme.list.plainBackgroundColor)
        self.actionButton.setState(.loading)
        
        self.inProgressDimNode = ASDisplayNode()
        self.inProgressDimNode.alpha = 0.0
        self.inProgressDimNode.isUserInteractionEnabled = false
        self.inProgressDimNode.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        
        super.init(navigationBar: navigationBar, updateNavigationOffset: updateNavigationOffset, state: signal)
        
        self.arguments = arguments
        
        openInfoImpl = { [weak self] focus in
            if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                strongSelf.present(BotCheckoutInfoController(account: account, invoice: paymentFormValue.invoice, messageId: messageId, initialFormInfo: currentFormInfo, focus: focus, formInfoUpdated: { formInfo, validatedInfo in
                    if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue {
                        strongSelf.currentFormInfo = formInfo
                        strongSelf.currentValidatedFormInfo = validatedInfo
                        var updatedCurrentShippingOptionId: String?
                        if let currentShippingOptionId = strongSelf.currentShippingOptionId, let shippingOptions = validatedInfo.shippingOptions {
                            if shippingOptions.contains(where: { $0.id == currentShippingOptionId }) {
                                updatedCurrentShippingOptionId = currentShippingOptionId
                            }
                        }
                        strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, formInfo, validatedInfo, updatedCurrentShippingOptionId, strongSelf.currentPaymentMethod)))
                    }
                }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }
        
        let applyPaymentMethod: (BotCheckoutPaymentMethod) -> Void = { [weak self] method in
            if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                strongSelf.currentPaymentMethod = method
                strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, currentFormInfo, strongSelf.currentValidatedFormInfo, strongSelf.currentShippingOptionId, strongSelf.currentPaymentMethod)))
            }
        }
        
        let openNewCard: () -> Void = { [weak self] in
            if let strongSelf = self, let paymentForm = strongSelf.paymentFormValue {
                if let nativeProvider = paymentForm.nativeProvider, nativeProvider.name == "stripe" {
                    guard let paramsData = nativeProvider.params.data(using: .utf8) else {
                        return
                    }
                    guard let nativeParams = (try? JSONSerialization.jsonObject(with: paramsData)) as? [String: Any] else {
                        return
                    }
                    guard let publishableKey = nativeParams["publishable_key"] as? String else {
                        return
                    }
                    
                    var additionalFields: BotCheckoutNativeCardEntryAdditionalFields = []
                    if let needCardholderName = nativeParams["need_cardholder_name"] as? NSNumber, needCardholderName.boolValue {
                        additionalFields.insert(.cardholderName)
                    }
                    if let needCountry = nativeParams["need_country"] as? NSNumber, needCountry.boolValue {
                        additionalFields.insert(.country)
                    }
                    if let needZip = nativeParams["need_zip"] as? NSNumber, needZip.boolValue {
                        additionalFields.insert(.zipCode)
                    }
                    
                    var dismissImpl: (() -> Void)?
                    
                    let controller = BotCheckoutNativeCardEntryController(account: strongSelf.account, additionalFields: additionalFields, publishableKey: publishableKey, completion: { method in
                        applyPaymentMethod(method)
                        dismissImpl?()
                    })
                    dismissImpl = { [weak controller] in
                        controller?.dismiss()
                    }
                    strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                } else {
                    var dismissImpl: (() -> Void)?
                    let controller = BotCheckoutWebInteractionController(account: account, url: paymentForm.url, intent: .addPaymentMethod({ method in
                        applyPaymentMethod(method)
                        dismissImpl?()
                    }))
                    dismissImpl = { [weak controller] in
                        controller?.dismiss()
                    }
                    strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            }
        }
        
        openPaymentMethodImpl = { [weak self] in
            if let strongSelf = self, let paymentForm = strongSelf.paymentFormValue {
                let supportsApplePay: Bool
                if let nativeProvider = paymentForm.nativeProvider, nativeProvider.name == "stripe" {
                    supportsApplePay = true
                } else {
                    supportsApplePay = false
                }
                let methods = availablePaymentMethods(current: strongSelf.currentPaymentMethod, supportsApplePay: supportsApplePay)
                if methods.isEmpty {
                    openNewCard()
                } else {
                    strongSelf.present(BotCheckoutPaymentMethodSheetController(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, currentMethod: strongSelf.currentPaymentMethod, methods: methods, applyValue: { method in
                        applyPaymentMethod(method)
                    }, newCard: {
                        openNewCard()
                    }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            }
        }
        
        openShippingMethodImpl = { [weak self] in
            if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let shippingOptions = strongSelf.currentValidatedFormInfo?.shippingOptions, !shippingOptions.isEmpty {
                strongSelf.present(BotCheckoutPaymentShippingOptionSheetController(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, currency: paymentFormValue.invoice.currency, options: shippingOptions, currentId: strongSelf.currentShippingOptionId, applyValue: { id in
                    if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                        strongSelf.currentShippingOptionId = id
                        strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, currentFormInfo, strongSelf.currentValidatedFormInfo, strongSelf.currentShippingOptionId, strongSelf.currentPaymentMethod)))
                    }
                }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }
        
        let formAndMaybeValidatedInfo = fetchBotPaymentForm(postbox: account.postbox, network: account.network, messageId: messageId)
            |> mapToSignal { paymentForm -> Signal<(BotPaymentForm, BotPaymentValidatedFormInfo?), BotPaymentFormRequestError> in
                if let current = paymentForm.savedInfo {
                    return validateBotPaymentForm(network: account.network, saveInfo: true, messageId: messageId, formInfo: current)
                        |> mapError { _ -> BotPaymentFormRequestError in
                            return .generic
                        }
                        |> map { result -> (BotPaymentForm, BotPaymentValidatedFormInfo?) in
                            return (paymentForm, result)
                        }
                        |> `catch` { _ -> Signal<(BotPaymentForm, BotPaymentValidatedFormInfo?), BotPaymentFormRequestError> in
                            return .single((paymentForm, nil))
                        }
                } else {
                    return .single((paymentForm, nil))
                }
            }
        
        self.formRequestDisposable = (formAndMaybeValidatedInfo |> deliverOnMainQueue).start(next: { [weak self] form, validatedInfo in
            if let strongSelf = self {
                let savedInfo: BotPaymentRequestedInfo
                if let current = form.savedInfo {
                    savedInfo = current
                } else {
                    savedInfo = BotPaymentRequestedInfo(name: nil, phone: nil, email: nil, shippingAddress: nil)
                }
                strongSelf.paymentFormValue = form
                strongSelf.currentFormInfo = savedInfo
                strongSelf.currentValidatedFormInfo = validatedInfo
                if let savedCredentials = form.savedCredentials {
                    strongSelf.currentPaymentMethod = .savedCredentials(savedCredentials)
                }
                strongSelf.actionButton.isEnabled = true
                strongSelf.paymentFormAndInfo.set(.single((form, savedInfo, validatedInfo, nil, strongSelf.currentPaymentMethod)))
                strongSelf.actionButton.setState(.active(strongSelf.presentationData.strings.CheckoutInfo_Pay))
            }
        }, error: { _ in
            
        })
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        self.actionButton.isEnabled = false
        self.addSubnode(self.actionButton)
        
        self.listNode.supernode?.insertSubnode(self.inProgressDimNode, aboveSubnode: self.listNode)
    }
    
    deinit {
        self.formRequestDisposable?.dispose()
        self.payDisposable.dispose()
        self.paymentAuthDisposable.dispose()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var updatedInsets = layout.intrinsicInsets
        updatedInsets.bottom += BotCheckoutActionButton.diameter + 20.0
        super.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, intrinsicInsets: updatedInsets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, standardInputHeight: layout.standardInputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging), navigationBarHeight: navigationBarHeight, transition: transition)
        
        let actionButtonFrame = CGRect(origin: CGPoint(x: 10.0, y: layout.size.height - 10.0 - BotCheckoutActionButton.diameter), size: CGSize(width: layout.size.width - 20.0, height: BotCheckoutActionButton.diameter))
        transition.updateFrame(node: self.actionButton, frame: actionButtonFrame)
        self.actionButton.updateLayout(size: actionButtonFrame.size, transition: transition)
        
        transition.updateFrame(node: self.inProgressDimNode, frame: self.listNode.frame)
    }
    
    @objc func actionButtonPressed() {
        self.pay()
    }
    
    private func pay(savedCredentialsToken: TemporaryTwoStepPasswordToken? = nil, liabilityNoticeAccepted: Bool = false, receivedCredentials: BotPaymentCredentials? = nil) {
        guard let paymentForm = self.paymentFormValue else {
            return
        }
        
        if !paymentForm.invoice.requestedFields.isEmpty {
            guard let validatedFormInfo = self.currentValidatedFormInfo else {
                if paymentForm.invoice.requestedFields.contains(.shippingAddress) {
                    self.arguments?.openInfo(.address)
                } else if paymentForm.invoice.requestedFields.contains(.name) {
                    self.arguments?.openInfo(.name)
                } else if paymentForm.invoice.requestedFields.contains(.email) {
                    self.arguments?.openInfo(.email)
                } else if paymentForm.invoice.requestedFields.contains(.phone) {
                    self.arguments?.openInfo(.phone)
                }
                return
            }
            
            if let _ = validatedFormInfo.shippingOptions {
                if self.currentShippingOptionId == nil {
                    self.arguments?.openShippingMethod()
                    return
                }
            }
        }
        
        guard let paymentMethod = self.currentPaymentMethod else {
            self.arguments?.openPaymentMethod()
            return
        }
        
        let credentials: BotPaymentCredentials
        if let receivedCredentials = receivedCredentials {
            credentials = receivedCredentials
        } else {
            switch paymentMethod {
                case let .savedCredentials(savedCredentials):
                    switch savedCredentials {
                        case let .card(id, title):
                            if let savedCredentialsToken = savedCredentialsToken {
                                credentials = .saved(id: id, tempPassword: savedCredentialsToken.token)
                            } else {
                                let _ = (cachedTwoStepPasswordToken(postbox: self.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] token in
                                    if let strongSelf = self {
                                        let timestamp = strongSelf.account.network.getApproximateRemoteTimestamp()
                                        if let token = token, token.validUntilDate > timestamp - 1 * 60 {
                                            if token.requiresBiometrics {
                                                let _ = (LocalAuth.auth(reason: strongSelf.presentationData.strings.Checkout_PayWithTouchId) |> deliverOnMainQueue).start(next: { value in
                                                    if let strongSelf = self {
                                                        if value {
                                                            strongSelf.pay(savedCredentialsToken: token)
                                                        } else {
                                                            strongSelf.requestPassword(cardTitle: title)
                                                        }
                                                    }
                                                })
                                            } else {
                                                strongSelf.pay(savedCredentialsToken: token)
                                            }
                                        } else {
                                            strongSelf.requestPassword(cardTitle: title)
                                        }
                                    }
                                })
                                return
                            }
                    }
                case let .webToken(_, data, saveOnServer):
                    credentials = .generic(data: data, saveOnServer: saveOnServer)
                case .applePayStripe:
                    let botPeerId = self.messageId.peerId
                    let _ = (self.account.postbox.modify({ modifier -> Peer? in
                        return modifier.getPeer(botPeerId)
                    }) |> deliverOnMainQueue).start(next: { [weak self] botPeer in
                        if let strongSelf = self, let botPeer = botPeer {
                            let request = PKPaymentRequest()
                            
                            request.merchantIdentifier = "merchant.ph.telegra.Telegraph"
                            request.supportedNetworks = [.visa, .amex, .masterCard]
                            request.merchantCapabilities = [.capability3DS]
                            request.countryCode = "US"
                            request.currencyCode = paymentForm.invoice.currency.uppercased()
                            
                            var items: [PKPaymentSummaryItem] = []
                            
                            var totalAmount: Int64 = 0
                            for price in paymentForm.invoice.prices {
                                totalAmount += price.amount
                                
                                let amount = NSDecimalNumber(value: Double(price.amount) * 0.01)
                                items.append(PKPaymentSummaryItem(label: price.label, amount: amount))
                            }
                            
                            if let shippingOptions = strongSelf.currentValidatedFormInfo?.shippingOptions, let shippingOptionId = strongSelf.currentShippingOptionId {
                                if let shippingOptionIndex = shippingOptions.index(where: { $0.id == shippingOptionId }) {
                                    for price in shippingOptions[shippingOptionIndex].prices {
                                        totalAmount += price.amount
                                        
                                        let amount = NSDecimalNumber(value: Double(price.amount) * 0.01)
                                        items.append(PKPaymentSummaryItem(label: price.label, amount: amount))
                                    }
                                }
                            }
                            
                            let amount = NSDecimalNumber(value: Double(totalAmount) * 0.01)
                            items.append(PKPaymentSummaryItem(label: botPeer.displayTitle, amount: amount))
                            
                            request.paymentSummaryItems = items
                            
                            if let controller = PKPaymentAuthorizationViewController(paymentRequest: request) {
                                controller.delegate = strongSelf
                                if let window = strongSelf.view.window {
                                    strongSelf.applePayController = controller
                                    window.rootViewController?.present(controller, animated: true)
                                }
                            }
                        }
                    })
                    return
            }
        }
        
        if !liabilityNoticeAccepted {
            let _ = (combineLatest(ApplicationSpecificNotice.getBotPaymentLiability(postbox: self.account.postbox, peerId: self.messageId.peerId), self.account.postbox.loadedPeerWithId(self.messageId.peerId), self.account.postbox.loadedPeerWithId(PeerId(namespace: Namespaces.Peer.CloudUser, id: paymentForm.providerId))) |> deliverOnMainQueue).start(next: { [weak self] value, botPeer, providerPeer in
                if let strongSelf = self {
                    if value {
                        strongSelf.pay(savedCredentialsToken: savedCredentialsToken, liabilityNoticeAccepted: true)
                    } else {
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: strongSelf.presentationData.strings.Checkout_LiabilityAlertTitle, text: strongSelf.presentationData.strings.Checkout_LiabilityAlert(botPeer.displayTitle, providerPeer.displayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            if let strongSelf = self {
                                let _ = ApplicationSpecificNotice.setBotPaymentLiability(postbox: strongSelf.account.postbox, peerId: strongSelf.messageId.peerId).start()
                                strongSelf.pay(savedCredentialsToken: savedCredentialsToken, liabilityNoticeAccepted: true)
                            }
                        })]), nil)
                    }
                }
            })
        } else {
            self.inProgressDimNode.isUserInteractionEnabled = true
            self.inProgressDimNode.alpha = 1.0
            self.actionButton.isEnabled = false
            self.payDisposable.set((sendBotPaymentForm(account: self.account, messageId: self.messageId, validatedInfoId: self.currentValidatedFormInfo?.id, shippingOptionId: self.currentShippingOptionId, credentials: credentials) |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    strongSelf.inProgressDimNode.isUserInteractionEnabled = false
                    strongSelf.inProgressDimNode.alpha = 0.0
                    strongSelf.actionButton.isEnabled = true
                    if let applePayAuthrorizationCompletion = strongSelf.applePayAuthrorizationCompletion {
                        strongSelf.applePayAuthrorizationCompletion = nil
                        applePayAuthrorizationCompletion(.success)
                    }
                    if let applePayController = strongSelf.applePayController {
                        strongSelf.applePayController = nil
                        applePayController.presentingViewController?.dismiss(animated: true, completion: nil)
                    }
                    
                    switch result {
                        case .done:
                            strongSelf.dismissAnimated()
                        case let .externalVerificationRequired(url):
                            var dismissImpl: (() -> Void)?
                            let controller = BotCheckoutWebInteractionController(account: strongSelf.account, url: url, intent: .externalVerification({ _ in
                                dismissImpl?()
                            }))
                            dismissImpl = { [weak controller] in
                                controller?.dismiss()
                                self?.dismissAnimated()
                            }
                            strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                    }
                }
            }, error: { [weak self] error in
                if let strongSelf = self {
                    strongSelf.inProgressDimNode.isUserInteractionEnabled = false
                    strongSelf.inProgressDimNode.alpha = 0.0
                    strongSelf.actionButton.isEnabled = true
                    if let applePayAuthrorizationCompletion = strongSelf.applePayAuthrorizationCompletion {
                        strongSelf.applePayAuthrorizationCompletion = nil
                        applePayAuthrorizationCompletion(.failure)
                    }
                    if let applePayController = strongSelf.applePayController {
                        strongSelf.applePayController = nil
                        applePayController.presentingViewController?.dismiss(animated: true, completion: nil)
                    }
                    
                    let text: String
                    switch error {
                        case .precheckoutFailed:
                            text = strongSelf.presentationData.strings.Checkout_ErrorPrecheckoutFailed
                        case .paymentFailed:
                            text = strongSelf.presentationData.strings.Checkout_ErrorPaymentFailed
                        case .alreadyPaid:
                            text = strongSelf.presentationData.strings.Checkout_ErrorInvoiceAlreadyPaid
                        case .generic:
                            text = strongSelf.presentationData.strings.Checkout_ErrorGeneric
                    }
                    
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                }
            }))
        }
    }
    
    private func requestPassword(cardTitle: String) {
        let period: Int32
        let requiresBiometrics: Bool
        if LocalAuth.biometricAuthentication != nil {
            period = 5 * 60 * 60
            requiresBiometrics = true
        } else {
            period = 1 * 60 * 60
            requiresBiometrics = false
        }
        self.present(botCheckoutPasswordEntryController(account: self.account, strings: self.presentationData.strings, cartTitle: cardTitle, period: period, requiresBiometrics: requiresBiometrics, completion: { [weak self] token in
            if let strongSelf = self {
                let durationString = timeIntervalString(strings: strongSelf.presentationData.strings, value: period)
                
                let alertText: String
                if requiresBiometrics {
                    alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeoutAndTouchId(durationString).0
                } else {
                    alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeout(durationString).0
                }
                
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: alertText, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_No, action: {
                        if let strongSelf = self {
                            strongSelf.pay(savedCredentialsToken: token)
                        }
                    }),
                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                        if let strongSelf = self {
                            let _ = cacheTwoStepPasswordToken(postbox: strongSelf.account.postbox, token: token).start()
                            strongSelf.pay(savedCredentialsToken: token)
                        }
                    })
                ]), nil)
            }
        }), nil)
    }
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        guard let paymentForm = self.paymentFormValue else {
            completion(.failure)
            return
        }
        guard let nativeProvider = paymentForm.nativeProvider, nativeProvider.name == "stripe" else {
            completion(.failure)
            return
        }
        guard let paramsData = nativeProvider.params.data(using: .utf8) else {
            return
        }
        guard let nativeParams = (try? JSONSerialization.jsonObject(with: paramsData)) as? [String: Any] else {
            return
        }
        guard let publishableKey = nativeParams["publishable_key"] as? String else {
            return
        }
        
        let signal: Signal<STPToken, Error> = Signal { subscriber in
            let configuration = STPPaymentConfiguration.shared().copy() as! STPPaymentConfiguration
            configuration.smsAutofillDisabled = true
            configuration.publishableKey = publishableKey
            configuration.appleMerchantIdentifier = "merchant.ph.telegra.Telegraph"
            
            let apiClient = STPAPIClient(configuration: configuration)
            
            apiClient.createToken(with: payment, completion: { token, error in
                if let token = token {
                    subscriber.putNext(token)
                    subscriber.putCompletion()
                } else if let error = error {
                    subscriber.putError(error)
                }
            })
            
            return ActionDisposable {
            }
        }
        
        self.paymentAuthDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] token in
            if let strongSelf = self {
                strongSelf.applePayAuthrorizationCompletion = completion
                strongSelf.pay(liabilityNoticeAccepted: true, receivedCredentials: .generic(data: "{\"type\": \"card\", \"id\": \"\(token.tokenId)\"}", saveOnServer: false))
            } else {
                completion(.failure)
            }
        }, error: { _ in
            completion(.failure)
        }))
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.presentingViewController?.dismiss(animated: true, completion: nil)
        self.paymentAuthDisposable.set(nil)
    }
}
