import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import AccountContext
import ChatPresentationInterfaceState

func inputNodeForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentNode: ChatInputNode?, interfaceInteraction: ChatPanelInterfaceInteraction?, inputMediaNode: ChatMediaInputNode?, controllerInteraction: ChatControllerInteraction, inputPanelNode: ChatInputPanelNode?) -> ChatInputNode? {
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
                var peerId: PeerId?
                if case let .peer(id) = chatPresentationInterfaceState.chatLocation {
                    peerId = id
                }
                let inputNode = ChatMediaInputNode(context: context, peerId: peerId, chatLocation: chatPresentationInterfaceState.chatLocation, controllerInteraction: controllerInteraction, chatWallpaper: chatPresentationInterfaceState.chatWallpaper, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, gifPaneIsActiveUpdated: { [weak interfaceInteraction] value in
                    if let interfaceInteraction = interfaceInteraction {
                        interfaceInteraction.updateInputModeAndDismissedButtonKeyboardMessageId { state in
                            if case let .media(_, expanded, focused) = state.inputMode {
                                if value {
                                    return (.media(mode: .gif, expanded: expanded, focused: focused), nil)
                                } else {
                                    return (.media(mode: .other, expanded: expanded, focused: focused), nil)
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
