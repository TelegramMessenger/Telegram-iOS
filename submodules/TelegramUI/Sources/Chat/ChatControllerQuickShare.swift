import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import ContextUI
import QuickShareScreen
import UndoUI
import ShareController

extension ChatControllerImpl {
    func displayQuickShare(id: EngineMessage.Id, node: ASDisplayNode, gesture: ContextGesture) {
        if node.view.accessibilityIdentifier == "bookmarkQuick" {
            self.displayQuickBookmarks(id: id, node: node, gesture: gesture)
            return
        }
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

    // New: Quick picker for Bookmarks topics
    func displayQuickBookmarks(id: EngineMessage.Id, node: ASDisplayNode, gesture: ContextGesture) {
        let controller = QuickBookmarksScreen(context: self.context, sourceNode: node, gesture: gesture, completion: { [weak self] peer, threadId, sourceFrame, title in
            guard let self else { return }
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
                    guard let self else { return }
                    if case .commit = action {
                        let enqueueMessage = StandaloneSendEnqueueMessage(
                            content: .forward(forward: StandaloneSendEnqueueMessage.Forward(
                                sourceId: id,
                                threadId: threadId
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
                            threadId: threadId,
                            messages: [enqueueMessage]
                        )).startStandalone()
                    }
                }
            )
            self.present(toastScreen, in: .window(.root))
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(title).string
            self.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        })
        self.presentInGlobalOverlay(controller)
    }
}
