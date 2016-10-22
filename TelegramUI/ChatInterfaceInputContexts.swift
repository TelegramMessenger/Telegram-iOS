import Foundation
import TelegramCore
import Postbox

func inputContextForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account) -> ChatPresentationInputContext? {
    if chatPresentationInterfaceState.interfaceState.inputState.inputText == "#" {
        return .hashtag
    } else if chatPresentationInterfaceState.interfaceState.inputState.inputText == "@" {
        return .mention
    }
    return nil
}

func inputTextPanelStateForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account) -> ChatTextInputPanelState {
    switch chatPresentationInterfaceState.inputMode {
        case .media:
            return ChatTextInputPanelState(accessoryItems: [.keyboard])
        case .none, .text:
            if chatPresentationInterfaceState.interfaceState.inputState.inputText.isEmpty {
                return ChatTextInputPanelState(accessoryItems: [.stickers])
            } else {
                return ChatTextInputPanelState(accessoryItems: [])
            }
    }
}
