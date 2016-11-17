import Foundation
import AsyncDisplayKit
import TelegramCore

func accessoryPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: AccessoryPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> AccessoryPanelNode? {
    if let _ = chatPresentationInterfaceState.interfaceState.selectionState {
        return nil
    }
    
    if let editMessage = chatPresentationInterfaceState.interfaceState.editMessage {
        if let editPanelNode = currentPanel as? EditAccessoryPanelNode, editPanelNode.messageId == editMessage.messageId {
            editPanelNode.interfaceInteraction = interfaceInteraction
            return editPanelNode
        } else {
            let panelNode = EditAccessoryPanelNode(account: account, messageId: editMessage.messageId)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let forwardMessageIds = chatPresentationInterfaceState.interfaceState.forwardMessageIds {
        if let forwardPanelNode = currentPanel as? ForwardAccessoryPanelNode, forwardPanelNode.messageIds == forwardMessageIds {
            forwardPanelNode.interfaceInteraction = interfaceInteraction
            return forwardPanelNode
        } else {
            let panelNode = ForwardAccessoryPanelNode(account: account, messageIds: forwardMessageIds)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let replyMessageId = chatPresentationInterfaceState.interfaceState.replyMessageId {
        if let replyPanelNode = currentPanel as? ReplyAccessoryPanelNode, replyPanelNode.messageId == replyMessageId {
            replyPanelNode.interfaceInteraction = interfaceInteraction
            return replyPanelNode
        } else {
            let panelNode = ReplyAccessoryPanelNode(account: account, messageId: replyMessageId)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else {
        return nil
    }
}
