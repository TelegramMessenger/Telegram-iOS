import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
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
import OverlayStatusController
import CheckNode
import TextFormat
import Markdown

final class BotCheckoutControllerArguments {
    fileprivate let account: Account
    fileprivate let openInfo: (BotCheckoutInfoControllerFocus) -> Void
    fileprivate let openPaymentMethod: () -> Void
    fileprivate let openShippingMethod: () -> Void
    fileprivate let updateTip: (Int64) -> Void
    fileprivate let ensureTipInputVisible: () -> Void
    
    fileprivate init(account: Account, openInfo: @escaping (BotCheckoutInfoControllerFocus) -> Void, openPaymentMethod: @escaping () -> Void, openShippingMethod: @escaping () -> Void, updateTip: @escaping (Int64) -> Void, ensureTipInputVisible: @escaping () -> Void) {
        self.account = account
        self.openInfo = openInfo
        self.openPaymentMethod = openPaymentMethod
        self.openShippingMethod = openShippingMethod
        self.updateTip = updateTip
        self.ensureTipInputVisible = ensureTipInputVisible
    }
}

private enum BotCheckoutSection: Int32 {
    case header
    case prices
    case info
}

enum BotCheckoutEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case header
        case price(Int)
        case actionPlaceholder(Int)
        case tip
        case paymentMethod
        case shippingInfo
        case shippingMethod
        case nameInfo
        case emailInfo
        case phoneInfo
    }

    case header(PresentationTheme, TelegramMediaInvoice, String)
    case price(Int, PresentationTheme, String, String, Bool, Bool, Int?)
    case tip(Int, PresentationTheme, String, String, String, Int64, Int64, [(String, Int64)])
    case paymentMethod(PresentationTheme, String, String)
    case shippingInfo(PresentationTheme, String, String)
    case shippingMethod(PresentationTheme, String, String)
    case nameInfo(PresentationTheme, String, String)
    case emailInfo(PresentationTheme, String, String)
    case phoneInfo(PresentationTheme, String, String)
    case actionPlaceholder(Int, Int)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return BotCheckoutSection.prices.rawValue
            case .price, .tip:
                return BotCheckoutSection.prices.rawValue
            default:
                return BotCheckoutSection.info.rawValue
        }
    }
    
    var sortId: Int32 {
        switch self {
            case .header:
                return 0
            case let .price(index, _, _, _, _, _, _):
                return 1 + Int32(index)
            case let .tip(index, _, _, _, _, _, _, _):
                return 1 + Int32(index)
            case let .actionPlaceholder(index, _):
                return 1 + Int32(index)
            case .paymentMethod:
                return 10000 + 2
            case .shippingInfo:
                return 10000 + 3
            case .shippingMethod:
                return 10000 + 4
            case .nameInfo:
                return 10000 + 5
            case .emailInfo:
                return 10000 + 6
            case .phoneInfo:
                return 10000 + 7
        }
    }

    var stableId: StableId {
        switch self {
            case .header:
                return .header
            case let .price(index, _, _, _, _, _, _):
                return .price(index)
            case .tip:
                return .tip
            case let .actionPlaceholder(index, _):
                return .actionPlaceholder(index)
            case .paymentMethod:
                return .paymentMethod
            case .shippingInfo:
                return .shippingInfo
            case .shippingMethod:
                return .shippingMethod
            case .nameInfo:
                return .nameInfo
            case .emailInfo:
                return .emailInfo
            case .phoneInfo:
                return .phoneInfo
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
            case let .price(lhsIndex, lhsTheme, lhsText, lhsValue, lhsFinal, lhsHasSeparator, lhsShimmeringIndex):
                if case let .price(rhsIndex, rhsTheme, rhsText, rhsValue, rhsFinal, rhsHasSeparator, rhsShimmeringIndex) = rhs {
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
                    if lhsHasSeparator != rhsHasSeparator {
                        return false
                    }
                    if lhsShimmeringIndex != rhsShimmeringIndex {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .tip(lhsIndex, lhsTheme, lhsText, lhsCurrency, lhsValue, lhsNumericValue, lhsMaxValue, lhsVariants):
                if case let .tip(rhsIndex, rhsTheme, rhsText, rhsCurrency, rhsValue, rhsNumericValue, rhsMaxValue, rhsVariants) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsText == rhsText, lhsCurrency == rhsCurrency, lhsValue == rhsValue, lhsNumericValue == rhsNumericValue, lhsMaxValue == rhsMaxValue {
                    if lhsVariants.count != rhsVariants.count {
                        return false
                    }
                    for i in 0 ..< lhsVariants.count {
                        if lhsVariants[i].0 != rhsVariants[i].0 {
                            return false
                        }
                        if lhsVariants[i].1 != rhsVariants[i].1 {
                            return false
                        }
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
            case let .actionPlaceholder(index, shimmeringIndex):
                if case .actionPlaceholder(index, shimmeringIndex) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: BotCheckoutEntry, rhs: BotCheckoutEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BotCheckoutControllerArguments
        switch self {
            case let .header(theme, invoice, botName):
                return BotCheckoutHeaderItem(account: arguments.account, theme: theme, invoice: invoice, botName: botName, sectionId: self.section)
            case let .price(_, theme, text, value, isFinal, hasSeparator, shimmeringIndex):
                return BotCheckoutPriceItem(theme: theme, title: text, label: value, isFinal: isFinal, hasSeparator: hasSeparator, shimmeringIndex: shimmeringIndex, sectionId: self.section)
            case let .tip(_, _, text, currency, value, numericValue, maxValue, variants):
                return BotCheckoutTipItem(theme: presentationData.theme, strings: presentationData.strings, title: text, currency: currency, value: value, numericValue: numericValue, maxValue: maxValue, availableVariants: variants, sectionId: self.section, updateValue: { value in
                    arguments.updateTip(value)
                }, updatedFocus: { isFocused in
                    if isFocused {
                        arguments.ensureTipInputVisible()
                    }
                })
            case let .paymentMethod(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openPaymentMethod()
                })
            case let .shippingInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.address(.street1))
                })
            case let .shippingMethod(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openShippingMethod()
                })
            case let .nameInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.name)
                })
            case let .emailInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.email)
                })
            case let .phoneInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openInfo(.phone)
                })
            case let .actionPlaceholder(_, shimmeringIndex):
                return ItemListDisclosureItem(presentationData: presentationData, title: " ", label: " ", sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                }, shimmeringIndex: shimmeringIndex)
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

private func currentTotalPrice(paymentForm: BotPaymentForm?, validatedFormInfo: BotPaymentValidatedFormInfo?, currentShippingOptionId: String?, currentTip: Int64?) -> Int64 {
    guard let paymentForm = paymentForm else {
        return 0
    }
    
    var totalPrice: Int64 = 0

    if let currentTip = currentTip {
        totalPrice += currentTip
    }
    
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

private func botCheckoutControllerEntries(presentationData: PresentationData, state: BotCheckoutControllerState, invoice: TelegramMediaInvoice, paymentForm: BotPaymentForm?, formInfo: BotPaymentRequestedInfo?, validatedFormInfo: BotPaymentValidatedFormInfo?, currentShippingOptionId: String?, currentPaymentMethod: BotCheckoutPaymentMethod?, currentTip: Int64?, botPeer: EnginePeer?) -> [BotCheckoutEntry] {
    var entries: [BotCheckoutEntry] = []
    
    var botName = ""
    if let botPeer = botPeer {
        botName = botPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
    }
    entries.append(.header(presentationData.theme, invoice, botName))
    
    if let paymentForm = paymentForm {
        var totalPrice: Int64 = 0

        if let currentTip = currentTip {
            totalPrice += currentTip
        }
        
        var index = 0
        for price in paymentForm.invoice.prices {
            entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: paymentForm.invoice.currency), false, index == 0, nil))
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
                            entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: paymentForm.invoice.currency), false, false, nil))
                            totalPrice += price.amount
                            index += 1
                        }
                        
                        break
                    }
                }
            }
        }

        if !entries.isEmpty {
            switch entries[entries.count - 1] {
            case let .price(index, theme, title, value, _, _, _):
                entries[entries.count - 1] = .price(index, theme, title, value, false, index == 0, nil)
            default:
                break
            }
        }

        if let tip = paymentForm.invoice.tip {
            let tipTitle: String
            tipTitle = presentationData.strings.Checkout_OptionalTipItem
            entries.append(.tip(index, presentationData.theme, tipTitle, paymentForm.invoice.currency, "\(formatCurrencyAmount(currentTip ?? 0, currency: paymentForm.invoice.currency))", currentTip ?? 0, tip.max, tip.suggested.map { item -> (String, Int64) in
                return ("\(formatCurrencyAmount(item, currency: paymentForm.invoice.currency))", item)
            }))
            index += 1
        }
        
        entries.append(.price(index, presentationData.theme, presentationData.strings.Checkout_TotalAmount, formatCurrencyAmount(totalPrice, currency: paymentForm.invoice.currency), true, true, nil))
        
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
    } else {
        let numItems = 4
        for index in 0 ..< numItems {
            entries.append(.price(index, presentationData.theme, " ", " ", false, index == 0, index))
        }

        for index in numItems ..< numItems + 2 {
            entries.append(.actionPlaceholder(index, index - numItems))
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
    if let savedCredentials = form.savedCredentials {
        if !methods.contains(.savedCredentials(savedCredentials)) {
            methods.append(.savedCredentials(savedCredentials))
        }
    }
    return methods
}

private final class RecurrentConfirmationNode: ASDisplayNode {
    private let isAcceptedUpdated: (Bool) -> Void
    private let openTerms: () -> Void
    
    private var checkNode: InteractiveCheckNode?
    private let textNode: ImmediateTextNode
    
    init(isAcceptedUpdated: @escaping (Bool) -> Void, openTerms: @escaping () -> Void) {
        self.isAcceptedUpdated = isAcceptedUpdated
        self.openTerms = openTerms
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        
        super.init()
        
        self.textNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.textNode.tapAttributeAction = { [weak self] attributes, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                self?.openTerms()
            }
        }
        
        self.addSubnode(self.textNode)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        guard let checkNode = self.checkNode else {
            return
        }
        if case .ended = recognizer.state {
            checkNode.setSelected(!checkNode.selected, animated: true)
            checkNode.valueChanged?(checkNode.selected)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if let (_, attributes) = self.textNode.attributesAtPoint(self.view.convert(point, to: self.textNode.view)) {
            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] == nil {
                return self.view
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    func update(presentationData: PresentationData, botName: String, width: CGFloat, sideInset: CGFloat) -> CGFloat {
        let spacing: CGFloat = 16.0
        let topInset: CGFloat = 8.0
        
        let checkNode: InteractiveCheckNode
        if let current = self.checkNode {
            checkNode = current
        } else {
            checkNode = InteractiveCheckNode(theme: CheckNodeTheme(backgroundColor: presentationData.theme.list.itemCheckColors.fillColor, strokeColor: presentationData.theme.list.itemCheckColors.foregroundColor, borderColor: presentationData.theme.list.itemCheckColors.strokeColor, overlayBorder: false, hasInset: false, hasShadow: false))
            checkNode.valueChanged = { [weak self] value in
                self?.isAcceptedUpdated(value)
            }
            self.checkNode = checkNode
            self.addSubnode(checkNode)
        }
        
        let checkSize = CGSize(width: 22.0, height: 22.0)
        
        self.textNode.linkHighlightColor = presentationData.theme.list.itemAccentColor.withAlphaComponent(0.3)
        
        let attributedText = parseMarkdownIntoAttributedString(
            presentationData.strings.Bot_AccepRecurrentInfo(botName).string,
            attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: presentationData.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: presentationData.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: presentationData.theme.list.itemAccentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
        )
        
        self.textNode.attributedText = attributedText
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0 - spacing - checkSize.width, height: .greatestFiniteMagnitude))
        
        let height = textSize.height + 15.0
        
        let contentWidth = checkSize.width + spacing + textSize.width
        let contentOriginX = sideInset + floor((width - sideInset * 2.0 - contentWidth) / 2.0)
        
        checkNode.frame = CGRect(origin: CGPoint(x: contentOriginX, y: topInset + floor((height - checkSize.height) / 2.0)), size: checkSize)
        
        self.textNode.frame = CGRect(origin: CGPoint(x: contentOriginX + checkSize.width + spacing, y: topInset + floor((height - textSize.height) / 2.0)), size: textSize)
        
        return height
    }
}

private final class ActionButtonPanelNode: ASDisplayNode {
    private(set) var isAccepted: Bool = false
    var isAcceptedUpdated: (() -> Void)?
    var openRecurrentTerms: (() -> Void)?
    private var recurrentConfirmationNode: RecurrentConfirmationNode?
    
    func update(presentationData: PresentationData, layout: ContainerViewLayout, invoice: BotPaymentInvoice?, botName: String?) -> (CGFloat, CGFloat) {
        let bottomPanelVerticalInset: CGFloat = 16.0
        
        var height = max(layout.intrinsicInsets.bottom, layout.inputHeight ?? 0.0) + bottomPanelVerticalInset * 2.0 + BotCheckoutActionButton.height
        var actionButtonOffset: CGFloat = bottomPanelVerticalInset
        
        if let invoice = invoice, let recurrentInfo = invoice.recurrentInfo, let botName = botName {
            let recurrentConfirmationNode: RecurrentConfirmationNode
            if let current = self.recurrentConfirmationNode {
                recurrentConfirmationNode = current
            } else {
                recurrentConfirmationNode = RecurrentConfirmationNode(isAcceptedUpdated: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.isAccepted = value
                    strongSelf.isAcceptedUpdated?()
                }, openTerms: { [weak self] in
                    self?.openRecurrentTerms?()
                })
                self.recurrentConfirmationNode = recurrentConfirmationNode
                self.addSubnode(recurrentConfirmationNode)
            }
            
            let _ = recurrentInfo
            
            let recurrentConfirmationHeight = recurrentConfirmationNode.update(presentationData: presentationData, botName: botName, width: layout.size.width, sideInset: layout.safeInsets.left + 33.0)
            recurrentConfirmationNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: recurrentConfirmationHeight))
            
            actionButtonOffset += recurrentConfirmationHeight
        } else if let recurrentConfirmationNode = self.recurrentConfirmationNode {
            self.recurrentConfirmationNode = nil
            
            recurrentConfirmationNode.removeFromSupernode()
        }
        
        height += actionButtonOffset - bottomPanelVerticalInset
        
        return (height, actionButtonOffset)
    }
}

final class BotCheckoutControllerNode: ItemListControllerNode, PKPaymentAuthorizationViewControllerDelegate {
    private weak var controller: BotCheckoutController?
    private let navigationBar: NavigationBar
    private let context: AccountContext
    private let source: BotPaymentInvoiceSource
    private let present: (ViewController, Any?) -> Void
    private let dismissAnimated: () -> Void
    private let completed: (String, EngineMessage.Id?) -> Void

    var pending: () -> Void = {}
    var failed: () -> Void = {}

    private var stateValue = BotCheckoutControllerState()
    private let state = ValuePromise(BotCheckoutControllerState(), ignoreRepeated: true)
    private var arguments: BotCheckoutControllerArguments?
    
    private var presentationData: PresentationData
    
    private let paymentFormAndInfo = Promise<(BotPaymentForm, BotPaymentRequestedInfo, BotPaymentValidatedFormInfo?, String?, BotCheckoutPaymentMethod?, Int64?)?>(nil)
    private var paymentFormValue: BotPaymentForm?
    private var botPeerValue: EnginePeer?
    private var currentFormInfo: BotPaymentRequestedInfo?
    private var currentValidatedFormInfo: BotPaymentValidatedFormInfo?
    private var currentShippingOptionId: String?
    private var currentPaymentMethod: BotCheckoutPaymentMethod?
    private var currentTipAmount: Int64?
    private var formRequestDisposable: Disposable?

    private let actionButtonPanelNode: ActionButtonPanelNode
    private let actionButtonPanelSeparator: ASDisplayNode
    private let actionButton: BotCheckoutActionButton
    private let inProgressDimNode: ASDisplayNode
    private var statusController: ViewController?
    
    private let payDisposable = MetaDisposable()
    private let paymentAuthDisposable = MetaDisposable()
    private var applePayAuthrorizationCompletion: ((PKPaymentAuthorizationStatus) -> Void)?
    private var applePayController: PKPaymentAuthorizationViewController?

    private var passwordTip: String?
    private var passwordTipDisposable: Disposable?
    
    init(controller: BotCheckoutController?, navigationBar: NavigationBar, context: AccountContext, invoice: TelegramMediaInvoice, source: BotPaymentInvoiceSource, inputData: Promise<BotCheckoutController.InputData?>, present: @escaping (ViewController, Any?) -> Void, dismissAnimated: @escaping () -> Void, completed: @escaping (String, EngineMessage.Id?) -> Void) {
        self.controller = controller
        self.navigationBar = navigationBar
        self.context = context
        self.source = source
        self.present = present
        self.dismissAnimated = dismissAnimated
        self.completed = completed
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var openInfoImpl: ((BotCheckoutInfoControllerFocus) -> Void)?
        var updateTipImpl: ((Int64) -> Void)?
        var openPaymentMethodImpl: (() -> Void)?
        var openShippingMethodImpl: (() -> Void)?
        var ensureTipInputVisibleImpl: (() -> Void)?
        
        let arguments = BotCheckoutControllerArguments(account: context.account, openInfo: { item in
            openInfoImpl?(item)
        }, openPaymentMethod: {
            openPaymentMethodImpl?()
        }, openShippingMethod: {
            openShippingMethodImpl?()
        }, updateTip: { value in
            updateTipImpl?(value)
        }, ensureTipInputVisible: {
            ensureTipInputVisibleImpl?()
        })

        let paymentBotPeer: Signal<EnginePeer?, NoError> = paymentFormAndInfo.get()
        |> map { paymentFormAndInfo -> EnginePeer.Id? in
            if let paymentBotId = paymentFormAndInfo?.0.paymentBotId {
                return paymentBotId
            } else {
                return nil
            }
        }
        |> distinctUntilChanged
        |> mapToSignal { peerId -> Signal<EnginePeer?, NoError> in
            if let peerId = peerId {
                return context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
            } else {
                return .single(nil)
            }
        }
        
        let signal: Signal<(ItemListPresentationData, (ItemListNodeState, Any)), NoError> = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, self.state.get(), paymentFormAndInfo.get(), paymentBotPeer)
        |> map { presentationData, state, paymentFormAndInfo, botPeer -> (ItemListPresentationData, (ItemListNodeState, Any)) in
            let nodeState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: botCheckoutControllerEntries(presentationData: presentationData, state: state, invoice: invoice, paymentForm: paymentFormAndInfo?.0, formInfo: paymentFormAndInfo?.1, validatedFormInfo: paymentFormAndInfo?.2, currentShippingOptionId: paymentFormAndInfo?.3, currentPaymentMethod: paymentFormAndInfo?.4, currentTip: paymentFormAndInfo?.5, botPeer: botPeer), style: .blocks, focusItemTag: nil, emptyStateItem: nil, animateChanges: false)

            return (ItemListPresentationData(presentationData), (nodeState, arguments))
        }

        self.actionButtonPanelNode = ActionButtonPanelNode()

        self.actionButtonPanelSeparator = ASDisplayNode()
        
        self.actionButton = BotCheckoutActionButton(activeFillColor: self.presentationData.theme.list.itemAccentColor, inactiveFillColor: self.presentationData.theme.list.itemDisabledTextColor.mixedWith(self.presentationData.theme.list.blocksBackgroundColor, alpha: 0.7), foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor)
        self.actionButton.setState(.placeholder)
        
        self.inProgressDimNode = ASDisplayNode()
        self.inProgressDimNode.alpha = 0.0
        self.inProgressDimNode.isUserInteractionEnabled = false
        self.inProgressDimNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor.withAlphaComponent(0.5)
        
        super.init(controller: nil, navigationBar: navigationBar, state: signal)
        
        self.arguments = arguments
        
        self.actionButtonPanelNode.isAcceptedUpdated = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateActionButton()
        }
        
        self.actionButtonPanelNode.openRecurrentTerms = { [weak self] in
            guard let strongSelf = self, let paymentForm = strongSelf.paymentFormValue, let recurrentInfo = paymentForm.invoice.recurrentInfo else {
                return
            }
            strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: recurrentInfo.termsUrl, forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {
                self?.view.endEditing(true)
            })
        }
        
        openInfoImpl = { [weak self] focus in
            if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                strongSelf.controller?.view.endEditing(true)
                strongSelf.present(BotCheckoutInfoController(context: context, invoice: paymentFormValue.invoice, source: source, initialFormInfo: currentFormInfo, focus: focus, formInfoUpdated: { formInfo, validatedInfo in
                    if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue {
                        strongSelf.currentFormInfo = formInfo
                        strongSelf.currentValidatedFormInfo = validatedInfo
                        var updatedCurrentShippingOptionId: String?
                        if let currentShippingOptionId = strongSelf.currentShippingOptionId, let shippingOptions = validatedInfo.shippingOptions {
                            if shippingOptions.contains(where: { $0.id == currentShippingOptionId }) {
                                updatedCurrentShippingOptionId = currentShippingOptionId
                            }
                        }

                        strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, formInfo, validatedInfo, updatedCurrentShippingOptionId, strongSelf.currentPaymentMethod, strongSelf.currentTipAmount)))

                        strongSelf.updateActionButton()
                    }
                }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }
        
        let applyPaymentMethod: (BotCheckoutPaymentMethod) -> Void = { [weak self] method in
            if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                strongSelf.currentPaymentMethod = method
                strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, currentFormInfo, strongSelf.currentValidatedFormInfo, strongSelf.currentShippingOptionId, strongSelf.currentPaymentMethod, strongSelf.currentTipAmount)))
                strongSelf.updateActionButton()
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
                    let controller = BotCheckoutNativeCardEntryController(context: strongSelf.context, provider: .stripe(additionalFields: additionalFields, publishableKey: publishableKey), completion: { method in
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
                                                    case .noPassword, .awaitingEmailConfirmation, .pendingPasswordReset:
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
                                    applyPaymentMethod(method)
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
                } else if let nativeProvider = paymentForm.nativeProvider, nativeProvider.name == "smartglocal" {
                    guard let paramsData = nativeProvider.params.data(using: .utf8) else {
                        return
                    }
                    guard let nativeParams = (try? JSONSerialization.jsonObject(with: paramsData)) as? [String: Any] else {
                        return
                    }
                    guard let publicToken = nativeParams["public_token"] as? String else {
                        return
                    }

                    var dismissImpl: (() -> Void)?
                    let canSave = paymentForm.canSaveCredentials || paymentForm.passwordMissing
                    let controller = BotCheckoutNativeCardEntryController(context: strongSelf.context, provider: .smartglobal(isTesting: paymentForm.invoice.isTest, publicToken: publicToken), completion: { method in
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
                                                    case .noPassword, .awaitingEmailConfirmation, .pendingPasswordReset:
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
                                    applyPaymentMethod(method)
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
                                            case .noPassword, .awaitingEmailConfirmation, .pendingPasswordReset:
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

        updateTipImpl = { [weak self] value in
            guard let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo else {
                return
            }

            if strongSelf.currentTipAmount == value {
                return
            }
            
            strongSelf.currentTipAmount = value

            strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, currentFormInfo, strongSelf.currentValidatedFormInfo, strongSelf.currentShippingOptionId, strongSelf.currentPaymentMethod, strongSelf.currentTipAmount)))

            strongSelf.updateActionButton()
        }

        ensureTipInputVisibleImpl = { [weak self] in
            self?.afterLayout({
                guard let strongSelf = self else {
                    return
                }
                var selectedItemNode: ListViewItemNode?
                strongSelf.listNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? BotCheckoutTipItemNode {
                        selectedItemNode = itemNode
                    }
                }
                if let selectedItemNode = selectedItemNode {
                    strongSelf.listNode.ensureItemNodeVisible(selectedItemNode, atTop: true)
                }
            })
        }
        
        openPaymentMethodImpl = { [weak self] in
            if let strongSelf = self, let paymentForm = strongSelf.paymentFormValue {
                strongSelf.controller?.view.endEditing(true)
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
                strongSelf.controller?.view.endEditing(true)
                strongSelf.present(BotCheckoutPaymentShippingOptionSheetController(context: strongSelf.context, currency: paymentFormValue.invoice.currency, options: shippingOptions, currentId: strongSelf.currentShippingOptionId, applyValue: { id in
                    if let strongSelf = self, let paymentFormValue = strongSelf.paymentFormValue, let currentFormInfo = strongSelf.currentFormInfo {
                        strongSelf.currentShippingOptionId = id
                        strongSelf.paymentFormAndInfo.set(.single((paymentFormValue, currentFormInfo, strongSelf.currentValidatedFormInfo, strongSelf.currentShippingOptionId, strongSelf.currentPaymentMethod, strongSelf.currentTipAmount)))
                        
                        strongSelf.updateActionButton()
                    }
                }), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }
        
        self.formRequestDisposable = (inputData.get() |> deliverOnMainQueue).start(next: { [weak self] formAndValidatedInfo in
            if let strongSelf = self {
                guard let formAndValidatedInfo = formAndValidatedInfo else {
                    strongSelf.controller?.dismiss()
                    return
                }
                UIView.transition(with: strongSelf.view, duration: 0.25, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                }, completion: nil)

                let savedInfo: BotPaymentRequestedInfo
                if let current = formAndValidatedInfo.form.savedInfo {
                    savedInfo = current
                } else {
                    savedInfo = BotPaymentRequestedInfo(name: nil, phone: nil, email: nil, shippingAddress: nil)
                }
                strongSelf.paymentFormValue = formAndValidatedInfo.form
                strongSelf.botPeerValue = formAndValidatedInfo.botPeer
                strongSelf.currentFormInfo = savedInfo
                strongSelf.currentValidatedFormInfo = formAndValidatedInfo.validatedFormInfo
                if let savedCredentials = formAndValidatedInfo.form.savedCredentials {
                    strongSelf.currentPaymentMethod = .savedCredentials(savedCredentials)
                }
                strongSelf.actionButton.isEnabled = true
                strongSelf.paymentFormAndInfo.set(.single((formAndValidatedInfo.form, savedInfo, formAndValidatedInfo.validatedFormInfo, nil, strongSelf.currentPaymentMethod, strongSelf.currentTipAmount)))
                
                strongSelf.updateActionButton()
            }
        })

        self.addSubnode(self.actionButtonPanelNode)
        self.actionButtonPanelNode.addSubnode(self.actionButtonPanelSeparator)
        self.actionButtonPanelNode.addSubnode(self.actionButton)
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        self.actionButton.isEnabled = false
        
        self.listNode.supernode?.insertSubnode(self.inProgressDimNode, aboveSubnode: self.listNode)

        self.passwordTipDisposable = (self.context.engine.auth.twoStepVerificationConfiguration()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            switch value {
            case .notSet:
                break
            case let .set(hint, _, _, _, _):
                if !hint.isEmpty {
                    strongSelf.passwordTip = hint
                }
            }
        })
        
        self.actionButtonPanelSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.actionButtonPanelNode.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
        self.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            
            let panelColor: UIColor
            let separatorColor: UIColor
            switch offset {
            case let .known(value):
                if value > 10.0 {
                    panelColor = strongSelf.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
                    separatorColor = strongSelf.presentationData.theme.rootController.navigationBar.separatorColor
                } else {
                    panelColor = .clear
                    separatorColor = .clear
                }
            default:
                panelColor = strongSelf.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
                separatorColor = strongSelf.presentationData.theme.rootController.navigationBar.separatorColor
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .linear)
            if strongSelf.actionButtonPanelNode.backgroundColor != panelColor {
                transition.updateBackgroundColor(node: strongSelf.actionButtonPanelNode, color: panelColor)
            }
            if strongSelf.actionButtonPanelSeparator.backgroundColor != separatorColor {
                transition.updateBackgroundColor(node: strongSelf.actionButtonPanelSeparator, color: separatorColor)
            }
        }
    }
    
    deinit {
        self.formRequestDisposable?.dispose()
        self.payDisposable.dispose()
        self.paymentAuthDisposable.dispose()
        self.passwordTipDisposable?.dispose()
    }
    
    private func updateActionButton() {
        let totalAmount = currentTotalPrice(paymentForm: self.paymentFormValue, validatedFormInfo: self.currentValidatedFormInfo, currentShippingOptionId: self.currentShippingOptionId, currentTip: self.currentTipAmount)
        let payString: String
        var isButtonEnabled = true
        if let paymentForm = self.paymentFormValue, totalAmount > 0 {
            payString = self.presentationData.strings.Checkout_PayPrice(formatCurrencyAmount(totalAmount, currency: paymentForm.invoice.currency)).string
            
            if let _ = paymentForm.invoice.recurrentInfo {
                if !self.actionButtonPanelNode.isAccepted {
                    isButtonEnabled = false
                }
            }
        } else {
            payString = self.presentationData.strings.CheckoutInfo_Pay
        }
        
        self.actionButton.isEnabled = isButtonEnabled
        
        if let currentPaymentMethod = self.currentPaymentMethod {
            switch currentPaymentMethod {
            case .applePay:
                self.actionButton.setState(.applePay(isEnabled: isButtonEnabled))
            default:
                self.actionButton.setState(.active(text: payString, isEnabled: isButtonEnabled))
            }
        } else {
            self.actionButton.setState(.active(text: payString, isEnabled: isButtonEnabled))
        }
        self.actionButtonPanelNode.isHidden = false
        
        self.controller?.requestLayout(transition: .immediate)
    }

    private func updateIsInProgress(_ value: Bool) {
        if value {
            if self.statusController == nil {
                let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                self.statusController = statusController
                self.controller?.present(statusController, in: .window(.root))
            }
        } else if let statusController = self.statusController {
            self.statusController = nil
            statusController.dismiss()
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, additionalInsets: UIEdgeInsets) {
        var updatedInsets = layout.intrinsicInsets

        let bottomPanelHorizontalInset: CGFloat = 16.0
        
        var botName: String?
        if let botPeer = self.botPeerValue {
            botName = botPeer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
        }
        
        let (bottomPanelHeight, actionButtonOffset) = self.actionButtonPanelNode.update(presentationData: self.presentationData, layout: layout, invoice: self.paymentFormValue?.invoice, botName: botName)

        transition.updateFrame(node: self.actionButtonPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomPanelHeight), size: CGSize(width: layout.size.width, height: bottomPanelHeight)))
        transition.updateFrame(node: self.actionButtonPanelSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: UIScreenPixel)))

        let actionButtonFrame = CGRect(origin: CGPoint(x: bottomPanelHorizontalInset, y: actionButtonOffset), size: CGSize(width: layout.size.width - bottomPanelHorizontalInset * 2.0, height: BotCheckoutActionButton.height))
        transition.updateFrame(node: self.actionButton, frame: actionButtonFrame)
        self.actionButton.updateLayout(absoluteRect: actionButtonFrame.offsetBy(dx: self.actionButtonPanelNode.frame.minX, dy: self.actionButtonPanelNode.frame.minY), containerSize: layout.size, transition: transition)

        updatedInsets.bottom = bottomPanelHeight

        super.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: updatedInsets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationBarHeight, transition: transition, additionalInsets: additionalInsets)
        
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
                                let _ = (self.context.engine.auth.cachedTwoStepPasswordToken()
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
                    var countryCode: String = "US"
                    if nativeProvider.name == "stripe" {
                        merchantId = "merchant.ph.telegra.Telegraph"
                    } else if let paramsId = nativeParams["apple_pay_merchant_id"] as? String {
                        merchantId = paramsId
                    } else {
                        return
                    }
                    if let paramsCountryCode = nativeParams["acquirer_bank_country"] as? String {
                        countryCode = paramsCountryCode
                    }
                    
                    let botPeerId = paymentForm.paymentBotId
                    let _ = (context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: botPeerId)
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] botPeer in
                        if let strongSelf = self, let botPeer = botPeer {
                            let request = PKPaymentRequest()
                            
                            request.merchantIdentifier = merchantId
                            request.supportedNetworks = [.visa, .amex, .masterCard]
                            request.merchantCapabilities = [.capability3DS]
                            request.countryCode = countryCode
                            request.currencyCode = paymentForm.invoice.currency.uppercased()

                            var items: [PKPaymentSummaryItem] = []
                            
                            var totalAmount: Int64 = 0

                            for price in paymentForm.invoice.prices {
                                totalAmount += price.amount

                                if let fractional = currencyToFractionalAmount(value: price.amount, currency: paymentForm.invoice.currency) {
                                    let amount = NSDecimalNumber(value: fractional)
                                    items.append(PKPaymentSummaryItem(label: price.label, amount: amount))
                                }
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

                            if let tipAmount = strongSelf.currentTipAmount {
                                totalAmount += tipAmount

                                if let fractional = currencyToFractionalAmount(value: tipAmount, currency: paymentForm.invoice.currency) {
                                    let amount = NSDecimalNumber(value: fractional)
                                    items.append(PKPaymentSummaryItem(label: strongSelf.presentationData.strings.Checkout_TipItem, amount: amount))
                                }
                            }

                            if let fractionalTotal = currencyToFractionalAmount(value: totalAmount, currency: paymentForm.invoice.currency) {
                                let amount = NSDecimalNumber(value: fractionalTotal)
                                items.append(PKPaymentSummaryItem(label: botPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder), amount: amount))
                            }
                            
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
            let botPeer: Signal<EnginePeer?, NoError> = context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: paymentForm.paymentBotId)
            )
            let providerPeer: Signal<EnginePeer?, NoError> = context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: paymentForm.providerId)
            )
            let _ = (combineLatest(
                ApplicationSpecificNotice.getBotPaymentLiability(accountManager: self.context.sharedContext.accountManager, peerId: paymentForm.paymentBotId),
                botPeer,
                providerPeer
            )
            |> deliverOnMainQueue).start(next: { [weak self] value, botPeer, providerPeer in
                if let strongSelf = self, let botPeer = botPeer {
                    if value {
                        strongSelf.pay(savedCredentialsToken: savedCredentialsToken, liabilityNoticeAccepted: true)
                    } else {
                        let paymentText = strongSelf.presentationData.strings.Checkout_PaymentLiabilityAlert
                            .replacingOccurrences(of: "{target}", with: botPeer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder))
                            .replacingOccurrences(of: "{payment_system}", with: providerPeer?.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder) ?? "")

                        strongSelf.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Checkout_LiabilityAlertTitle, text: paymentText, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: { }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            if let strongSelf = self {
                                let _ = ApplicationSpecificNotice.setBotPaymentLiability(accountManager: strongSelf.context.sharedContext.accountManager, peerId: paymentForm.paymentBotId).start()
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
            self.updateIsInProgress(true)

            var tipAmount = self.currentTipAmount
            if tipAmount == nil, let _ = paymentForm.invoice.tip {
                tipAmount = 0
            }

            let totalAmount = currentTotalPrice(paymentForm: paymentForm, validatedFormInfo: self.currentValidatedFormInfo, currentShippingOptionId: self.currentShippingOptionId, currentTip: self.currentTipAmount)
            let currencyValue = formatCurrencyAmount(totalAmount, currency: paymentForm.invoice.currency)

            self.payDisposable.set((self.context.engine.payments.sendBotPaymentForm(source: self.source, formId: paymentForm.id, validatedInfoId: self.currentValidatedFormInfo?.id, shippingOptionId: self.currentShippingOptionId, tipAmount: tipAmount, credentials: credentials) |> deliverOnMainQueue).start(next: { [weak self] result in
                if let strongSelf = self {
                    strongSelf.inProgressDimNode.isUserInteractionEnabled = false
                    strongSelf.inProgressDimNode.alpha = 0.0
                    strongSelf.actionButton.isEnabled = true
                    strongSelf.updateIsInProgress(false)
                    if let applePayAuthrorizationCompletion = strongSelf.applePayAuthrorizationCompletion {
                        strongSelf.applePayAuthrorizationCompletion = nil
                        applePayAuthrorizationCompletion(.success)
                    }
                    if let applePayController = strongSelf.applePayController {
                        strongSelf.applePayController = nil
                        applePayController.presentingViewController?.dismiss(animated: true, completion: nil)
                    }

                    let proceedWithCompletion: (Bool, EngineMessage.Id?) -> Void = { success, receiptMessageId in
                        guard let strongSelf = self else {
                            return
                        }

                        if success {
                            strongSelf.dismissAnimated()
                            strongSelf.completed(currencyValue, receiptMessageId)
                        } else {
                            strongSelf.dismissAnimated()
                        }
                    }
                    
                    switch result {
                        case let .done(receiptMessageId):
                            proceedWithCompletion(true, receiptMessageId)
                        case let .externalVerificationRequired(url):
                            strongSelf.updateActionButton()
                            var dismissImpl: ((Bool) -> Void)?
                            let controller = BotCheckoutWebInteractionController(context: strongSelf.context, url: url, intent: .externalVerification({ success in
                                dismissImpl?(success)
                            }))
                            dismissImpl = { [weak controller] success in
                                controller?.dismiss()
                                proceedWithCompletion(success, nil)
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
                    strongSelf.updateIsInProgress(false)
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
                    
                    strongSelf.failed()
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
        self.present(botCheckoutPasswordEntryController(context: self.context, strings: self.presentationData.strings, passwordTip: self.passwordTip, cartTitle: cardTitle, period: period, requiresBiometrics: requiresBiometrics, completion: { [weak self] token in
            if let strongSelf = self {
                let durationString = timeIntervalString(strings: strongSelf.presentationData.strings, value: period)
                
                let alertText: String
                if requiresBiometrics {
                    if let biometricAuthentication = LocalAuth.biometricAuthentication, case .faceId = biometricAuthentication {
                        alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeoutAndFaceId(durationString).string
                    } else {
                        alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeoutAndTouchId(durationString).string
                    }
                } else {
                    alertText = strongSelf.presentationData.strings.Checkout_SavePasswordTimeout(durationString).string
                }
                
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: alertText, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_No, action: {
                        if let strongSelf = self {
                            strongSelf.pay(savedCredentialsToken: token)
                        }
                    }),
                    TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Yes, action: {
                        if let strongSelf = self {
                            let _ = strongSelf.context.engine.auth.cacheTwoStepPasswordToken(token: token).start()
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
