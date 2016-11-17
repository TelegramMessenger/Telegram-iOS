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
    
    var canEdit = false
    if let author = message.author, author.id == account.peerId {
        var hasUneditableAttributes = false
        for attribute in message.attributes {
            if let _ = attribute as? InlineBotMessageAttribute {
                hasUneditableAttributes = true
                break
            }
        }
        
        if !hasUneditableAttributes {
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            if message.timestamp >= timestamp - 60 * 60 * 24 * 2 {
                canEdit = true
            }
        }
    }
    
    if canReply {
        actions.append(ContextMenuAction(content: .text("Reply"), action: {
            interfaceInteraction.setupReplyMessage(message.id)
        }))
    }
    
    if canEdit {
        actions.append(ContextMenuAction(content: .text("Edit"), action: {
            interfaceInteraction.setupEditMessage(message.id)
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
