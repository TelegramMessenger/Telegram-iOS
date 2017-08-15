import Foundation
import TelegramCore

func inputContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatInputContextPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputContextPanelNode? {
    guard let inputQueryResult = chatPresentationInterfaceState.inputQueryResult, let _ = chatPresentationInterfaceState.peer else {
        return nil
    }
    
    switch inputQueryResult {
        case let .stickers(results):
            if !results.isEmpty {
                if let currentPanel = currentPanel as? HorizontalStickersChatContextPanelNode {
                    currentPanel.updateResults(results.map({ $0.file }))
                    return currentPanel
                } else {
                    let panel = HorizontalStickersChatContextPanelNode(account: account)
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
                let panel = HashtagChatInputContextPanelNode(account: account)
                panel.interfaceInteraction = interfaceInteraction
                panel.updateResults(results)
                return panel
            }
        case let .mentions(peers):
            if !peers.isEmpty {
                if let currentPanel = currentPanel as? MentionChatInputContextPanelNode {
                    currentPanel.updateResults(peers)
                    return currentPanel
                } else {
                    let panel = MentionChatInputContextPanelNode(account: account)
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
                    let panel = CommandChatInputContextPanelNode(account: account)
                    panel.interfaceInteraction = interfaceInteraction
                    panel.updateResults(commands)
                    return panel
                }
            } else {
                return nil
            }
        case let .contextRequestResult(peer, results):
            if let results = results, (!results.results.isEmpty || results.switchPeer != nil) {
                switch results.presentation {
                    case .list:
                        if let currentPanel = currentPanel as? VerticalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = VerticalListContextResultsChatInputContextPanelNode(account: account)
                            panel.interfaceInteraction = interfaceInteraction
                            panel.updateResults(results)
                            return panel
                        }
                    case .media:
                        if let currentPanel = currentPanel as? HorizontalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = HorizontalListContextResultsChatInputContextPanelNode(account: account)
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
