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
    func presentPaidMessageAlertIfNeeded(count: Int32 = 1, forceDark: Bool = false, alwaysAsk: Bool = false, completion: @escaping (Bool) -> Void) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer.flatMap(EnginePeer.init) else {
            completion(false)
            return
        }
        guard let renderedPeer = self.presentationInterfaceState.renderedPeer.flatMap(EngineRenderedPeer.init) else {
            return
        }
        if let sendPaidMessageStars = self.presentationInterfaceState.sendPaidMessageStars, self.presentationInterfaceState.interfaceState.editMessage == nil {
            let totalAmount = sendPaidMessageStars.value * Int64(count)
            
            let _ = (ApplicationSpecificNotice.dismissedPaidMessageWarningNamespace(accountManager: self.context.sharedContext.accountManager, peerId: peer.id)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] dismissedAmount in
                guard let self, let starsContext = self.context.starsContext else {
                    return
                }
                if !alwaysAsk, let dismissedAmount, dismissedAmount == sendPaidMessageStars.value, let currentState = starsContext.currentState, currentState.balance.value > totalAmount {
                    if count < 3 && totalAmount < 100 {
                        completion(false)
                    } else {
                        completion(true)
                        self.displayPaidMessageUndo(count: count, amount: sendPaidMessageStars)
                    }
                } else {
                    var presentationData = self.presentationData
                    if forceDark {
                        presentationData = presentationData.withUpdated(theme: defaultDarkColorPresentationTheme)
                    }
                    var peer = peer
                    var renderedPeer = renderedPeer
                    if let peerDiscussionId = self.presentationInterfaceState.peerDiscussionId, let channel = self.contentData?.state.peerView?.peers[peerDiscussionId] {
                        peer = EnginePeer(channel)
                        renderedPeer = EngineRenderedPeer(peer: peer)
                    }
                    let controller = chatMessagePaymentAlertController(
                        context: self.context,
                        presentationData: presentationData,
                        updatedPresentationData: nil,
                        peers: [renderedPeer],
                        count: count,
                        amount: sendPaidMessageStars,
                        totalAmount: nil,
                        hasCheck: !alwaysAsk,
                        navigationController: self.navigationController as? NavigationController,
                        completion: { [weak self] dontAskAgain in
                            guard let self else {
                                return
                            }
                            
                            if dontAskAgain {
                                let _ = ApplicationSpecificNotice.setDismissedPaidMessageWarningNamespace(accountManager: self.context.sharedContext.accountManager, peerId: peer.id, amount: sendPaidMessageStars.value).start()
                            }
                            
                            if let currentState = starsContext.currentState, currentState.balance.value < totalAmount {
                                let _ = (self.context.engine.payments.starsTopUpOptions()
                                |> take(1)
                                |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                                    guard let self else {
                                        return
                                    }
                                    let controller = self.context.sharedContext.makeStarsPurchaseScreen(context: self.context, starsContext: starsContext, options: options, purpose: .sendMessage(peerId: peer.id, requiredStars: totalAmount), completion: { stars in
                                        starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                                        let _ = (starsContext.onUpdate
                                        |> deliverOnMainQueue).start(next: {
                                            completion(false)
                                        })
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
        
        let title = self.presentationData.strings.Chat_PaidMessage_Sent_Title(count)
        let text = self.presentationData.strings.Chat_PaidMessage_Sent_Text(self.presentationData.strings.Chat_PaidMessage_Sent_Text_Stars(Int32(amount.value * Int64(count)))).string
        let textItems: [AnimatedTextComponent.Item] = [
            AnimatedTextComponent.Item(id: 0, content: .text(text))
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
