import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import TelegramNotices
import ContextUI
import AccountContext
import ChatMessageItemView
import ChatMessageItemCommon
import ReactionSelectionNode
import EntityKeyboard
import TextNodeWithEntities
import PremiumUI
import TooltipUI

extension ChatControllerImpl {
    func openMessageContextMenu(message: Message, selectAll: Bool, node: ASDisplayNode, frame: CGRect, anyRecognizer: UIGestureRecognizer?, location: CGPoint?) -> Void {
        if self.presentationInterfaceState.interfaceState.selectionState != nil {
            return
        }
        let presentationData = self.presentationData
        
        self.dismissAllTooltips()
        
        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
        let gesture: ContextGesture? = anyRecognizer as? ContextGesture
        if let messages = self.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) {
            (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
            self.chatDisplayNode.cancelInteractiveKeyboardGestures()
            var updatedMessages = messages
            for i in 0 ..< updatedMessages.count {
                if updatedMessages[i].id == message.id {
                    let message = updatedMessages.remove(at: i)
                    updatedMessages.insert(message, at: 0)
                    break
                }
            }
            
            guard let topMessage = messages.first else {
                return
            }
            
            let _ = combineLatest(queue: .mainQueue(),
                self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId)),
                contextMenuForChatPresentationInterfaceState(chatPresentationInterfaceState: self.presentationInterfaceState, context: self.context, messages: updatedMessages, controllerInteraction: self.controllerInteraction, selectAll: selectAll, interfaceInteraction: self.interfaceInteraction, messageNode: node as? ChatMessageItemView),
                peerMessageAllowedReactions(context: self.context, message: topMessage),
                peerMessageSelectedReactions(context: self.context, message: topMessage),
                topMessageReactions(context: self.context, message: topMessage),
                ApplicationSpecificNotice.getChatTextSelectionTips(accountManager: self.context.sharedContext.accountManager)
            ).startStandalone(next: { [weak self] peer, actions, allowedReactions, selectedReactions, topReactions, chatTextSelectionTips in
                guard let self else {
                    return
                }
                
                /*var hasPremium = false
                if case let .user(user) = peer, user.isPremium {
                    hasPremium = true
                }*/
                
                var actions = actions
                switch actions.content {
                case let .list(itemList):
                    if itemList.isEmpty {
                        return
                    }
                case .custom, .twoLists:
                    break
                }

                var tip: ContextController.Tip?
                
                if tip == nil {
                    let isAd = message.adAttribute != nil
                        
                    var isAction = false
                    for media in message.media {
                        if media is TelegramMediaAction {
                            isAction = true
                            break
                        }
                    }
                    if self.presentationInterfaceState.copyProtectionEnabled && !isAction && !isAd {
                        if case .scheduledMessages = self.subject {
                        } else {
                            var isChannel = false
                            if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
                                isChannel = true
                            }
                            tip = .messageCopyProtection(isChannel: isChannel)
                        }
                    } else {
                        let numberOfComponents = message.text.components(separatedBy: CharacterSet.whitespacesAndNewlines).count
                        let displayTextSelectionTip = numberOfComponents >= 3 && !message.text.isEmpty && chatTextSelectionTips < 3 && !isAd
                        if displayTextSelectionTip {
                            let _ = ApplicationSpecificNotice.incrementChatTextSelectionTips(accountManager: self.context.sharedContext.accountManager).startStandalone()
                            tip = .textSelection
                        }
                    }
                }

                if actions.tip == nil {
                    actions.tip = tip
                }
                
                actions.context = self.context
                actions.animationCache = self.controllerInteraction?.presentationContext.animationCache
                                                         
                if canAddMessageReactions(message: topMessage), let allowedReactions = allowedReactions, !topReactions.isEmpty {
                    actions.reactionItems = topReactions.map(ReactionContextItem.reaction)
                    actions.selectedReactionItems = selectedReactions.reactions
                    
                    if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
                        actions.alwaysAllowPremiumReactions = true
                    }
                    
                    if !actions.reactionItems.isEmpty {
                        let reactionItems: [EmojiComponentReactionItem] = actions.reactionItems.compactMap { item -> EmojiComponentReactionItem? in
                            switch item {
                            case let .reaction(reaction):
                                return EmojiComponentReactionItem(reaction: reaction.reaction.rawValue, file: reaction.stillAnimation)
                            default:
                                return nil
                            }
                        }
                        
                        var allReactionsAreAvailable = false
                        switch allowedReactions {
                        case .set:
                            allReactionsAreAvailable = false
                        case .all:
                            allReactionsAreAvailable = true
                        }
                        
                        if let channel = self.presentationInterfaceState.renderedPeer?.chatMainPeer as? TelegramChannel, case .broadcast = channel.info {
                            allReactionsAreAvailable = false
                        }
                        
                        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                        if premiumConfiguration.isPremiumDisabled {
                            allReactionsAreAvailable = false
                        }
                        
                        if allReactionsAreAvailable {
                            actions.getEmojiContent = { [weak self] animationCache, animationRenderer in
                                guard let self else {
                                    preconditionFailure()
                                }
                                
                                return EmojiPagerContentComponent.emojiInputData(
                                    context: self.context,
                                    animationCache: animationCache,
                                    animationRenderer: animationRenderer,
                                    isStandalone: false,
                                    subject: .reaction(onlyTop: false),
                                    hasTrending: false,
                                    topReactionItems: reactionItems,
                                    areUnicodeEmojiEnabled: false,
                                    areCustomEmojiEnabled: true,
                                    chatPeerId: self.chatLocation.peerId,
                                    selectedItems: selectedReactions.files
                                )
                            }
                        } else if reactionItems.count > 16 {
                            actions.getEmojiContent = { [weak self] animationCache, animationRenderer in
                                guard let self else {
                                    preconditionFailure()
                                }
                                
                                return EmojiPagerContentComponent.emojiInputData(
                                    context: self.context,
                                    animationCache: animationCache,
                                    animationRenderer: animationRenderer,
                                    isStandalone: false,
                                    subject: .reaction(onlyTop: true),
                                    hasTrending: false,
                                    topReactionItems: reactionItems,
                                    areUnicodeEmojiEnabled: false,
                                    areCustomEmojiEnabled: false,
                                    chatPeerId: self.chatLocation.peerId,
                                    selectedItems: selectedReactions.files
                                )
                            }
                        }
                    }
                }
                
                self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                let presentationContext = self.controllerInteraction?.presentationContext
                
                var disableTransitionAnimations = false
                var actionsSignal: Signal<ContextController.Items, NoError> = .single(actions)
                if let entitiesAttribute = message.textEntitiesAttribute {
                    var emojiFileIds: [Int64] = []
                    for entity in entitiesAttribute.entities {
                        if case let .CustomEmoji(_, fileId) = entity.type {
                            emojiFileIds.append(fileId)
                        }
                    }
                    
                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                    
                    if !emojiFileIds.isEmpty && !premiumConfiguration.isPremiumDisabled {
                        tip = .animatedEmoji(text: nil, arguments: nil, file: nil, action: nil)
                        actions.tip = tip
                        disableTransitionAnimations = true
                        
                        let context = self.context
                        actionsSignal = .single(actions)
                        |> then(
                            context.engine.stickers.resolveInlineStickers(fileIds: emojiFileIds)
                            |> mapToSignal { files -> Signal<ContextController.Items, NoError> in
                                var packReferences: [StickerPackReference] = []
                                var existingIds = Set<Int64>()
                                for (_, file) in files {
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
                                
                                let action = { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.presentEmojiList(references: packReferences)
                                }
                                
                                if packReferences.count > 1 {
                                    actions.tip = .animatedEmoji(text: presentationData.strings.ChatContextMenu_EmojiSet(Int32(packReferences.count)), arguments: nil, file: nil, action: action)
                                    return .single(actions)
                                } else if let reference = packReferences.first {
                                    return context.engine.stickers.loadedStickerPack(reference: reference, forceActualized: false)
                                    |> filter { result in
                                        if case .result = result {
                                            return true
                                        } else {
                                            return false
                                        }
                                    }
                                    |> mapToSignal { result in
                                        if case let .result(info, items, _) = result, let presentationContext = presentationContext {
                                            actions.tip = .animatedEmoji(
                                                text: presentationData.strings.ChatContextMenu_EmojiSetSingle(info.title).string,
                                                arguments: TextNodeWithEntities.Arguments(
                                                    context: context,
                                                    cache: presentationContext.animationCache,
                                                    renderer: presentationContext.animationRenderer,
                                                    placeholderColor: .clear,
                                                    attemptSynchronous: true
                                                ),
                                                file: items.first?.file,
                                                action: action)
                                            return .single(actions)
                                        } else {
                                            return .complete()
                                        }
                                    }
                                } else {
                                    actions.tip = nil
                                    return .single(actions)
                                }
                            }
                        )
                    }
                }
                
                let source: ContextContentSource
                if let location = location {
                    source = .location(ChatMessageContextLocationContentSource(controller: self, location: node.view.convert(node.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
                } else {
                    source = .extracted(ChatMessageContextExtractedContentSource(chatNode: self.chatDisplayNode, engine: self.context.engine, message: message, selectAll: selectAll))
                }
                
                self.canReadHistory.set(false)
                
                let controller = ContextController(presentationData: self.presentationData, source: source, items: actionsSignal, recognizer: recognizer, gesture: gesture)
                controller.dismissed = { [weak self] in
                    self?.canReadHistory.set(true)
                }
                controller.immediateItemsTransitionAnimation = disableTransitionAnimations
                controller.getOverlayViews = { [weak self] in
                    guard let self else {
                        return []
                    }
                    return [self.chatDisplayNode.navigateButtons.view]
                }
                self.currentContextController = controller
                
                controller.premiumReactionsSelected = { [weak self, weak controller] in
                    guard let self else {
                        return
                    }
                    
                    controller?.dismissWithoutContent()

                    let context = self.context
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = PremiumDemoScreen(context: context, subject: .uniqueReactions, action: {
                        let controller = PremiumIntroScreen(context: context, source: .reactions)
                        replaceImpl?(controller)
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    self.push(controller)
                }
                
                controller.reactionSelected = { [weak self, weak controller] chosenUpdatedReaction, isLarge in
                    guard let self else {
                        return
                    }
                    
                    guard let message = messages.first else {
                        return
                    }
                    
                    controller?.view.endEditing(true)
                    
                    let chosenReaction: MessageReaction.Reaction = chosenUpdatedReaction.reaction
                    
                    let currentReactions = mergedMessageReactions(attributes: message.attributes)?.reactions ?? []
                    var updatedReactions: [MessageReaction.Reaction] = currentReactions.filter(\.isSelected).map(\.value)
                    var removedReaction: MessageReaction.Reaction?
                    var isFirst = false
                    
                    if let index = updatedReactions.firstIndex(where: { $0 == chosenReaction }) {
                        removedReaction = chosenReaction
                        updatedReactions.remove(at: index)
                    } else {
                        updatedReactions.append(chosenReaction)
                        isFirst = !currentReactions.contains(where: { $0.value == chosenReaction })
                    }
                    
                    /*guard let allowedReactions = allowedReactions else {
                        itemNode.openMessageContextMenu()
                        return
                    }
                    
                    switch allowedReactions {
                    case let .set(set):
                        if !messageAlreadyHasThisReaction && updatedReactions.contains(where: { !set.contains($0) }) {
                            itemNode.openMessageContextMenu()
                            return
                        }
                    case .all:
                        break
                    }*/
                    
                    if removedReaction == nil, case .custom = chosenReaction {
                        if let peer = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = peer.info {
                        } else {
                            if !self.presentationInterfaceState.isPremium {
                                controller?.premiumReactionsSelected?()
                                return
                            }
                        }
                    }
                    
                    self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                            if item.message.id == message.id {
                                if removedReaction == nil && !updatedReactions.isEmpty {
                                    itemNode.awaitingAppliedReaction = (chosenReaction, { [weak self, weak itemNode] in
                                        guard let self, let controller = controller else {
                                            return
                                        }
                                        if let itemNode = itemNode, let targetView = itemNode.targetReactionView(value: chosenReaction) {
                                            self.chatDisplayNode.messageTransitionNode.addMessageContextController(messageId: item.message.id, contextController: controller)
                                            
                                            var hideTargetButton: UIView?
                                            if isFirst {
                                                hideTargetButton = targetView.superview
                                            }
                                            
                                            controller.dismissWithReaction(value: chosenReaction, targetView: targetView, hideNode: true, animateTargetContainer: hideTargetButton, addStandaloneReactionAnimation: { [weak self] standaloneReactionAnimation in
                                                guard let self else {
                                                    return
                                                }
                                                self.chatDisplayNode.messageTransitionNode.addMessageStandaloneReactionAnimation(messageId: item.message.id, standaloneReactionAnimation: standaloneReactionAnimation)
                                                standaloneReactionAnimation.frame = self.chatDisplayNode.bounds
                                                self.chatDisplayNode.addSubnode(standaloneReactionAnimation)
                                            }, completion: { [weak self, weak itemNode, weak targetView] in
                                                guard let self, let itemNode = itemNode, let targetView = targetView else {
                                                    return
                                                }
                                                
                                                let _ = self
                                                let _ = itemNode
                                                let _ = targetView
                                            })
                                        } else {
                                            controller.dismiss()
                                        }
                                    })
                                } else {
                                    itemNode.awaitingAppliedReaction = (nil, {
                                        controller?.dismiss()
                                    })
                                }
                            }
                        }
                    }
                    
                    let mappedUpdatedReactions = updatedReactions.map { reaction -> UpdateMessageReaction in
                        switch reaction {
                        case let .builtin(value):
                            return .builtin(value)
                        case let .custom(fileId):
                            var customFile: TelegramMediaFile?
                            if case let .custom(customFileId, file) = chosenUpdatedReaction, fileId == customFileId {
                                customFile = file
                            }
                            return .custom(fileId: fileId, file: customFile)
                        }
                    }
                    
                    let _ = updateMessageReactionsInteractively(account: self.context.account, messageId: message.id, reactions: mappedUpdatedReactions, isLarge: isLarge, storeAsRecentlyUsed: true).startStandalone()
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
