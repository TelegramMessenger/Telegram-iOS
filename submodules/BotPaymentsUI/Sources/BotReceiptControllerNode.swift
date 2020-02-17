import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramStringFormatting

final class BotReceiptControllerArguments {
    fileprivate let account: Account
    
    fileprivate init(account: Account) {
        self.account = account
    }
}

private enum BotReceiptSection: Int32 {
    case header
    case prices
    case info
}

enum BotReceiptEntry: ItemListNodeEntry {
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
                return BotReceiptSection.header.rawValue
            case .price:
                return BotReceiptSection.prices.rawValue
            default:
                return BotReceiptSection.info.rawValue
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
    
    static func ==(lhs: BotReceiptEntry, rhs: BotReceiptEntry) -> Bool {
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
    
    static func <(lhs: BotReceiptEntry, rhs: BotReceiptEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BotReceiptControllerArguments
        switch self {
            case let .header(theme, invoice, botName):
                return BotCheckoutHeaderItem(account: arguments.account, theme: theme, invoice: invoice, botName: botName, sectionId: self.section)
            case let .price(_, theme, text, value, isFinal):
                return BotCheckoutPriceItem(theme: theme, title: text, label: value, isFinal: isFinal, sectionId: self.section)
            case let .paymentMethod(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .shippingInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .shippingMethod(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .nameInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .emailInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .phoneInfo(theme, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        }
    }
}

private func botReceiptControllerEntries(presentationData: PresentationData, invoice: TelegramMediaInvoice, formInvoice: BotPaymentInvoice?, formInfo: BotPaymentRequestedInfo?, shippingOption: BotPaymentShippingOption?, paymentMethodTitle: String?, botPeer: Peer?) -> [BotReceiptEntry] {
    var entries: [BotReceiptEntry] = []
    
    var botName = ""
    if let botPeer = botPeer {
        botName = botPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
    }
    entries.append(.header(presentationData.theme, invoice, botName))
    
    if let formInvoice = formInvoice {
        var totalPrice: Int64 = 0
        
        var index = 0
        for price in formInvoice.prices {
            entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: formInvoice.currency), false))
            totalPrice += price.amount
            index += 1
        }
        
        var shippingOptionString: String?
        if let shippingOption = shippingOption {
            shippingOptionString = shippingOption.title
            
            for price in shippingOption.prices {
                entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: formInvoice.currency), false))
                totalPrice += price.amount
                index += 1
            }
        }
        
        entries.append(.price(index, presentationData.theme, presentationData.strings.Checkout_TotalAmount, formatCurrencyAmount(totalPrice, currency: formInvoice.currency), true))
        
        if let paymentMethodTitle = paymentMethodTitle {
            entries.append(.paymentMethod(presentationData.theme, presentationData.strings.Checkout_PaymentMethod, paymentMethodTitle))
        }
        
        if formInvoice.requestedFields.contains(.shippingAddress) {
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
        
        if formInvoice.requestedFields.contains(.name) {
            entries.append(.nameInfo(presentationData.theme, presentationData.strings.Checkout_Name, formInfo?.name ?? ""))
        }
        
        if formInvoice.requestedFields.contains(.email) {
            entries.append(.emailInfo(presentationData.theme, presentationData.strings.Checkout_Email, formInfo?.email ?? ""))
        }
        
        if formInvoice.requestedFields.contains(.phone) {
            entries.append(.phoneInfo(presentationData.theme, presentationData.strings.Checkout_Phone, formInfo?.phone ?? ""))
        }
    }
    
    return entries
}

private func availablePaymentMethods(current: BotCheckoutPaymentMethod?) -> [BotCheckoutPaymentMethod] {
    if let current = current {
        return [current]
    }
    return []
}

final class BotReceiptControllerNode: ItemListControllerNode {
    private let context: AccountContext
    private let dismissAnimated: () -> Void
    
    private var presentationData: PresentationData
    
    private let receiptData = Promise<(BotPaymentInvoice, BotPaymentRequestedInfo?, BotPaymentShippingOption?, String?)?>(nil)
    private var dataRequestDisposable: Disposable?
    
    private let actionButton: BotCheckoutActionButton
    
    init(controller: ItemListController?, navigationBar: NavigationBar, updateNavigationOffset: @escaping (CGFloat) -> Void, context: AccountContext, invoice: TelegramMediaInvoice, messageId: MessageId, dismissAnimated: @escaping () -> Void) {
        self.context = context
        self.dismissAnimated = dismissAnimated
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let arguments = BotReceiptControllerArguments(account: context.account)
        
        let signal: Signal<(ItemListPresentationData, (ItemListNodeState, Any)), NoError> = combineLatest(context.sharedContext.presentationData, receiptData.get(), context.account.postbox.loadedPeerWithId(messageId.peerId))
        |> map { presentationData, receiptData, botPeer -> (ItemListPresentationData, (ItemListNodeState, Any)) in
            let nodeState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: botReceiptControllerEntries(presentationData: presentationData, invoice: invoice, formInvoice: receiptData?.0, formInfo: receiptData?.1, shippingOption: receiptData?.2, paymentMethodTitle: receiptData?.3, botPeer: botPeer), style: .plain, focusItemTag: nil, emptyStateItem: nil, animateChanges: false)
            
            return (ItemListPresentationData(presentationData), (nodeState, arguments))
        }
        
        self.actionButton = BotCheckoutActionButton(inactiveFillColor: self.presentationData.theme.list.plainBackgroundColor, activeFillColor: self.presentationData.theme.list.itemAccentColor, foregroundColor: self.presentationData.theme.list.plainBackgroundColor)
        self.actionButton.setState(.inactive(self.presentationData.strings.Common_Done))
        
        super.init(controller: controller, navigationBar: navigationBar, updateNavigationOffset: updateNavigationOffset, state: signal)
        
        self.dataRequestDisposable = (requestBotPaymentReceipt(network: context.account.network, messageId: messageId) |> deliverOnMainQueue).start(next: { [weak self] receipt in
            if let strongSelf = self {
                strongSelf.receiptData.set(.single((receipt.invoice, receipt.info, receipt.shippingOption, receipt.credentialsTitle)))
            }
        })
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        self.addSubnode(self.actionButton)
    }
    
    deinit {
        self.dataRequestDisposable?.dispose()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, additionalInsets: UIEdgeInsets) {
        var updatedInsets = layout.intrinsicInsets
        updatedInsets.bottom += BotCheckoutActionButton.diameter + 20.0
        super.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: updatedInsets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationBarHeight, transition: transition, additionalInsets: additionalInsets)
        
        let actionButtonFrame = CGRect(origin: CGPoint(x: 10.0, y: layout.size.height - 10.0 - BotCheckoutActionButton.diameter - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width - 20.0, height: BotCheckoutActionButton.diameter))
        transition.updateFrame(node: self.actionButton, frame: actionButtonFrame)
        self.actionButton.updateLayout(size: actionButtonFrame.size, transition: transition)
    }
    
    @objc func actionButtonPressed() {
        self.dismissAnimated()
    }
}
