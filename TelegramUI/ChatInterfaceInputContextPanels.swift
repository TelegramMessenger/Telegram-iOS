import Foundation
import TelegramCore

/*
 case stickers([FoundStickerItem])
 case hashtags([String])
 case mentions([Peer])
 case commands([PeerCommand])
 case emojis([(String, String)])
 case contextRequestResult(Peer?, ChatContextResultCollection?)
 */

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
        case let .emojis(items):
            return (5, !items.isEmpty)
    }
}

func inputContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatInputContextPanelNode?, controllerInteraction: ChatControllerInteraction?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputContextPanelNode? {
    guard let _ = chatPresentationInterfaceState.renderedPeer?.peer else {
        return nil
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
    
    if let bannedRights = (chatPresentationInterfaceState.renderedPeer?.peer as? TelegramChannel)?.bannedRights, bannedRights.flags.contains(.banSendInline) {
        switch inputQueryResult {
            case .stickers, .contextRequestResult:
                if let currentPanel = currentPanel as? DisabledContextResultsChatInputContextPanelNode {
                    return currentPanel
                } else {
                    let panel = DisabledContextResultsChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
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
                if let currentPanel = currentPanel as? HorizontalStickersChatContextPanelNode {
                    currentPanel.updateResults(results.map({ $0.file }))
                    return currentPanel
                } else {
                    let panel = HorizontalStickersChatContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                    panel.controllerInteraction = controllerInteraction
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(results.map({ $0.file }))
                    return panel
                }
            }
        case let .hashtags(results):
            if let currentPanel = currentPanel as? HashtagChatInputContextPanelNode {
                currentPanel.updateResults(results)
                return currentPanel
            } else {
                let panel = HashtagChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panel.interfaceInteraction = interfaceInteraction
                panel.updateResults(results)
                return panel
            }
        case let .emojis(results):
            if !results.isEmpty {
                if let currentPanel = currentPanel as? EmojisChatInputContextPanelNode {
                    currentPanel.updateResults(results)
                    return currentPanel
                } else {
                    let panel = EmojisChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
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
                    let panel = MentionChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, mode: .input)
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
                    let panel = CommandChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
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
                            let panel = VerticalListContextResultsChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                            panel.interfaceInteraction = interfaceInteraction
                            panel.updateResults(results)
                            return panel
                        }
                    case .media:
                        if let currentPanel = currentPanel as? HorizontalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = HorizontalListContextResultsChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
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

func chatOverlayContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatInputContextPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputContextPanelNode? {
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
                    let panel = MentionChatInputContextPanelNode(account: account, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, mode: .search)
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

