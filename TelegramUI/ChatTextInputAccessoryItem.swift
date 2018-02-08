import Foundation

enum ChatTextInputAccessoryItem: Equatable {
    case keyboard
    case stickers
    case inputButtons
    case commands
    case silentPost(Bool)
    case messageAutoremoveTimeout(Int32?)
    
    static func ==(lhs: ChatTextInputAccessoryItem, rhs: ChatTextInputAccessoryItem) -> Bool {
        switch lhs {
            case .keyboard:
                if case .keyboard = rhs {
                    return true
                } else {
                    return false
                }
            case .stickers:
                if case .stickers = rhs {
                    return true
                } else {
                    return false
                }
            case .inputButtons:
                if case .inputButtons = rhs {
                    return true
                } else {
                    return false
                }
            case .commands:
                if case .commands = rhs {
                    return true
                } else {
                    return false
                }
            case let .silentPost(value):
                if case .silentPost(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .messageAutoremoveTimeout(lhsTimeout):
                if case let .messageAutoremoveTimeout(rhsTimeout) = rhs, lhsTimeout == rhsTimeout {
                    return true
                } else {
                    return false
                }
        }
    }
}
