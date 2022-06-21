import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState

func inputPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatInputPanelNode?, currentSecondaryPanel: ChatInputPanelNode?, textInputPanelNode: ChatTextInputPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> (primary: ChatInputPanelNode?, secondary: ChatInputPanelNode?) {
    if let renderedPeer = chatPresentationInterfaceState.renderedPeer, renderedPeer.peer?.restrictionText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) != nil {
        return (nil, nil)
    }
    if chatPresentationInterfaceState.isNotAccessible {
        return (nil, nil)
    }
    
    if case .forwardedMessages = chatPresentationInterfaceState.subject {
        return (nil, nil)
    }
    
    if let _ = chatPresentationInterfaceState.search {
        var selectionPanel: ChatMessageSelectionInputPanelNode?
        if let selectionState = chatPresentationInterfaceState.interfaceState.selectionState {
            if let currentPanel = (currentPanel as? ChatMessageSelectionInputPanelNode) ?? (currentSecondaryPanel as? ChatMessageSelectionInputPanelNode) {
                currentPanel.selectedMessages = selectionState.selectedIds
                currentPanel.interfaceInteraction = interfaceInteraction
                currentPanel.updateTheme(theme: chatPresentationInterfaceState.theme)
                selectionPanel = currentPanel
            } else {
                let panel = ChatMessageSelectionInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.context = context
                panel.selectedMessages = selectionState.selectedIds
                panel.interfaceInteraction = interfaceInteraction
                selectionPanel = panel
            }
        }
        
        if let currentPanel = (currentPanel as? ChatSearchInputPanelNode) ?? (currentSecondaryPanel as? ChatSearchInputPanelNode) {
            currentPanel.interfaceInteraction = interfaceInteraction
            return (currentPanel, selectionPanel)
        } else {
            let panel = ChatSearchInputPanelNode(theme: chatPresentationInterfaceState.theme)
            panel.context = context
            panel.interfaceInteraction = interfaceInteraction
            return (panel, selectionPanel)
        }
    }
    
    if let selectionState = chatPresentationInterfaceState.interfaceState.selectionState {
        if let _ = chatPresentationInterfaceState.reportReason {
            if let currentPanel = (currentPanel as? ChatMessageReportInputPanelNode) ?? (currentSecondaryPanel as? ChatMessageReportInputPanelNode) {
                currentPanel.selectedMessages = selectionState.selectedIds
                currentPanel.interfaceInteraction = interfaceInteraction
                currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                return (currentPanel, nil)
            } else {
                let panel = ChatMessageReportInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.context = context
                panel.selectedMessages = selectionState.selectedIds
                panel.interfaceInteraction = interfaceInteraction
                return (panel, nil)
            }
        } else {
            if let currentPanel = (currentPanel as? ChatMessageSelectionInputPanelNode) ?? (currentSecondaryPanel as? ChatMessageSelectionInputPanelNode) {
                currentPanel.selectedMessages = selectionState.selectedIds
                currentPanel.interfaceInteraction = interfaceInteraction
                currentPanel.updateTheme(theme: chatPresentationInterfaceState.theme)
                return (currentPanel, nil)
            } else {
                let panel = ChatMessageSelectionInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.context = context
                panel.selectedMessages = selectionState.selectedIds
                panel.interfaceInteraction = interfaceInteraction
                return (panel, nil)
            }
        }
    }
    
    if case .pinnedMessages = chatPresentationInterfaceState.subject {
        if let currentPanel = (currentPanel as? ChatChannelSubscriberInputPanelNode) ?? (currentSecondaryPanel as? ChatChannelSubscriberInputPanelNode) {
            return (currentPanel, nil)
        } else {
            let panel = ChatChannelSubscriberInputPanelNode()
            panel.interfaceInteraction = interfaceInteraction
            panel.context = context
            return (panel, nil)
        }
    }
    
    if chatPresentationInterfaceState.peerIsBlocked {
        if let currentPanel = (currentPanel as? ChatUnblockInputPanelNode) ?? (currentSecondaryPanel as? ChatUnblockInputPanelNode) {
            currentPanel.interfaceInteraction = interfaceInteraction
            currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return (currentPanel, nil)
        } else {
            let panel = ChatUnblockInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            panel.context = context
            panel.interfaceInteraction = interfaceInteraction
            return (panel, nil)
        }
    }
    
    var displayInputTextPanel = false
    
    if let peer = chatPresentationInterfaceState.renderedPeer?.peer {
        if peer.id.isReplies {
            if let currentPanel = (currentPanel as? ChatChannelSubscriberInputPanelNode) ?? (currentSecondaryPanel as? ChatChannelSubscriberInputPanelNode) {
                return (currentPanel, nil)
            } else {
                let panel = ChatChannelSubscriberInputPanelNode()
                panel.interfaceInteraction = interfaceInteraction
                panel.context = context
                return (panel, nil)
            }
        }
        
        if let secretChat = peer as? TelegramSecretChat {
            switch secretChat.embeddedState {
                case .handshake:
                    if let currentPanel = (currentPanel as? SecretChatHandshakeStatusInputPanelNode) ?? (currentSecondaryPanel as? SecretChatHandshakeStatusInputPanelNode) {
                        return (currentPanel, nil)
                    } else {
                        let panel = SecretChatHandshakeStatusInputPanelNode()
                        panel.context = context
                        panel.interfaceInteraction = interfaceInteraction
                        return (panel, nil)
                    }
                case .terminated:
                    if let currentPanel = (currentPanel as? DeleteChatInputPanelNode) ?? (currentSecondaryPanel as? DeleteChatInputPanelNode) {
                        return (currentPanel, nil)
                    } else {
                        let panel = DeleteChatInputPanelNode()
                        panel.context = context
                        panel.interfaceInteraction = interfaceInteraction
                        return (panel, nil)
                    }
                case .active:
                    break
            }
        } else if let channel = peer as? TelegramChannel {
            var isMember: Bool = false
            switch channel.participationStatus {
            case .kicked:
                if let currentPanel = (currentPanel as? DeleteChatInputPanelNode) ?? (currentSecondaryPanel as? DeleteChatInputPanelNode) {
                    return (currentPanel, nil)
                } else {
                    let panel = DeleteChatInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return (panel, nil)
                }
            case .member:
                isMember = true
            case .left:
                if case .replyThread = chatPresentationInterfaceState.chatLocation {
                    if !channel.flags.contains(.joinToSend) {
                        isMember = true
                    }
                }
            }
                        
            if isMember && channel.hasBannedPermission(.banSendMessages) != nil && !channel.flags.contains(.isGigagroup) {
                if let currentPanel = (currentPanel as? ChatRestrictedInputPanelNode) ?? (currentSecondaryPanel as? ChatRestrictedInputPanelNode) {
                    return (currentPanel, nil)
                } else {
                    let panel = ChatRestrictedInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return (panel, nil)
                }
            }
            
            switch channel.info {
            case .broadcast:
                if chatPresentationInterfaceState.interfaceState.editMessage != nil, channel.hasPermission(.editAllMessages) {
                    displayInputTextPanel = true
                } else if !channel.hasPermission(.sendMessages) || !isMember {
                    if let currentPanel = (currentPanel as? ChatChannelSubscriberInputPanelNode) ?? (currentSecondaryPanel as? ChatChannelSubscriberInputPanelNode) {
                        return (currentPanel, nil)
                    } else {
                        let panel = ChatChannelSubscriberInputPanelNode()
                        panel.interfaceInteraction = interfaceInteraction
                        panel.context = context
                        return (panel, nil)
                    }
                }
            case .group:
                switch channel.participationStatus {
                case .kicked, .left:
                    if !isMember {
                        if let currentPanel = (currentPanel as? ChatChannelSubscriberInputPanelNode) ?? (currentSecondaryPanel as? ChatChannelSubscriberInputPanelNode) {
                            return (currentPanel, nil)
                        } else {
                            let panel = ChatChannelSubscriberInputPanelNode()
                            panel.interfaceInteraction = interfaceInteraction
                            panel.context = context
                            return (panel, nil)
                        }
                    }
                case .member:
                    if channel.flags.contains(.isGigagroup) && !channel.hasPermission(.sendMessages) {
                        if let currentPanel = (currentPanel as? ChatChannelSubscriberInputPanelNode) ?? (currentSecondaryPanel as? ChatChannelSubscriberInputPanelNode) {
                            return (currentPanel, nil)
                        } else {
                            let panel = ChatChannelSubscriberInputPanelNode()
                            panel.interfaceInteraction = interfaceInteraction
                            panel.context = context
                            return (panel, nil)
                        }
                    } else {
                        break
                    }
                }
            }
        } else if let group = peer as? TelegramGroup {
            switch group.membership {
            case .Removed, .Left:
                if let currentPanel = (currentPanel as? DeleteChatInputPanelNode) ?? (currentSecondaryPanel as? DeleteChatInputPanelNode) {
                    return (currentPanel, nil)
                } else {
                    let panel = DeleteChatInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return (panel, nil)
                }
            case .Member:
                break
            }
            
            if group.hasBannedPermission(.banSendMessages) {
                if let currentPanel = (currentPanel as? ChatRestrictedInputPanelNode) ?? (currentSecondaryPanel as? ChatRestrictedInputPanelNode) {
                    return (currentPanel, nil)
                } else {
                    let panel = ChatRestrictedInputPanelNode()
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return (panel, nil)
                }
            }
        }
        
        var displayBotStartPanel = false
        
        var isScheduledMessages = false
        if case .scheduledMessages = chatPresentationInterfaceState.subject {
            isScheduledMessages = true
        }
        
        if !isScheduledMessages {
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
            if let currentPanel = (currentPanel as? ChatBotStartInputPanelNode) ?? (currentSecondaryPanel as? ChatBotStartInputPanelNode) {
                currentPanel.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                return (currentPanel, nil)
            } else {
                let panel = ChatBotStartInputPanelNode(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.context = context
                panel.interfaceInteraction = interfaceInteraction
                return (panel, nil)
            }
        } else {
            if let _ = chatPresentationInterfaceState.recordedMediaPreview {
                if let currentPanel = (currentPanel as? ChatRecordingPreviewInputPanelNode) ?? (currentSecondaryPanel as? ChatRecordingPreviewInputPanelNode) {
                    return (currentPanel, nil)
                } else {
                    let panel = ChatRecordingPreviewInputPanelNode(theme: chatPresentationInterfaceState.theme)
                    panel.context = context
                    panel.interfaceInteraction = interfaceInteraction
                    return (panel, nil)
                }
            }
            
            displayInputTextPanel = true
        }
    }
    
    if case .inline = chatPresentationInterfaceState.mode {
        displayInputTextPanel = false
    }
    
    if displayInputTextPanel {
        if let currentPanel = (currentPanel as? ChatTextInputPanelNode) ?? (currentSecondaryPanel as? ChatTextInputPanelNode) {
            currentPanel.interfaceInteraction = interfaceInteraction
            return (currentPanel, nil)
        } else {
            if let textInputPanelNode = textInputPanelNode {
                textInputPanelNode.interfaceInteraction = interfaceInteraction
                textInputPanelNode.context = context
                return (textInputPanelNode, nil)
            } else {
                let panel = ChatTextInputPanelNode(presentationInterfaceState: chatPresentationInterfaceState, presentationContext: nil, presentController: { [weak interfaceInteraction] controller in
                    interfaceInteraction?.presentController(controller, nil)
                })
                
                panel.interfaceInteraction = interfaceInteraction
                panel.context = context
                return (panel, nil)
            }
        }
    } else {
        return (nil, nil)
    }
}
