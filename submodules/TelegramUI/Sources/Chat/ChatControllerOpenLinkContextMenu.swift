import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import ContextUI
import UndoUI
import AccountContext
import ChatMessageItemView
import ChatMessageItemCommon
import MessageUI
import ChatControllerInteraction
import UrlWhitelist
import OpenInExternalAppUI
import SafariServices

extension ChatControllerImpl {
    func openLinkContextMenu(url: String, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let contentNode = params.contentNode else {
            return
        }
        
        guard let messages = self.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) else {
            return
        }
        
        var updatedMessages = messages
        for i in 0 ..< updatedMessages.count {
            if updatedMessages[i].id == message.id {
                let message = updatedMessages.remove(at: i)
                updatedMessages.insert(message, at: 0)
                break
            }
        }
        
        var (cleanUrl, _) = parseUrl(url: url, wasConcealed: false)
        var canAddToReadingList = true
        let canOpenIn = availableOpenInOptions(context: self.context, item: .url(url: url)).count > 1
        
        let mailtoString = "mailto:"
        var openText = self.presentationData.strings.Conversation_LinkDialogOpen
        
        if cleanUrl.hasPrefix(mailtoString) {
            canAddToReadingList = false
            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
//            isEmail = true
        } else if canOpenIn {
            openText = self.presentationData.strings.Conversation_FileOpenIn
        }
            
        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil// anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
        let gesture: ContextGesture? = nil // anyRecognizer as? ContextGesture
        
        let source: ContextContentSource
//                if let location = location {
//                    source = .location(ChatMessageContextLocationContentSource(controller: self, location: messageNode.view.convert(messageNode.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
//                } else {
            source = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))
//                }
        
        var items: [ContextMenuItem] = []
        
        items.append(
            .action(ContextMenuActionItem(text: openText, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Browser"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                guard let self else {
                    return
                }
                f(.default)
                
                if canOpenIn {
                    self.openUrlIn(url)
                }
                else {
                    self.openUrl(url, concealed: false)
                }
            }))
        )
        
        if canAddToReadingList {
            items.append(
                .action(ContextMenuActionItem(text: "Add to Reading List", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    f(.default)
                    
                    if let link = URL(string: url) {
                        let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                    }
                }))
            )
//                /                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
//                //                    actionSheet?.dismissAnimated()
//                //                    if let link = URL(string: url) {
//                //                        let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
//                //                    }
//                //                }))
        }
        
        items.append(
            .action(ContextMenuActionItem(text: "Copy Link", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)

                guard let self else {
                    return
                }
                
                UIPasteboard.general.string = url

                self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }))
        )
         
        self.canReadHistory.set(false)
        
        let controller = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture, disableScreenshots: false)
        controller.dismissed = { [weak self] in
            self?.canReadHistory.set(true)
        }
        
        self.window?.presentInGlobalOverlay(controller)
    }
}
