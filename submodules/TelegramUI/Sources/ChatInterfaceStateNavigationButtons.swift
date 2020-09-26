import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext

enum ChatNavigationButtonAction: Equatable {
    case openChatInfo(expandAvatar: Bool)
    case clearHistory
    case clearCache
    case cancelMessageSelection
    case search
    case dismiss
    case toggleInfoPanel
    case spacer
}

struct ChatNavigationButton: Equatable {
    let action: ChatNavigationButtonAction
    let buttonItem: UIBarButtonItem
    
    static func ==(lhs: ChatNavigationButton, rhs: ChatNavigationButton) -> Bool {
        return lhs.action == rhs.action && lhs.buttonItem === rhs.buttonItem
    }
}

func leftNavigationButtonForChatInterfaceState(_ presentationInterfaceState: ChatPresentationInterfaceState, subject: ChatControllerSubject?, strings: PresentationStrings, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?) -> ChatNavigationButton? {
    if let _ = presentationInterfaceState.interfaceState.selectionState {
        if case .replyThread = presentationInterfaceState.chatLocation {
            return nil
        }
        if let currentButton = currentButton, currentButton.action == .clearHistory {
            return currentButton
        } else if let peer = presentationInterfaceState.renderedPeer?.peer {
            let canClear: Bool
            var title = strings.Conversation_ClearAll
            if presentationInterfaceState.isScheduledMessages {
                canClear = true
                title = strings.ScheduledMessages_ClearAll
            } else {
                if peer is TelegramUser || peer is TelegramGroup || peer is TelegramSecretChat {
                    canClear = true
                } else if let peer = peer as? TelegramChannel, case .group = peer.info, peer.addressName == nil && presentationInterfaceState.peerGeoLocation == nil {
                    canClear = true
                } else {
                    canClear = false
                }
            }
            
            if canClear {
                return ChatNavigationButton(action: .clearHistory, buttonItem: UIBarButtonItem(title: title, style: .plain, target: target, action: selector))
            } else {
                title = strings.Conversation_ClearCache
                return ChatNavigationButton(action: .clearCache, buttonItem: UIBarButtonItem(title: title, style: .plain, target: target, action: selector))
            }
        }
    }
    /*if let subject = subject, case .scheduledMessages = subject {
        if let currentButton = currentButton, currentButton.action == .dismiss {
            return currentButton
        } else {
            return ChatNavigationButton(action: .dismiss, buttonItem: UIBarButtonItem(title: strings.Common_Done, style: .plain, target: target, action: selector))
        }
    }*/
    return nil
}

func rightNavigationButtonForChatInterfaceState(_ presentationInterfaceState: ChatPresentationInterfaceState, strings: PresentationStrings, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?, chatInfoNavigationButton: ChatNavigationButton?) -> ChatNavigationButton? {
    if let _ = presentationInterfaceState.interfaceState.selectionState {
        if let currentButton = currentButton, currentButton.action == .cancelMessageSelection {
            return currentButton
        } else {
            return ChatNavigationButton(action: .cancelMessageSelection, buttonItem: UIBarButtonItem(title: strings.Common_Cancel, style: .plain, target: target, action: selector))
        }
    }
    
    var hasMessages = false
    if let chatHistoryState = presentationInterfaceState.chatHistoryState {
        if case .loaded(false) = chatHistoryState {
            hasMessages = true
        }
    }
    
    if case .replyThread = presentationInterfaceState.chatLocation {
        if hasMessages {
            if case .search = currentButton?.action {
                return currentButton
            } else {
                let buttonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
                buttonItem.accessibilityLabel = strings.Conversation_Search
                return ChatNavigationButton(action: .search, buttonItem: buttonItem)
            }
        } else {
            if case .spacer = currentButton?.action {
                return currentButton
            } else {
                return ChatNavigationButton(action: .spacer, buttonItem: UIBarButtonItem(title: "", style: .plain, target: target, action: selector))
            }
        }
    }
    if case let .peer(peerId) = presentationInterfaceState.chatLocation {
        if peerId.isReplies {
            if hasMessages {
                if case .search = currentButton?.action {
                    return currentButton
                } else {
                    let buttonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
                    buttonItem.accessibilityLabel = strings.Conversation_Search
                    return ChatNavigationButton(action: .search, buttonItem: buttonItem)
                }
            } else {
                if case .spacer = currentButton?.action {
                    return currentButton
                } else {
                    return ChatNavigationButton(action: .spacer, buttonItem: UIBarButtonItem(title: "", style: .plain, target: target, action: selector))
                }
            }
        }
    }
    
    if presentationInterfaceState.isScheduledMessages {
        return chatInfoNavigationButton
    }
    
    if case .standard(true) = presentationInterfaceState.mode {
        return chatInfoNavigationButton
    } else if let peer = presentationInterfaceState.renderedPeer?.peer {
        if presentationInterfaceState.accountPeerId == peer.id {
            if presentationInterfaceState.isScheduledMessages {
                return chatInfoNavigationButton
            } else {
                let buttonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
                buttonItem.accessibilityLabel = strings.Conversation_Search
                return ChatNavigationButton(action: .search, buttonItem: buttonItem)
            }
        }
    }

    return chatInfoNavigationButton
}
