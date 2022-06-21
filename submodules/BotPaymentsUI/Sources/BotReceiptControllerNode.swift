import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
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
    case price(Int, PresentationTheme, String, String, Bool, Bool)
    case paymentMethod(PresentationTheme, String, String)
    case shippingInfo(PresentationTheme, String, String)
    case shippingMethod(PresentationTheme, String, String)
    case nameInfo(PresentationTheme, String, String)
    case emailInfo(PresentationTheme, String, String)
    case phoneInfo(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return BotReceiptSection.prices.rawValue
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
            case let .price(index, _, _, _, _, _):
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
            case let .price(lhsIndex, lhsTheme, lhsText, lhsValue, lhsHasSeparator, lhsFinal):
                if case let .price(rhsIndex, rhsTheme, rhsText, rhsValue, rhsHasSeparator, rhsFinal) = rhs {
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
                    if lhsHasSeparator != rhsHasSeparator {
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
            case let .price(_, theme, text, value, hasSeparator, isFinal):
                return BotCheckoutPriceItem(theme: theme, title: text, label: value, isFinal: isFinal, hasSeparator: hasSeparator, shimmeringIndex: nil, sectionId: self.section)
            case let .paymentMethod(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .shippingInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .shippingMethod(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .nameInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .emailInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
            case let .phoneInfo(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        }
    }
}

private func botReceiptControllerEntries(presentationData: PresentationData, invoice: TelegramMediaInvoice?, formInvoice: BotPaymentInvoice?, formInfo: BotPaymentRequestedInfo?, shippingOption: BotPaymentShippingOption?, paymentMethodTitle: String?, botPeer: EnginePeer?, tipAmount: Int64?) -> [BotReceiptEntry] {
    var entries: [BotReceiptEntry] = []
    
    var botName = ""
    if let botPeer = botPeer {
        botName = botPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
    }
    if let invoice = invoice {
        entries.append(.header(presentationData.theme, invoice, botName))
    }
    
    if let formInvoice = formInvoice {
        var totalPrice: Int64 = 0
        
        var index = 0
        for price in formInvoice.prices {
            entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: formInvoice.currency), index == 0, false))
            totalPrice += price.amount
            index += 1
        }
        
        var shippingOptionString: String?
        if let shippingOption = shippingOption {
            shippingOptionString = shippingOption.title
            
            for price in shippingOption.prices {
                entries.append(.price(index, presentationData.theme, price.label, formatCurrencyAmount(price.amount, currency: formInvoice.currency), index == 0, false))
                totalPrice += price.amount
                index += 1
            }
        }

        if let tipAmount = tipAmount, tipAmount != 0 {
            entries.append(.price(index, presentationData.theme, presentationData.strings.Checkout_TipItem, formatCurrencyAmount(tipAmount, currency: formInvoice.currency), index == 0, false))
            totalPrice += tipAmount
            index += 1
        }
        
        entries.append(.price(index, presentationData.theme, presentationData.strings.Checkout_TotalAmount, formatCurrencyAmount(totalPrice, currency: formInvoice.currency), true, true))
        
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
    
    private let receiptData = Promise<(BotPaymentInvoice, BotPaymentRequestedInfo?, BotPaymentShippingOption?, String?, TelegramMediaInvoice, Int64?)?>(nil)
    private var dataRequestDisposable: Disposable?

    private let actionButtonPanelNode: ASDisplayNode
    private let actionButtonPanelSeparator: ASDisplayNode
    private let actionButton: BotCheckoutActionButton
    
    init(controller: ItemListController?, navigationBar: NavigationBar, context: AccountContext, messageId: EngineMessage.Id, dismissAnimated: @escaping () -> Void) {
        self.context = context
        self.dismissAnimated = dismissAnimated
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let arguments = BotReceiptControllerArguments(account: context.account)
        
        let signal: Signal<(ItemListPresentationData, (ItemListNodeState, Any)), NoError> = combineLatest(
            context.sharedContext.presentationData,
            receiptData.get(),
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
            )
        )
        |> map { presentationData, receiptData, botPeer -> (ItemListPresentationData, (ItemListNodeState, Any)) in
            let nodeState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: botReceiptControllerEntries(presentationData: presentationData, invoice: receiptData?.4, formInvoice: receiptData?.0, formInfo: receiptData?.1, shippingOption: receiptData?.2, paymentMethodTitle: receiptData?.3, botPeer: botPeer, tipAmount: receiptData?.5), style: .blocks, focusItemTag: nil, emptyStateItem: nil, animateChanges: false)
            
            return (ItemListPresentationData(presentationData), (nodeState, arguments))
        }

        self.actionButtonPanelNode = ASDisplayNode()
        self.actionButtonPanelNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor

        self.actionButtonPanelSeparator = ASDisplayNode()
        self.actionButtonPanelSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.actionButton = BotCheckoutActionButton(activeFillColor: self.presentationData.theme.list.itemAccentColor, foregroundColor: self.presentationData.theme.list.plainBackgroundColor)
        self.actionButton.setState(.active(self.presentationData.strings.Common_Done))
        
        super.init(controller: controller, navigationBar: navigationBar, state: signal)
        
        self.dataRequestDisposable = (context.engine.payments.requestBotPaymentReceipt(messageId: messageId) |> deliverOnMainQueue).start(next: { [weak self] receipt in
            if let strongSelf = self {
                UIView.transition(with: strongSelf.view, duration: 0.25, options: UIView.AnimationOptions.transitionCrossDissolve, animations: {
                }, completion: nil)
                
                strongSelf.receiptData.set(.single((receipt.invoice, receipt.info, receipt.shippingOption, receipt.credentialsTitle, receipt.invoiceMedia, receipt.tipAmount)))
            }
        })
        
        self.actionButton.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)

        self.addSubnode(self.actionButtonPanelNode)
        self.actionButtonPanelNode.addSubnode(self.actionButtonPanelSeparator)
        self.actionButtonPanelNode.addSubnode(self.actionButton)
    }
    
    deinit {
        self.dataRequestDisposable?.dispose()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition, additionalInsets: UIEdgeInsets) {
        var updatedInsets = layout.intrinsicInsets

        let bottomPanelHorizontalInset: CGFloat = 16.0
        let bottomPanelVerticalInset: CGFloat = 16.0
        let bottomPanelHeight = max(updatedInsets.bottom, layout.inputHeight ?? 0.0) + bottomPanelVerticalInset * 2.0 + BotCheckoutActionButton.height

        transition.updateFrame(node: self.actionButtonPanelNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomPanelHeight), size: CGSize(width: layout.size.width, height: bottomPanelHeight)))
        transition.updateFrame(node: self.actionButtonPanelSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: UIScreenPixel)))

        let actionButtonFrame = CGRect(origin: CGPoint(x: bottomPanelHorizontalInset, y: bottomPanelVerticalInset), size: CGSize(width: layout.size.width - bottomPanelHorizontalInset * 2.0, height: BotCheckoutActionButton.height))
        transition.updateFrame(node: self.actionButton, frame: actionButtonFrame)
        self.actionButton.updateLayout(absoluteRect: actionButtonFrame.offsetBy(dx: self.actionButtonPanelNode.frame.minX, dy: self.actionButtonPanelNode.frame.minY), containerSize: layout.size, transition: transition)

        updatedInsets.bottom = bottomPanelHeight

        super.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: updatedInsets, safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationBarHeight, transition: transition, additionalInsets: additionalInsets)
    }
    
    @objc func actionButtonPressed() {
        self.dismissAnimated()
    }
}
