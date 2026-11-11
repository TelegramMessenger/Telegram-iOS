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
import ChatInputAccessoryPanel
import ChatInputMessageAccessoryPanel
import ComponentFlow
import TelegramNotices
import PresentationDataUtils
import Display
import Markdown
import TextFormat
import TelegramPresentationData
import AlertComponent
import ChatTextInputPanelNode

/// What a panel above the input field shows, so that showing something else (another link, a reply to another
/// message) brings the panel over the others again.
private enum TextInputAccessoryPanelKey: Hashable {
    case linkPreview(url: String)
    case editLinkPreview(url: String)
    case edit(EngineMessage.Id)
    case forward([EngineMessage.Id])
    case reply(EngineMessage.Id)
    case suggestPost
}

func textInputAccessoryPanel(
    context: AccountContext,
    chatPresentationInterfaceState: ChatPresentationInterfaceState,
    chatControllerInteraction: ChatControllerInteraction?,
    interfaceInteraction: ChatPanelInterfaceInteraction?
) -> [ChatTextInputAccessoryPanelCandidate]? {
    // nil hides the slot without unsetting anything, so the panels keep their order for when it shows again.
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
    
    // The panels share one slot: the input panel shows the one that appeared last. They are listed highest
    // priority first, which decides between panels that appear together.
    var candidates: [ChatTextInputAccessoryPanelCandidate] = []
    
    if let editMessage = chatPresentationInterfaceState.interfaceState.editMessage, chatPresentationInterfaceState.interfaceState.postSuggestionState == nil {
        if let editingUrlPreview = chatPresentationInterfaceState.editingUrlPreview, !editMessage.disableUrlPreviews.contains(editingUrlPreview.url) {
            var previousTapTimestamp: Double?
            candidates.append(ChatTextInputAccessoryPanelCandidate(key: TextInputAccessoryPanelKey.editLinkPreview(url: editingUrlPreview.url), panel: AnyComponentWithIdentity(id: "linkPreview", component: AnyComponent(ChatInputMessageAccessoryPanel(
                context: context,
                contents: .linkPreview(ChatInputMessageAccessoryPanel.Contents.LinkPreview(
                    url: editingUrlPreview.url,
                    webpage: editingUrlPreview.webPage
                )),
                chatPeerId: chatPresentationInterfaceState.chatLocation.peerId,
                action: { sourceView in
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    if let previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                        return
                    }
                    previousTapTimestamp = CFAbsoluteTimeGetCurrent()
                    interfaceInteraction?.presentLinkOptions(sourceView)
                },
                dismiss: { _ in
                    interfaceInteraction?.dismissUrlPreview()
                }
            )))))
        }
        
        candidates.append(ChatTextInputAccessoryPanelCandidate(key: TextInputAccessoryPanelKey.edit(editMessage.messageId), panel: AnyComponentWithIdentity(id: "edit", component: AnyComponent(ChatInputMessageAccessoryPanel(
            context: context,
            contents: .edit(ChatInputMessageAccessoryPanel.Contents.Edit(
                id: editMessage.messageId,
                message: nil
            )),
            chatPeerId: chatPresentationInterfaceState.chatLocation.peerId,
            action: { _ in
            },
            dismiss: { _ in
                interfaceInteraction?.setupEditMessage(nil, { _ in })
            }
        )))))
        return candidates
    }
    
    if let urlPreview = chatPresentationInterfaceState.urlPreview, !chatPresentationInterfaceState.interfaceState.composeDisableUrlPreviews.contains(urlPreview.url) {
        var previousTapTimestamp: Double?
        candidates.append(ChatTextInputAccessoryPanelCandidate(key: TextInputAccessoryPanelKey.linkPreview(url: urlPreview.url), panel: AnyComponentWithIdentity(id: "linkPreview", component: AnyComponent(ChatInputMessageAccessoryPanel(
            context: context,
            contents: .linkPreview(ChatInputMessageAccessoryPanel.Contents.LinkPreview(
                url: urlPreview.url,
                webpage: urlPreview.webPage
            )),
            chatPeerId: chatPresentationInterfaceState.chatLocation.peerId,
            action: { sourceView in
                let timestamp = CFAbsoluteTimeGetCurrent()
                if let previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                    return
                }
                previousTapTimestamp = CFAbsoluteTimeGetCurrent()
                interfaceInteraction?.presentLinkOptions(sourceView)
            },
            dismiss: { _ in
                interfaceInteraction?.dismissUrlPreview()
            }
        )))))
    }
    if let forwardMessageIds = chatPresentationInterfaceState.interfaceState.forwardMessageIds {
        var chatPeerId: EnginePeer.Id?
        if let peerId = chatPresentationInterfaceState.chatLocation.peerId {
            chatPeerId = peerId
        } else if case .customChatContents = chatPresentationInterfaceState.chatLocation {
            chatPeerId = context.account.peerId
        }
        if let chatPeerId {
            var previousTapTimestamp: Double?
            let theme = chatPresentationInterfaceState.theme
            let strings = chatPresentationInterfaceState.strings
            let nameDisplayOrder = chatPresentationInterfaceState.nameDisplayOrder
            
            candidates.append(ChatTextInputAccessoryPanelCandidate(key: TextInputAccessoryPanelKey.forward(forwardMessageIds), panel: AnyComponentWithIdentity(id: "forward", component: AnyComponent(ChatInputMessageAccessoryPanel(
                context: context,
                contents: .forward(ChatInputMessageAccessoryPanel.Contents.Forward(
                    messageIds: forwardMessageIds,
                    forwardOptionsState: chatPresentationInterfaceState.interfaceState.forwardOptionsState
                )),
                chatPeerId: chatPeerId,
                action: { sourceView in
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    if let previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                        return
                    }
                    previousTapTimestamp = CFAbsoluteTimeGetCurrent()
                    interfaceInteraction?.presentForwardOptions(sourceView)
                    let _ = ApplicationSpecificNotice.incrementChatForwardOptionsTip(accountManager: context.sharedContext.accountManager, count: 3).start()
                },
                dismiss: { sourceView in
                    Task { @MainActor [weak sourceView] in
                        guard let messageId = forwardMessageIds.first else {
                            return
                        }
                        guard let message = await context.engine.data.get(
                            TelegramEngine.EngineData.Item.Messages.Message(id: messageId)
                        ).get() else {
                            return
                        }
                        guard let peer = message.peers[message.id.peerId] else {
                            return
                        }
                        
                        let peerId = peer.id
                        let peerDisplayTitle = EnginePeer(peer).displayTitle(strings: strings, displayOrder: nameDisplayOrder)

                        let messageCount = Int32(forwardMessageIds.count)
                        let messages = strings.Conversation_ForwardOptions_Messages(messageCount)
                        let string: PresentationStrings.FormattedString
                        if peerId == context.account.peerId {
                            string = strings.Conversation_ForwardOptions_TextSaved(messages)
                        } else if peerId.namespace == Namespaces.Peer.CloudUser {
                            string = strings.Conversation_ForwardOptions_TextPersonal(messages, peerDisplayTitle)
                        } else {
                            string = strings.Conversation_ForwardOptions_Text(messages, peerDisplayTitle)
                        }

                        let font = Font.regular(15.0)
                        let boldFont = Font.semibold(15.0)
                        let body = MarkdownAttributeSet(font: font, textColor: theme.actionSheet.primaryTextColor)
                        let bold = MarkdownAttributeSet(font: boldFont, textColor: theme.actionSheet.primaryTextColor)
                        let text = addAttributesToStringWithRanges(string._tuple, body: body, argumentAttributes: [0: bold, 1: bold], textAlignment: .natural)
                        
                        var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
                        content.append(AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(
                                AlertTitleComponent(
                                    title: strings.Conversation_ForwardOptions_Title(messageCount)
                                )
                            )
                        ))
                        content.append(AnyComponentWithIdentity(
                            id: "text",
                            component: AnyComponent(
                                AlertTextComponent(content: .attributed(text))
                            )
                        ))
                        
                        let alertController = AlertScreen(
                            context: context,
                            configuration: AlertScreen.Configuration(actionAlignment: .vertical, allowInputInset: true),
                            content: content,
                            actions: [
                                .init(title: strings.Conversation_ForwardOptions_ShowOptions, action: {
                                    guard let sourceView else {
                                        return
                                    }
                                    interfaceInteraction?.presentForwardOptions(sourceView)
                                    let _ = ApplicationSpecificNotice.incrementChatForwardOptionsTip(accountManager: context.sharedContext.accountManager, count: 3).start()
                                }),
                                .init(title: strings.Conversation_ForwardOptions_CancelForwarding, type: .destructive, action: {
                                    interfaceInteraction?.dismissForwardMessages()
                                })
                            ]
                        )
                        interfaceInteraction?.presentController(alertController, nil)
                    }
                }
            )))))
        }
    }
    if let replyMessageSubject = chatPresentationInterfaceState.interfaceState.replyMessageSubject {
        var chatPeerId: EnginePeer.Id?
        if let peerId = chatPresentationInterfaceState.chatLocation.peerId {
            chatPeerId = peerId
        } else if case .customChatContents = chatPresentationInterfaceState.chatLocation {
            chatPeerId = context.account.peerId
        }
        if let chatPeerId {
            var previousTapTimestamp: Double?
            candidates.append(ChatTextInputAccessoryPanelCandidate(key: TextInputAccessoryPanelKey.reply(replyMessageSubject.messageId), panel: AnyComponentWithIdentity(id: "reply", component: AnyComponent(ChatInputMessageAccessoryPanel(
                context: context,
                contents: .reply(ChatInputMessageAccessoryPanel.Contents.Reply(
                    id: replyMessageSubject.messageId,
                    quote: replyMessageSubject.quote,
                    innerSubject: replyMessageSubject.innerSubject,
                    message: nil
                )),
                chatPeerId: chatPeerId,
                action: { sourceView in
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    if let previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                        return
                    }
                    previousTapTimestamp = CFAbsoluteTimeGetCurrent()
                    interfaceInteraction?.presentReplyOptions(sourceView)
                    let _ = ApplicationSpecificNotice.incrementChatReplyOptionsTip(accountManager: context.sharedContext.accountManager, count: 3).start()
                },
                longPressAction: { _ in
                    interfaceInteraction?.navigateToMessage(replyMessageSubject.messageId, false, true, ChatLoadingMessageSubject.generic)
                },
                dismiss: { _ in
                    interfaceInteraction?.setupReplyMessage(nil, nil, { _, f in f() })
                }
            )))))
        }
    }
    if let postSuggestionState = chatPresentationInterfaceState.interfaceState.postSuggestionState {
        var previousTapTimestamp: Double?
        candidates.append(ChatTextInputAccessoryPanelCandidate(key: TextInputAccessoryPanelKey.suggestPost, panel: AnyComponentWithIdentity(id: "suggestPost", component: AnyComponent(ChatInputMessageAccessoryPanel(
            context: context,
            contents: .suggestPost(ChatInputMessageAccessoryPanel.Contents.SuggestPost(
                state: postSuggestionState
            )),
            chatPeerId: chatPresentationInterfaceState.chatLocation.peerId,
            action: { sourceView in
                let timestamp = CFAbsoluteTimeGetCurrent()
                if let previousTapTimestamp, previousTapTimestamp + 1.0 > timestamp {
                    return
                }
                previousTapTimestamp = CFAbsoluteTimeGetCurrent()
                interfaceInteraction?.presentSuggestPostOptions()
            },
            dismiss: { _ in
                interfaceInteraction?.dismissSuggestPost()
            }
        )))))
    }
    
    return candidates
}

func accessoryPanelForChatPresentationIntefaceState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentPanel: AccessoryPanelNode?, chatControllerInteraction: ChatControllerInteraction?, interfaceInteraction: ChatPanelInterfaceInteraction?) -> AccessoryPanelNode? {
    if "".isEmpty {
        return nil
    }
    
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
        let _ = editMessage
        return nil
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
                let panelNode = ReplyAccessoryPanelNode(context: context, chatPeerId: chatPeerId, messageId: replyMessageSubject.messageId, quote: replyMessageSubject.quote, innerSubject: replyMessageSubject.innerSubject, theme: chatPresentationInterfaceState.theme, strings: chatPresentationInterfaceState.strings, nameDisplayOrder: chatPresentationInterfaceState.nameDisplayOrder, dateTimeFormat: chatPresentationInterfaceState.dateTimeFormat, animationCache: chatControllerInteraction?.presentationContext.animationCache, animationRenderer: chatControllerInteraction?.presentationContext.animationRenderer)
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
