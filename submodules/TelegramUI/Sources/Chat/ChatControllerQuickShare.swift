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
            completion: { [weak self] peer, sourceFrame in
                guard let self else {
                    return
                }
                self.window?.forEachController({ controller in
                    if let controller = controller as? QuickShareToastScreen {
                        controller.dismissWithCommitAction()
                    }
                })
                let toastScreen = QuickShareToastScreen(
                    context: self.context,
                    peer: peer,
                    sourceFrame: sourceFrame,
                    action: { [weak self] action in
                        guard let self else {
                            return
                        }
                        switch action {
                        case .info:
                            self.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                        case .commit:
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
                                peerId: peer.id,
                                threadId: nil,
                                messages: [enqueueMessage]
                            )).startStandalone()
                        }
                    }
                )
                self.present(toastScreen, in: .window(.root))
            }
        )
        self.presentInGlobalOverlay(controller)
    }
}
