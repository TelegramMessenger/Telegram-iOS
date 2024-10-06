import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SafariServices
import MobileCoreServices
import Intents
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import TextFormat
import TelegramBaseController
import AccountContext
import TelegramStringFormatting
import PresentationDataUtils
import UndoUI
import PeerInfoUI
import AppBundle
import LocalizedPeerData
import ChatInterfaceState
import ChatControllerInteraction
import StoryContainerScreen
import SaveToCameraRoll
import MediaEditorScreen

extension ChatControllerImpl {
    func openStorySharing(messages: [Message]) {
        let context = self.context
        let subject: Signal<MediaEditorScreen.Subject?, NoError> = .single(.message(messages.map { $0.id }))
        
        let externalState = MediaEditorTransitionOutExternalState(
            storyTarget: nil,
            isForcedTarget: false,
            isPeerArchived: false,
            transitionOut: nil
        )
        
        let controller = MediaEditorScreen(
            context: context,
            mode: .storyEditor,
            subject: subject,
            transitionIn: nil,
            transitionOut: { _, _ in
                return nil
            },
            completion: { [weak self] result, commit in
                guard let self else {
                    return
                }
                let targetPeerId: EnginePeer.Id
                let target: Stories.PendingTarget
                if let sendAsPeerId = result.options.sendAsPeerId {
                    target = .peer(sendAsPeerId)
                    targetPeerId = sendAsPeerId
                } else {
                    target = .myStories
                    targetPeerId = self.context.account.peerId
                }
                externalState.storyTarget = target
                
                if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                    rootController.proceedWithStoryUpload(target: target, result: result, existingMedia: nil, forwardInfo: nil, externalState: externalState, commit: commit)
                }
                
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: targetPeerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, let peer else {
                        return
                    }
                    let text: String
                    if case .channel = peer {
                        text = self.presentationData.strings.Story_MessageReposted_Channel(peer.compactDisplayTitle).string
                    } else {
                        text = self.presentationData.strings.Story_MessageReposted_Personal
                    }
                    Queue.mainQueue().after(0.25) {
                        self.present(UndoOverlayController(
                            presentationData: self.presentationData,
                            content: .forward(savedMessages: false, text: text),
                            elevatedLayout: false,
                            action: { _ in return false }
                        ), in: .current)
                        
                        Queue.mainQueue().after(0.1) {
                            self.chatDisplayNode.hapticFeedback.success()
                        }
                    }
                })
            }
        )
        self.push(controller)
    }
}
