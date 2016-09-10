import Foundation
import TelegramCore

func inputContextPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatInputContextPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatInputContextPanelNode? {
    guard let inputContext = chatPresentationInterfaceState.inputContext, let peer = chatPresentationInterfaceState.peer else {
        return nil
    }
    
    switch inputContext {
        case .hashtag:
            if let currentPanel = currentPanel as? HashtagChatInputContextPanelNode {
                return currentPanel
            } else {
                let panel = HashtagChatInputContextPanelNode()
                panel.interfaceInteraction = interfaceInteraction
                return panel
            }
        case .mention:
            if let currentPanel = currentPanel as? MentionChatInputContextPanelNode {
                return currentPanel
            } else {
                let panel = MentionChatInputContextPanelNode()
                panel.interfaceInteraction = interfaceInteraction
                panel.setup(account: account, peerId: peer.id, query: "")
                return panel
            }
    }
    
    return nil
}
