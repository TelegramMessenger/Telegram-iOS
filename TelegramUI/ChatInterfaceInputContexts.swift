import Foundation
import TelegramCore
import Postbox

func inputContextForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account) -> ChatPresentationInputContext? {
    if let _ = chatPresentationInterfaceState.interfaceState.editMessage {
        return nil
    } else {
        if chatPresentationInterfaceState.interfaceState.composeInputState.inputText == "#" {
            return .hashtag
        } else if chatPresentationInterfaceState.interfaceState.composeInputState.inputText == "@" {
            return .mention
        }
        return nil
    }
}

func inputTextPanelStateForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account) -> ChatTextInputPanelState {
    switch chatPresentationInterfaceState.inputMode {
        case .media:
            return ChatTextInputPanelState(accessoryItems: [.keyboard])
        case .none, .text:
            if let _ = chatPresentationInterfaceState.interfaceState.editMessage {
                return ChatTextInputPanelState(accessoryItems: [])
            } else {
                if chatPresentationInterfaceState.interfaceState.composeInputState.inputText.isEmpty {
                    return ChatTextInputPanelState(accessoryItems: [.stickers])
                } else {
                    return ChatTextInputPanelState(accessoryItems: [])
                }
            }
    }
}
