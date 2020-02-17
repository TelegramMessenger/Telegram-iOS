import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import PassKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices
import TelegramStringFormatting
import PasswordSetupUI
import Stripe
import LocalAuth

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
                    if !lhsInvoice.isEqual(to: rhsInvoice) {
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BotCheckoutControllerArguments
        switch self {
            case let .header(theme, invoice, botName):
                return BotCheckoutHeaderItem(account: arguments.account, theme: theme, invoice: invoice, botName: botName, sectionId: self.section)
            case let .price(_, theme, text, value, isFinal):
                return BotCheckoutPriceItem(theme: theme, title: text, label: value, isFinal: isFinal, sectionId: self.section)
            case let .paymentMethod(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openPaymentMethod()
                })
            case let .shippingInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.address(.street1))
                })
            case let .shippingMethod(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openShippingMethod()
                })
            case let .nameInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.name)
                })
            case let .emailInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.email)
                })
            case let .phoneInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
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

private func currentTotalPrice(paymentForm: BotPaymentForm?, validatedFormInfo: BotPaymentValidatedFormInfo?, currentShippingOptionId: String?) -> Int64 {
    guard let paymentForm = paymentForm else {
        return 0
    }
    
    var totalPrice: Int64 = 0
    
    var index = 0
    for price in paymentForm.invoice.prices {
        totalPrice += price.amount
        index += 1
    }
    
    if let validatedFormInfo = validatedFormInfo, let shippingOptions = validatedFormInfo.shippingOptions {
        if let currentShippingOptionId = currentShippingOptionId {
            for option in shippingOptions {
                if option.id == currentShippingOptionId {
                    for price in option.prices {
                        totalPrice += price.amount
                    }
                    break
                }
            }
        }
    }
    
    return totalPrice
}

private func botCheckoutControllerEntries(presentationData: PresentationData, state: BotCheckoutControllerState, invoice: TelegramMediaInvoice, paymentForm: BotPaymentForm?, formInfo: BotPaymentRequestedInfo?, validatedFormInfo: BotPaymentValidatedFormInfo?, currentShippingOptionId: String?, currentPaymentMethod: BotCheckoutPaymentMethod?, botPeer: Peer?) -> [BotCheckoutEntry] {
    var entries: [BotCheckoutEntry] = []
    
    var botName = ""
    if let botPeer = botPeer {
        botName = botPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
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

private func formSupportApplePay(_ paymentForm: BotPaymentForm) -> Bool {
    if !hasApplePaySupport {
        return false
    }
    guard let nativeProvider = paymentForm.nativeProvider else {
        return false
    }
    let applePayProviders = Set<String>([
        "stripe",
        "sberbank",
        "yandex",
        "privatbank",
        "tranzzo"
    ])
    if !applePayProviders.contains(nativeProvider.name) {
        return false
    }
    guard let nativeParamsData = nativeProvider.params.data(using: .utf8) else {
        return false
    }
    guard let nativeParams = (try? JSONSerialization.jsonObject(with: nativeParamsData, options: [])) as? [String: Any] else {
        return false
    }
    
    var merchantId: String?
    if nativeProvider.name == "stripe" {
        merchantId = "merchant.ph.telegra.Telegraph"
    } else if let paramsId = nativeParams["apple_pay_merchant_id"] as? String {
        merchantId = paramsId
    }
    
    return merchantId != nil
}

private func availablePaymentMethods(form: BotPaymentForm, current: BotCheckoutPaymentMethod?) -> [BotCheckoutPaymentMethod] {
    var methods: [BotCheckoutPaymentMethod] = []
    if formSupportApplePay(form) && hasApplePaySupport {
        methods.append(.applePay)
    }
    if let current = current {
        if !methods.contains(current) {
            methods.append(current)
        }
    }
    return methods
}

final class BotCheckoutControllerNode: ItemListControllerNode, PKPaymentAuthorizationViewControllerDelegate {
    private let context: AccountContext
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
    
    init(controller: ItemListController?, navigationBar: NavigationBar, updateNavigationOffset: @escaping (CGFloat) -> Void, context: AccountContext, invoice: TelegramMediaInvoice, messageId: MessageId, present: @escaping (ViewController, Any?) -> Void, dismissAnimated: @escaping () -> Void) {
        self.context = context
        self.messageId = messageId
        self.present = present
        self.dismissAnimated = dismissAnimated
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var openInfoImpl: ((BotCheckoutInfoControllerFocus) -> Void)?
        var openPaymentMethodImpl: (() -> Void)?
        var openShippingMethodImpl: (() -> Void)?
        
        let arguments = BotCheckoutControllerArguments(account: context.account, openInfo: { item in
            openInfoImpl?(item)
        }, openPaymentMethod: {
            openPaymentMethodImpl?()
        }, openShippingMethod: {
            openShippingMethodImpl?()
        })
        
        let signal: Signal<(ItemListPresentationData, (ItemListNodeState, Any)), NoError> = combineLatest(context.sharedContext.presentationData, self.state.get(), paymentFormAndInfo.get(), context.account.postbox.loadedPeerWithId(messageId.peerId))
            |> map { presentationData, state, paymentFormAndInfo, botPeer -> (ItemListPresentationData, (ItemListNodeState, Any)) in
            let nodeState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: botCheckoutControllerEntries(presentationData: presentationData, state: state, invoice: invoice, paymentForm: paymentFormAndInfo?.0, formInfo: paymentFormAndInfo?.1, validatedFormInfo: paymentFormAndInfo?.2, currentShippingOptionId: paymentFormAndInfo?.3, currentPaymentMethod: paymentFormAndInfo?.4, botPeer: botPeer), style: .plain, focusItemTag: nil, emptyStateItem: nil, animateChanges: false)
            
            return (ItemListPresentationData(presentationData), (nodeState, arguments))
        }
        
        self.actionButton = BotCheckoutActionButton(inactiveFillColor: self.presentationData.theme.list.plainBackgroundColor, activeFillColor: self.presentationData.theme.list.itemAccentColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor)
        self.actionButton.setState(.loading)
        
        self.inProgressDimNode = ASDisplayNode()
        self.inProgressDimNode.alpha = 0.0
        self.inProgressDimNode.isUserInteractionEnabled = false
        self.inProgressDimNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor.withAlphaComponent(0.5)
        
        super.init(controller: controller, navigationBar: navigationBar, updateNavigationOffset: updateNavigationOffset, state: signal)
        
        self.arguments = arguments
        
        openInfoImpl = { [weak self] focus in
            if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                strongSelf.present(BotCheckoutInfoController(context: context, invoice: paymentFormValue.invoice, messageId: messageId, initialFormInfo: currentFormInfo, focus: focus, formInfoUpdated: { formInfo, validatedInfo in
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
                        
                        strongSelf.updateActionButton()
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
                    let canSave = paymentForm.canSaveCredentials || paymentForm.passwordMissing
                    let controller = BotCheckoutNativeCardEntryController(context: strongSelf.context, additionalFields: additionalFields, publishableKey: publishableKey, completion: { method in
                        guard let strongSelf = self else {
                            return
                        }
                        if canSave && paymentForm.passwordMissing {
                            switch method {
                                case let .webToken(webToken) where webToken.saveOnServer:
                                    var text = strongSelf.presentationData.strings.Checkout_NewCard_SaveInfoEnableHelp
                                    text = text.replacingOccurrences(of: "[", with: "")
                                    text = text.replacingOccurrences(of: "]", with: "")
                                    present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_NotNow, action: {
                                        var updatedToken = webToken
                                        updatedToken.saveOnServer = false
                                        applyPaymentMethod(.webToken(updatedToken))
                                    }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        if paymentForm.passwordMissing {
                                            var updatedToken = webToken
                                            updatedToken.saveOnServer = false
                                            applyPaymentMethod(.webToken(updatedToken))
                                            
                                            let controller = SetupTwoStepVerificationController(context: strongSelf.context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                                                if shouldDismiss {
                                                    controller.dismiss()
                                                }
                                                switch update {
                                                    case .noPassword, .awaitingEmailConfirmation:
                                                        break
                                                    case .passwordSet:
                                                        var updatedToken = webToken
                                                        updatedToken.saveOnServer = true
                                                        applyPaymentMethod(.webToken(updatedToken))
                                                }
                                            })
                                            strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                        } else {
                                            var updatedToken = webToken
                                            updatedToken.saveOnServer = true
                                            applyPaymentMethod(.webToken(updatedToken))
                                        }
                                    })]), nil)
                                default:
                                    break
                            }
                        } else {
                            applyPaymentMethod(method)
                        }
                        dismissImpl?()
                    })
                    dismissImpl = { [weak controller] in
                        controller?.dismiss()
                    }
                    strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                } else {
                    var dismissImpl: (() -> Void)?
                    let controller = BotCheckoutWebInteractionController(context: context, url: paymentForm.url, intent: .addPaymentMethod({ [weak self] token in
                        dismissImpl?()
                        
                        guard let strongSelf = self else {
                            return
                        }
                        let canSave = paymentForm.canSaveCredentials || paymentForm.passwordMissing
                        let allowSaving = paymentForm.canSaveCredentials && !paymentForm.passwordMissing
                        if canSave {
                            present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Checkout_NewCard_SaveInfoHelp, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_NotNow, action: {
                                var updatedToken = token
                                updatedToken.saveOnServer = false
                                applyPaymentMethod(.webToken(updatedToken))
                            }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                                guard let strongSelf = self else {
                                    return
                                }
                                if paymentForm.passwordMissing {
                                    var updatedToken = token
                                    updatedToken.saveOnServer = false
                                    applyPaymentMethod(.webToken(updatedToken))
                                    
                                    let controller = SetupTwoStepVerificationController(context: strongSelf.context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                                        if shouldDismiss {
                                            controller.dismiss()
                                        }
                                        switch update {
                                            case .noPassword, .awaitingEmailConfirmation:
                                                break
                                            case .passwordSet:
                                                var updatedToken = token
                                                updatedToken.saveOnServer = true
                                                applyPaymentMethod(.webToken(updatedToken))
                                        }
                                    })
                                    strongSelf.present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                                } else {
                                    var updatedToken = token
                                    updatedToken.saveOnServer = true
                                    applyPaymentMethod(.webToken(updatedToken))
                                }
                            })]), nil)
                        } else {
                            var updatedToken = token
                            updatedToken.saveOnServer = false
                            applyPaymentMethod(.webToken(updatedToken))
                            
                            if allowSaving {
                                present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Checkout_NewCard_SaveInfoEnableHelp.replacingOccurrences(of: "]", with: "").replacingOccurrences(of: "[", with: ""), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                                })]), nil)
                            }
                        }
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
                let methods = availablePaymentMethods(form: paymentForm, current: strongSelf.currentPaymentMethod)
                if methods.isEmpty {
                    openNewCard()
                } else {
                    strongSelf.present(BotCheckoutPaymentMethodSheetController(context: strongSelf.context, currentMethod: strongSelf.currentPaymentMethod, methods: methods, applyValue: { method in
                        applyPaymentMethod(method)
                    }, newCard: {
                        openNewCard()
                    }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            }
        }
        
        openShippingMethodImpl = { [weak self] in
            if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let shippingOptions = strongSelf.currentValidatedFormInfo?.shippingOptions, !shippingOptions.isEmpty {
                strongSelf.present(BotCheckoutPaymentShippingOptionSheetController(context: strongSelf.context, currency: paymentFormValue.invoice.currency, options: shippingOptions, currentId: strongSelf.currentShippingOptionId, applyValue: { id in
                    if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                        strongSelf.currentShippingOptionId = id
                        strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, currentFormInfo, strongSelf.currentValidatedFormInfo, strongSelf.currentShippingOptionId, strongSelf.currentPaymentMethod)))
                        
                        strongSelf.updateActionButton()
                    }
                }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }
        
        let formAndMaybeValidatedInfo = fetchBotPaymentForm(postbox: context.account.postbox, network: context.account.network, messageId: messageId)
            |> mapToSignal { paymentForm -> Signal<(BotPaymentForm, BotPaymentValidatedFormInfo?), BotPaymentFormRequestError> in
                if let current = paymentForm.savedInfo {
                    return validateBotPaymentForm(network: context.account.network, saveInfo: true, messageId: messageId, formInfo: current)
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
                
                strongSelf.updateActionButton()
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
    
    private func updateActionButton() {
        let totalAmount = currentTotalPrice(paymentForm: self.paymentFormValue, validatedFormInfo: self.currentValidatedFormInfo, currentShippingOptionId: self.currentShippingOptionId)
        let payString: String
        if let paymentForm = self.paymentFormValue, totalAmount > 0 {
            payString = self.presentationData.strings.Checkout_PayPrice(formatCurrencyAmount(totalAmount, currency: paymentForm.invoice.currency)).0
        } else {
            payString = self.presentationData.strings.CheckoutInfo_Pay
        }
        if self.actionButton.isEnabled {
            self.actionButton.setState(.active(payString))
        } else {
            self.actionButton.setState(.loading)
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, additionalInsets: UIEdgeInsets) {
        var updatedInsets = layout.intrinsicInsets
        updatedInsets.bottom += BotCheckoutActionButton.diameter + 20.0
        super.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: updatedInsets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationBarHeight, transition: transition, additionalInsets: additionalInsets)
        
        let actionButtonFrame = CGRect(origin: CGPoint(x: 10.0, y: layout.size.height - 10.0 - BotCheckoutActionButton.diameter - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width - 20.0, height: BotCheckoutActionButton.diameter))
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
                    self.arguments?.openInfo(.address(.street1))
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
                                let _ = (cachedTwoStepPasswordToken(postbox: self.context.account.postbox)
                                |> deliverOnMainQueue).start(next: { [weak self] token in
                                    if let strongSelf = self {
                                        let timestamp = strongSelf.context.account.network.getApproximateRemoteTimestamp()
                                        if let token = token, token.validUntilDate > timestamp - 1 * 60 {
                                            if token.requiresBiometrics {
                                                let reasonText: String
                                                if let biometricAuthentication = LocalAuth.biometricAuthentication, case .faceId = biometricAuthentication {
                                                    reasonText = strongSelf.presentationData.strings.Checkout_PayWithFaceId
                                                } else {
                                                    reasonText = strongSelf.presentationData.strings.Checkout_PayWithTouchId
                                                }
                                                let _ = (LocalAuth.auth(reason: reasonText) |> deliverOnMainQueue).start(next: { value, _ in
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
                case let .webToken(token):
                    credentials = .generic(data: token.data, saveOnServer: token.saveOnServer)
                case .applePay:
                    guard let paymentForm = self.paymentFormValue, let nativeProvider = paymentForm.nativeProvider else {
                        return
                    }
                    guard let nativeParamsData = nativeProvider.params.data(using: .utf8) else {
                        return
                    }
                    guard let nativeParams = (try? JSONSerialization.jsonObject(with: nativeParamsData, options: [])) as? [String: Any] else {
                        return
                    }
                    
                    let merchantId: String
                    if nativeProvider.name == "stripe" {
                        merchantId = "merchant.ph.telegra.Telegraph"
                    } else if let paramsId = nativeParams["apple_pay_merchant_id"] as? String {
                        merchantId = paramsId
                    } else {
                        return
                    }
                    
                    let botPeerId = self.messageId.peerId
                    let _ = (self.context.account.postbox.transaction({ transaction -> Peer? in
                        return transaction.getPeer(botPeerId)
                    }) |> deliverOnMainQueue).start(next: { [weak self] botPeer in
                        if let strongSelf = self, let botPeer = botPeer {
                            let request = PKPaymentRequest()
                            
                            request.merchantIdentifier = merchantId
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
                                if let shippingOptionIndex = shippingOptions.firstIndex(where: { $0.id == shippingOptionId }) {
                                    for price in shippingOptions[shippingOptionIndex].prices {
                                        totalAmount += price.amount
                                        
                                        let amount = NSDecimalNumber(value: Double(price.amount) * 0.01)
                                        items.append(PKPaymentSummaryItem(label: price.label, amount: amount))
                                    }
                                }
                            }
                            
                            let amount = NSDecimalNumber(value: Double(totalAmount) * 0.01)
                            items.append(PKPaymentSummaryItem(label: botPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), amount: amount))
                            
                            request.paymentSummaryItems = items
                            
                            if let controller = PKPaymentAuthorizationViewController(paymentRequest: request) {
                                controller.delegate = strongSelf
                                if let window = strongSelf.view.window {
                                    strongSelf.applePayController = controller
                                    controller.popoverPresentationController?.sourceView = window
                                    controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                                    window.rootViewController?.present(controller, animated: true)
                                }
                            }
                        }
                    })
                    return
            }
        }
        
        if !liabilityNoticeAccepted {
            let messageId = self.messageId
            let botPeer: Signal<Peer?, NoError> = self.context.account.postbox.transaction { transaction -> Peer? in
                if let message = transaction.getMessage(messageId) {
                    return message.author
                }
                return nil
            }
            let _ = (combineLatest(ApplicationSpecificNotice.getBotPaymentLiability(accountManager: self.context.sharedContext.accountManager, peerId: self.messageId.peerId), botPeer, self.context.account.postbox.loadedPeerWithId(paymentForm.providerId))
            |> deliverOnMainQueue).start(next: { [weak self] value, botPeer, providerPeer in
                if let strongSelf = self, let botPeer = botPeer {
                    if value {
                        strongSelf.pay(savedCredentialsToken: savedCredentialsToken, liabilityNoticeAccepted: true)
                    } else {
                        strongSelf.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Checkout_LiabilityAlertTitle, text: strongSelf.presentationData.strings.Checkout_LiabilityAlert(botPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), providerPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder)).0, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: { }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            if let strongSelf = self {
                                let _ = ApplicationSpecificNotice.setBotPaymentLiability(accountManager: strongSelf.context.sharedContext.accountManager, peerId: strongSelf.messageId.peerId).start()
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
            self.updateActionButton()
            self.payDisposable.set((sendBotPaymentForm(account: self.context.account, messageId: self.messageId, validatedInfoId: self.currentValidatedFormInfo?.id, shippingOptionId: self.currentShippingOptionId, credentials: credentials) |> deliverOnMainQueue).start(next: { [weak self] result in
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
                            strongSelf.updateActionButton()
                            var dismissImpl: (() -> Void)?
                            let controller = BotCheckoutWebInteractionController(context: strongSelf.context, url: url, intent: .externalVerification({ _ in
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
                    strongSelf.updateActionButton()
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
                    
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
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
        self.present(botCheckoutPasswordEntryController(context: self.context, strings: self.presentationData.strings, cartTitle: cardTitle, period: period, requiresBiometrics: requiresBiometrics, completion: { [weak self] token in
            if let strongSelf = self {
                let durationString = timeIntervalString(strings: strongSelf.presentationData.strings, value: period)
                
                let alertText: String
                if requiresBiometrics {
                    if let biometricAuthentication = LocalAuth.biometricAuthentication, case .faceId = biometricAuthentication {
                        alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeoutAndFaceId(durationString).0
                    } else {
                        alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeoutAndTouchId(durationString).0
                    }
                } else {
                    alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeout(durationString).0
                }
                
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: alertText, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_No, action: {
                        if let strongSelf = self {
                            strongSelf.pay(savedCredentialsToken: token)
                        }
                    }),
                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                        if let strongSelf = self {
                            let _ = cacheTwoStepPasswordToken(postbox: strongSelf.context.account.postbox, token: token).start()
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
        if !formSupportApplePay(paymentForm) {
            completion(.failure)
            return
        }
        guard let nativeProvider = paymentForm.nativeProvider else {
            completion(.failure)
            return
        }
        guard let paramsData = nativeProvider.params.data(using: .utf8) else {
            return
        }
        guard let nativeParams = (try? JSONSerialization.jsonObject(with: paramsData)) as? [String: Any] else {
            return
        }
        
        if nativeProvider.name == "stripe" {
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
        } else {
            self.applePayAuthrorizationCompletion = completion
            guard let paymentString = String(data: payment.token.paymentData, encoding: .utf8) else {
                return
            }
            self.pay(liabilityNoticeAccepted: true, receivedCredentials: .applePay(data: paymentString))
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.presentingViewController?.dismiss(animated: true, completion: nil)
        self.paymentAuthDisposable.set(nil)
    }
}
