import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import ContextUI
import Display
import UIKit
import ReactionListContextMenuContent
import UndoUI
import TooltipUI
import StickerPackPreviewUI
import TextNodeWithEntities
import ChatPresentationInterfaceState
import SavedTagNameAlertController
import PremiumUI

extension ChatControllerImpl {
    func presentTagPremiumPaywall() {
        let context = self.context
        var replaceImpl: ((ViewController) -> Void)?
        let controller = PremiumDemoScreen(context: context, subject: .messageTags, action: {
            let controller = PremiumIntroScreen(context: context, source: .messageTags)
            replaceImpl?(controller)
        })
        replaceImpl = { [weak controller] c in
            controller?.replace(with: c)
        }
        self.push(controller)
    }
    
    func openMessageReactionContextMenu(message: Message, sourceView: ContextExtractedContentContainingView, gesture: ContextGesture?, value: MessageReaction.Reaction) {
        if message.areReactionsTags(accountPeerId: self.context.account.peerId) {
            if !self.presentationInterfaceState.isPremium {
                self.presentTagPremiumPaywall()
                return
            }
            
            let reactionFile: Signal<TelegramMediaFile?, NoError>
            switch value {
            case .builtin:
                reactionFile = self.context.engine.stickers.availableReactions()
                |> take(1)
                |> map { availableReactions -> TelegramMediaFile? in
                    return availableReactions?.reactions.first(where: { $0.value == value })?.selectAnimation
                }
            case let .custom(fileId):
                reactionFile = self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                |> map { files -> TelegramMediaFile? in
                    return files.values.first
                }
            }
            
            let _ = (combineLatest(queue: .mainQueue(),
                self.context.engine.stickers.savedMessageTagData(),
                reactionFile
            )
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] savedMessageTags, reactionFile in
                guard let self, let savedMessageTags else {
                    return
                }
                guard let reactionFile else {
                    return
                }
                
                var items: [ContextMenuItem] = []
                
                let tag: EngineMessage.CustomTag = ReactionsMessageAttribute.messageTag(reaction: value)
                
                var hasTitle = false
                if let tag = savedMessageTags.tags.first(where: { $0.reaction == value }) {
                    if let title = tag.title, !title.isEmpty {
                        hasTitle = true
                    }
                }
                
                let optionTitle = hasTitle ? self.presentationData.strings.Chat_EditTagTitle_TitleEdit : self.presentationData.strings.Chat_EditTagTitle_TitleSet
                
                items.append(.action(ContextMenuActionItem(text: optionTitle, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/TagEditName"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, a in
                    guard let self else {
                        a(.default)
                        return
                    }
                    c.dismiss(completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        let _ = (self.context.engine.stickers.savedMessageTagData()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] savedMessageTags in
                            guard let self, let savedMessageTags else {
                                return
                            }
                            
                            let reaction = value
                            
                            let promptController = savedTagNameAlertController(context: self.context, updatedPresentationData: nil, text: optionTitle, subtext: self.presentationData.strings.Chat_EditTagTitle_Text, value: savedMessageTags.tags.first(where: { $0.reaction == reaction })?.title ?? "", reaction: reaction, file: reactionFile, characterLimit: 10, apply: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                
                                if let value {
                                    let _ = self.context.engine.stickers.setSavedMessageTagTitle(reaction: reaction, title: value.isEmpty ? nil : value).start()
                                }
                            })
                            self.interfaceInteraction?.presentController(promptController, nil)
                        })
                    })
                })))
                
                if case .pinnedMessages = self.subject {
                } else {
                    if self.presentationInterfaceState.historyFilter?.customTag != tag {
                        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_ReactionContextMenu_FilterByTag, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/TagFilter"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] _, a in
                            guard let self else {
                                a(.default)
                                return
                            }
                            self.chatDisplayNode.historyNode.frozenMessageForScrollingReset = message.id
                            self.interfaceInteraction?.updateHistoryFilter { _ in
                                return ChatPresentationInterfaceState.HistoryFilter(customTag: tag)
                            }
                            
                            a(.default)
                        })))
                    }
                }
                
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_ReactionContextMenu_RemoveTag, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/TagRemove"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak self] _, a in
                    a(.dismissWithoutContent)
                    guard let self else {
                        return
                    }
                    self.controllerInteraction?.updateMessageReaction(message, .reaction(value), true)
                })))
                
                self.canReadHistory.set(false)
                
                let controller = ContextController(presentationData: self.presentationData, source: .extracted(ChatMessageReactionContextExtractedContentSource(chatNode: self.chatDisplayNode, engine: self.context.engine, message: message, contentView: sourceView)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
                controller.dismissed = { [weak self] in
                    self?.canReadHistory.set(true)
                }
                
                self.forEachController({ controller in
                    if let controller = controller as? TooltipScreen {
                        controller.dismiss()
                    }
                    return true
                })
                self.window?.presentInGlobalOverlay(controller)
            })
        } else {
            var customFileIds: [Int64] = []
            if case let .custom(fileId) = value {
                customFileIds.append(fileId)
            }
            
            let _ = (combineLatest(
                self.context.engine.stickers.availableReactions(),
                self.context.engine.stickers.resolveInlineStickers(fileIds: customFileIds)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] availableReactions, customEmoji in
                guard let self else {
                    return
                }
                
                var dismissController: ((@escaping () -> Void) -> Void)?
                
                var items = ContextController.Items(content: .custom(ReactionListContextMenuContent(
                    context: self.context,
                    displayReadTimestamps: false,
                    availableReactions: availableReactions,
                    animationCache: self.controllerInteraction!.presentationContext.animationCache,
                    animationRenderer: self.controllerInteraction!.presentationContext.animationRenderer,
                    message: EngineMessage(message), reaction: value, readStats: nil, back: nil, openPeer: { peer, hasReaction in
                    dismissController?({ [weak self] in
                        guard let self else {
                            return
                        }
                        
                        self.openPeer(peer: peer, navigation: .default, fromMessage: MessageReference(message), fromReactionMessageId: hasReaction ? message.id : nil)
                    })
                })))
                
                var packReferences: [StickerPackReference] = []
                var existingIds = Set<Int64>()
                for (_, file) in customEmoji {
                    loop: for attribute in file.attributes {
                        if case let .CustomEmoji(_, _, _, packReference) = attribute, let packReference = packReference {
                            if case let .id(id, _) = packReference, !existingIds.contains(id) {
                                packReferences.append(packReference)
                                existingIds.insert(id)
                            }
                            break loop
                        }
                    }
                }
                
                self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                let context = self.context
                let presentationData = self.presentationData
                
                let action = { [weak self] in
                    guard let packReference = packReferences.first, let self else {
                        return
                    }
                    self.chatDisplayNode.dismissTextInput()
                    
                    let presentationData = self.presentationData
                    let controller = StickerPackScreen(context: context, updatedPresentationData: self.updatedPresentationData, mainStickerPack: packReference, stickerPacks: Array(packReferences), parentNavigationController: self.effectiveNavigationController, actionPerformed: { [weak self] actions in
                        guard let self else {
                            return
                        }
                        if actions.count > 1, let first = actions.first {
                            if case .add = first.2 {
                                self.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.EmojiPackActionInfo_AddedTitle, text: presentationData.strings.EmojiPackActionInfo_MultipleAddedText(Int32(actions.count)), undo: false, info: first.0, topItem: first.1.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { _ in
                                    return true
                                }))
                            } else if actions.allSatisfy({
                                if case .remove = $0.2 {
                                    return true
                                } else {
                                    return false
                                }
                            }) {
                                let isEmoji = actions[0].0.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks
                                
                                self.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_MultipleRemovedText(Int32(actions.count)) : presentationData.strings.StickerPackActionInfo_MultipleRemovedText(Int32(actions.count)), undo: true, info: actions[0].0, topItem: actions[0].1.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { action in
                                    if case .undo = action {
                                        var itemsAndIndices: [(StickerPackCollectionInfo, [StickerPackItem], Int)] = actions.compactMap { action -> (StickerPackCollectionInfo, [StickerPackItem], Int)? in
                                            if case let .remove(index) = action.2 {
                                                return (action.0, action.1, index)
                                            } else {
                                                return nil
                                            }
                                        }
                                        itemsAndIndices.sort(by: { $0.2 < $1.2 })
                                        for (info, items, index) in itemsAndIndices.reversed() {
                                            let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: index).startStandalone()
                                        }
                                    }
                                    return true
                                }))
                            }
                        } else if let (info, items, action) = actions.first {
                            let isEmoji = info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks
                            
                            switch action {
                            case .add:
                                self.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedTitle : presentationData.strings.StickerPackActionInfo_AddedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedText(info.title).string : presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { _ in
                                    return true
                                }))
                            case let .remove(positionInList):
                                self.presentInGlobalOverlay(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedText(info.title).string : presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { action in
                                    if case .undo = action {
                                        let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).startStandalone()
                                    }
                                    return true
                                }))
                            }
                        }
                    })
                    self.present(controller, in: .window(.root))
                }
                
                let presentationContext = self.controllerInteraction?.presentationContext
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                
                if !packReferences.isEmpty && !premiumConfiguration.isPremiumDisabled {
                    items.tip = .animatedEmoji(text: nil, arguments: nil, file: nil, action: nil)
                    
                    if packReferences.count > 1 {
                        items.tip = .animatedEmoji(text: presentationData.strings.ChatContextMenu_EmojiSet(Int32(packReferences.count)), arguments: nil, file: nil, action: action)
                    } else if let reference = packReferences.first {
                        var tipSignal: Signal<LoadedStickerPack, NoError>
                        tipSignal = context.engine.stickers.loadedStickerPack(reference: reference, forceActualized: false)
                        
                        items.tipSignal = tipSignal
                        
                        |> filter { result in
                            if case .result = result {
                                return true
                            } else {
                                return false
                            }
                        }
                        |> mapToSignal { result -> Signal<ContextController.Tip?, NoError> in
                            if case let .result(info, items, _) = result, let presentationContext = presentationContext {
                                let tip: ContextController.Tip = .animatedEmoji(
                                    text: presentationData.strings.ChatContextMenu_ReactionEmojiSetSingle(info.title).string,
                                    arguments: TextNodeWithEntities.Arguments(
                                        context: context,
                                        cache: presentationContext.animationCache,
                                        renderer: presentationContext.animationRenderer,
                                        placeholderColor: .clear,
                                        attemptSynchronous: true
                                    ),
                                    file: items.first?.file,
                                    action: action)
                                return .single(tip)
                            } else {
                                return .complete()
                            }
                        }
                    }
                }
                
                self.canReadHistory.set(false)
                
                let controller = ContextController(presentationData: self.presentationData, source: .extracted(ChatMessageReactionContextExtractedContentSource(chatNode: self.chatDisplayNode, engine: self.context.engine, message: message, contentView: sourceView)), items: .single(items), recognizer: nil, gesture: gesture)
                controller.dismissed = { [weak self] in
                    self?.canReadHistory.set(true)
                }
                dismissController = { [weak controller] completion in
                    controller?.dismiss(completion: {
                        completion()
                    })
                }
                
                self.forEachController({ controller in
                    if let controller = controller as? TooltipScreen {
                        controller.dismiss()
                    }
                    return true
                })
                self.window?.presentInGlobalOverlay(controller)
            })
        }
    }
}
