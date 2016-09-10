import Foundation
import Postbox
import TelegramCore
import Display
import UIKit

func contextMenuForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, message: Message, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ContextMenuController? {
    guard let peer = chatPresentationInterfaceState.peer, let interfaceInteraction = interfaceInteraction else {
        return nil
    }
    
    var actions: [ContextMenuAction] = []
    
    var canReply = false
    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
        switch channel.role {
            case .creator, .editor, .moderator:
                canReply = true
            case .member:
                canReply = false
        }
    } else {
        canReply = true
    }
    if canReply {
        actions.append(ContextMenuAction(content: .text("Reply"), action: {
            interfaceInteraction.setupReplyMessage(message.id)
        }))
    }
    
    actions.append(ContextMenuAction(content: .text("Copy"), action: {
        if !message.text.isEmpty {
            UIPasteboard.general.string = message.text
        }
    }))
    
    actions.append(ContextMenuAction(content: .text("More..."), action: {
        interfaceInteraction.beginMessageSelection(message.id)
    }))

    
    if !actions.isEmpty {
        let contextMenuController = ContextMenuController(actions: actions)
        return contextMenuController
    } else {
        return nil
    }
}
