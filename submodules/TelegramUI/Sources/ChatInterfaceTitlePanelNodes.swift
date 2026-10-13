import Foundation
import UIKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ComponentFlow
import ChatSideTopicsPanel
import LegacyChatHeaderPanelComponent

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
        case .welcomeMessages:
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
    
    if let _ = chatPresentationInterfaceState.peerVerification {
        if let currentPanel = currentPanel as? ChatVerifiedPeerTitlePanelNode {
            return currentPanel
        } else if let controllerInteraction = controllerInteraction {
            let panel = ChatVerifiedPeerTitlePanelNode(context: context, animationCache: controllerInteraction.presentationContext.animationCache, animationRenderer: controllerInteraction.presentationContext.animationRenderer)
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    }
    
    if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForumOrMonoForum {
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
    } else if chatPresentationInterfaceState.isManagedBot, let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.profileImageRepresentations.isEmpty {
        if let currentPanel = currentPanel as? ChatReportPeerTitlePanelNode {
            return currentPanel
        } else if let controllerInteraction = controllerInteraction {
            let panel = ChatReportPeerTitlePanelNode(context: context, animationCache: controllerInteraction.presentationContext.animationCache, animationRenderer: controllerInteraction.presentationContext.animationRenderer)
            panel.interfaceInteraction = interfaceInteraction
            return panel
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

/// The "bot manages this chat" bar of a business chat.
///
/// It is deliberately NOT one of the mutually exclusive panels returned by
/// `titlePanelForChatPresentationInterfaceState`: it used to be, ranked above the pinned-message
/// context, so for as long as a business bot managed a chat the pinned-message bar was replaced by
/// the bot bar and the pinned messages were unreachable from the chat (bugs.telegram.org/c/45791).
/// The chat node gives this panel its own slot in the header-panel stack, above the pinned bar,
/// so both are visible.
///
/// `displayedTitlePanel` is the panel `titlePanelForChatPresentationInterfaceState` chose for the
/// same state. The bot bar still yields to the two dismissable notices that outranked it before,
/// the peer-actions (report / add contact) bar and the peer-verification bar, but only while one
/// of them is actually on screen: deciding from the bar's *eligibility* instead would blank the
/// bot bar for the lifetime of every transient context (an in-progress request, a toast) that
/// displaces the report bar without showing it.
func managingBotTitlePanelForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, displayedTitlePanel: ChatTitleAccessoryPanelNode?, currentPanel: ChatManagingBotTitlePanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatManagingBotTitlePanelNode? {
    guard let contactStatus = chatPresentationInterfaceState.contactStatus, contactStatus.managingBot != nil else {
        return nil
    }
    if chatPresentationInterfaceState.peerIsBlocked {
        return nil
    }
    switch chatPresentationInterfaceState.mode {
    case .standard(.embedded), .overlay:
        return nil
    default:
        break
    }
    if chatPresentationInterfaceState.renderedPeer?.peer?.restrictionText(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) != nil {
        return nil
    }
    if chatPresentationInterfaceState.search != nil {
        return nil
    }
    switch chatPresentationInterfaceState.subject {
    case .messageOptions, .scheduledMessages, .pinnedMessages:
        return nil
    case let .customChatContents(customChatContents):
        if case .businessLinkSetup = customChatContents.kind {
            return nil
        }
    default:
        break
    }
    guard case .peer = chatPresentationInterfaceState.chatLocation else {
        return nil
    }
    if displayedTitlePanel is ChatReportPeerTitlePanelNode || displayedTitlePanel is ChatVerifiedPeerTitlePanelNode {
        return nil
    }
    
    if let currentPanel {
        return currentPanel
    }
    let panel = ChatManagingBotTitlePanelNode(context: context)
    panel.interfaceInteraction = interfaceInteraction
    return panel
}

func headerTopicsPanelForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, controllerInteraction: ChatControllerInteraction?, interfaceInteraction: ChatPanelInterfaceInteraction?, force: Bool) -> AnyComponent<Empty>? {
    guard let peerId = chatPresentationInterfaceState.chatLocation.peerId else {
        return nil
    }
    if chatPresentationInterfaceState.subject?.isService ?? false {
        return nil
    }
    if peerId.namespace == Namespaces.Peer.CloudUser {
        guard let chatHistoryState = chatPresentationInterfaceState.chatHistoryState else {
            return nil
        }
        switch chatHistoryState {
        case .loading:
            return nil
        case let .loaded(isEmpty, _):
            if isEmpty && chatPresentationInterfaceState.chatLocation.threadId == nil {
                return nil
            }
        }
    }
    
    if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = chatPresentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect), chatPresentationInterfaceState.search == nil {
        let topicListDisplayModeOnTheSide = chatPresentationInterfaceState.persistentData.topicListPanelLocation == .side
        if !topicListDisplayModeOnTheSide {
            return AnyComponent(ChatTopicsHeaderPanelComponent(
                context: context,
                theme: chatPresentationInterfaceState.theme,
                strings: chatPresentationInterfaceState.strings,
                peerId: peerId,
                kind: .monoforum,
                location: chatPresentationInterfaceState.persistentData.topicListPanelLocation == .top ? .top : .bottom,
                topicId: chatPresentationInterfaceState.chatLocation.threadId,
                controller: { [weak interfaceInteraction] in
                    return interfaceInteraction?.chatController()
                },
                togglePanel: { [weak interfaceInteraction] in
                    interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak interfaceInteraction] topicId, direction in
                    interfaceInteraction?.updateChatLocationThread(topicId, direction)
                },
                openDeletePeer: { [weak interfaceInteraction] threadId in
                    guard let controller = interfaceInteraction?.chatController() as? ChatControllerImpl else {
                        return
                    }
                    controller.openDeleteMonoforumPeer(peerId: EnginePeer.Id(threadId))
                }
            ))
        }
    } else if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForum, chatPresentationInterfaceState.search == nil {
        if !chatPresentationInterfaceState.viewForumAsMessages {
            return nil
        }
        let topicListDisplayModeOnTheSide = chatPresentationInterfaceState.persistentData.topicListPanelLocation == .side
        if !topicListDisplayModeOnTheSide {
            return AnyComponent(ChatTopicsHeaderPanelComponent(
                context: context,
                theme: chatPresentationInterfaceState.theme,
                strings: chatPresentationInterfaceState.strings,
                peerId: peerId,
                kind: .forum,
                location: chatPresentationInterfaceState.persistentData.topicListPanelLocation == .top ? .top : .bottom,
                topicId: chatPresentationInterfaceState.chatLocation.threadId,
                controller: { [weak interfaceInteraction] in
                    return interfaceInteraction?.chatController()
                },
                togglePanel: { [weak interfaceInteraction] in
                    interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak interfaceInteraction] topicId, direction in
                    interfaceInteraction?.updateChatLocationThread(topicId, direction)
                },
                openDeletePeer: { [weak interfaceInteraction] threadId in
                    guard let controller = interfaceInteraction?.chatController() as? ChatControllerImpl else {
                        return
                    }
                    controller.openDeleteMonoforumPeer(peerId: EnginePeer.Id(threadId))
                }
            ))
        }
    } else if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum), chatPresentationInterfaceState.search == nil {
        if !botInfo.flags.contains(.forumManagedByUser) {
            if !chatPresentationInterfaceState.hasTopics {
                return nil
            }
        }
        let topicListDisplayModeOnTheSide = chatPresentationInterfaceState.persistentData.topicListPanelLocation == .side
        if !topicListDisplayModeOnTheSide {
            return AnyComponent(ChatTopicsHeaderPanelComponent(
                context: context,
                theme: chatPresentationInterfaceState.theme,
                strings: chatPresentationInterfaceState.strings,
                peerId: peerId,
                kind: .botForum(forumManagedByUser: botInfo.flags.contains(.forumManagedByUser)),
                location: chatPresentationInterfaceState.persistentData.topicListPanelLocation == .top ? .top : .bottom,
                topicId: chatPresentationInterfaceState.chatLocation.threadId,
                controller: { [weak interfaceInteraction] in
                    return interfaceInteraction?.chatController()
                },
                togglePanel: { [weak interfaceInteraction] in
                    interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak interfaceInteraction] topicId, direction in
                    interfaceInteraction?.updateChatLocationThread(topicId, direction)
                },
                openDeletePeer: { [weak interfaceInteraction] threadId in
                    guard let controller = interfaceInteraction?.chatController() as? ChatControllerImpl else {
                        return
                    }
                    controller.openDeleteMonoforumPeer(peerId: EnginePeer.Id(threadId))
                }
            ))
        }
    }
    
    return nil
}

func floatingTopicsPanelForChatPresentationInterfaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, controllerInteraction: ChatControllerInteraction?, interfaceInteraction: ChatPanelInterfaceInteraction?, force: Bool) -> ChatFloatingTopicsPanel? {
    guard let peerId = chatPresentationInterfaceState.chatLocation.peerId else {
        return nil
    }
    if chatPresentationInterfaceState.subject?.isService ?? false {
        return nil
    }
    if peerId.namespace == Namespaces.Peer.CloudUser {
        guard let chatHistoryState = chatPresentationInterfaceState.chatHistoryState else {
            return nil
        }
        switch chatHistoryState {
        case .loading:
            return nil
        case let .loaded(isEmpty, _):
            if isEmpty && chatPresentationInterfaceState.chatLocation.threadId == nil {
                return nil
            }
        }
    }
    
    if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = chatPresentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect), chatPresentationInterfaceState.search == nil {
        let topicListDisplayModeOnTheSide = chatPresentationInterfaceState.persistentData.topicListPanelLocation == .side
        if topicListDisplayModeOnTheSide {
            return ChatFloatingTopicsPanel(
                context: context,
                theme: chatPresentationInterfaceState.theme,
                preferClearGlass: chatPresentationInterfaceState.preferredGlassType == .clear,
                strings: chatPresentationInterfaceState.strings,
                location: .side,
                peerId: peerId,
                kind: .monoforum,
                topicId: chatPresentationInterfaceState.chatLocation.threadId,
                controller: { [weak interfaceInteraction] in
                    return interfaceInteraction?.chatController()
                },
                togglePanel: { [weak interfaceInteraction] in
                    interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak interfaceInteraction] topicId, direction in
                    interfaceInteraction?.updateChatLocationThread(topicId, direction)
                },
                openDeletePeer: { [weak interfaceInteraction] threadId in
                    guard let controller = interfaceInteraction?.chatController() as? ChatControllerImpl else {
                        return
                    }
                    controller.openDeleteMonoforumPeer(peerId: EnginePeer.Id(threadId))
                }
            )
        }
    } else if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isForum, chatPresentationInterfaceState.search == nil {
        if !chatPresentationInterfaceState.viewForumAsMessages {
            return nil
        }
        let topicListDisplayModeOnTheSide = chatPresentationInterfaceState.persistentData.topicListPanelLocation == .side
        if topicListDisplayModeOnTheSide {
            return ChatFloatingTopicsPanel(
                context: context,
                theme: chatPresentationInterfaceState.theme,
                preferClearGlass: chatPresentationInterfaceState.preferredGlassType == .clear,
                strings: chatPresentationInterfaceState.strings,
                location: .side,
                peerId: peerId,
                kind: .forum,
                topicId: chatPresentationInterfaceState.chatLocation.threadId,
                controller: { [weak interfaceInteraction] in
                    return interfaceInteraction?.chatController()
                },
                togglePanel: { [weak interfaceInteraction] in
                    interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak interfaceInteraction] topicId, direction in
                    interfaceInteraction?.updateChatLocationThread(topicId, direction)
                },
                openDeletePeer: { [weak interfaceInteraction] threadId in
                    guard let controller = interfaceInteraction?.chatController() as? ChatControllerImpl else {
                        return
                    }
                    controller.openDeleteMonoforumPeer(peerId: EnginePeer.Id(threadId))
                }
            )
        }
    } else if let user = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.hasForum), chatPresentationInterfaceState.search == nil {
        if !botInfo.flags.contains(.forumManagedByUser) {
            if !chatPresentationInterfaceState.hasTopics {
                return nil
            }
        }
        let topicListDisplayModeOnTheSide = chatPresentationInterfaceState.persistentData.topicListPanelLocation == .side
        if topicListDisplayModeOnTheSide {
            return ChatFloatingTopicsPanel(
                context: context,
                theme: chatPresentationInterfaceState.theme,
                preferClearGlass: chatPresentationInterfaceState.preferredGlassType == .clear,
                strings: chatPresentationInterfaceState.strings,
                location: .side,
                peerId: peerId,
                kind: .botForum(forumManagedByUser: botInfo.flags.contains(.forumManagedByUser)),
                topicId: chatPresentationInterfaceState.chatLocation.threadId,
                controller: { [weak interfaceInteraction] in
                    return interfaceInteraction?.chatController()
                },
                togglePanel: { [weak interfaceInteraction] in
                    interfaceInteraction?.toggleChatSidebarMode()
                },
                updateTopicId: { [weak interfaceInteraction] topicId, direction in
                    interfaceInteraction?.updateChatLocationThread(topicId, direction)
                },
                openDeletePeer: { [weak interfaceInteraction] threadId in
                    guard let controller = interfaceInteraction?.chatController() as? ChatControllerImpl else {
                        return
                    }
                    controller.openDeleteMonoforumPeer(peerId: EnginePeer.Id(threadId))
                }
            )
        }
    }
    
    return nil
}
