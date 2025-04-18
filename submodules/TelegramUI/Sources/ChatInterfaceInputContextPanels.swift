import Foundation
import UIKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatInputContextPanelNode

private func inputQueryResultPriority(_ result: ChatPresentationInputQueryResult) -> (Int, Bool) {
    switch result {
        case let .stickers(items):
            return (0, !items.isEmpty)
        case let .hashtags(items, _):
            return (1, !items.isEmpty)
        case let .mentions(items):
            return (2, !items.isEmpty)
        case let .commands(items):
            return (3, !items.commands.isEmpty || items.hasShortcuts)
        case let .contextRequestResult(_, result):
            var nonEmpty = false
            if let result = result, !result.results.isEmpty {
                nonEmpty = true
            }
            return (4, nonEmpty)
        case let .emojis(items, _):
            return (5, !items.isEmpty)
    }
}

func inputContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatInputContextPanelNode?, controllerInteraction: ChatControllerInteraction, interfaceInteraction: ChatPanelInterfaceInteraction?, chatPresentationContext: ChatPresentationContext) -> ChatInputContextPanelNode? {
    if chatPresentationInterfaceState.showCommands, let renderedPeer = chatPresentationInterfaceState.renderedPeer {
        if let currentPanel = currentPanel as? CommandMenuChatInputContextPanelNode {
            return currentPanel
        } else {
            let panel = CommandMenuChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, peerId: renderedPeer.peerId, chatPresentationContext: chatPresentationContext)
            panel.interfaceInteraction = interfaceInteraction
            return panel
        }
    }
    
    guard let inputQueryResult = chatPresentationInterfaceState.inputQueryResults.values.sorted(by: { lhs, rhs in
        let (lhsP, lhsHasItems) = inputQueryResultPriority(lhs)
        let (rhsP, rhsHasItems) = inputQueryResultPriority(rhs)
        if lhsHasItems != rhsHasItems {
            if lhsHasItems {
                return true
            } else {
                return false
            }
        }
        return lhsP < rhsP
    }).first else {
        return nil
    }
    
    var hasBannedInlineContent = false
    if let channel = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.hasBannedPermission(.banSendInline) != nil {
        hasBannedInlineContent = true
    } else if let group = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramGroup, group.hasBannedPermission(.banSendInline) {
        hasBannedInlineContent = true
    }
    
    if hasBannedInlineContent {
        switch inputQueryResult {
            case .stickers, .contextRequestResult:
                if let currentPanel = currentPanel as? DisabledContextResultsChatInputContextPanelNode {
                    return currentPanel
                } else {
                    let panel = DisabledContextResultsChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, chatPresentationContext: controllerInteraction.presentationContext)
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
            }
            default:
                break
        }
    }
    
    switch inputQueryResult {
        case let .stickers(unfilteredResults):
            if !unfilteredResults.isEmpty {
                var results: [FoundStickerItem] = []
                for result in unfilteredResults {
                    if !results.contains(where: { $0.file.fileId == result.file.fileId }) {
                        results.append(result)
                    }
                }
                
                let query = chatPresentationInterfaceState.interfaceState.composeInputState.inputText.string
                
                if let currentPanel = currentPanel as? InlineReactionSearchPanel {
                    currentPanel.updateResults(results: results.map({ $0.file }), query: query)
                    return currentPanel
                } else {
                    let panel = InlineReactionSearchPanel(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, peerId: chatPresentationInterfaceState.renderedPeer?.peerId, chatPresentationContext: chatPresentationContext)
                    panel.controllerInteraction = controllerInteraction
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(results: results.map({ $0.file }), query: query)
                    return panel
                }
            }
        case let .hashtags(results, query):
            var peer: EnginePeer?
            if let chatPeer = chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel, chatPeer.addressName != nil {
                peer = EnginePeer(chatPeer)
            }
            if !results.isEmpty || (peer != nil && query.count >= 4) {
                if let currentPanel = currentPanel as? HashtagChatInputContextPanelNode {
                    currentPanel.updateResults(results, query: query, peer: peer)
                    return currentPanel
                } else {
                    let panel = HashtagChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, chatPresentationContext: controllerInteraction.presentationContext)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(results, query: query, peer: peer)
                    return panel
                }
            }
        case let .emojis(results, _):
            if !results.isEmpty {
                if let currentPanel = currentPanel as? EmojisChatInputContextPanelNode {
                    currentPanel.updateResults(results)
                    return currentPanel
                } else {
                    let panel = EmojisChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, chatPresentationContext: chatPresentationContext)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(results)
                    return panel
                }
            }
        case let .mentions(peers):
            if !peers.isEmpty {
                if let currentPanel = currentPanel as? MentionChatInputContextPanelNode, currentPanel.mode == .input {
                    currentPanel.updateResults(peers)
                    return currentPanel
                } else {
                    let panel = MentionChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, mode: .input, chatPresentationContext: chatPresentationContext)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(peers)
                    return panel
                }
            } else {
                return nil
            }
        case let .commands(commands):
            if !commands.commands.isEmpty || commands.hasShortcuts {
                if let currentPanel = currentPanel as? CommandChatInputContextPanelNode {
                    currentPanel.updateResults(commands.commands, accountPeer: commands.accountPeer, hasShortcuts: commands.hasShortcuts, query: commands.query)
                    return currentPanel
                } else {
                    let panel = CommandChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, chatPresentationContext: controllerInteraction.presentationContext)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(commands.commands, accountPeer: commands.accountPeer, hasShortcuts: commands.hasShortcuts, query: commands.query)
                    return panel
                }
            } else {
                return nil
            }
        case let .contextRequestResult(_, results):
            if let results = results, (!results.results.isEmpty || results.switchPeer != nil || results.webView != nil) {
                switch results.presentation {
                    case .list:
                        if let currentPanel = currentPanel as? VerticalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = VerticalListContextResultsChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, chatPresentationContext: controllerInteraction.presentationContext)
                            panel.interfaceInteraction = interfaceInteraction
                            panel.updateResults(results)
                            return panel
                        }
                    case .media:
                        if let currentPanel = currentPanel as? HorizontalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = HorizontalListContextResultsChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, chatPresentationContext: controllerInteraction.presentationContext)
                            panel.interfaceInteraction = interfaceInteraction
                            panel.updateResults(results)
                            return panel
                        }
                }
            } else {
                return nil
            }
    }
    
    return nil
}

func chatOverlayContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatInputContextPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?, chatPresentationContext: ChatPresentationContext) -> ChatInputContextPanelNode? {
    guard let searchQuerySuggestionResult = chatPresentationInterfaceState.searchQuerySuggestionResult, let _ = chatPresentationInterfaceState.renderedPeer?.peer else {
        return nil
    }
    
    switch searchQuerySuggestionResult {
        case let .mentions(peers):
            if !peers.isEmpty {
                if let currentPanel = currentPanel as? MentionChatInputContextPanelNode, currentPanel.mode == .search {
                    currentPanel.updateResults(peers)
                    return currentPanel
                } else {
                    let panel = MentionChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, mode: .search, chatPresentationContext: chatPresentationContext)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(peers)
                    return panel
                }
            } else {
                return nil
            }
        default:
            break
    }
    
    return nil
}

