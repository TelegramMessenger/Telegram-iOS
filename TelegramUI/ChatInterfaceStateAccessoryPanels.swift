import Foundation
import AsyncDisplayKit
import TelegramCore

func accessoryPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: AccessoryPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> AccessoryPanelNode? {
    if let _ = chatPresentationInterfaceState.interfaceState.selectionState {
        return nil
    }
    
    if let replyMessageId = chatPresentationInterfaceState.interfaceState.replyMessageId {
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
