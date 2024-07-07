import Foundation
import UIKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction

func titlePanelForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatTitleAccessoryPanelNode?, controllerInteraction: ChatControllerInteraction?, interfaceInteraction: ChatPanelInterfaceInteraction?, force: Bool) -> ChatTitleAccessoryPanelNode? {
    if !force, case .standard(.embedded) = chatPresentationInterfaceState.mode {
        return nil
    }
    
    if case .overlay = chatPresentationInterfaceState.mode {
        return nil
    }
    if chatPresentationInterfaceState.renderedPeer?.peer?.restrictionText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) != nil {
        return nil
    }
    if let search = chatPresentationInterfaceState.search {
        var matches = false
        if chatPresentationInterfaceState.chatLocation.peerId == context.account.peerId {
            if chatPresentationInterfaceState.hasSearchTags || !chatPresentationInterfaceState.isPremium {
                if case .everything = search.domain {
                    matches = true
                } else if case .tag = search.domain, search.query.isEmpty {
                    matches = true
                }
            }
        }
        if case .standard(.embedded) = chatPresentationInterfaceState.mode {
            if !chatPresentationInterfaceState.isPremium {
                matches = false
            }
        }
        
        if matches {
            if let currentPanel = currentPanel as? ChatSearchTitleAccessoryPanelNode {
                return currentPanel
            } else {
                let panel = ChatSearchTitleAccessoryPanelNode(context: context, chatLocation: chatPresentationInterfaceState.chatLocation)
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        } else {
            return nil
        }
    }
    
    var inhibitTitlePanelDisplay = false
    switch chatPresentationInterfaceState.subject {
    case .messageOptions:
        return nil
    case .scheduledMessages, .pinnedMessages:
        inhibitTitlePanelDisplay = true
    case let .customChatContents(customChatContents):
        switch customChatContents.kind {
        case .hashTagSearch:
            break
        case .quickReplyMessageInput:
            break
        case .businessLinkSetup:
            if let currentPanel = currentPanel as? ChatBusinessLinkTitlePanelNode {
                return currentPanel
            } else {
                let panel = ChatBusinessLinkTitlePanelNode(context: context)
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        }
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
                case .requestInProgress, .toastAlert, .inviteRequests:
                    selectedContext = context
                    break loop
            }
        }
    }

    if inhibitTitlePanelDisplay, let selectedContextValue = selectedContext {
        switch selectedContextValue {
        case .pinnedMessage:
            if case .peer = chatPresentationInterfaceState.chatLocation {
                selectedContext = nil
            }
            break
        default:
            selectedContext = nil
        }
    }
    
    if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.flags.contains(.isForum) {
        if let threadData = chatPresentationInterfaceState.threadData {
            if threadData.isClosed {
                var canManage = false
                if channel.flags.contains(.isCreator) {
                    canManage = true
                } else if channel.hasPermission(.manageTopics) {
                    canManage = true
                } else if threadData.isOwnedByMe {
                    canManage = true
                }
                
                if canManage {
                    if let currentPanel = currentPanel as? ChatReportPeerTitlePanelNode {
                        return currentPanel
                    } else if let controllerInteraction = controllerInteraction {
                        let panel = ChatReportPeerTitlePanelNode(context: context, animationCache: controllerInteraction.presentationContext.animationCache, animationRenderer: controllerInteraction.presentationContext.animationRenderer)
                        panel.interfaceInteraction = interfaceInteraction
                        return panel
                    }
                }
            }
        }
    }
    
    var displayActionsPanel = false
    if !chatPresentationInterfaceState.peerIsBlocked && !inhibitTitlePanelDisplay, let contactStatus = chatPresentationInterfaceState.contactStatus {
        if let peerStatusSettings = contactStatus.peerStatusSettings {
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
            if peerStatusSettings.requestChatTitle != nil {
                displayActionsPanel = true
            }
        }
    }
    
    if (selectedContext == nil || selectedContext! <= .pinnedMessage) {
        if displayActionsPanel {
            if let currentPanel = currentPanel as? ChatReportPeerTitlePanelNode {
                return currentPanel
            } else if let controllerInteraction = controllerInteraction {
                let panel = ChatReportPeerTitlePanelNode(context: context, animationCache: controllerInteraction.presentationContext.animationCache, animationRenderer: controllerInteraction.presentationContext.animationRenderer)
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        } else if !chatPresentationInterfaceState.peerIsBlocked && !inhibitTitlePanelDisplay, let contactStatus = chatPresentationInterfaceState.contactStatus, contactStatus.managingBot != nil {
            if let currentPanel = currentPanel as? ChatManagingBotTitlePanelNode {
                return currentPanel
            } else {
                let panel = ChatManagingBotTitlePanelNode(context: context)
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        }
    }
    
    if let selectedContext = selectedContext {
        switch selectedContext {
            case .pinnedMessage:
                if let currentPanel = currentPanel as? ChatPinnedMessageTitlePanelNode {
                    return currentPanel
                } else {
                    let panel = ChatPinnedMessageTitlePanelNode(context: context, animationCache: controllerInteraction?.presentationContext.animationCache, animationRenderer: controllerInteraction?.presentationContext.animationRenderer)
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
