import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import RadialStatusNode
import AnimatedCountLabelNode
import AnimatedAvatarSetNode
import ReactionButtonListComponent
import AccountContext

final class MessageReactionButtonsNode: ASDisplayNode {
    enum DisplayType {
        case incoming
        case outgoing
        case freeform
    }
    
    enum DisplayAlignment {
        case left
        case right
    }
    
    private let container: ReactionButtonsLayoutContainer
    var reactionSelected: ((String) -> Void)?
    
    override init() {
        self.container = ReactionButtonsLayoutContainer()
        
        super.init()
    }
    
    func prepareUpdate(
        context: AccountContext,
        presentationData: ChatPresentationData,
        availableReactions: AvailableReactions?,
        reactions: ReactionsMessageAttribute,
        alignment: DisplayAlignment,
        constrainedWidth: CGFloat,
        type: DisplayType
    ) -> (proposedWidth: CGFloat, continueLayout: (CGFloat) -> (size: CGSize, apply: (ListViewItemUpdateAnimation) -> Void)) {
        let reactionColors: ReactionButtonComponent.Colors
        switch type {
        case .incoming:
            reactionColors = ReactionButtonComponent.Colors(
                deselectedBackground: presentationData.theme.theme.chat.message.incoming.accentControlColor.withMultipliedAlpha(0.1).argb,
                selectedBackground: presentationData.theme.theme.chat.message.incoming.accentControlColor.withMultipliedAlpha(1.0).argb,
                deselectedForeground: presentationData.theme.theme.chat.message.incoming.accentTextColor.argb,
                selectedForeground: presentationData.theme.theme.chat.message.incoming.bubble.withWallpaper.fill.last!.argb
            )
        case .outgoing:
            reactionColors = ReactionButtonComponent.Colors(
                deselectedBackground: presentationData.theme.theme.chat.message.outgoing.accentControlColor.withMultipliedAlpha(0.1).argb,
                selectedBackground: presentationData.theme.theme.chat.message.outgoing.accentControlColor.withMultipliedAlpha(1.0).argb,
                deselectedForeground: presentationData.theme.theme.chat.message.outgoing.accentTextColor.argb,
                selectedForeground: presentationData.theme.theme.chat.message.outgoing.bubble.withWallpaper.fill.last!.argb
            )
        case .freeform:
            reactionColors = ReactionButtonComponent.Colors(
                deselectedBackground: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper).argb,
                selectedBackground: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper).argb,
                deselectedForeground: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.message.incoming.actionButtonsTextColor, wallpaper: presentationData.theme.wallpaper).argb,
                selectedForeground: bubbleVariableColor(variableColor: presentationData.theme.theme.chat.message.incoming.actionButtonsTextColor, wallpaper: presentationData.theme.wallpaper).argb
            )
        }
        
        let reactionButtons = self.container.update(
            context: context,
            action: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reactionSelected?(value)
            },
            reactions: reactions.reactions.map { reaction in
                var iconFile: TelegramMediaFile?
                
                if let availableReactions = availableReactions {
                    for availableReaction in availableReactions.reactions {
                        if availableReaction.value == reaction.value {
                            iconFile = availableReaction.staticIcon
                            break
                        }
                    }
                }
                
                return ReactionButtonsLayoutContainer.Reaction(
                    reaction: ReactionButtonComponent.Reaction(
                        value: reaction.value,
                        iconFile: iconFile
                    ),
                    count: Int(reaction.count),
                    isSelected: reaction.isSelected
                )
            },
            colors: reactionColors,
            constrainedWidth: constrainedWidth,
            transition: .immediate
        )
        
        var reactionButtonsSize = CGSize()
        var currentRowWidth: CGFloat = 0.0
        for item in reactionButtons.items {
            if currentRowWidth + item.size.width > constrainedWidth {
                reactionButtonsSize.width = max(reactionButtonsSize.width, currentRowWidth)
                if !reactionButtonsSize.height.isZero {
                    reactionButtonsSize.height += 6.0
                }
                reactionButtonsSize.height += item.size.height
                currentRowWidth = 0.0
            }
            
            if !currentRowWidth.isZero {
                currentRowWidth += 6.0
            }
            currentRowWidth += item.size.width
        }
        if !currentRowWidth.isZero && !reactionButtons.items.isEmpty {
            reactionButtonsSize.width = max(reactionButtonsSize.width, currentRowWidth)
            if !reactionButtonsSize.height.isZero {
                reactionButtonsSize.height += 6.0
            }
            reactionButtonsSize.height += reactionButtons.items[0].size.height
        }
        
        let topInset: CGFloat = 0.0
        let bottomInset: CGFloat = 2.0
        
        return (proposedWidth: reactionButtonsSize.width, continueLayout: { [weak self] boundingWidth in
            let size = CGSize(width: boundingWidth, height: topInset + reactionButtonsSize.height + bottomInset)
            return (size: size, apply: { animation in
                guard let strongSelf = self else {
                    return
                }
                
                var reactionButtonPosition: CGPoint
                switch alignment {
                case .left:
                    reactionButtonPosition = CGPoint(x: -1.0, y: topInset)
                case .right:
                    reactionButtonPosition = CGPoint(x: size.width + 1.0, y: topInset)
                }
                for item in reactionButtons.items {
                    switch alignment {
                    case .left:
                        if reactionButtonPosition.x + item.size.width > boundingWidth {
                            reactionButtonPosition.x = 0.0
                            reactionButtonPosition.y += item.size.height + 6.0
                        }
                    case .right:
                        if reactionButtonPosition.x - item.size.width < -1.0 {
                            reactionButtonPosition.x = size.width + 1.0
                            reactionButtonPosition.y += item.size.height + 6.0
                        }
                    }
                    
                    let itemFrame: CGRect
                    switch alignment {
                    case .left:
                        itemFrame = CGRect(origin: reactionButtonPosition, size: item.size)
                        reactionButtonPosition.x += item.size.width + 6.0
                    case .right:
                        itemFrame = CGRect(origin: CGPoint(x: reactionButtonPosition.x - item.size.width, y: reactionButtonPosition.y), size: item.size)
                        reactionButtonPosition.x -= item.size.width + 6.0
                    }
                        
                    if item.view.superview == nil {
                        strongSelf.view.addSubview(item.view)
                        if animation.isAnimated {
                            item.view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                            item.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                        item.view.frame = itemFrame
                    } else {
                        animation.animator.updateFrame(layer: item.view.layer, frame: itemFrame, completion: nil)
                    }
                }
                
                for view in reactionButtons.removedViews {
                    if animation.isAnimated {
                        view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                        view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    } else {
                    view.removeFromSuperview()
                    }
                }
            })
        })
    }
    
    func reactionTargetView(value: String) -> UIView? {
        for (_, button) in self.container.buttons {
            if let result = button.findTaggedView(tag: ReactionButtonComponent.ViewTag(value: value)) as? ReactionButtonComponent.View {
                return result.iconView
            }
        }
        return nil
    }
    
    func animateIn(animation: ListViewItemUpdateAnimation) {
        for (_, button) in self.container.buttons {
            animation.animator.animateScale(layer: button.layer, from: 0.01, to: 1.0, completion: nil)
        }
    }
    
    func animateOut(animation: ListViewItemUpdateAnimation) {
        for (_, button) in self.container.buttons {
            animation.animator.updateScale(layer: button.layer, scale: 0.01, completion: nil)
        }
    }
}

final class ChatMessageReactionsFooterContentNode: ChatMessageBubbleContentNode {
    private let buttonsNode: MessageReactionButtonsNode
    
    required init() {
        self.buttonsNode = MessageReactionButtonsNode()
        
        super.init()
        
        self.addSubnode(self.buttonsNode)
        
        self.buttonsNode.reactionSelected = { [weak self] value in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(item.message, .reaction(value))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let buttonsNode = self.buttonsNode
        
        return { item, layoutConstants, preparePosition, _, constrainedSize in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            //let displaySeparator: Bool
            let topOffset: CGFloat
            if case let .linear(top, _) = preparePosition, case .Neighbour(_, .media, _) = top {
                //displaySeparator = false
                topOffset = 4.0
            } else {
                //displaySeparator = true
                topOffset = 0.0
            }
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let reactionsAttribute = mergedMessageReactions(attributes: item.message.attributes) ?? ReactionsMessageAttribute(reactions: [], recentPeers: [])
                let buttonsUpdate = buttonsNode.prepareUpdate(
                    context: item.context,
                    presentationData: item.presentationData,
                    availableReactions: item.associatedData.availableReactions, reactions: reactionsAttribute, alignment: .left, constrainedWidth: constrainedSize.width, type: item.message.effectivelyIncoming(item.context.account.peerId) ? .incoming : .outgoing)
                     
                return (layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right + buttonsUpdate.proposedWidth, { boundingWidth in
                    var boundingSize = CGSize()
                    
                    let buttonsSizeAndApply = buttonsUpdate.continueLayout(boundingWidth - (layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right))
                    
                    boundingSize = buttonsSizeAndApply.size
                    
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height += topOffset + 2.0
                    
                    return (boundingSize, { [weak self] animation, synchronousLoad in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            animation.animator.updateFrame(layer: strongSelf.buttonsNode.layer, frame: CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left, y: topOffset - 2.0), size: buttonsSizeAndApply.size), completion: nil)
                            buttonsSizeAndApply.apply(animation)
                            
                            let _ = synchronousLoad
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.buttonsNode.animateOut(animation: ListViewItemUpdateAnimation.System(duration: 0.25, transition: ControlledTransition(duration: 0.25, curve: .spring, interactive: false)))
    }
    
    override func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        self.layer.animatePosition(from: CGPoint(x: 0.0, y: -self.bounds.height / 2.0), to: CGPoint(), duration: duration, removeOnCompletion: true, additive: true)
    }
    
    override func animateRemovalFromBubble(_ duration: Double, completion: @escaping () -> Void) {
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -self.bounds.height / 2.0), duration: duration, removeOnCompletion: false, additive: true)
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.buttonsNode.animateOut(animation: ListViewItemUpdateAnimation.System(duration: 0.25, transition: ControlledTransition(duration: 0.25, curve: .spring, interactive: false)))
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if let result = self.buttonsNode.hitTest(self.view.convert(point, to: self.buttonsNode.view), with: nil), result !== self.buttonsNode.view {
            return .ignore
        }
        return .none
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.buttonsNode.hitTest(self.view.convert(point, to: self.buttonsNode.view), with: event), result !== self.buttonsNode.view {
            return result
        }
        return nil
    }
    
    override func reactionTargetView(value: String) -> UIView? {
        return self.buttonsNode.reactionTargetView(value: value)
    }
}

final class ChatMessageReactionButtonsNode: ASDisplayNode {
    final class Arguments {
        let context: AccountContext
        let presentationData: ChatPresentationData
        let availableReactions: AvailableReactions?
        let reactions: ReactionsMessageAttribute
        let isIncoming: Bool
        let constrainedWidth: CGFloat
        
        init(
            context: AccountContext,
            presentationData: ChatPresentationData,
            availableReactions: AvailableReactions?,
            reactions: ReactionsMessageAttribute,
            isIncoming: Bool,
            constrainedWidth: CGFloat
        ) {
            self.context = context
            self.presentationData = presentationData
            self.availableReactions = availableReactions
            self.reactions = reactions
            self.isIncoming = isIncoming
            self.constrainedWidth = constrainedWidth
        }
    }
    
    private let buttonsNode: MessageReactionButtonsNode
    
    var reactionSelected: ((String) -> Void)?
    
    override init() {
        self.buttonsNode = MessageReactionButtonsNode()
        
        super.init()
        
        self.addSubnode(self.buttonsNode)
        self.buttonsNode.reactionSelected = { [weak self] value in
            self?.reactionSelected?(value)
        }
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageReactionButtonsNode?) -> (_ arguments: ChatMessageReactionButtonsNode.Arguments) -> (minWidth: CGFloat, layout: (CGFloat) -> (size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode)) {
        return { arguments in
            let node = maybeNode ?? ChatMessageReactionButtonsNode()
            
            let buttonsUpdate = node.buttonsNode.prepareUpdate(
                context: arguments.context,
                presentationData: arguments.presentationData,
                availableReactions: arguments.availableReactions,
                reactions: arguments.reactions,
                alignment: arguments.isIncoming ? .left : .right,
                constrainedWidth: arguments.constrainedWidth,
                type: .freeform
            )
            
            return (buttonsUpdate.proposedWidth, { constrainedWidth in
                let buttonsResult = buttonsUpdate.continueLayout(constrainedWidth)
                
                return (CGSize(width: constrainedWidth, height: buttonsResult.size.height), { animation in
                    node.buttonsNode.frame = CGRect(origin: CGPoint(), size: buttonsResult.size)
                    buttonsResult.apply(animation)
                    
                    return node
                })
            })
        }
    }
    
    func animateIn(animation: ListViewItemUpdateAnimation) {
        self.buttonsNode.animateIn(animation: animation)
        self.buttonsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    func animateOut(animation: ListViewItemUpdateAnimation, completion: @escaping () -> Void) {
        self.buttonsNode.animateOut(animation: animation)
        animation.animator.updateAlpha(layer: self.buttonsNode.layer, alpha: 0.0, completion: { _ in
            completion()
        })
        animation.animator.updateFrame(layer: self.buttonsNode.layer, frame: self.buttonsNode.layer.frame.offsetBy(dx: 0.0, dy: -self.buttonsNode.layer.bounds.height / 2.0), completion: nil)
    }
    
    func reactionTargetView(value: String) -> UIView? {
        return self.buttonsNode.reactionTargetView(value: value)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.buttonsNode.hitTest(self.view.convert(point, to: self.buttonsNode.view), with: event), result !== self.buttonsNode.view {
            return result
        }
        return nil
    }
}
