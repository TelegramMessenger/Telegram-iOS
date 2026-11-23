import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import ContextUI
import Pasteboard
import UndoUI
import OverlayStatusController
import PresentationDataUtils
import SupportUserInfoScreen

extension PeerInfoScreenNode {
    func openSupportInfoContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode, let info = self.data?.supportUserInfo else {
            return
        }

        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Common_Edit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                self?.openSupportInfoEditor()
            }
        })))
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                guard let self else {
                    return
                }
                storeMessageTextInPasteboard(info.text, entities: info.entities)
                self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.Support_Info_Copied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }
        })))

        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }

    func openSupportInfoEditor() {
        guard let supportContext = self.context.supportContext, case let .user(user) = self.data?.peer else {
            return
        }
        let context = self.context
        let peerId = user.id
        let presentationData = self.presentationData

        let progressSignal = Signal<Never, NoError> { [weak self] _ in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                self?.supportInfoEditDisposable.set(nil)
            }))
            self?.controller?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()

        self.supportInfoEditDisposable.set((context.engine.peers.refreshSupportUserInfo(peerId: peerId)
        |> deliverOnMainQueue
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }).start(error: { [weak self] _ in
            guard let self else {
                return
            }
            self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.Support_Info_LoadError, timeout: nil, customUndoText: nil), action: { _ in return false }), in: .current)
        }, completed: { [weak self] in
            let screen = SupportUserInfoScreen(context: context, peerId: peerId, info: supportContext.currentUserInfo(peerId: peerId))
            self?.controller?.present(screen, in: .window(.root))
        }))
    }
}
