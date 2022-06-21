import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState

func accessoryPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: AccessoryPanelNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> AccessoryPanelNode? {
    if let _ = chatPresentationInterfaceState.interfaceState.selectionState {
        return nil
    }
    if chatPresentationInterfaceState.search != nil {
        return nil
    }
    
    switch chatPresentationInterfaceState.subject {
        case .pinnedMessages, .forwardedMessages:
            return nil
        default:
            break
    }
    
    if let editMessage = chatPresentationInterfaceState.interfaceState.editMessage {
        if let editingUrlPreview = chatPresentationInterfaceState.editingUrlPreview, editMessage.disableUrlPreview != editingUrlPreview.0 {
            if let previewPanelNode = currentPanel as? WebpagePreviewAccessoryPanelNode {
                previewPanelNode.interfaceInteraction = interfaceInteraction
                previewPanelNode.replaceWebpage(url: editingUrlPreview.0, webpage: editingUrlPreview.1)
                previewPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                return previewPanelNode
            } else {
                let panelNode = WebpagePreviewAccessoryPanelNode(context: context, url: editingUrlPreview.0, webpage: editingUrlPreview.1, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panelNode.interfaceInteraction = interfaceInteraction
                return panelNode
            }
        }
        
        if let editPanelNode = currentPanel as? EditAccessoryPanelNode, editPanelNode.messageId == editMessage.messageId {
            editPanelNode.interfaceInteraction = interfaceInteraction
            editPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return editPanelNode
        } else {
            let panelNode = EditAccessoryPanelNode(context: context, messageId: editMessage.messageId, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, dateTimeFormat: chatPresentationInterfaceState.dateTimeFormat)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let urlPreview = chatPresentationInterfaceState.urlPreview, chatPresentationInterfaceState.interfaceState.composeDisableUrlPreview != urlPreview.0 {
        if let previewPanelNode = currentPanel as? WebpagePreviewAccessoryPanelNode {
            previewPanelNode.interfaceInteraction = interfaceInteraction
            previewPanelNode.replaceWebpage(url: urlPreview.0, webpage: urlPreview.1)
            previewPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return previewPanelNode
        } else {
            let panelNode = WebpagePreviewAccessoryPanelNode(context: context, url: urlPreview.0, webpage: urlPreview.1, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let forwardMessageIds = chatPresentationInterfaceState.interfaceState.forwardMessageIds {
        if let forwardPanelNode = currentPanel as? ForwardAccessoryPanelNode, forwardPanelNode.messageIds == forwardMessageIds {
            forwardPanelNode.interfaceInteraction = interfaceInteraction
            forwardPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, forwardOptionsState: chatPresentationInterfaceState.interfaceState.forwardOptionsState)
            return forwardPanelNode
        } else {
            let panelNode = ForwardAccessoryPanelNode(context: context, messageIds: forwardMessageIds, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, forwardOptionsState: chatPresentationInterfaceState.interfaceState.forwardOptionsState)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let replyMessageId = chatPresentationInterfaceState.interfaceState.replyMessageId {
        if let replyPanelNode = currentPanel as? ReplyAccessoryPanelNode, replyPanelNode.messageId == replyMessageId {
            replyPanelNode.interfaceInteraction = interfaceInteraction
            replyPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return replyPanelNode
        } else {
            let panelNode = ReplyAccessoryPanelNode(context: context, messageId: replyMessageId, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, dateTimeFormat: chatPresentationInterfaceState.dateTimeFormat)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else {
        return nil
    }
}
