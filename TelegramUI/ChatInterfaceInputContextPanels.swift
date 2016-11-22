import Foundation
import TelegramCore

func inputContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatInputContextPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputContextPanelNode? {
    guard let inputQueryResult = chatPresentationInterfaceState.inputQueryResult, let peer = chatPresentationInterfaceState.peer else {
        return nil
    }
    
    switch inputQueryResult {
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
            if let currentPanel = currentPanel as? MentionChatInputContextPanelNode {
                currentPanel.updateResults(peers)
                return currentPanel
            } else {
                let panel = MentionChatInputContextPanelNode(account: account)
                panel.interfaceInteraction = interfaceInteraction
                panel.updateResults(peers)
                return panel
            }
        case let .commands(peersAndCommands):
            return nil
        case let .contextRequestResult(peer, results):
            if let results = results, (!results.results.isEmpty || results.switchPeer != nil) {
                switch results.presentation {
                    case .list, .media:
                        if let currentPanel = currentPanel as? VerticalListContextResultsChatInputContextPanelNode {
                            currentPanel.updateResults(results)
                            return currentPanel
                        } else {
                            let panel = VerticalListContextResultsChatInputContextPanelNode(account: account)
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
