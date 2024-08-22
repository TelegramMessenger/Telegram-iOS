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
import TopMessageReactions
import TelegramNotices

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
                topMessageReactions(context: self.context, message: topMessage, subPeerId: self.chatLocation.threadId.flatMap(EnginePeer.Id.init)),
                ApplicationSpecificNotice.getChatTextSelectionTips(accountManager: self.context.sharedContext.accountManager)
            ).startStandalone(next: { [weak self] peer, actions, allowedReactionsAndStars, selectedReactions, topReactions, chatTextSelectionTips in
                guard let self else {
                    return
                }
                
                var (allowedReactions, _) = allowedReactionsAndStars
                
                var actions = actions
                switch actions.content {
                case let .list(itemList):
                    if itemList.isEmpty {
                        return
                    }
                case .custom, .twoLists:
                    break
                }
                
                if allowedReactions != nil, case let .customChatContents(customChatContents) = self.presentationInterfaceState.subject {
                    if case let .hashTagSearch(publicPosts) = customChatContents.kind, publicPosts {
                        allowedReactions = nil
                    }
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
                    actions.reactionItems = topReactions.map { ReactionContextItem.reaction(item: $0, icon: .none) }
                    actions.selectedReactionItems = selectedReactions.reactions
                    if message.areReactionsTags(accountPeerId: self.context.account.peerId) {
                        if self.presentationInterfaceState.isPremium {
                            actions.reactionsTitle = presentationData.strings.Chat_ContextMenuTagsTitle
                        } else {
                            actions.reactionsTitle = presentationData.strings.Chat_MessageContextMenu_NonPremiumTagsTitle
                            actions.reactionsLocked = true
                            actions.selectedReactionItems = Set()
                        }
                        actions.allPresetReactionsAreAvailable = true
                    }
                    
                    if let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = channel.info {
                        actions.alwaysAllowPremiumReactions = true
                    }
                    
                    if !actions.reactionItems.isEmpty {
                        let reactionItems: [EmojiComponentReactionItem] = actions.reactionItems.compactMap { item -> EmojiComponentReactionItem? in
                            switch item {
                            case let .reaction(reaction, _):
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
                                    subject: message.areReactionsTags(accountPeerId: self.context.account.peerId) ? .messageTag : .reaction(onlyTop: false),
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
                    source = .extracted(ChatMessageContextExtractedContentSource(chatController: self, chatNode: self.chatDisplayNode, engine: self.context.engine, message: message, selectAll: selectAll))
                }
                
                self.canReadHistory.set(false)
                
                let isSecret = self.presentationInterfaceState.copyProtectionEnabled || self.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat
                let controller = ContextController(presentationData: self.presentationData, source: source, items: actionsSignal, recognizer: recognizer, gesture: gesture, disableScreenshots: isSecret)
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
                    self.presentTagPremiumPaywall()
                }
                
                controller.reactionSelected = { [weak self, weak controller] chosenUpdatedReaction, isLarge in
                    guard let self else {
                        return
                    }
                    
                    guard let message = messages.first else {
                        return
                    }
                    
                    controller?.view.endEditing(true)
                    
                    if case .stars = chosenUpdatedReaction.reaction {
                        if isLarge {
                            if let controller {
                                controller.dismiss(completion: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.openMessageSendStarsScreen(message: message)
                                })
                            }
                            return
                        }
                        
                        let isFirst = !"".isEmpty
                        
                        self.chatDisplayNode.historyNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item {
                                if item.message.id == message.id {
                                    let chosenReaction: MessageReaction.Reaction = .stars
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
                                            }, onHit: { [weak self, weak itemNode] in
                                                guard let self else {
                                                    return
                                                }
                                                if let itemNode = itemNode, let targetView = itemNode.targetReactionView(value: chosenReaction) {
                                                    if !"".isEmpty {
                                                        if self.context.sharedContext.energyUsageSettings.fullTranslucency {
                                                            self.chatDisplayNode.wrappingNode.triggerRipple(at: targetView.convert(targetView.bounds.center, to: self.chatDisplayNode.view))
                                                        }
                                                    }
                                                }
                                            }, completion: {})
                                        } else {
                                            controller.dismiss()
                                        }
                                    })
                                }
                            }
                        }
                        
                        guard let starsContext = self.context.starsContext else {
                            return
                        }
                        guard let peerId = self.chatLocation.peerId else {
                            return
                        }
                        let _ = (combineLatest(
                            starsContext.state,
                            self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ReactionSettings(id: peerId))
                        )
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { [weak self] state, reactionSettings in
                            guard let strongSelf = self, let balance = state?.balance else {
                                return
                            }
                            
                            if case let .known(reactionSettings) = reactionSettings, let starsAllowed = reactionSettings.starsAllowed, !starsAllowed {
                                if let peer = strongSelf.presentationInterfaceState.renderedPeer?.chatMainPeer {
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.Chat_ToastStarsReactionsDisabled(peer.debugDisplayTitle).string, actions: [
                                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {})
                                    ]), in: .window(.root))
                                }
                                return
                            }
                            
                            if balance < 1 {
                                controller?.dismiss(completion: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    let _ = (strongSelf.context.engine.payments.starsTopUpOptions()
                                    |> take(1)
                                    |> deliverOnMainQueue).startStandalone(next: { [weak strongSelf] options in
                                        guard let strongSelf else {
                                            return
                                        }
                                        guard let starsContext = strongSelf.context.starsContext else {
                                            return
                                        }
                                        
                                        let purchaseScreen = strongSelf.context.sharedContext.makeStarsPurchaseScreen(context: strongSelf.context, starsContext: starsContext, options: options, purpose: .reactions(peerId: peerId, requiredStars: 1), completion: { result in
                                            let _ = result
                                            //TODO:release
                                        })
                                        strongSelf.push(purchaseScreen)
                                    })
                                })
                                
                                return
                            }
                            
                            let _ = (strongSelf.context.engine.messages.sendStarsReaction(id: message.id, count: 1, isAnonymous: nil)
                            |> deliverOnMainQueue).startStandalone(next: { isAnonymous in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.displayOrUpdateSendStarsUndo(messageId: message.id, count: 1, isAnonymous: isAnonymous)
                            })
                        })
                    } else {
                        let chosenReaction: MessageReaction.Reaction = chosenUpdatedReaction.reaction
                        
                        let currentReactions = mergedMessageReactions(attributes: message.attributes, isTags: message.areReactionsTags(accountPeerId: self.context.account.peerId))?.reactions ?? []
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
                        
                        if message.areReactionsTags(accountPeerId: self.context.account.peerId) {
                            if removedReaction == nil, !topReactions.contains(where: { $0.reaction.rawValue == chosenReaction }) {
                                if !self.presentationInterfaceState.isPremium {
                                    controller?.premiumReactionsSelected?()
                                    return
                                }
                            }
                        } else {
                            if removedReaction == nil, case .custom = chosenReaction {
                                if let peer = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, case .broadcast = peer.info {
                                } else {
                                    if !self.presentationInterfaceState.isPremium {
                                        controller?.premiumReactionsSelected?()
                                        return
                                    }
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
                                                }, onHit: nil, completion: { [weak self, weak itemNode, weak targetView] in
                                                    guard let self, let itemNode, let targetView else {
                                                        return
                                                    }
                                                    
                                                    if self.chatLocation.peerId == self.context.account.peerId {
                                                        let _ = (ApplicationSpecificNotice.getSavedMessageTagLabelSuggestion(accountManager: self.context.sharedContext.accountManager)
                                                                 |> take(1)
                                                                 |> deliverOnMainQueue).startStandalone(next: { [weak self, weak targetView, weak itemNode] value in
                                                            guard let self, let targetView, let itemNode else {
                                                                return
                                                            }
                                                            if value >= 3 {
                                                                return
                                                            }
                                                            
                                                            let _ = itemNode
                                                            
                                                            let rect = self.chatDisplayNode.view.convert(targetView.bounds, from: targetView).insetBy(dx: -8.0, dy: -8.0)
                                                            let tooltipScreen = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: self.presentationData.strings.Chat_TooltipAddTagLabel), location: .point(rect, .bottom), displayDuration: .manual, shouldDismissOnTouch: { _, _ in
                                                                return .dismiss(consume: false)
                                                            })
                                                            self.present(tooltipScreen, in: .current)
                                                            
                                                            let _ = ApplicationSpecificNotice.incrementSavedMessageTagLabelSuggestion(accountManager: self.context.sharedContext.accountManager).startStandalone()
                                                        })
                                                    }
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
                            case .stars:
                                return .stars
                            }
                        }
                        
                        let _ = updateMessageReactionsInteractively(account: self.context.account, messageIds: [message.id], reactions: mappedUpdatedReactions, isLarge: isLarge, storeAsRecentlyUsed: true).startStandalone()
                    }
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

final class ChatContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    weak var sourceView: UIView?
    let sourceRect: CGRect?
    
    let navigationController: NavigationController? = nil

    let passthroughTouches: Bool
    
    init(controller: ViewController, sourceNode: ASDisplayNode?, sourceRect: CGRect? = nil, passthroughTouches: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.sourceRect = sourceRect
        self.passthroughTouches = passthroughTouches
    }
    
    init(controller: ViewController, sourceView: UIView?, sourceRect: CGRect? = nil, passthroughTouches: Bool) {
        self.controller = controller
        self.sourceView = sourceView
        self.sourceRect = sourceRect
        self.passthroughTouches = passthroughTouches
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceView = self.sourceView
        let sourceNode = self.sourceNode
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceView = sourceView {
                return (sourceView, sourceRect ?? sourceView.bounds)
            } else if let sourceNode = sourceNode {
                return (sourceNode.view, sourceRect ?? sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}

final class ChatControllerContextReferenceContentSource: ContextReferenceContentSource {
    let controller: ViewController
    let sourceView: UIView
    let insets: UIEdgeInsets
    let contentInsets: UIEdgeInsets
    
    init(controller: ViewController, sourceView: UIView, insets: UIEdgeInsets, contentInsets: UIEdgeInsets = UIEdgeInsets()) {
        self.controller = controller
        self.sourceView = sourceView
        self.insets = insets
        self.contentInsets = contentInsets
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds.inset(by: self.insets), insets: self.contentInsets)
    }
}
