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

public func giftPurchaseAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    peer: EnginePeer,
    animateBalanceOverlay: Bool = false,
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
        return content
    }
    
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
            commit(currency)
        }))
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
