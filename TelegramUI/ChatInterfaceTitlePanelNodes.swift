import Foundation
import TelegramCore

func titlePanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentPanel: ChatTitleAccessoryPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> ChatTitleAccessoryPanelNode? {
    if !chatPresentationInterfaceState.titlePanelContexts.isEmpty {
        switch chatPresentationInterfaceState.titlePanelContexts[chatPresentationInterfaceState.titlePanelContexts.count - 1] {
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
        }
    }
    return nil
}
