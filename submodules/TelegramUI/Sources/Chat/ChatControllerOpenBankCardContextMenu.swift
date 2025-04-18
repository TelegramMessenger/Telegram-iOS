import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import ContextUI
import UndoUI
import AccountContext
import ChatMessageItemView
import ChatMessageItemCommon
import ChatControllerInteraction

extension ChatControllerImpl {
    func openBankCardContextMenu(number: String, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let contentNode = params.contentNode else {
            return
        }
                
        guard let messages = self.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) else {
            return
        }
        
        var updatedMessages = messages
        for i in 0 ..< updatedMessages.count {
            if updatedMessages[i].id == message.id {
                let message = updatedMessages.remove(at: i)
                updatedMessages.insert(message, at: 0)
                break
            }
        }
        
        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil// anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
        let gesture: ContextGesture? = nil // anyRecognizer as? ContextGesture
                                           
        let source: ContextContentSource
//                if let location = location {
//                    source = .location(ChatMessageContextLocationContentSource(controller: self, location: messageNode.view.convert(messageNode.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
//                } else {
            source = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))
//                }
        
        params.progress?.set(.single(true))
        
        let _ = (self.context.engine.payments.getBankCardInfo(cardNumber: number)
        |> deliverOnMainQueue).start(next: { [weak self] info in
            guard let self else {
                return
            }
            params.progress?.set(.single(false))
            
            var items: [ContextMenuItem] = []
            
            items.append(
                .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Card_Copy, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                    f(.default)

                    guard let self else {
                        return
                    }
                    
                    UIPasteboard.general.string = number

                    self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: presentationData.strings.Conversation_CardNumberCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }))
            )
            
            if let info {
                items.append(.separator)
                let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
                items.append(.action(ContextMenuActionItem(text: info.title, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction)))
            }
             
            self.canReadHistory.set(false)
            
            let controller = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture, disableScreenshots: false)
            controller.dismissed = { [weak self] in
                self?.canReadHistory.set(true)
            }
            
            self.window?.presentInGlobalOverlay(controller)
        })
    }
}
