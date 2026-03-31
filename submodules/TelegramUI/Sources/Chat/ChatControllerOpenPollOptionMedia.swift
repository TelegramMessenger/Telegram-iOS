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
import ChatControllerInteraction
import TelegramStringFormatting
import TelegramPresentationData
import StickerPeekUI
import StickerPackPreviewUI

extension ChatControllerImpl {
    func openPollMedia(message: Message, subject: ChatControllerInteraction.PollMediaSubject) -> Void {
        let mediaSubject: GalleryMediaSubject
        var media: Media?
        switch subject {
        case let .option(option):
            media = option.media
            mediaSubject = .pollOption(option.opaqueIdentifier)
        case let .solution(solution):
            media = solution.media
            mediaSubject = .pollSolution
        }
        
        guard let media else {
            return
        }
        
        if let file = media as? TelegramMediaFile, file.isSticker || file.isCustomEmoji {
            let _ = (self.context.engine.stickers.isStickerSaved(id: file.fileId)
            |> deliverOnMainQueue).start(next: { [weak self] isStarred in
                guard let self else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                items.append(.action(ContextMenuActionItem(text: isStarred ? self.presentationData.strings.Stickers_RemoveFromFavorites : self.presentationData.strings.Stickers_AddToFavorites, icon: { theme in generateTintedImage(image: isStarred ? UIImage(bundleImageName: "Chat/Context Menu/Unfave") : UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                    f(.default)
                    
                    guard let self else {
                        return
                    }
                    let _ = (self.context.engine.stickers.toggleStickerSaved(file: file, saved: !isStarred)
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        if let self {
                            self.present(UndoOverlayController(presentationData: self.presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: !isStarred ? self.presentationData.strings.Conversation_StickerAddedToFavorites : self.presentationData.strings.Conversation_StickerRemovedFromFavorites, undoText: nil, customAction: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                        }
                    })
                })))
                
                var packReference: StickerPackReference?
                for attribute in file.attributes {
                    switch attribute {
                    case let .Sticker(_, packReferenceValue, _):
                        packReference = packReferenceValue
                        break
                    default:
                        break
                    }
                }
                if let packReference {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.StickerPack_ViewPack, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Sticker"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let self, let controllerInteraction = self.controllerInteraction else {
                            return
                        }
                        
                        let controller = StickerPackScreen(context: self.context, mainStickerPack: packReference, stickerPacks: [packReference], parentNavigationController: controllerInteraction.navigationController(), sendSticker: { [weak self] file, sourceNode, sourceRect in
                            if let self, let controllerInteraction = self.controllerInteraction {
                                return controllerInteraction.sendSticker(file, false, false, nil, true, sourceNode, sourceRect, nil, [])
                            } else {
                                return false
                            }
                        })
                        
                        controllerInteraction.navigationController()?.view.window?.endEditing(true)
                        controllerInteraction.presentController(controller, nil)
                    })))
                }
                
                let peekController = makePeekController(
                    presentationData: self.presentationData,
                    content: StickerPreviewPeekContent(
                        context: self.context,
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        item: .pack(file),
                        isCreating: false,
                        menu: items,
                        openPremiumIntro: {}
                    ),
                    sourceView: {
                        return nil
                    },
                    activateImmediately: true
                )
                self.presentInGlobalOverlay(peekController)
                
            })
        } else {
            let _ = self.context.sharedContext.openChatMessage(OpenChatMessageParams(
                context: self.context,
                updatedPresentationData: self.controllerInteraction?.updatedPresentationData,
                chatLocation: self.chatLocation,
                chatFilterTag: nil,
                chatLocationContextHolder: nil,
                message: message,
                mediaSubject: mediaSubject,
                standalone: true,
                reverseMessageGalleryOrder: false,
                navigationController: self.controllerInteraction?.navigationController(),
                dismissInput: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.controllerInteraction?.dismissTextInput()
                },
                present: { [weak self] controller, arguments, presentationContextType in
                    guard let self else {
                        return
                    }
                    switch presentationContextType {
                    case .current:
                        self.controllerInteraction?.presentControllerInCurrent(controller, arguments)
                    default:
                        self.controllerInteraction?.presentController(controller, arguments)
                    }
                },
                transitionNode: { [weak self] messageId, media, adjustRect in
                    var selectedNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
                    if let self {
                        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? ChatMessageItemView {
                                if let result = itemNode.transitionNode(id: messageId, media: media, adjustRect: adjustRect) {
                                    selectedNode = result
                                }
                            }
                        }
                    }
                    return selectedNode
                },
                addToTransitionSurface: { [weak self] view in
                    guard let self else {
                        return
                    }
                    self.chatDisplayNode.historyNode.view.superview?.insertSubview(view, aboveSubview: self.chatDisplayNode.historyNode.view)
                },
                openUrl: { [weak self] url in
                    guard let self else {
                        return
                    }
                    self.controllerInteraction?.openUrl(.init(url: url, concealed: false, progress: Promise()))
                },
                openPeer: { [weak self] peer, navigation in
                    guard let self else {
                        return
                    }
                    self.controllerInteraction?.openPeer(EnginePeer(peer), navigation, nil, .default)
                },
                callPeer: { [weak self] peerId, isVideo in
                    guard let self else {
                        return
                    }
                    self.controllerInteraction?.callPeer(peerId, isVideo)
                },
                openConferenceCall: { [weak self] message in
                    guard let self else {
                        return
                    }
                    self.controllerInteraction?.openConferenceCall(message)
                },
                enqueueMessage: { _ in
                },
                sendSticker: { [weak self] fileReference, sourceNode, sourceRect in
                    guard let self else {
                        return false
                    }
                    return self.controllerInteraction?.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect, nil, []) ?? false
                },
                sendEmoji: { [weak self] text, attribute in
                    guard let self else {
                        return
                    }
                    self.controllerInteraction?.sendEmoji(text, attribute, false)
                },
                setupTemporaryHiddenMedia: { _, _, _ in
                },
                chatAvatarHiddenMedia: { _, _ in
                },
                gallerySource: .standaloneMessage(message, mediaSubject)
            ))
        }
    }
}
