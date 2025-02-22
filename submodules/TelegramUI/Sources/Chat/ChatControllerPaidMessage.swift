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
import ChatControllerInteraction
import AnimatedTextComponent
import ChatMessagePaymentAlertController
import TelegramPresentationData
import TelegramNotices

extension ChatControllerImpl {
    func presentPaidMessageAlertIfNeeded(count: Int32 = 1, forceDark: Bool = false, completion: @escaping (Bool) -> Void) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer.flatMap(EnginePeer.init) else {
            completion(false)
            return
        }
        if let sendPaidMessageStars = self.presentationInterfaceState.sendPaidMessageStars {
            let _ = (ApplicationSpecificNotice.dismissedPaidMessageWarningNamespace(accountManager: self.context.sharedContext.accountManager, peerId: peer.id)
            |> deliverOnMainQueue).start(next: { [weak self] dismissedAmount in
                guard let self else {
                    return
                }
                if let dismissedAmount, dismissedAmount == sendPaidMessageStars.value {
                    completion(true)
                    self.displayPaidMessageUndo(count: count, amount: sendPaidMessageStars)
                } else {
                    var presentationData = self.presentationData
                    if forceDark {
                        presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                    }
                    let controller = chatMessagePaymentAlertController(
                        context: self.context,
                        presentationData: presentationData,
                        updatedPresentationData: nil,//self.updatedPresentationData,
                        peers: [peer],
                        count: count,
                        amount: sendPaidMessageStars,
                        totalAmount: nil,
                        navigationController: self.navigationController as? NavigationController,
                        completion: { [weak self] dontAskAgain in
                            guard let self, let starsContext = self.context.starsContext else {
                                return
                            }
                            
                            if dontAskAgain {
                                let _ = ApplicationSpecificNotice.setDismissedPaidMessageWarningNamespace(accountManager: self.context.sharedContext.accountManager, peerId: peer.id, amount: sendPaidMessageStars.value).start()
                            }
                            
                            if let currentState = starsContext.currentState, currentState.balance < sendPaidMessageStars {
                                let _ = (self.context.engine.payments.starsTopUpOptions()
                                |> take(1)
                                |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                                    guard let self else {
                                        return
                                    }
                                    let controller = self.context.sharedContext.makeStarsPurchaseScreen(context: self.context, starsContext: starsContext, options: options, purpose: .sendMessage(peerId: peer.id, requiredStars: sendPaidMessageStars.value), completion: { _ in
                                        completion(false)
                                    })
                                    self.push(controller)
                                })
                            } else {
                                completion(false)
                            }
                        }
                    )
                    self.present(controller, in: .window(.root))
                }
            })
        } else {
            completion(false)
        }
    }
    
    func displayPaidMessageUndo(count: Int32, amount: StarsAmount) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        
        if let current = self.currentPaidMessageUndoController {
            self.currentPaidMessageUndoController = nil
            current.dismiss()
            
            self.context.engine.messages.forceSendPostponedPaidMessage(peerId: peerId)
        }
        
        //TODO:localize
        let title: String
        if count > 1 {
            title = "\(count) Messages Sent"
        } else {
            title = "Message Sent"
        }
       
        let textItems: [AnimatedTextComponent.Item] = [
            AnimatedTextComponent.Item(id: 0, content: .text("You paid \(amount.value * Int64(count)) Stars"))
        ]
        
        let controller = UndoOverlayController(presentationData: self.presentationData, content: .starsSent(context: self.context, title: title, text: textItems), elevatedLayout: false, position: .top, action: { [weak self] action in
            guard let self else {
                return false
            }
            if case .undo = action {
                var messageIds: [MessageId] = []
                self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemNodeProtocol {
                        for message in itemNode.messages() {
                            if message.id.namespace == Namespaces.Message.Local {
                                messageIds.append(message.id)
                            }
                        }
                    }
                }
                let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: .forLocalPeer).startStandalone()
            }
            return false
        })
        self.currentPaidMessageUndoController = controller
        self.present(controller, in: .current)
    }
}
