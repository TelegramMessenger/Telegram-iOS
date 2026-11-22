import Foundation
import TelegramPresentationData
import AccountContext
import TelegramCore
import SwiftSignalKit
import Display
import PresentationDataUtils
import ChatMessageItemView
import TelegramNotices
import TooltipUI

extension ChatControllerImpl {
    func displayGuestChatMessageTooltip(itemNode: ChatMessageItemView) {
        let _ = (ApplicationSpecificNotice.getGuestChatMessageTooltip(accountManager: self.context.sharedContext.accountManager)
        |> deliverOnMainQueue).startStandalone(next: { [weak self, weak itemNode] value in
            guard let self, let itemNode else {
                return
            }
                        
            if value >= 2 {
                return
            }
            
            guard let sourceNode = itemNode.getAuthorNameNode() else {
                return
            }
            
            Queue.mainQueue().after(0.5) { [weak self] in
                guard let self else {
                    return
                }

                let sourceRect = sourceNode.view.convert(sourceNode.view.bounds, to: nil)
                
                self.messageTooltipController?.dismiss()
                self.guestChatMessageTooltipController?.dismiss()
                
                let tooltipScreen = TooltipScreen(
                    account: self.context.account,
                    sharedContext: self.context.sharedContext,
                    text: .plain(text: self.presentationData.strings.Chat_GuestChatMessageTooltip),
                    balancedTextLayout: true,
                    location: .point(sourceRect, .bottom),
                    displayDuration: .custom(3.5),
                    shouldDismissOnTouch: { _, _ in
                        return .dismiss(consume: false)
                    }
                )
                self.guestChatMessageTooltipController = tooltipScreen
                tooltipScreen.becameDismissed = { [weak self, weak tooltipScreen] _ in
                    if let strongSelf = self, let tooltipScreen, strongSelf.guestChatMessageTooltipController === tooltipScreen {
                        strongSelf.guestChatMessageTooltipController = nil
                    }
                }
                                
                self.present(tooltipScreen, in: .current)
                
                let _ = ApplicationSpecificNotice.incrementGuestChatMessageTooltip(accountManager: self.context.sharedContext.accountManager).startStandalone()
            }
        })
    }
}
