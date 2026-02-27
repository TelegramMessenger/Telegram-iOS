import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import GiftItemComponent
import ChatMessagePaymentAlertController
import TooltipUI
import MultilineTextComponent
import TelegramStringFormatting
import AlertComponent
import TableComponent
import AvatarComponent
import AlertTransferHeaderComponent
import AlertTableComponent

public func giftTransferAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    peer: EnginePeer,
    transferStars: Int64,
    navigationController: NavigationController?,
    commit: @escaping () -> Void
) -> AlertScreen {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let title = strings.Gift_Transfer_Confirmation_Title
    let text: String
    let buttonText: String
    if transferStars > 0 {
        text = strings.Gift_Transfer_Confirmation_Text("\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))", peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), strings.Gift_Transfer_Confirmation_Text_Stars(Int32(clamping: transferStars))).string
        buttonText = "\(strings.Gift_Transfer_Confirmation_Transfer)  $  \(transferStars)"
    } else {
        text = strings.Gift_Transfer_Confirmation_TextFree("\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))", peer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)).string
        buttonText = strings.Gift_Transfer_Confirmation_TransferFree
    }
    
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
    
    let alertController = ChatMessagePaymentAlertController(
        context: context,
        presentationData: presentationData,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical, dismissOnOutsideTap: true, allowInputInset: false),
        content: content,
        actions: [
            .init(title: buttonText, type: .default, action: {
                commit()
            }),
            .init(title: strings.Common_Cancel)
        ],
        navigationController: navigationController,
        chatPeerId: context.account.peerId,
        showBalance: transferStars > 0
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
