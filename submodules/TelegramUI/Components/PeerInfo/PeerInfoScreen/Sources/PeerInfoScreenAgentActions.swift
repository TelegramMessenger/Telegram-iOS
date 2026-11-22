import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import ContextUI
import UndoUI
import AgentConnectScreen

extension PeerInfoScreenNode {
    func openAgentConnect() {
        guard let controller = self.controller, let settingsContext = self.data?.agentSettingsContext else {
            return
        }
        let botPeer = self.data?.peer
        let screen = AgentConnectScreen(context: self.context, settingsContext: settingsContext, completion: { [weak self] provider in
            guard let self else {
                return
            }
            let presentationData = self.presentationData
            let botName = botPeer?.addressName.flatMap { "@\($0)" } ?? botPeer?.compactDisplayTitle ?? ""
            Queue.mainQueue().after(0.4, { [weak self] in
                guard let self else {
                    return
                }
                self.controller?.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(title: presentationData.strings.Agent_Connected_Title(provider.title).string, text: presentationData.strings.Agent_Connected_Text(botName).string, cancel: presentationData.strings.Agent_Connected_Start, destructive: false),
                    elevatedLayout: false,
                    action: { [weak self] action in
                        if case .undo = action {
                            self?.openChat(peerId: nil)
                        }
                        return true
                    }
                ), in: .current)
            })
        })
        controller.push(screen)
    }

    func setAgentActiveProvider(_ provider: String) {
        guard let settingsContext = self.data?.agentSettingsContext, let settings = self.data?.agentState?.settings, settings.keys.count > 1, settings.activeProvider != provider else {
            return
        }
        let _ = (settingsContext.setActiveProvider(provider)
        |> deliverOnMainQueue).startStandalone(error: { [weak self] _ in
            self?.presentAgentError()
        })
    }

    func openAgentProviderContextMenu(provider: String, node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode, let settingsContext = self.data?.agentSettingsContext else {
            gesture?.cancel()
            return
        }
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: self.presentationData.strings.Common_Delete, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: {
                    let _ = (settingsContext.disconnect(provider: provider)
                    |> deliverOnMainQueue).startStandalone(error: { [weak self] _ in
                        self?.presentAgentError()
                    })
                })
            }))
        ]
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }

    private func presentAgentError() {
        self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: self.presentationData.strings.Login_UnknownError, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return true }), in: .current)
    }
}
