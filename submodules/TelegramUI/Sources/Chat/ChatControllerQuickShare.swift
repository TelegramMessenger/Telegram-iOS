import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import ContextUI
import QuickShareScreen

extension ChatControllerImpl {
    func displayQuickShare(id: EngineMessage.Id, node: ASDisplayNode, gesture: ContextGesture) {
        let controller = QuickShareScreen(
            context: self.context,
            sourceNode: node,
            gesture: gesture,
            openPeer: { [weak self] peerId in
                guard let self else {
                    return
                }
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self else {
                        return
                    }
                    self.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                })
            },
            completion: { [weak self] peerId in
                guard let self else {
                    return
                }
                let enqueueMessage = StandaloneSendEnqueueMessage(
                    content: .forward(forward: StandaloneSendEnqueueMessage.Forward(
                        sourceId: id,
                        threadId: nil
                    )),
                    replyToMessageId: nil
                )
                let _ = (standaloneSendEnqueueMessages(
                    accountPeerId: self.context.account.peerId,
                    postbox: self.context.account.postbox,
                    network: self.context.account.network,
                    stateManager: self.context.account.stateManager,
                    auxiliaryMethods: self.context.account.auxiliaryMethods,
                    peerId: peerId,
                    threadId: nil,
                    messages: [enqueueMessage]
                )).startStandalone()
            }
        )
        self.presentInGlobalOverlay(controller)
    }
}
