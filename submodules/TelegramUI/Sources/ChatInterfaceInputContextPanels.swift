import Foundation
import UIKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState

private func inputQueryResultPriority(_ result: ChatPresentationInputQueryResult) -> (Int, Bool) {
    switch result {
        case let .stickers(items):
            return (0, !items.isEmpty)
        case let .hashtags(items):
            return (1, !items.isEmpty)
        case let .mentions(items):
            return (2, !items.isEmpty)
        case let .commands(items):
            return (3, !items.isEmpty)
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

func inputContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatInputContextPanelNode?, controllerInteraction: ChatControllerInteraction?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputContextPanelNode? {
    guard let _ = chatPresentationInterfaceState.renderedPeer?.peer else {
        return nil
    }
    
    if chatPresentationInterfaceState.showCommands, let renderedPeer = chatPresentationInterfaceState.renderedPeer {
        if let currentPanel = currentPanel as? CommandMenuChatInputContextPanelNode {
            return currentPanel
        } else {
            let panel = CommandMenuChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, peerId: renderedPeer.peerId)
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
                    let panel = DisabledContextResultsChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize)
                    panel.interfaceInteraction = interfaceInteraction
                    return panel
            }
            default:
                break
        }
    }
    
    switch inputQueryResult {
        case let .stickers(results):
            if !results.isEmpty {
                let query = chatPresentationInterfaceState.interfaceState.composeInputState.inputText.string
                
                if let currentPanel = currentPanel as? InlineReactionSearchPanel {
                    currentPanel.updateResults(results: results.map({ $0.file }), query: query)
                    return currentPanel
                } else {
                    let panel = InlineReactionSearchPanel(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, peerId: chatPresentationInterfaceState.renderedPeer?.peerId)
                    panel.controllerInteraction = controllerInteraction
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(results: results.map({ $0.file }), query: query)
                    return panel
                }
            }
        case let .hashtags(results):
            if !results.isEmpty {
                if let currentPanel = currentPanel as? HashtagChatInputContextPanelNode {
                    currentPanel.updateResults(results)
                    return currentPanel
                } else {
                    let panel = HashtagChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(results)
                    return panel
                }
            }
        case let .emojis(results, _):
            if !results.isEmpty {
                if let currentPanel = currentPanel as? EmojisChatInputContextPanelNode {
                    currentPanel.updateResults(results)
                    return currentPanel
                } else {
                    let panel = EmojisChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize)
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
                    let panel = MentionChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, mode: .input)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(peers)
                    return panel
                }
            } else {
                return nil
            }
        case let .commands(commands):
            if !commands.isEmpty {
                if let currentPanel = currentPanel as? CommandChatInputContextPanelNode {
                    currentPanel.updateResults(commands)
                    return currentPanel
                } else {
                    let panel = CommandChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(commands)
                    return panel
                }
            } else {
                return nil
            }
        case let .contextRequestResult(_, results):
            if let results = results, (!results.results.isEmpty || results.switchPeer != nil) {
                switch results.presentation {
                    case .list:
                        if let currentPanel = currentPanel as? VerticalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = VerticalListContextResultsChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize)
                            panel.interfaceInteraction = interfaceInteraction
                            panel.updateResults(results)
                            return panel
                        }
                    case .media:
                        if let currentPanel = currentPanel as? HorizontalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = HorizontalListContextResultsChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize)
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

func chatOverlayContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: ChatInputContextPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputContextPanelNode? {
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
                    let panel = MentionChatInputContextPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, mode: .search)
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

