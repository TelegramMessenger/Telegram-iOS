import Foundation
import AsyncDisplayKit
import TelegramCore

func inputNodeForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentNode: ChatInputNode?, interfaceInteraction: ChatPanelInterfaceInteraction?, inputMediaNode: ChatMediaInputNode?, controllerInteraction: ChatControllerInteraction, inputPanelNode: ChatInputPanelNode?) -> ChatInputNode? {
    if !(inputPanelNode is ChatTextInputPanelNode) {
        return nil
    }
    switch chatPresentationInterfaceState.inputMode {
        case .media:
            if let currentNode = currentNode as? ChatMediaInputNode {
                return currentNode
            } else if let inputMediaNode = inputMediaNode {
                return inputMediaNode
            } else {
                let inputNode = ChatMediaInputNode(account: account, controllerInteraction: controllerInteraction, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                inputNode.interfaceInteraction = interfaceInteraction
                return inputNode
            }
        case .inputButtons:
            if let currentNode = currentNode as? ChatButtonKeyboardInputNode {
                return currentNode
            } else {
                let inputNode = ChatButtonKeyboardInputNode(account: account, controllerInteraction: controllerInteraction)
                inputNode.interfaceInteraction = interfaceInteraction
                return inputNode
            }
        case .none, .text:
            return nil
    }
    return nil
}
