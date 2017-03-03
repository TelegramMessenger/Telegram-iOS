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
    var canPin = false
    if let channel = peer as? TelegramChannel {
        switch channel.info {
            case .broadcast:
                switch channel.role {
                    case .creator, .editor, .moderator:
                        canReply = true
                    case .member:
                        canReply = false
                }
            case .group:
                switch channel.role {
                    case .creator, .editor, .moderator:
                        canPin = true
                    case .member:
                        canPin = false
                }
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
    
    if canPin {
        if chatPresentationInterfaceState.pinnedMessageId != message.id {
            actions.append(ContextMenuAction(content: .text("Pin"), action: {
                interfaceInteraction.pinMessage(message.id)
            }))
        } else {
            actions.append(ContextMenuAction(content: .text("Unpin"), action: {
                interfaceInteraction.unpinMessage()
            }))
        }
    }
    
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
