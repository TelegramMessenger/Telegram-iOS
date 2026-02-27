import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import AvatarNode
import GiftItemComponent
import ChatMessagePaymentAlertController
import TabSelectorComponent
import BundleIconComponent
import MultilineTextComponent
import TelegramStringFormatting
import TooltipUI
import AlertComponent
import AlertTransferHeaderComponent
import AvatarComponent
import AlertTableComponent
import TableComponent

public func giftPurchaseAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    showAttributes: Bool,
    peer: EnginePeer,
    animateBalanceOverlay: Bool = false,
    autoDismissOnCommit: Bool = true,
    navigationController: NavigationController?,
    commit: @escaping (CurrencyAmount.Currency) -> Void,
    dismissed: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let currencyPromise = ValuePromise<CurrencyAmount.Currency>(.stars)
    if gift.resellForTonOnly {
        currencyPromise.set(.ton)
    }
    
    var showAttributeInfoImpl: ((Any, String) -> Void)?
    
    let contentSignal = currencyPromise.get()
    |> map { currency in
        var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
        if gift.resellForTonOnly {
            content.append(AnyComponentWithIdentity(
                id: "tonOnly",
                component: AnyComponent(
                    AlertTextComponent(
                        content: .plain(strings.Gift_Buy_AcceptsTonOnly),
                        alignment: .center,
                        color: .secondary,
                        style: .plain(.small),
                        insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 8.0, right: 0.0)
                    )
                )
            ))
        } else {
            content.append(AnyComponentWithIdentity(
                id: "currency",
                component: AnyComponent(
                    AlertCurrencyComponent(
                        currency: currency,
                        updatedCurrency: { currency in
                            currencyPromise.set(currency)
                        }
                    )
                )
            ))
        }
        
        content.append(AnyComponentWithIdentity(
            id: "header",
            component: AnyComponent(
                AlertTransferHeaderComponent(
                    fromComponent: AnyComponentWithIdentity(id: "gift", component: AnyComponent(
                        GiftItemComponent(
                            context: context,
                            theme: presentationData.theme,
                            strings: strings,
                            peer: nil,
                            subject: .uniqueGift(gift: gift, price: nil),
                            mode: .thumbnail
                        )
                    )),
                    toComponent: AnyComponentWithIdentity(id: "avatar", component: AnyComponent(
                        AvatarComponent(
                            context: context,
                            theme: presentationData.theme,
                            peer: peer
                        )
                    )),
                    type: .transfer
                )
            )
        ))
        content.append(AnyComponentWithIdentity(
            id: "title",
            component: AnyComponent(
                AlertTitleComponent(title: strings.Gift_Buy_Confirm_Title)
            )
        ))
                
        let giftTitle = "\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))"
        var priceString = ""
        switch currency {
        case .stars:
            if let resellAmount = gift.resellAmounts?.first(where: { $0.currency == .stars }) {
                priceString = strings.Gift_Buy_Confirm_Text_Stars(Int32(clamping: resellAmount.amount.value))
            }
        case .ton:
            if let resellAmount = gift.resellAmounts?.first(where: { $0.currency == .ton }) {
                priceString = "**\(formatTonAmountText(resellAmount.amount.value, dateTimeFormat: presentationData.dateTimeFormat)) TON**"
            }
        }
    
        let text: String
        if peer.id == context.account.peerId {
            text = strings.Gift_Buy_Confirm_Text(giftTitle, priceString).string
        } else {
            text = strings.Gift_Buy_Confirm_GiftText(giftTitle, priceString, peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)).string
        }
        content.append(AnyComponentWithIdentity(
            id: "text",
            component: AnyComponent(
                AlertTextComponent(content: .plain(text))
            )
        ))
        
        if showAttributes {
            let tableFont = Font.regular(15.0)
            let tableTextColor = presentationData.theme.list.itemPrimaryTextColor
            
            let modelButtonTag = GenericComponentViewTag()
            let backdropButtonTag = GenericComponentViewTag()
            let symbolButtonTag = GenericComponentViewTag()
            
            var tableItems: [TableComponent.Item] = []
            let order: [StarGift.UniqueGift.Attribute.AttributeType] = [
                .model, .pattern, .backdrop, .originalInfo
            ]
            
            var attributeMap: [StarGift.UniqueGift.Attribute.AttributeType: StarGift.UniqueGift.Attribute] = [:]
            for attribute in gift.attributes {
                attributeMap[attribute.attributeType] = attribute
            }
            
            for type in order {
                if let attribute = attributeMap[type] {
                    let id: String?
                    let title: String?
                    let value: NSAttributedString
                    let percentage: Float?
                    let tag: AnyObject?
                    
                    switch attribute {
                    case let .model(name, _, rarity, _):
                        id = "model"
                        title = strings.Gift_Unique_Model
                        value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                        percentage = Float(rarity.permilleValue) * 0.1
                        tag = modelButtonTag
                    case let .backdrop(name, _, _, _, _, _, rarity):
                        id = "backdrop"
                        title = strings.Gift_Unique_Backdrop
                        value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                        percentage = Float(rarity.permilleValue) * 0.1
                        tag = backdropButtonTag
                    case let .pattern(name, _, rarity):
                        id = "pattern"
                        title = strings.Gift_Unique_Symbol
                        value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                        percentage = Float(rarity.permilleValue) * 0.1
                        tag = symbolButtonTag
                    case .originalInfo:
                        continue
                    }
                    
                    var items: [AnyComponentWithIdentity<Empty>] = []
                    items.append(
                        AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(value))
                            )
                        )
                    )
                    if let percentage, let tag {
                        items.append(AnyComponentWithIdentity(
                            id: AnyHashable(1),
                            component: AnyComponent(Button(
                                content: AnyComponent(ButtonContentComponent(
                                    context: context,
                                    text: formatPercentage(percentage),
                                    color: presentationData.theme.list.itemAccentColor
                                )),
                                action: {
                                    showAttributeInfoImpl?(tag, strings.Gift_Unique_AttributeDescription(formatPercentage(percentage)).string)
                                }
                            ).tagged(tag))
                        ))
                    }
                    let itemComponent = AnyComponent(
                        HStack(items, spacing: 4.0)
                    )
                    
                    tableItems.append(.init(
                        id: id,
                        title: title,
                        hasBackground: false,
                        component: itemComponent
                    ))
                }
            }
            content.append(AnyComponentWithIdentity(
                id: "table",
                component: AnyComponent(
                    AlertTableComponent(items: tableItems)
                )
            ))
        }
        
        return content
    }
    
    let actionProgress = ValuePromise<Bool>(false)
    let actionsSignal = currencyPromise.get()
    |> map { currency in
        var actions: [AlertScreen.Action] = []
        var buyString = ""
        switch currency {
        case .stars:
            if let resellAmount = gift.resellAmounts?.first(where: { $0.currency == .stars }) {
                buyString = strings.Gift_Buy_Confirm_BuyFor(Int32(resellAmount.amount.value))
            }
        case .ton:
            if let resellAmount = gift.resellAmounts?.first(where: { $0.currency == .ton }) {
                buyString = strings.Gift_Buy_Confirm_BuyForTon(formatTonAmountText(resellAmount.amount.value, dateTimeFormat: presentationData.dateTimeFormat)).string
            }
        }
        actions.append(.init(id: "buy", title: buyString, type: .default, action: {
            if !autoDismissOnCommit {
                actionProgress.set(true)
            }
            commit(currency)
        }, autoDismiss: autoDismissOnCommit, progress: actionProgress.get()))
        actions.append(.init(title: strings.Common_Cancel))
        return actions
    }
    
    let alertController = ChatMessagePaymentAlertController(
        context: context,
        presentationData: presentationData,
        updatedPresentationData: (presentationData, context.sharedContext.presentationData),
        configuration: AlertScreen.Configuration(actionAlignment: .vertical, dismissOnOutsideTap: true, allowInputInset: false),
        contentSignal: contentSignal,
        actionsSignal: actionsSignal,
        navigationController: navigationController,
        chatPeerId: context.account.peerId,
        showBalance: true,
        currencySignal: currencyPromise.get(),
        animateBalanceOverlay: animateBalanceOverlay
    )
    alertController.dismissed = { _ in
        dismissed()
    }
    
    var dismissAllTooltipsImpl: (() -> Void)?
    showAttributeInfoImpl = { [weak alertController] tag, text in
        dismissAllTooltipsImpl?()
        guard let alertController, let sourceView = alertController.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: alertController.view) else {
            return
        }
        
        let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 12.0), size: CGSize())
        let tooltipController = TooltipScreen(account: context.account, sharedContext: context.sharedContext, text: .plain(text: text), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
            return .dismiss(consume: false)
        })
        alertController.present(tooltipController, in: .current)
    }
    dismissAllTooltipsImpl = { [weak alertController] in
        guard let alertController else {
            return
        }
        alertController.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
        })
        alertController.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            return true
        })
    }

//    if !gift.resellForTonOnly {
//        Queue.mainQueue().after(0.3) {
//            if let headerView = contentNode?.header.view as? TabSelectorComponent.View {
//                let absoluteFrame = headerView.convert(headerView.bounds, to: nil)
//                var originX = absoluteFrame.width * 0.75
//                if let itemFrame = headerView.frameForItem(AnyHashable(1)) {
//                    originX = itemFrame.midX
//                }
//                let location = CGRect(origin: CGPoint(x: absoluteFrame.minX + floor(originX), y: absoluteFrame.minY - 8.0), size: CGSize())
//                let tooltipController = TooltipScreen(account: context.account, sharedContext: context.sharedContext, text: .plain(text: presentationData.strings.Gift_Buy_PayInTon_Tooltip), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
//                    return .dismiss(consume: false)
//                })
//                controller.present(tooltipController, in: .window(.root))
//            }
//        }
//    }
    
    return alertController
}

private final class AlertCurrencyComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment

    let currency: CurrencyAmount.Currency
    let updatedCurrency: (CurrencyAmount.Currency) -> Void
    
    public init(
        currency: CurrencyAmount.Currency,
        updatedCurrency: @escaping (CurrencyAmount.Currency) -> Void
    ) {
        self.currency = currency
        self.updatedCurrency = updatedCurrency
    }

    public static func ==(lhs: AlertCurrencyComponent, rhs: AlertCurrencyComponent) -> Bool {
        if lhs.currency != rhs.currency {
            return false
        }
        return true
    }

    final class View: UIView {
        private let header = ComponentView<Empty>()

        private var component: AlertCurrencyComponent?
        private weak var state: EmptyComponentState?

        func update(component: AlertCurrencyComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let environment = environment[AlertComponentEnvironment.self]

            let headerSize = self.header.update(
                transition: transition,
                component: AnyComponent(TabSelectorComponent(
                    colors: TabSelectorComponent.Colors(
                        foreground: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.35),
                        selection: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1),
                        simple: true
                    ),
                    theme: environment.theme,
                    customLayout: TabSelectorComponent.CustomLayout(
                        font: Font.medium(14.0),
                        spacing: 10.0
                    ),
                    items: [
                        TabSelectorComponent.Item(
                            id: AnyHashable(0),
                            content: .text(environment.strings.Gift_Buy_PayInStars)
                        ),
                        TabSelectorComponent.Item(
                            id: AnyHashable(1),
                            content: .text(environment.strings.Gift_Buy_PayInTon)
                        )
                    ],
                    selectedId: component.currency == .ton ? AnyHashable(1) : AnyHashable(0),
                    setSelectedId: { [weak self] id in
                        guard let self, let component = self.component else {
                            return
                        }
                        let currency: CurrencyAmount.Currency
                        if id == AnyHashable(0) {
                            currency = .stars
                        } else {
                            currency = .ton
                        }
                        if currency != component.currency {
                            component.updatedCurrency(currency)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width + 54.0, height: 100.0)
            )
            
            let headerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - headerSize.width) / 2.0), y: 0.0), size: headerSize)
            if let view = self.header.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = headerFrame
            }
            
            return CGSize(width: availableSize.width, height: headerSize.height + 12.0)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
