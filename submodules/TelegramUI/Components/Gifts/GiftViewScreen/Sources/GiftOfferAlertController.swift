import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import GiftItemComponent
import TooltipUI
import MultilineTextComponent
import BundleIconComponent
import TelegramStringFormatting
import AlertComponent
import TableComponent
import AvatarComponent
import AlertTransferHeaderComponent
import AlertTableComponent

public func giftOfferAlertController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    gift: StarGift.UniqueGift,
    peer: EnginePeer,
    amount: CurrencyAmount,
    commit: @escaping () -> Void
) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let title = strings.Chat_GiftPurchaseOffer_AcceptConfirmation_Title
    let buttonText: String = strings.Chat_GiftPurchaseOffer_AcceptConfirmation_Confirm
    
    let priceString: String
    switch amount.currency {
    case .stars:
        priceString = strings.Chat_GiftPurchaseOffer_AcceptConfirmation_Text_Stars(Int32(clamping: amount.amount.value))
    case .ton:
        priceString = formatTonAmountText(amount.amount.value, dateTimeFormat: presentationData.dateTimeFormat) + " TON"
    }
    
    let resaleConfiguration = StarsSubscriptionConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    let finalPriceString: String
    switch amount.currency {
    case .stars:
        let starsValue = Int32(floor(Float(amount.amount.value) * Float(resaleConfiguration.starGiftCommissionStarsPermille) / 1000.0))
        finalPriceString = strings.Chat_GiftPurchaseOffer_AcceptConfirmation_Text_Stars(starsValue)
    case .ton:
        let tonValue = Int64(Float(amount.amount.value) * Float(resaleConfiguration.starGiftCommissionTonPermille) / 1000.0)
        finalPriceString = formatTonAmountText(tonValue, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: 3) + " TON"
    }
    
    let giftTitle = "\(gift.title) #\(formatCollectibleNumber(gift.number, dateTimeFormat: presentationData.dateTimeFormat))"
    let text = strings.Chat_GiftPurchaseOffer_AcceptConfirmation_Text(giftTitle, peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), priceString, finalPriceString).string
    
    let tableFont = Font.regular(15.0)
    let tableTextColor = presentationData.theme.list.itemPrimaryTextColor
    
    let modelButtonTag = GenericComponentViewTag()
    let backdropButtonTag = GenericComponentViewTag()
    let symbolButtonTag = GenericComponentViewTag()
    var showAttributeInfoImpl: ((Any, String) -> Void)?
    
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
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
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
            AlertTitleComponent(title: title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(text))
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "table",
        component: AnyComponent(
            AlertTableComponent(items: tableItems)
        )
    ))
    
    if let valueAmount = gift.valueUsdAmount {
        let resaleConfiguration = StarsSubscriptionConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        
        let usdRate: Double
        switch amount.currency {
        case .stars:
            usdRate = Double(resaleConfiguration.usdWithdrawRate) / 1000.0 / 100.0
        case .ton:
            usdRate = Double(resaleConfiguration.tonUsdRate) / 1000.0 / 1000000.0
        }
        let offerUsdValue = Double(amount.amount.value) * usdRate
        let giftUsdValue = Double(valueAmount) / 100.0
        
        let fraction = giftUsdValue / offerUsdValue
        let percentage = Int(fraction * 100) - 100
        
        if percentage > 20 {
            let warningText = strings.Chat_GiftPurchaseOffer_AcceptConfirmation_BadValue("\(percentage)%").string
            content.append(AnyComponentWithIdentity(
                id: "warning",
                component: AnyComponent(
                    AlertTextComponent(content: .plain(warningText), color: .destructive, style: .plain(.small))
                )
            ))
        }
    }
    
    let updatedPresentationDataSignal = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(actionAlignment: .vertical, dismissOnOutsideTap: true, allowInputInset: false),
        content: content,
        actions: [
            .init(title: buttonText, type: .default, action: {
                commit()
            }),
            .init(title: strings.Common_Cancel)
        ],
        updatedPresentationData: (initial: presentationData, signal: updatedPresentationDataSignal)
    )

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
    return alertController
}
