import Foundation
import UIKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState

func titlePanelForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatTitleAccessoryPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatTitleAccessoryPanelNode? {
    if case .overlay = chatPresentationInterfaceState.mode {
        return nil
    }
    if chatPresentationInterfaceState.renderedPeer?.peer?.restrictionText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) != nil {
        return nil
    }
    if chatPresentationInterfaceState.search != nil {
        return nil
    }
    
    var inhibitTitlePanelDisplay = false
    switch chatPresentationInterfaceState.subject {
    case .forwardedMessages:
        return nil
    case .scheduledMessages, .pinnedMessages:
        inhibitTitlePanelDisplay = true
    default:
        break
    }
    if case .peer = chatPresentationInterfaceState.chatLocation {
    } else {
        inhibitTitlePanelDisplay = true
    }
    
    var selectedContext: ChatTitlePanelContext?
    if !chatPresentationInterfaceState.titlePanelContexts.isEmpty {
        loop: for context in chatPresentationInterfaceState.titlePanelContexts.reversed() {
            switch context {
                case .pinnedMessage:
                    if case .pinnedMessages = chatPresentationInterfaceState.subject {
                    } else {
                        if let pinnedMessage = chatPresentationInterfaceState.pinnedMessage, pinnedMessage.topMessageId != chatPresentationInterfaceState.interfaceState.messageActionsState.closedPinnedMessageId, !chatPresentationInterfaceState.pendingUnpinnedAllMessages {
                            selectedContext = context
                            break loop
                        }
                    }
                case .chatInfo, .requestInProgress, .toastAlert, .inviteRequests:
                    selectedContext = context
                    break loop
            }
        }
    }

    if inhibitTitlePanelDisplay, let selectedContextValue = selectedContext {
        switch selectedContextValue {
        case .pinnedMessage:
            break
        default:
            selectedContext = nil
        }
    }
    
    var displayActionsPanel = false
    if !chatPresentationInterfaceState.peerIsBlocked && !inhibitTitlePanelDisplay, let contactStatus = chatPresentationInterfaceState.contactStatus, let peerStatusSettings = contactStatus.peerStatusSettings {
        if !peerStatusSettings.flags.isEmpty {
            if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
                displayActionsPanel = true
            } else if peerStatusSettings.contains(.canReport) || peerStatusSettings.contains(.canBlock) || peerStatusSettings.contains(.autoArchived) {
                displayActionsPanel = true
            } else if peerStatusSettings.contains(.canShareContact) {
                displayActionsPanel = true
            } else if contactStatus.canReportIrrelevantLocation && peerStatusSettings.contains(.canReportIrrelevantGeoLocation) {
                displayActionsPanel = true
            } else if peerStatusSettings.contains(.suggestAddMembers) {
                displayActionsPanel = true
            }
        }
    }
    
    if displayActionsPanel && (selectedContext == nil || selectedContext! <= .pinnedMessage) {
        if let currentPanel = currentPanel as? ChatReportPeerTitlePanelNode {
            return currentPanel
        } else {
            let panel = ChatReportPeerTitlePanelNode()
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    }
    
    if let selectedContext = selectedContext {
        switch selectedContext {
            case .pinnedMessage:
                if let currentPanel = currentPanel as? ChatPinnedMessageTitlePanelNode {
                    return currentPanel
                } else {
                    let panel = ChatPinnedMessageTitlePanelNode(context: context)
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            case .chatInfo:
                if let currentPanel = currentPanel as? ChatInfoTitlePanelNode {
                    return currentPanel
                } else {
                    let panel = ChatInfoTitlePanelNode()
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            case .requestInProgress:
                if let currentPanel = currentPanel as? ChatRequestInProgressTitlePanelNode {
                    return currentPanel
                } else {
                    let panel = ChatRequestInProgressTitlePanelNode()
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            case let .toastAlert(text):
                if let currentPanel = currentPanel as? ChatToastAlertPanelNode {
                    currentPanel.text = text
                    return currentPanel
                } else {
                    let panel = ChatToastAlertPanelNode()
                    panel.text = text
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
                }
            case let .inviteRequests(peers, count):
                if let peerId = chatPresentationInterfaceState.renderedPeer?.peerId {
                    if let currentPanel = currentPanel as? ChatInviteRequestsTitlePanelNode {
                        currentPanel.update(peerId: peerId, peers: peers, count: count)
                        return currentPanel
                    } else {
                        let panel = ChatInviteRequestsTitlePanelNode(context: context)
                        panel.interfaceInteraction = interfaceInteraction
                        panel.update(peerId: peerId, peers: peers, count: count)
                        return panel
                    }
                }
        }
    }
    
    return nil
}
