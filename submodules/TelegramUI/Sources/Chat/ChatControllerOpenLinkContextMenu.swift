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
            var (cleanUrl, _) = parseUrl(url: url, wasConcealed: false)
            var canAddToReadingList = true
            var canOpenIn = availableOpenInOptions(context: self.context, item: .url(url: url)).count > 1
            let mailtoString = "mailto:"
            let telString = "tel:"
            var openText = self.presentationData.strings.Conversation_LinkDialogOpen
            var phoneNumber: String?
            
            var isPhoneNumber = false
            var isEmail = false
            var hasOpenAction = true
            
            if cleanUrl.hasPrefix(mailtoString) {
                canAddToReadingList = false
                cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
                isEmail = true
            } else if cleanUrl.hasPrefix(telString) {
                canAddToReadingList = false
                phoneNumber = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
                cleanUrl = phoneNumber!
                openText = self.presentationData.strings.UserInfo_PhoneCall
                canOpenIn = false
                isPhoneNumber = true
                
                if cleanUrl.hasPrefix("+888") {
                    hasOpenAction = false
                }
            } else if canOpenIn {
                openText = self.presentationData.strings.Conversation_FileOpenIn
            }
            
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            var items: [ActionSheetItem] = []
            items.append(ActionSheetTextItem(title: cleanUrl))
            if hasOpenAction {
                items.append(ActionSheetButtonItem(title: openText, color: .accent, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let strongSelf = self {
                        if canOpenIn {
                            strongSelf.openUrlIn(url)
                        } else {
                            strongSelf.openUrl(url, concealed: false)
                        }
                    }
                }))
            }
            if let phoneNumber = phoneNumber {
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_AddContact, color: .accent, action: { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let strongSelf = self {
                        strongSelf.controllerInteraction?.addContact(phoneNumber)
                    }
                }))
            }
            items.append(ActionSheetButtonItem(title: canAddToReadingList ? self.presentationData.strings.ShareMenu_CopyShareLink : self.presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet, weak self] in
                actionSheet?.dismissAnimated()
                guard let self else {
                    return
                }
                UIPasteboard.general.string = cleanUrl
                
                let content: UndoOverlayContent
                if isPhoneNumber {
                    content = .copy(text: self.presentationData.strings.Conversation_PhoneCopied)
                } else if isEmail {
                    content = .copy(text: self.presentationData.strings.Conversation_EmailCopied)
                } else if canAddToReadingList {
                    content = .linkCopied(text: self.presentationData.strings.Conversation_LinkCopied)
                } else {
                    content = .copy(text: self.presentationData.strings.Conversation_TextCopied)
                }
                self.present(UndoOverlayController(presentationData: self.presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }))
            if canAddToReadingList {
                items.append(ActionSheetButtonItem(title: self.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    if let link = URL(string: url) {
                        let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                    }
                }))
            }
            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            self.chatDisplayNode.dismissInput()
            self.present(actionSheet, in: .window(.root))
            
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
        
        var isEmail = false
        let mailtoString = "mailto:"
        var openText = self.presentationData.strings.Conversation_LinkDialogOpen
        var copyText = self.presentationData.strings.Conversation_ContextMenuCopyLink
        if cleanUrl.hasPrefix(mailtoString) {
            canAddToReadingList = false
            cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
            copyText = self.presentationData.strings.Conversation_ContextMenuCopyEmail
            isEmail = true
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
        
        items.append(
            .action(ContextMenuActionItem(text: copyText, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)

                guard let self else {
                    return
                }
                
                UIPasteboard.general.string = cleanUrl

                self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: isEmail ? presentationData.strings.Conversation_EmailCopied : presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }))
        )
        
        if canAddToReadingList {
            items.append(
                .action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_AddToReadingList, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReadingList"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    f(.default)
                    
                    if let link = URL(string: url) {
                        let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                    }
                }))
            )
        }
        
        self.canReadHistory.set(false)
        
        let controller = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture, disableScreenshots: false)
        controller.dismissed = { [weak self] in
            self?.canReadHistory.set(true)
        }
        
        self.window?.presentInGlobalOverlay(controller)
    }
}
