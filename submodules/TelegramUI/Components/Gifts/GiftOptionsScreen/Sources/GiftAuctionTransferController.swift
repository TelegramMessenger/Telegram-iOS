import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import AlertComponent
import AlertTransferHeaderComponent
import AvatarComponent

func giftAuctionTransferController(context: AccountContext, fromPeer: EnginePeer, toPeer: EnginePeer, commit: @escaping () -> Void) -> AlertScreen {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    let title = strings.Gift_AuctionTransfer_Title
    let text: String
    if fromPeer.id == context.account.peerId {
        text = strings.Gift_AuctionTransfer_TextFromYourself(toPeer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)).string
    } else if toPeer.id == context.account.peerId {
        text = strings.Gift_AuctionTransfer_TextToYourself(fromPeer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)).string
    } else {
        text = strings.Gift_AuctionTransfer_Text(fromPeer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder), toPeer.displayTitle(strings: strings, displayOrder: presentationData.nameDisplayOrder)).string
    }
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "header",
        component: AnyComponent(
            AlertTransferHeaderComponent(
                fromComponent: AnyComponentWithIdentity(id: "fromPeer", component: AnyComponent(
                    AvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: fromPeer
                    )
                )),
                toComponent: AnyComponentWithIdentity(id: "toPeer", component: AnyComponent(
                    AvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: toPeer
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
    
    let alertController = AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical, dismissOnOutsideTap: true, allowInputInset: false),
        content: content,
        actions: [
            .init(title: strings.Gift_AuctionTransfer_Change, type: .default, action: {
                commit()
            }),
            .init(title: strings.Common_Cancel)
        ]
    )
    return alertController
}
