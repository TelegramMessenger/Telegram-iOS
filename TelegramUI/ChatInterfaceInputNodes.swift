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
                let inputNode = ChatMediaInputNode(account: account, controllerInteraction: controllerInteraction, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, gifPaneIsActiveUpdated: { [weak interfaceInteraction] value in
                    if let interfaceInteraction = interfaceInteraction {
                        interfaceInteraction.updateInputModeAndDismissedButtonKeyboardMessageId { state in
                            if case .media = state.inputMode {
                                if value {
                                    return (.media(.gif), nil)
                                } else {
                                    return (.media(.other), nil)
                                }
                            } else {
                                return (state.inputMode, nil)
                            }
                        }
                    }
                })
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
