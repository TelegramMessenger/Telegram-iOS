import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import AlertComponent
import AlertTransferHeaderComponent
import GiftItemComponent
import AvatarComponent

public func giftThemeTransferAlertController(
    context: AccountContext,
    gift: StarGift.UniqueGift,
    previousPeer: EnginePeer,
    commit: @escaping () -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
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
                toComponent: AnyComponentWithIdentity(id: "user", component: AnyComponent(
                    AvatarComponent(
                        context: context,
                        theme: presentationData.theme,
                        peer: previousPeer
                    )
                )),
                type: .take
            )
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Conversation_Theme_GiftTransfer_Text(previousPeer.compactDisplayTitle).string))
        )
    ))
    
    let alertController = AlertScreen(
        context: context,
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.Conversation_Theme_GiftTransfer_Proceed, type: .default, action: {
                commit()
            })
        ]
    )
    return alertController
}
