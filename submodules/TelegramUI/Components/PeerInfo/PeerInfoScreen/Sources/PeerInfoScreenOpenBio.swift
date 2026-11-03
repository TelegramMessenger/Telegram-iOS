import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import TelegramUIPreferences
import ContextUI
import TranslateUI
import TextProcessingScreen
import Pasteboard
import ChatRichTextEditorComposer
import UndoUI

extension PeerInfoScreenNode {
    func openBioContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] sharedData in
            guard let self else {
                return
            }
            
            let translationSettings: TranslationSettings
            if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                translationSettings = current
            } else {
                translationSettings = TranslationSettings.defaultSettings
            }
            
            guard let sourceNode = node as? ContextExtractedContentContainingNode else {
                return
            }
            guard let cachedData = self.data?.cachedData else {
                return
            }
            
            var bioText: String?
            if let cachedData = cachedData as? CachedUserData {
                bioText = cachedData.about
            } else if let cachedData = cachedData as? CachedChannelData {
                bioText = cachedData.about
            } else if let cachedData = cachedData as? CachedGroupData {
                bioText = cachedData.about
            }
            
            guard let bioText, !bioText.isEmpty else {
                return
            }
            
            let copyAction = { [weak self] in
                guard let self else {
                    return
                }
                UIPasteboard.general.string = bioText
                
                let toastText: String
                if case .user = self.data?.peer {
                    toastText = self.presentationData.strings.MyProfile_ToastBioCopied
                } else {
                    toastText = self.presentationData.strings.ChannelProfile_ToastAboutCopied
                }
                
                self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: toastText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }
            
            var items: [ContextMenuItem] = []
            
            if self.isMyProfile {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_BioActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        self.performNavigationButtonAction?(.edit, nil, nil)
                        
                        for (_, section) in self.editingSections {
                            for (id, itemNode) in section.itemNodes {
                                if id == AnyHashable("bio_edit") {
                                    if let itemNode = itemNode as? PeerInfoScreenMultilineInputItemNode {
                                        itemNode.focus()
                                    }
                                    break
                                }
                            }
                        }
                    }
                })))
            }
            
            let copyText: String
            if case .user = self.data?.peer {
                copyText = self.presentationData.strings.MyProfile_BioActionCopy
            } else {
                copyText = self.presentationData.strings.ChannelProfile_AboutActionCopy
            }
            items.append(.action(ContextMenuActionItem(text: copyText, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                c?.dismiss {
                    copyAction()
                }
            })))
            
            let (canTranslate, language) = canTranslateText(context: self.context, text: bioText, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
            if canTranslate {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuTranslate, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Translate"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }

                        Task { @MainActor [weak self] in
                            guard let self, let parentController = self.controller else {
                                return
                            }
                            let presentationData = self.presentationData
                            let controller = await TextProcessingScreen(
                                context: self.context,
                                mode: .translate(fromLanguage: language, applyResult: nil),
                                inputText: .plain(text: bioText, entities: []),
                                copyResult: { [weak parentController] text in
                                    storeComposedRichMessageInPasteboard(text)
                                    parentController?.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                                },
                                translateChat: nil
                            )
                            parentController.present(controller, in: .window(.root))
                        }
                    }
                })))
            }
            
            let actions = ContextController.Items(content: .list(items))
            
            let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
            self.controller?.present(contextController, in: .window(.root))
        })
    }
}
