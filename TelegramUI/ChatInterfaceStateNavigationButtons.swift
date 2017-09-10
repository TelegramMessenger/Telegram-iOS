import Foundation
import UIKit

enum ChatNavigationButtonAction {
    case openChatInfo
    case clearHistory
    case cancelMessageSelection
}

struct ChatNavigationButton: Equatable {
    let action: ChatNavigationButtonAction
    let buttonItem: UIBarButtonItem
    
    static func ==(lhs: ChatNavigationButton, rhs: ChatNavigationButton) -> Bool {
        return lhs.action == rhs.action
    }
}

func leftNavigationButtonForChatInterfaceState(_ chatInterfaceState: ChatInterfaceState, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?) -> ChatNavigationButton? {
    if let _ = chatInterfaceState.selectionState {
        if let currentButton = currentButton, currentButton.action == .clearHistory {
            return currentButton
        } else {
            return ChatNavigationButton(action: .clearHistory, buttonItem: UIBarButtonItem(title: "Delete All", style: .plain, target: target, action: selector))
        }
    }
    return nil
}

func rightNavigationButtonForChatInterfaceState(_ chatInterfaceState: ChatInterfaceState, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?, chatInfoNavigationButton: ChatNavigationButton?) -> ChatNavigationButton? {
    if let _ = chatInterfaceState.selectionState {
        if let currentButton = currentButton, currentButton.action == .cancelMessageSelection {
            return currentButton
        } else {
            return ChatNavigationButton(action: .cancelMessageSelection, buttonItem: UIBarButtonItem(title: "Cancel", style: .plain, target: target, action: selector))
        }
    }

    return chatInfoNavigationButton
}
