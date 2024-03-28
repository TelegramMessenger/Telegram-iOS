import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import PresentationDataUtils
import QuickReplyNameAlertController
import BusinessLinkNameAlertController

extension ChatControllerImpl {
    func editChat() {
        if case let .customChatContents(customChatContents) = self.subject, case let .quickReplyMessageInput(currentValue, shortcutType) = customChatContents.kind, case .generic = shortcutType {
            var completion: ((String?) -> Void)?
            let alertController = quickReplyNameAlertController(
                context: self.context,
                text: self.presentationData.strings.QuickReply_EditShortcutTitle,
                subtext: self.presentationData.strings.QuickReply_EditShortcutText,
                value: currentValue,
                characterLimit: 32,
                apply: { value in
                    completion?(value)
                }
            )
            completion = { [weak self, weak alertController] value in
                guard let self else {
                    alertController?.dismissAnimated()
                    return
                }
                if let value, !value.isEmpty {
                    if value == currentValue {
                        alertController?.dismissAnimated()
                        return
                    }
                    
                    let _ = (self.context.engine.accountData.shortcutMessageList(onlyRemote: false)
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] shortcutMessageList in
                        guard let self else {
                            alertController?.dismissAnimated()
                            return
                        }
                        
                        if shortcutMessageList.items.contains(where: { $0.shortcut.lowercased() == value.lowercased() }) {
                            if let contentNode = alertController?.contentNode as? QuickReplyNameAlertContentNode {
                                contentNode.setErrorText(errorText: self.presentationData.strings.QuickReply_ShortcutExistsInlineError)
                            }
                        } else {
                            self.chatTitleView?.titleContent = .custom("\(value)", nil, false)
                            alertController?.view.endEditing(true)
                            alertController?.dismissAnimated()
                            
                            if case let .customChatContents(customChatContents) = self.subject {
                                customChatContents.quickReplyUpdateShortcut(value: value)
                            }
                        }
                    })
                }
            }
            self.present(alertController, in: .window(.root))
        } else if case let .customChatContents(customChatContents) = self.subject, case let .businessLinkSetup(link) = customChatContents.kind {
            let currentValue = link.title ?? ""
            
            var completion: ((String?) -> Void)?
            let alertController = businessLinkNameAlertController(
                context: self.context,
                text: self.presentationData.strings.Business_Links_LinkNameTitle,
                subtext: self.presentationData.strings.Business_Links_LinkNameText,
                value: currentValue,
                characterLimit: 32,
                apply: { value in
                    completion?(value)
                }
            )
            completion = { [weak self, weak alertController] value in
                guard let self else {
                    alertController?.dismissAnimated()
                    return
                }
                if let value {
                    if value == currentValue {
                        alertController?.dismissAnimated()
                        return
                    }
                    
                    let _ = self.context.engine.accountData.editBusinessChatLink(url: link.url, message: link.message, entities: link.entities, title: value.isEmpty ? nil : value).startStandalone()
                    
                    let linkUrl: String
                    if link.url.hasPrefix("https://") {
                        linkUrl = String(link.url[link.url.index(link.url.startIndex, offsetBy: "https://".count)...])
                    } else {
                        linkUrl = link.url
                    }
                    self.chatTitleView?.titleContent = .custom(value.isEmpty ? self.presentationData.strings.Business_Links_EditLinkTitle : value, linkUrl, false)
                    if case let .customChatContents(customChatContents) = self.subject {
                        customChatContents.businessLinkUpdate(message: link.message, entities: link.entities, title: value.isEmpty ? nil : value)
                    }
                    
                    alertController?.view.endEditing(true)
                    alertController?.dismissAnimated()
                }
            }
            self.present(alertController, in: .window(.root))
        }
    }
}
