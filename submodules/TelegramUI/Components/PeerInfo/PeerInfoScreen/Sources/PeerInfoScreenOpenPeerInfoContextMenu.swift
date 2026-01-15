import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import UndoUI
import TranslateUI
import TelegramStringFormatting
import TelegramUIPreferences

extension PeerInfoScreenNode {
    func openPeerInfoContextMenu(subject: PeerInfoContextSubject, sourceNode: ASDisplayNode, sourceRect: CGRect?) {
        guard let data = self.data, let peer = data.peer, let controller = self.controller else {
            return
        }
        let context = self.context
        switch subject {
        case .birthday:
            if let cachedData = data.cachedData as? CachedUserData, let birthday = cachedData.birthday {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text = stringForCompactBirthday(birthday, strings: presentationData.strings)
                
                let actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                    UIPasteboard.general.string = text
                    
                    self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                })]
                let contextMenuController = makeContextMenuController(actions: actions)
                controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                    if let controller = self?.controller, let sourceNode = sourceNode {
                        var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                        if let sourceRect = sourceRect {
                            rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                        }
                        return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
        case .bio:
            var text: String?
            if let cachedData = data.cachedData as? CachedUserData {
                text = cachedData.about
            } else if let cachedData = data.cachedData as? CachedGroupData {
                text = cachedData.about
            } else if let cachedData = data.cachedData as? CachedChannelData {
                text = cachedData.about
            }
            if let text = text, !text.isEmpty {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] sharedData in
                    let translationSettings: TranslationSettings
                    if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                        translationSettings = current
                    } else {
                        translationSettings = TranslationSettings.defaultSettings
                    }
                    
                    var actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                        UIPasteboard.general.string = text
                        
                        self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    })]
                    
                    let (canTranslate, language) = canTranslateText(context: context, text: text, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
                    if canTranslate {
                        actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuTranslate, accessibilityLabel: presentationData.strings.Conversation_ContextMenuTranslate), action: { [weak self] in
                            
                            let controller = TranslateScreen(context: context, text: text, canCopy: true, fromLanguage: language, ignoredLanguages: translationSettings.ignoredLanguages)
                            controller.pushController = { [weak self] c in
                                (self?.controller?.navigationController as? NavigationController)?._keepModalDismissProgress = true
                                self?.controller?.push(c)
                            }
                            controller.presentController = { [weak self] c in
                                self?.controller?.present(c, in: .window(.root))
                            }
                            self?.controller?.present(controller, in: .window(.root))
                        }))
                    }
                    
                    let contextMenuController = makeContextMenuController(actions: actions)
                    controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                        if let controller = self?.controller, let sourceNode = sourceNode {
                            var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                            if let sourceRect = sourceRect {
                                rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                            }
                            return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                        } else {
                            return nil
                        }
                    }))
                })
            }
        case let .phone(phone):
            let contextMenuController = makeContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = phone
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })])
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                    if let sourceRect = sourceRect {
                        rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                    }
                    return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        case let .link(customLink):
            let text: String
            let content: UndoOverlayContent
            if let customLink = customLink {
                text = customLink
                content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
            } else if let addressName = peer.addressName {
                if peer is TelegramChannel {
                    text = "https://t.me/\(addressName)"
                    content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
                } else {
                    text = "@" + addressName
                    content = .copy(text: self.presentationData.strings.Conversation_UsernameCopied)
                }
            } else {
                text = "https://t.me/@id\(peer.id.id._internalGetInt64Value())"
                content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
            }
        
            let contextMenuController = makeContextMenuController(actions: [ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = text
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })])
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                    if let sourceRect = sourceRect {
                        rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                    }
                    return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        case .businessHours(let text), .businessLocation(let text):
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
            let actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: { [weak self] in
                UIPasteboard.general.string = text
                
                self?.controller?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })]
            
            let contextMenuController = makeContextMenuController(actions: actions)
            controller.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self, weak sourceNode] in
                if let controller = self?.controller, let sourceNode = sourceNode {
                    var rect = sourceNode.bounds.insetBy(dx: 0.0, dy: 2.0)
                    if let sourceRect = sourceRect {
                        rect = sourceRect.insetBy(dx: 0.0, dy: 2.0)
                    }
                    return (sourceNode, rect, controller.displayNode, controller.view.bounds)
                } else {
                    return nil
                }
            }))
        }
    }
}
