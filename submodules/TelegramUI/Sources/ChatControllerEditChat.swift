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

extension ChatControllerImpl {
    func editChat() {
        if case let .customChatContents(customChatContents) = self.subject, case let .quickReplyMessageInput(currentValue) = customChatContents.kind {
            var completion: ((String?) -> Void)?
            let alertController = quickReplyNameAlertController(
                context: self.context,
                text: "Edit Shortcut",
                subtext: "Add a new name for your shortcut.",
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
                    
                    let _ = (self.context.engine.accountData.shortcutMessages()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] shortcutMessages in
                        guard let self else {
                            alertController?.dismissAnimated()
                            return
                        }
                        
                        var shortcuts = shortcutMessages.shortcuts
                        guard let index = shortcuts.firstIndex(where: { $0.shortcut.lowercased() == currentValue }) else {
                            alertController?.dismissAnimated()
                            return
                        }
                        
                        if shortcuts.contains(where: { $0.shortcut.lowercased() == value.lowercased() }) {
                            if let contentNode = alertController?.contentNode as? QuickReplyNameAlertContentNode {
                                contentNode.setErrorText(errorText: "Shortcut with that name already exists")
                            }
                        } else {
                            shortcuts[index] = QuickReplyMessageShortcut(
                                id: shortcuts[index].id,
                                shortcut: value,
                                messages: shortcuts[index].messages
                            )
                            let updatedShortcutMessages = QuickReplyMessageShortcutsState(shortcuts: shortcuts)
                            self.context.engine.accountData.updateShortcutMessages(state: updatedShortcutMessages)
                            
                            self.chatTitleView?.titleContent = .custom("/\(value)", nil, false)
                            
                            if case let .customChatContents(customChatContents) = self.subject {
                                customChatContents.quickReplyUpdateShortcut(value: value)
                            }
                            
                            alertController?.dismissAnimated()
                        }
                    })
                }
            }
            self.present(alertController, in: .window(.root))
        }
    }
}
