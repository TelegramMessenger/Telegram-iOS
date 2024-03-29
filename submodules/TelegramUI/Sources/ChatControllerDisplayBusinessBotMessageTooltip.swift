import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import PresentationDataUtils
import ChatMessageItemView
import TelegramNotices

extension ChatControllerImpl {
    func displayBusinessBotMessageTooltip(itemNode: ChatMessageItemView) {
        let _ = (ApplicationSpecificNotice.getBusinessBotMessageTooltip(accountManager: self.context.sharedContext.accountManager)
        |> deliverOnMainQueue).startStandalone(next: { [weak self, weak itemNode] value in
            guard let self, let itemNode else {
                return
            }
            if value >= 2 {
                return
            }
            
            guard let statusNode = itemNode.getStatusNode() else {
                return
            }
            
            let bounds = statusNode.view.convert(statusNode.view.bounds, to: self.chatDisplayNode.view)
            let location = CGPoint(x: bounds.midX, y: bounds.minY - 11.0)
            
            let tooltipController = TooltipController(content: .text(self.presentationData.strings.Chat_BusinessBotMessageTooltip), baseFontSize: self.presentationData.listsFontSize.baseDisplaySize, balancedTextLayout: true, timeout: 3.5, dismissByTapOutside: true, dismissImmediatelyOnLayoutUpdate: true)
            self.checksTooltipController = tooltipController
            tooltipController.dismissed = { [weak self, weak tooltipController] _ in
                if let strongSelf = self, let tooltipController = tooltipController, strongSelf.checksTooltipController === tooltipController {
                    strongSelf.checksTooltipController = nil
                }
            }
            
            let _ = self.chatDisplayNode.messageTransitionNode.addCustomOffsetHandler(itemNode: itemNode, update: { [weak tooltipController] offset, transition in
                guard let tooltipController, tooltipController.isNodeLoaded else {
                    return false
                }
                guard let containerView = tooltipController.view else {
                    return false
                }
                containerView.bounds = containerView.bounds.offsetBy(dx: 0.0, dy: -offset)
                transition.animateOffsetAdditive(layer: containerView.layer, offset: offset)
                
                return true
            })
            
            self.present(tooltipController, in: .current, with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                guard let self else {
                    return nil
                }
                return (self.chatDisplayNode, CGRect(origin: location, size: CGSize()))
            }))
            
            #if DEBUG
            if "".isEmpty {
                return
            }
            #endif
            let _ = ApplicationSpecificNotice.incrementBusinessBotMessageTooltip(accountManager: self.context.sharedContext.accountManager).startStandalone()
        })
    }
}
