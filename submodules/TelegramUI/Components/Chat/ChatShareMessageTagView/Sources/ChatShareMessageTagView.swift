import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import UndoUI
import ReactionSelectionNode
import EntityKeyboard

public final class ChatShareMessageTagView: UIView, UndoOverlayControllerAdditionalView {
    private struct Params: Equatable {
        var size: CGSize
        
        init(size: CGSize) {
            self.size = size
        }
    }
    
    public var interaction: UndoOverlayControllerAdditionalViewInteraction?
    
    private var reactionContextNode: ReactionContextNode?
    private var params: Params?
    
    public init(context: AccountContext, presentationData: PresentationData, isSingleMessage: Bool, reactionItems: [ReactionItem], completion: @escaping (TelegramMediaFile, UpdateMessageReaction) -> Void) {
        super.init(frame: CGRect())
        
        let reactionContextNode = ReactionContextNode(
            context: context,
            animationCache: context.animationCache,
            presentationData: presentationData,
            items: reactionItems.map { ReactionContextItem.reaction(item: $0, icon: .none) },
            selectedItems: Set(),
            title: isSingleMessage ? presentationData.strings.Chat_ForwardToSavedMessageTagSelectionTitle : presentationData.strings.Chat_ForwardToSavedMessagesTagSelectionTitle,
            reactionsLocked: false,
            alwaysAllowPremiumReactions: false,
            allPresetReactionsAreAvailable: true,
            getEmojiContent: { animationCache, animationRenderer in
                let mappedReactionItems: [EmojiComponentReactionItem] = reactionItems.map { reaction -> EmojiComponentReactionItem in
                    return EmojiComponentReactionItem(reaction: reaction.reaction.rawValue, file: reaction.stillAnimation)
                }
                
                return EmojiPagerContentComponent.emojiInputData(
                    context: context,
                    animationCache: animationCache,
                    animationRenderer: animationRenderer,
                    isStandalone: false,
                    subject: .messageTag,
                    hasTrending: false,
                    topReactionItems: mappedReactionItems,
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: context.account.peerId,
                    selectedItems: Set(),
                    premiumIfSavedMessages: false
                )
            },
            isExpandedUpdated: { [weak self] transition in
                guard let self else {
                    return
                }
                self.interaction?.disableTimeout()
                self.update(transition: transition)
            },
            requestLayout: { [weak self] transition in
                guard let self else {
                    return
                }
                self.update(transition: transition)
            },
            requestUpdateOverlayWantsToBeBelowKeyboard: { [weak self] transition in
                guard let self else {
                    return
                }
                self.update(transition: transition)
            }
        )
        reactionContextNode.reactionSelected = { [weak self] updateReaction, _ in
            guard let self else {
                return
            }
            
            let _ = (context.engine.stickers.availableReactions()
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] availableReactions in
                guard let self, let availableReactions else {
                    return
                }
                
                var file: TelegramMediaFile?
                switch updateReaction {
                case .builtin:
                    for reaction in availableReactions.reactions {
                        if reaction.value == updateReaction.reaction {
                            file = reaction.centerAnimation?._parse()
                            break
                        }
                    }
                case let .custom(_, fileValue):
                    file = fileValue
                case .stars:
                    for reaction in availableReactions.reactions {
                        if reaction.value == updateReaction.reaction {
                            file = reaction.centerAnimation?._parse()
                            break
                        }
                    }
                }
                
                guard let file else {
                    return
                }
                
                completion(file, updateReaction)
                
                self.interaction?.dismiss()
            })
        }
        reactionContextNode.displayTail = false
        reactionContextNode.forceTailToRight = true
        reactionContextNode.forceDark = false
        self.reactionContextNode = reactionContextNode
        
        self.addSubnode(reactionContextNode)
    }
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let reactionContextNode = self.reactionContextNode, let result = reactionContextNode.view.hitTest(self.convert(point, to: reactionContextNode.view), with: event) {
            return result
        }
        return nil
    }

    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let params = Params(size: size)
        if self.params == params {
            return
        }
        self.params = params
        self.update(params: params, transition: transition)
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        if let params = self.params {
            self.update(params: params, transition: transition)
        }
    }
    
    private func update(params: Params, transition: ContainedViewLayoutTransition) {
        guard let reactionContextNode = self.reactionContextNode else {
            return
        }
        
        let isFirstTime = reactionContextNode.bounds.isEmpty
        
        let reactionsAnchorRect = CGRect(origin: CGPoint(x: params.size.width - 1.0, y: 0.0), size: CGSize(width: 1.0, height: 1.0))
        
        transition.updateFrame(node: reactionContextNode, frame: CGRect(origin: CGPoint(), size: params.size))
        reactionContextNode.updateLayout(size: params.size, insets: UIEdgeInsets(), anchorRect: reactionsAnchorRect, centerAligned: true, isCoveredByInput: false, isAnimatingOut: false, transition: transition)
        reactionContextNode.updateIsIntersectingContent(isIntersectingContent: true, transition: .immediate)
        if isFirstTime {
            reactionContextNode.animateIn(from: reactionsAnchorRect)
        }
    }
}
