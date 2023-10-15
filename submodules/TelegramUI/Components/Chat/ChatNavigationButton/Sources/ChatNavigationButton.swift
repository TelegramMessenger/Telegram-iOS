import Foundation
import UIKit

public enum ChatNavigationButtonAction: Equatable {
    case openChatInfo(expandAvatar: Bool)
    case clearHistory
    case clearCache
    case cancelMessageSelection
    case search
    case dismiss
    case toggleInfoPanel
    case spacer
}

public struct ChatNavigationButton: Equatable {
    public let action: ChatNavigationButtonAction
    public let buttonItem: UIBarButtonItem

    public init(action: ChatNavigationButtonAction, buttonItem: UIBarButtonItem) {
        self.action = action
        self.buttonItem = buttonItem
    }
    
    public static func ==(lhs: ChatNavigationButton, rhs: ChatNavigationButton) -> Bool {
        return lhs.action == rhs.action && lhs.buttonItem === rhs.buttonItem
    }
}
