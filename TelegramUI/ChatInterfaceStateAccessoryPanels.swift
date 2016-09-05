import Foundation
import AsyncDisplayKit
import TelegramCore

func accessoryPanelForChatIntefaceState(_ chatInterfaceState: ChatInterfaceState, account: Account, currentPanel: AccessoryPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> AccessoryPanelNode? {
    if let _ = chatInterfaceState.selectionState {
        return nil
    }
    
    if let replyMessageId = chatInterfaceState.replyMessageId {
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
