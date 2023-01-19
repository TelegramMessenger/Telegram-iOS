import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatInputNode
import ChatEntityKeyboardInputNode

func inputNodeForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentNode: ChatInputNode?, interfaceInteraction: ChatPanelInterfaceInteraction?, inputMediaNode: ChatMediaInputNode?, controllerInteraction: ChatControllerInteraction, inputPanelNode: ChatInputPanelNode?, makeMediaInputNode: () -> ChatInputNode?) -> ChatInputNode? {
    if let inputPanelNode = inputPanelNode, !(inputPanelNode is ChatTextInputPanelNode) {
        return nil
    }
    switch chatPresentationInterfaceState.inputMode {
    case .media:
        if let currentNode = currentNode as? ChatEntityKeyboardInputNode {
            return currentNode
        } else if let inputMediaNode = inputMediaNode {
            return inputMediaNode
        } else if let inputMediaNode = makeMediaInputNode() {
            inputMediaNode.interfaceInteraction = interfaceInteraction
            return inputMediaNode
        } else {
            return nil
        }
    case .inputButtons:
        if chatPresentationInterfaceState.forceInputCommandsHidden {
            return nil
        } else {
            if let currentNode = currentNode as? ChatButtonKeyboardInputNode {
                return currentNode
            } else {
                let inputNode = ChatButtonKeyboardInputNode(context: context, controllerInteraction: controllerInteraction)
                inputNode.interfaceInteraction = interfaceInteraction
                return inputNode
            }
        }
    case .none, .text:
        return nil
    }
}
