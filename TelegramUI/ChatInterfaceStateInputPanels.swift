import Foundation
import AsyncDisplayKit
import TelegramCore

func inputPanelForChatIntefaceState(_ chatInterfaceState: ChatInterfaceState, account: Account, currentPanel: ChatInputPanelNode?, textInputPanelNode: ChatTextInputPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputPanelNode? {
    if let selectionState = chatInterfaceState.selectionState {
        if let currentPanel = currentPanel as? ChatMessageSelectionInputPanelNode {
            currentPanel.selectedMessageCount = selectionState.selectedIds.count
            currentPanel.interfaceInteraction = interfaceInteraction
            return currentPanel
        } else {
            let panel = ChatMessageSelectionInputPanelNode()
            panel.selectedMessageCount = selectionState.selectedIds.count
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    } else {
        if let currentPanel = currentPanel as? ChatTextInputPanelNode {
            currentPanel.interfaceInteraction = interfaceInteraction
            return currentPanel
        } else {
            if let textInputPanelNode = textInputPanelNode {
                textInputPanelNode.interfaceInteraction = interfaceInteraction
                return textInputPanelNode
            } else {
                let panel = ChatTextInputPanelNode()
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        }
    }
}
