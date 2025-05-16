import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import ChatNavigationButton

func leftNavigationButtonForChatInterfaceState(_ presentationInterfaceState: ChatPresentationInterfaceState, subject: ChatControllerSubject?, strings: PresentationStrings, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?) -> ChatNavigationButton? {
    if let _ = presentationInterfaceState.interfaceState.selectionState {
        if case .messageOptions = presentationInterfaceState.subject {
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
    
    if case let .customChatContents(customChatContents) = presentationInterfaceState.subject {
        switch customChatContents.kind {
        case .hashTagSearch:
            break
        case .quickReplyMessageInput, .businessLinkSetup:
            if let currentButton = currentButton, currentButton.action == .dismiss {
                return currentButton
            } else {
                let buttonItem = UIBarButtonItem(title: strings.Common_Close, style: .plain, target: target, action: selector)
                buttonItem.accessibilityLabel = strings.Common_Close
                return ChatNavigationButton(action: .dismiss, buttonItem: buttonItem)
            }
        }
    }
    
    return nil
}

func rightNavigationButtonForChatInterfaceState(context: AccountContext, presentationInterfaceState: ChatPresentationInterfaceState, strings: PresentationStrings, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?, chatInfoNavigationButton: ChatNavigationButton?, moreInfoNavigationButton: ChatNavigationButton?) -> ChatNavigationButton? {
    if let _ = presentationInterfaceState.interfaceState.selectionState {
        if case .messageOptions = presentationInterfaceState.subject {
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
    
    if case let .replyThread(message) = presentationInterfaceState.chatLocation, message.peerId == context.account.peerId {
        let isTags = presentationInterfaceState.hasSearchTags
        
        if case .search(isTags) = currentButton?.action {
            return currentButton
        } else {
            let buttonItem = UIBarButtonItem(image: isTags ? PresentationResourcesRootController.navigationCompactTagsSearchIcon(presentationInterfaceState.theme) : PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
            buttonItem.accessibilityLabel = strings.Conversation_Search
            return ChatNavigationButton(action: .search(hasTags: isTags), buttonItem: buttonItem)
        }
    }
    
    if let channel = presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, case .peer = presentationInterfaceState.chatLocation {
        if case .search(false) = currentButton?.action {
            return currentButton
        } else {
            let buttonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
            buttonItem.accessibilityLabel = strings.Conversation_Search
            return ChatNavigationButton(action: .search(hasTags: false), buttonItem: buttonItem)
        }
    }
    
    if let channel = presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum, let moreInfoNavigationButton = moreInfoNavigationButton {
        if case .replyThread = presentationInterfaceState.chatLocation {
        } else {
            if case .pinnedMessages = presentationInterfaceState.subject {
            } else {
                return moreInfoNavigationButton
            }
        }
    }
    
    var hasMessages = false
    if let chatHistoryState = presentationInterfaceState.chatHistoryState {
        if case .loaded(false, _) = chatHistoryState {
            hasMessages = true
        }
    }
    
    if case .messageOptions = presentationInterfaceState.subject {
        return nil
    }
    
    if case .pinnedMessages = presentationInterfaceState.subject {
        return nil
    }
    
    if case let .customChatContents(customChatContents) = presentationInterfaceState.subject {
        switch customChatContents.kind {
        case .hashTagSearch:
            return nil
        case let .quickReplyMessageInput(_, shortcutType):
            switch shortcutType {
            case .generic:
                if let currentButton = currentButton, currentButton.action == .edit {
                    return currentButton
                } else {
                    let buttonItem = UIBarButtonItem(title: strings.Common_Edit, style: .plain, target: target, action: selector)
                    buttonItem.accessibilityLabel = strings.Common_Done
                    return ChatNavigationButton(action: .edit, buttonItem: buttonItem)
                }
            case .greeting, .away:
                return nil
            }
        case .businessLinkSetup:
            if let currentButton = currentButton, currentButton.action == .edit {
                return currentButton
            } else {
                let buttonItem = UIBarButtonItem(title: strings.Common_Edit, style: .plain, target: target, action: selector)
                buttonItem.accessibilityLabel = strings.Common_Done
                return ChatNavigationButton(action: .edit, buttonItem: buttonItem)
            }
        }
    }
    
    if case .replyThread = presentationInterfaceState.chatLocation {
        if let channel = presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum {
        } else if hasMessages {
            if case .search = currentButton?.action {
                return currentButton
            } else {
                let buttonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
                buttonItem.accessibilityLabel = strings.Conversation_Search
                return ChatNavigationButton(action: .search(hasTags: false), buttonItem: buttonItem)
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
        if peerId.isRepliesOrVerificationCodes {
            if hasMessages {
                if case .search = currentButton?.action {
                    return currentButton
                } else {
                    let buttonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
                    buttonItem.accessibilityLabel = strings.Conversation_Search
                    return ChatNavigationButton(action: .search(hasTags: false), buttonItem: buttonItem)
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
    
    if case .standard(.previewing) = presentationInterfaceState.mode {
        return chatInfoNavigationButton
    } else if let peerId = presentationInterfaceState.chatLocation.peerId {
        if presentationInterfaceState.accountPeerId == peerId {
            var displaySearchButton = false
            
            if case .replyThread = presentationInterfaceState.chatLocation {
                displaySearchButton = true
            }
            
            if case .scheduledMessages = presentationInterfaceState.subject {
                return chatInfoNavigationButton
            } else {
                displaySearchButton = true
            }
            
            if displaySearchButton {
                let isTags = presentationInterfaceState.hasSearchTags
                
                if case .search(isTags) = currentButton?.action {
                    return currentButton
                } else {
                    let buttonItem = UIBarButtonItem(image: isTags ? PresentationResourcesRootController.navigationCompactTagsSearchIcon(presentationInterfaceState.theme) : PresentationResourcesRootController.navigationCompactSearchIcon(presentationInterfaceState.theme), style: .plain, target: target, action: selector)
                    buttonItem.accessibilityLabel = strings.Conversation_Search
                    return ChatNavigationButton(action: .search(hasTags: isTags), buttonItem: buttonItem)
                }
            }
        }
    }

    return chatInfoNavigationButton
}

func secondaryRightNavigationButtonForChatInterfaceState(context: AccountContext, presentationInterfaceState: ChatPresentationInterfaceState, strings: PresentationStrings, currentButton: ChatNavigationButton?, target: Any?, selector: Selector?, chatInfoNavigationButton: ChatNavigationButton?, moreInfoNavigationButton: ChatNavigationButton?) -> ChatNavigationButton? {
    if presentationInterfaceState.interfaceState.selectionState != nil {
        return nil
    }
    if case .standard(.default) = presentationInterfaceState.mode {
        if case .peer(context.account.peerId) = presentationInterfaceState.chatLocation, presentationInterfaceState.subject != .scheduledMessages, presentationInterfaceState.hasSavedChats {
            return moreInfoNavigationButton
        }
    }
    
    return nil
}
