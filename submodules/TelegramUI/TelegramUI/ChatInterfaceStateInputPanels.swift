import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import AccountContext

func inputPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatInputPanelNode?, textInputPanelNode: ChatTextInputPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputPanelNode? {
    if let renderedPeer = chatPresentationInterfaceState.renderedPeer, renderedPeer.peer?.restrictionText(platform: "ios") != nil {
        return nil
    }
    if chatPresentationInterfaceState.isNotAccessible {
        return nil
    }
    
    if let _ = chatPresentationInterfaceState.search {
        var hasSelection = false
        if let selectionState = chatPresentationInterfaceState.interfaceState.selectionState, !selectionState.selectedIds.isEmpty {
            hasSelection = true
        }
        if !hasSelection {
            if let currentPanel = currentPanel as? ChatSearchInputPanelNode {
                currentPanel.interfaceInteraction = interfaceInteraction
                return currentPanel
            } else {
                let panel = ChatSearchInputPanelNode(theme: chatPresentationInterfaceState.theme)
                panel.context = context
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        }
    }
    
    if let selectionState = chatPresentationInterfaceState.interfaceState.selectionState {
        if let currentPanel = currentPanel as? ChatMessageSelectionInputPanelNode {
            currentPanel.selectedMessages = selectionState.selectedIds
            currentPanel.interfaceInteraction = interfaceInteraction
            currentPanel.updateTheme(theme: chatPresentationInterfaceState.theme)
            return currentPanel
        } else {
            let panel = ChatMessageSelectionInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            panel.context = context
            panel.selectedMessages = selectionState.selectedIds
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    }
    if chatPresentationInterfaceState.peerIsBlocked {
        if let currentPanel = currentPanel as? ChatUnblockInputPanelNode {
            currentPanel.interfaceInteraction = interfaceInteraction
            currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return currentPanel
        } else {
            let panel = ChatUnblockInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            panel.context = context
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    }
    
    var displayInputTextPanel = false
    
    if let peer = chatPresentationInterfaceState.renderedPeer?.peer {
        if let secretChat = peer as? TelegramSecretChat {
            switch secretChat.embeddedState {
                case .handshake:
                    if let currentPanel = currentPanel as? SecretChatHandshakeStatusInputPanelNode {
                        return currentPanel
                    } else {
                        let panel = SecretChatHandshakeStatusInputPanelNode()
                        panel.context = context
                        panel.interfaceInteraction = interfaceInteraction
                        return panel
                    }
                case .terminated:
                    if let currentPanel = currentPanel as? DeleteChatInputPanelNode {
                        return currentPanel
                    } else {
                        let panel = DeleteChatInputPanelNode()
                        panel.context = context
                        panel.interfaceInteraction = interfaceInteraction
                        return panel
                    }
                case .active:
                    break
            }
        } else if let channel = peer as? TelegramChannel {
            var isMember: Bool = false
            switch channel.participationStatus {
            case .kicked:
                if let currentPanel = currentPanel as? DeleteChatInputPanelNode {
                    return currentPanel
                } else {
                    let panel = DeleteChatInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            case .member:
                isMember = true
            case .left:
                break
            }
            
            if isMember && channel.hasBannedPermission(.banSendMessages) != nil {
                if let currentPanel = currentPanel as? ChatRestrictedInputPanelNode {
                    return currentPanel
                } else {
                    let panel = ChatRestrictedInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            }
            
            switch channel.info {
            case .broadcast:
                if chatPresentationInterfaceState.interfaceState.editMessage != nil, channel.hasPermission(.editAllMessages) {
                    displayInputTextPanel = true
                } else if !channel.hasPermission(.sendMessages) {
                    if let currentPanel = currentPanel as? ChatChannelSubscriberInputPanelNode {
                        return currentPanel
                    } else {
                        let panel = ChatChannelSubscriberInputPanelNode()
                        panel.interfaceInteraction = interfaceInteraction
                        panel.context = context
                        return panel
                    }
                }
            case .group:
                switch channel.participationStatus {
                case .kicked, .left:
                    if let currentPanel = currentPanel as? ChatChannelSubscriberInputPanelNode {
                        return currentPanel
                    } else {
                        let panel = ChatChannelSubscriberInputPanelNode()
                        panel.interfaceInteraction = interfaceInteraction
                        panel.context = context
                        return panel
                    }
                case .member:
                    break
                }
            }
        } else if let group = peer as? TelegramGroup {
            switch group.membership {
            case .Removed, .Left:
                if let currentPanel = currentPanel as? DeleteChatInputPanelNode {
                    return currentPanel
                } else {
                    let panel = DeleteChatInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            case .Member:
                break
            }
            
            if group.hasBannedPermission(.banSendMessages) {
                if let currentPanel = currentPanel as? ChatRestrictedInputPanelNode {
                    return currentPanel
                } else {
                    let panel = ChatRestrictedInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            }
        }
        
        var displayBotStartPanel = false
        if !chatPresentationInterfaceState.isScheduledMessages {
            if let _ = chatPresentationInterfaceState.botStartPayload {
                if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
                    displayBotStartPanel = true
                }
            } else if let chatHistoryState = chatPresentationInterfaceState.chatHistoryState, case .loaded(true) = chatHistoryState {
                if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
                    displayBotStartPanel = true
                }
            }
        }
        
        if displayBotStartPanel {
            if let currentPanel = currentPanel as? ChatBotStartInputPanelNode {
                currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                return currentPanel
            } else {
                let panel = ChatBotStartInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.context = context
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        } else {
            if let _ = chatPresentationInterfaceState.recordedMediaPreview {
                if let currentPanel = currentPanel as? ChatRecordingPreviewInputPanelNode {
                    //currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                    return currentPanel
                } else {
                    let panel = ChatRecordingPreviewInputPanelNode(theme: chatPresentationInterfaceState.theme)
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            }
            
            displayInputTextPanel = true
        }
    }
    
    if case .inline = chatPresentationInterfaceState.mode {
        displayInputTextPanel = false
    }
    
    if displayInputTextPanel {
        if let currentPanel = currentPanel as? ChatTextInputPanelNode {
            currentPanel.interfaceInteraction = interfaceInteraction
            return currentPanel
        } else {
            if let textInputPanelNode = textInputPanelNode {
                textInputPanelNode.interfaceInteraction = interfaceInteraction
                textInputPanelNode.context = context
                return textInputPanelNode
            } else {
                let panel = ChatTextInputPanelNode(presentationInterfaceState: chatPresentationInterfaceState, presentController: { [weak interfaceInteraction] controller in
                    interfaceInteraction?.presentController(controller, nil)
                })
                
                panel.interfaceInteraction = interfaceInteraction
                panel.context = context
                return panel
            }
        }
    } else {
        return nil
    }
}
