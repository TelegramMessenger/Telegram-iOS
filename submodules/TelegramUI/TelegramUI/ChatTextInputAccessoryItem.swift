import Foundation

enum ChatTextInputAccessoryItem: Equatable {
    case keyboard
    case stickers(Bool)
    case inputButtons
    case commands
    case silentPost(Bool)
    case messageAutoremoveTimeout(Int32?)
    case scheduledMessages
}
