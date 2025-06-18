import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import AccessoryPanelNode
import ForwardAccessoryPanelNode
import ReplyAccessoryPanelNode
import SuggestPostAccessoryPanelNode

func accessoryPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: AccessoryPanelNode?, chatControllerInteraction: ChatControllerInteraction?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> AccessoryPanelNode? {
    if case .standard(.previewing) = chatPresentationInterfaceState.mode {
        return nil
    }
    if let _ = chatPresentationInterfaceState.interfaceState.selectionState {
        return nil
    }
    if chatPresentationInterfaceState.search != nil {
        return nil
    }
    
    switch chatPresentationInterfaceState.subject {
    case .pinnedMessages, .messageOptions:
        return nil
    default:
        break
    }
    
    if let editMessage = chatPresentationInterfaceState.interfaceState.editMessage, chatPresentationInterfaceState.interfaceState.postSuggestionState == nil {
        if let editingUrlPreview = chatPresentationInterfaceState.editingUrlPreview, !editMessage.disableUrlPreviews.contains(editingUrlPreview.url) {
            if let previewPanelNode = currentPanel as? WebpagePreviewAccessoryPanelNode {
                previewPanelNode.interfaceInteraction = interfaceInteraction
                previewPanelNode.replaceWebpage(url: editingUrlPreview.url, webpage: editingUrlPreview.webPage)
                previewPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                return previewPanelNode
            } else {
                let panelNode = WebpagePreviewAccessoryPanelNode(context: context, url: editingUrlPreview.url, webpage: editingUrlPreview.webPage, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
                panelNode.interfaceInteraction = interfaceInteraction
                return panelNode
            }
        }
        
        if let editPanelNode = currentPanel as? EditAccessoryPanelNode, editPanelNode.messageId == editMessage.messageId {
            editPanelNode.interfaceInteraction = interfaceInteraction
            editPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return editPanelNode
        } else {
            let panelNode = EditAccessoryPanelNode(context: context, messageId: editMessage.messageId, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, dateTimeFormat: chatPresentationInterfaceState.dateTimeFormat, animationCache: chatControllerInteraction?.presentationContext.animationCache, animationRenderer: chatControllerInteraction?.presentationContext.animationRenderer)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let urlPreview = chatPresentationInterfaceState.urlPreview, !chatPresentationInterfaceState.interfaceState.composeDisableUrlPreviews.contains(urlPreview.url) {
        if let previewPanelNode = currentPanel as? WebpagePreviewAccessoryPanelNode {
            previewPanelNode.interfaceInteraction = interfaceInteraction
            previewPanelNode.replaceWebpage(url: urlPreview.url, webpage: urlPreview.webPage)
            previewPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return previewPanelNode
        } else {
            let panelNode = WebpagePreviewAccessoryPanelNode(context: context, url: urlPreview.url, webpage: urlPreview.webPage, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let forwardMessageIds = chatPresentationInterfaceState.interfaceState.forwardMessageIds {
        if let forwardPanelNode = currentPanel as? ForwardAccessoryPanelNode, forwardPanelNode.messageIds == forwardMessageIds {
            forwardPanelNode.interfaceInteraction = interfaceInteraction
            forwardPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, forwardOptionsState: chatPresentationInterfaceState.interfaceState.forwardOptionsState)
            return forwardPanelNode
        } else {
            let panelNode = ForwardAccessoryPanelNode(context: context, messageIds: forwardMessageIds, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, fontSize: chatPresentationInterfaceState.fontSize, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, forwardOptionsState: chatPresentationInterfaceState.interfaceState.forwardOptionsState, animationCache: chatControllerInteraction?.presentationContext.animationCache, animationRenderer: chatControllerInteraction?.presentationContext.animationRenderer)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else if let replyMessageSubject = chatPresentationInterfaceState.interfaceState.replyMessageSubject {
        if let replyPanelNode = currentPanel as? ReplyAccessoryPanelNode, replyPanelNode.messageId == replyMessageSubject.messageId && replyPanelNode.quote == replyMessageSubject.quote {
            replyPanelNode.interfaceInteraction = interfaceInteraction
            replyPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return replyPanelNode
        } else {
            var chatPeerId: EnginePeer.Id?
            if let peerId = chatPresentationInterfaceState.chatLocation.peerId {
                chatPeerId = peerId
            } else if case .customChatContents = chatPresentationInterfaceState.chatLocation {
                chatPeerId = context.account.peerId
            }
            
            if let chatPeerId {
                let panelNode = ReplyAccessoryPanelNode(context: context, chatPeerId: chatPeerId, messageId: replyMessageSubject.messageId, quote: replyMessageSubject.quote, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, dateTimeFormat: chatPresentationInterfaceState.dateTimeFormat, animationCache: chatControllerInteraction?.presentationContext.animationCache, animationRenderer: chatControllerInteraction?.presentationContext.animationRenderer)
                panelNode.interfaceInteraction = interfaceInteraction
                return panelNode
            } else {
                return nil
            }
        }
    } else if chatPresentationInterfaceState.interfaceState.postSuggestionState != nil {
        if let replyPanelNode = currentPanel as? SuggestPostAccessoryPanelNode {
            replyPanelNode.interfaceInteraction = interfaceInteraction
            replyPanelNode.updateThemeAndStrings(theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings)
            return replyPanelNode
        } else {
            let panelNode = SuggestPostAccessoryPanelNode(context: context, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, dateTimeFormat: chatPresentationInterfaceState.dateTimeFormat, animationCache: chatControllerInteraction?.presentationContext.animationCache, animationRenderer: chatControllerInteraction?.presentationContext.animationRenderer)
            panelNode.interfaceInteraction = interfaceInteraction
            return panelNode
        }
    } else {
        return nil
    }
}
