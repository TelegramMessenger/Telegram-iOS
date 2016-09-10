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
