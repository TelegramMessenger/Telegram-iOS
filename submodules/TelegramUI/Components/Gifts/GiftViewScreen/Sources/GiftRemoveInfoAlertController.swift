import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import ChatMessagePaymentAlertController
import TelegramStringFormatting
import TextFormat
import AlertComponent

public func giftRemoveInfoAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    peers: [EnginePeer.Id: EnginePeer],
    removeInfoStars: Int64,
    navigationController: NavigationController?,
    commit: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Gift_RemoveDetails_Title)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Gift_RemoveDetails_Text))
        )
    ))
    
    for attribute in gift.attributes {
        if case let .originalInfo(senderPeerId, recipientPeerId, date, text, entities) = attribute {
            let textColor = presentationData.theme.actionSheet.primaryTextColor
            let linkColor = presentationData.theme.actionSheet.controlAccentColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let italicTextFont = Font.italic(15.0)
            let boldItalicTextFont = Font.with(size: 15.0, weight: .semibold, traits: .italic)
            let fixedTextFont = Font.monospace(15.0)
            
            let senderName = senderPeerId.flatMap { peers[$0]?.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder) }
            let recipientName = peers[recipientPeerId]?.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder) ?? ""
            
            let dateString = stringForMediumDate(timestamp: date, strings: strings, dateTimeFormat: presentationData.dateTimeFormat, withTime: false)
            let value: NSAttributedString
            if let text {
                let attributedText = stringWithAppliedEntities(text, entities: entities ?? [], baseColor: textColor, linkColor: linkColor, baseFont: textFont, linkFont: textFont, boldFont: boldTextFont, italicFont: italicTextFont, boldItalicFont: boldItalicTextFont, fixedFont: fixedTextFont, blockQuoteFont: textFont, message: nil)
                
                let format = senderName != nil ? strings.Gift_Unique_OriginalInfoSenderWithText(senderName!, recipientName, dateString, "") : strings.Gift_Unique_OriginalInfoWithText(recipientName, dateString, "")
                let string = NSMutableAttributedString(string: format.string, font: textFont, textColor: textColor)
                string.replaceCharacters(in: format.ranges[format.ranges.count - 1].range, with: attributedText)
                if let _ = senderPeerId {
                    string.addAttribute(.foregroundColor, value: linkColor, range: format.ranges[0].range)
                    string.addAttribute(.foregroundColor, value: linkColor, range: format.ranges[1].range)
                } else {
                    string.addAttribute(.foregroundColor, value: linkColor, range: format.ranges[0].range)
                }
                value = string
            } else {
                let format = senderName != nil ? strings.Gift_Unique_OriginalInfoSender(senderName!, recipientName, dateString) : strings.Gift_Unique_OriginalInfo(recipientName, dateString)
                let string = NSMutableAttributedString(string: format.string, font: textFont, textColor: textColor)
                if let _ = senderPeerId {
                    string.addAttribute(.foregroundColor, value: linkColor, range: format.ranges[0].range)
                    string.addAttribute(.foregroundColor, value: linkColor, range: format.ranges[1].range)
                } else {
                    string.addAttribute(.foregroundColor, value: linkColor, range: format.ranges[0].range)
                }
                
                value = string
            }
            
            content.append(AnyComponentWithIdentity(
                id: "info",
                component: AnyComponent(
                    AlertTextComponent(content: .attributed(value), style: .background(.small))
                )
            ))
        }
    }
        
    let alertController = ChatMessagePaymentAlertController(
        context: context,
        presentationData: presentationData,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        content: content,
        actions: [
            .init(title: strings.Gift_RemoveDetails_Action(" $  \(presentationStringsFormattedNumber(Int32(clamping: removeInfoStars), presentationData.dateTimeFormat.groupingSeparator))").string, type: .default, action: {
                commit()
            }),
            .init(title: strings.Common_Cancel)
        ],
        navigationController: navigationController,
        chatPeerId: context.account.peerId,
        showBalance: removeInfoStars > 0
    )
    return alertController
}
