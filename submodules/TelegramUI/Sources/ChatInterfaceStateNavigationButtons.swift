import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState

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
        if case .forwardedMessages = presentationInterfaceState.subject {
            return nil
        }
        if let _ = presentationInterfaceState.reportReason {
            return ChatNavigationButton(action: .spacer, buttonItem: UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil))
        }
        if case .replyThread = presentationInterfaceState.chatLocation {
            return nil
        }
        if let currentButton = currentButton, currentButton.action == .clearHistory {
            return currentButton
        } else if let peer = presentationInterfaceState.renderedPeer?.peer {
            let canClear: Bool
            var title = strings.Conversation_ClearAll
            if case .scheduledMessages = presentationInterfaceState.subject {
                canClear = true
                title = strings.ScheduledMessages_ClearAll
            } else {
                if peer is TelegramUser || peer is TelegramGroup || peer is TelegramSecretChat {
                    canClear = true
                } else if let peer = peer as? TelegramChannel, case .group = peer.info, peer.addressName == nil && presentationInterfaceState.peerGeoLocation == nil {
                    canClear = true
                } else if let peer = peer as? TelegramChannel {
                    if case .broadcast = peer.info {
                        title = strings.Conversation_ClearChannel
                    }
                    if peer.hasPermission(.changeInfo) {
                        canClear = true
                    } else {
                        canClear = false
                    }
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
    return nil
}

func rightNavigationButtonForChatInterfaceState(_ presentationInterfaceState: ChatPresentationInterfaceState, strings: PresentationStrings, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?, chatInfoNavigationButton: ChatNavigationButton?, moreInfoNavigationButton: ChatNavigationButton?) -> ChatNavigationButton? {
    if let _ = presentationInterfaceState.interfaceState.selectionState {
        if case .forwardedMessages = presentationInterfaceState.subject {
            return nil
        }
        if let currentButton = currentButton, currentButton.action == .cancelMessageSelection {
            return currentButton
        } else {
            let buttonItem = UIBarButtonItem(title: strings.Common_Cancel, style: .plain, target: target, action: selector)
            buttonItem.accessibilityLabel = strings.Common_Cancel
            return ChatNavigationButton(action: .cancelMessageSelection, buttonItem: buttonItem)
        }
    }
    
    if let channel = presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.flags.contains(.isForum), let moreInfoNavigationButton = moreInfoNavigationButton {
        if case .replyThread = presentationInterfaceState.chatLocation {
        } else {
            return moreInfoNavigationButton
        }
    }
    
    var hasMessages = false
    if let chatHistoryState = presentationInterfaceState.chatHistoryState {
        if case .loaded(false) = chatHistoryState {
            hasMessages = true
        }
    }
    
    if case .forwardedMessages = presentationInterfaceState.subject {
        return nil
    }
    
    if case .pinnedMessages = presentationInterfaceState.subject {
        return nil
    }
    
    if case .replyThread = presentationInterfaceState.chatLocation {
        if let channel = presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.flags.contains(.isForum) {
        } else if hasMessages {
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
    
    if case .scheduledMessages = presentationInterfaceState.subject {
        return chatInfoNavigationButton
    }
    
    if case .standard(true) = presentationInterfaceState.mode {
        return chatInfoNavigationButton
    } else if let peer = presentationInterfaceState.renderedPeer?.peer {
        if presentationInterfaceState.accountPeerId == peer.id {
            if case .scheduledMessages = presentationInterfaceState.subject {
                return chatInfoNavigationButton
            } else {
                if presentationInterfaceState.hasPlentyOfMessages {
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
    }

    return chatInfoNavigationButton
}
