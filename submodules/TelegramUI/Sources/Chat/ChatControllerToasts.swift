import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import UndoUI
import AccountContext
import ChatControllerInteraction

extension ChatControllerImpl {
    func displayPostedScheduledMessagesToast(ids: [EngineMessage.Id]) {
        let timestamp = CFAbsoluteTimeGetCurrent()
        if self.lastPostedScheduledMessagesToastTimestamp + 0.4 >= timestamp {
            return
        }
        self.lastPostedScheduledMessagesToastTimestamp = timestamp
        
        guard case .scheduledMessages = self.presentationInterfaceState.subject else {
            return
        }
        
        let _ = (self.context.engine.data.get(
            EngineDataList(ids.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:)))
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] messages in
            guard let self else {
                return
            }
            let messages = messages.compactMap { $0 }
            
            var found: (message: EngineMessage, file: TelegramMediaFile)?
            outer: for message in messages {
                for media in message.media {
                    if let file = media as? TelegramMediaFile, file.isVideo {
                        found = (message, file)
                        break outer
                    }
                }
            }
            
            guard let (message, file) = found else {
                return
            }
            
            guard case let .loaded(isEmpty, _) = self.chatDisplayNode.historyNode.currentHistoryState else {
                return
            }
            
            if isEmpty {
                if let navigationController = self.navigationController as? NavigationController, let topController = navigationController.viewControllers.first(where: { c in
                    if let c = c as? ChatController, c.chatLocation == self.chatLocation {
                        return true
                    }
                    return false
                }) as? ChatControllerImpl {
                    topController.controllerInteraction?.presentControllerInCurrent(UndoOverlayController(
                        presentationData: self.presentationData,
                        content: .media(
                            context: self.context,
                            file: .message(message: MessageReference(message._asMessage()), media: file),
                            title: nil,
                            text: self.presentationData.strings.Chat_ToastVideoPublished_Title,
                            undoText: nil,
                            customAction: nil
                        ),
                        elevatedLayout: false,
                        position: .top,
                        animateInAsReplacement: false,
                        action: { _ in false }
                    ), nil)
                    
                    self.dismiss()
                }
            } else {
                self.controllerInteraction?.presentControllerInCurrent(UndoOverlayController(
                    presentationData: self.presentationData,
                    content: .media(
                        context: self.context,
                        file: .message(message: MessageReference(message._asMessage()), media: file),
                        title: nil,
                        text: self.presentationData.strings.Chat_ToastVideoPublished_Title,
                        undoText: self.presentationData.strings.Chat_ToastVideoPublished_Action,
                        customAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.dismiss()
                        }
                    ),
                    elevatedLayout: false,
                    position: .top,
                    animateInAsReplacement: false,
                    action: { _ in false }
                ), nil)
            }
        })
    }
}
