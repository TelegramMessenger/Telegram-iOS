import Foundation
import AsyncDisplayKit
import TelegramCore

func inputPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatInputPanelNode?, textInputPanelNode: ChatTextInputPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputPanelNode? {
    if let renderedPeer = chatPresentationInterfaceState.renderedPeer, renderedPeer.peer?.restrictionText != nil {
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
                panel.account = account
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
            let panel = ChatMessageSelectionInputPanelNode(theme: chatPresentationInterfaceState.theme)
            panel.account = account
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
            panel.account = account
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    }
    
    var displayInputTextPanel = false
    
    if case .group = chatPresentationInterfaceState.chatLocation {
        if chatPresentationInterfaceState.interfaceState.editMessage != nil {
            displayInputTextPanel = true
        } else {
            if let currentPanel = currentPanel as? ChatFeedNavigationInputPanelNode {
                currentPanel.interfaceInteraction = interfaceInteraction
                currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                return currentPanel
            } else {
                let panel = ChatFeedNavigationInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.account = account
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        }
    }
    
    if let peer = chatPresentationInterfaceState.renderedPeer?.peer {
        if let secretChat = peer as? TelegramSecretChat {
            switch secretChat.embeddedState {
                case .handshake:
                    if let currentPanel = currentPanel as? SecretChatHandshakeStatusInputPanelNode {
                        return currentPanel
                    } else {
                        let panel = SecretChatHandshakeStatusInputPanelNode()
                        panel.account = account
                        panel.interfaceInteraction = interfaceInteraction
                        return panel
                    }
                case .terminated:
                    if let currentPanel = currentPanel as? DeleteChatInputPanelNode {
                        return currentPanel
                    } else {
                        let panel = DeleteChatInputPanelNode()
                        panel.account = account
                        panel.interfaceInteraction = interfaceInteraction
                        return panel
                    }
                case .active:
                    break
            }
        } else if let channel = peer as? TelegramChannel {
            if channel.hasBannedPermission(.banSendMessages) != nil {
                if let currentPanel = currentPanel as? ChatRestrictedInputPanelNode {
                    return currentPanel
                } else {
                    let panel = ChatRestrictedInputPanelNode()
                    panel.account = account
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            }
            
            switch channel.participationStatus {
                case .kicked:
                    if let currentPanel = currentPanel as? DeleteChatInputPanelNode {
                        return currentPanel
                    } else {
                        let panel = DeleteChatInputPanelNode()
                        panel.account = account
                        panel.interfaceInteraction = interfaceInteraction
                        return panel
                    }
                case .member, .left:
                    break
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
                            panel.account = account
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
                                panel.account = account
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
                        panel.account = account
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
                    panel.account = account
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            }
        }
        
        var displayBotStartPanel = false
        if let _ = chatPresentationInterfaceState.botStartPayload {
            displayBotStartPanel = true
        } else if let chatHistoryState = chatPresentationInterfaceState.chatHistoryState, case .loaded(true) = chatHistoryState {
            if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
                displayBotStartPanel = true
            }
        }
        
        if displayBotStartPanel {
            if let currentPanel = currentPanel as? ChatBotStartInputPanelNode {
                currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                return currentPanel
            } else {
                let panel = ChatBotStartInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.account = account
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
                    panel.account = account
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
                textInputPanelNode.account = account
                return textInputPanelNode
            } else {
                let panel = ChatTextInputPanelNode(theme: chatPresentationInterfaceState.theme, presentController: { [weak interfaceInteraction] controller in
                    interfaceInteraction?.presentController(controller, nil)
                })
                panel.interfaceInteraction = interfaceInteraction
                panel.account = account
                return panel
            }
        }
    } else {
        return nil
    }
}
