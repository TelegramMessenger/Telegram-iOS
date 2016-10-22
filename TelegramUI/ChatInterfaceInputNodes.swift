import Foundation
import AsyncDisplayKit
import TelegramCore

func inputNodeForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentNode: ChatInputNode?, interfaceInteraction: ChatPanelInterfaceInteraction?, inputMediaNode: ChatMediaInputNode?, controllerInteraction: ChatControllerInteraction) -> ChatInputNode? {
    switch chatPresentationInterfaceState.inputMode {
        case .media:
            if let currentNode = currentNode as? ChatMediaInputNode {
                return currentNode
            } else if let inputMediaNode = inputMediaNode {
                return inputMediaNode
            } else {
                let inputNode = ChatMediaInputNode(account: account, controllerInteraction: controllerInteraction)
                inputNode.interfaceInteraction = interfaceInteraction
                return inputNode
            }
        case .none, .text:
            return nil
    }
    return nil
}
