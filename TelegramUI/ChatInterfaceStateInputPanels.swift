import Foundation
import AsyncDisplayKit
import TelegramCore

func inputPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatInputPanelNode?, textInputPanelNode: ChatTextInputPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputPanelNode? {
    if let selectionState = chatPresentationInterfaceState.interfaceState.selectionState {
        if let currentPanel = currentPanel as? ChatMessageSelectionInputPanelNode {
            currentPanel.selectedMessageCount = selectionState.selectedIds.count
            currentPanel.interfaceInteraction = interfaceInteraction
            currentPanel.peer = chatPresentationInterfaceState.peer
            return currentPanel
        } else {
            let panel = ChatMessageSelectionInputPanelNode()
            panel.account = account
            panel.peer = chatPresentationInterfaceState.peer
            panel.selectedMessageCount = selectionState.selectedIds.count
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    } else {
        if let peer = chatPresentationInterfaceState.peer {
            if let channel = peer as? TelegramChannel {
                switch channel.info {
                    case .broadcast:
                        switch channel.role {
                            case .creator, .editor, .moderator:
                                break
                            case .member:
                                if let currentPanel = currentPanel as? ChatChannelSubscriberInputPanelNode {
                                    currentPanel.peer = peer
                                    return currentPanel
                                } else {
                                    let panel = ChatChannelSubscriberInputPanelNode()
                                    panel.account = account
                                    panel.peer = peer
                                    return panel
                                }
                        }
                    case .group:
                        switch channel.participationStatus {
                            case .kicked, .left:
                                if let currentPanel = currentPanel as? ChatChannelSubscriberInputPanelNode {
                                    currentPanel.peer = peer
                                    return currentPanel
                                } else {
                                    let panel = ChatChannelSubscriberInputPanelNode()
                                    panel.account = account
                                    panel.peer = peer
                                    return panel
                                }
                            case .member:
                                break
                        }
                }
            }
            
            if let currentPanel = currentPanel as? ChatTextInputPanelNode {
                currentPanel.interfaceInteraction = interfaceInteraction
                currentPanel.peer = peer
                return currentPanel
            } else {
                if let textInputPanelNode = textInputPanelNode {
                    textInputPanelNode.interfaceInteraction = interfaceInteraction
                    textInputPanelNode.account = account
                    textInputPanelNode.peer = peer
                    return textInputPanelNode
                } else {
                    let panel = ChatTextInputPanelNode()
                    panel.interfaceInteraction = interfaceInteraction
                    panel.account = account
                    panel.peer = peer
                    return panel
                }
            }
        } else {
            return nil
        }
    }
}
