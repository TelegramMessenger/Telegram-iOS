import Foundation
import UIKit
import AsyncDisplayKit
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import AccountContext
import MediaEditor
import TelegramPresentationData
import ReactionSelectionNode
import UndoUI
import EntityKeyboard
import ComponentFlow

public class DrawingReactionEntityView: DrawingStickerEntityView {
    private var backgroundView: UIImageView
    private var outlineView: UIImageView
    
    override init(context: AccountContext, entity: DrawingStickerEntity) {
        let backgroundView = UIImageView(image: UIImage(bundleImageName: "Stories/ReactionShadow"))
        backgroundView.layer.zPosition = -1000.0
        
        let outlineView = UIImageView(image: UIImage(bundleImageName: "Stories/ReactionOutline"))
        outlineView.tintColor = .white
        backgroundView.addSubview(outlineView)
        
        self.backgroundView = backgroundView
        self.outlineView = outlineView
        
        super.init(context: context, entity: entity)

        self.insertSubview(backgroundView, at: 0)
                
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isReaction: Bool {
        return true
    }
    
    override func animateInsertion() {
        super.animateInsertion()
        
        Queue.mainQueue().after(0.2) {
            let _ = self.selectedTapAction()
        }
    }
    
    override func onSelection() {
        self.presentReactionSelection()
    }
    
    override func onDeselection() {
        let _ = self.dismissReactionSelection()
    }
    
    public override func update(animated: Bool) {
        super.update(animated: animated)
        
        if case let .file(_, type) = self.stickerEntity.content, case let .reaction(_, style) = type {
            switch style {
            case .white:
                self.outlineView.tintColor = .white
            case .black:
                self.outlineView.tintColor = UIColor(rgb: 0x000000, alpha: 0.5)
            }
        }
    }
    
    override func updateMirroring(animated: Bool) {
        let staticTransform = CATransform3DMakeScale(self.stickerEntity.mirrored ? -1.0 : 1.0, 1.0, 1.0)
        if animated {
            let isCurrentlyMirrored = ((self.backgroundView.layer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0) < 0.0
            var animationSourceTransform = CATransform3DIdentity
            var animationTargetTransform = CATransform3DIdentity
            if isCurrentlyMirrored {
                animationSourceTransform = CATransform3DRotate(animationSourceTransform, .pi, 0.0, 1.0, 0.0)
                animationSourceTransform.m34 = -1.0 / self.imageNode.frame.width
            }
            if self.stickerEntity.mirrored {
                animationTargetTransform = CATransform3DRotate(animationTargetTransform, .pi, 0.0, 1.0, 0.0)
                animationTargetTransform.m34 = -1.0 / self.imageNode.frame.width
            }
            self.backgroundView.layer.transform = animationSourceTransform
            
            let values = [1.0, 0.01, 1.0]
            let keyTimes = [0.0, 0.5, 1.0]
            self.animationNode?.layer.animateKeyframes(values: values as [NSNumber], keyTimes: keyTimes as [NSNumber], duration: 0.25, keyPath: "transform.scale.x", timingFunction: CAMediaTimingFunctionName.linear.rawValue)
            
            UIView.animate(withDuration: 0.25, animations: {
                self.backgroundView.layer.transform = animationTargetTransform
            }, completion: { finished in
                self.backgroundView.layer.transform = staticTransform
            })
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.backgroundView.layer.transform = staticTransform
            CATransaction.commit()
        }
    }
    
    private weak var reactionContextNode: ReactionContextNode?
    fileprivate func presentReactionSelection() {
        guard let containerView = self.containerView, let superview = containerView.superview?.superview?.superview?.superview?.superview?.superview, self.reactionContextNode == nil else {
            return
        }
        
        let availableSize = superview.frame.size
        let reactionItems = containerView.getAvailableReactions()
        
        let insets = UIEdgeInsets(top: 64.0, left: 0.0, bottom: 64.0, right: 0.0)
        
        let layout: (ContainedViewLayoutTransition) -> Void = { [weak self, weak superview] transition in
            guard let self, let superview, let reactionContextNode = self.reactionContextNode else {
                return
            }
            let anchorRect = self.convert(self.bounds, to: superview).offsetBy(dx: 0.0, dy: -20.0)
            reactionContextNode.updateLayout(size: availableSize, insets: insets, anchorRect: anchorRect, centerAligned: true, isCoveredByInput: false, isAnimatingOut: false, transition: transition)
        }
        
        let reactionContextNodeTransition: ComponentTransition = .immediate
        let reactionContextNode: ReactionContextNode
        reactionContextNode = ReactionContextNode(
            context: self.context,
            animationCache: self.context.animationCache,
            presentationData: self.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: defaultDarkPresentationTheme),
            items: reactionItems.map { ReactionContextItem.reaction(item: $0, icon: .none) },
            selectedItems: Set(),
            title: nil,
            reactionsLocked: false,
            alwaysAllowPremiumReactions: false,
            allPresetReactionsAreAvailable: false,
            getEmojiContent: { [weak self] animationCache, animationRenderer in
                guard let self else {
                    preconditionFailure()
                }
                
                let mappedReactionItems: [EmojiComponentReactionItem] = reactionItems.map { reaction -> EmojiComponentReactionItem in
                    return EmojiComponentReactionItem(reaction: reaction.reaction.rawValue, file: reaction.stillAnimation)
                }
                
                return EmojiPagerContentComponent.emojiInputData(
                    context: self.context,
                    animationCache: animationCache,
                    animationRenderer: animationRenderer,
                    isStandalone: false,
                    subject: .reaction(onlyTop: false),
                    hasTrending: false,
                    topReactionItems: mappedReactionItems,
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: self.context.account.peerId,
                    selectedItems: Set(),
                    premiumIfSavedMessages: false
                )
            },
            isExpandedUpdated: { transition in
                layout(transition)
            },
            requestLayout: { transition in
                layout(transition)
            },
            requestUpdateOverlayWantsToBeBelowKeyboard: { transition in
                layout(transition)
            }
        )
        reactionContextNode.displayTail = true
        reactionContextNode.forceTailToRight = true
        reactionContextNode.forceDark = true
        self.reactionContextNode = reactionContextNode
                
        reactionContextNode.reactionSelected = { [weak self] updateReaction, _ in
            guard let self else {
                return
            }
            
            let continueWithAnimationFile: (TelegramMediaFile) -> Void = { [weak self] animation in
                guard let self else {
                    return
                }
                
                if case let .file(_, type) = self.stickerEntity.content, case let .reaction(_, style) = type {
                    self.stickerEntity.content = .file(.standalone(media: animation), .reaction(updateReaction.reaction, style))
                }
                
                var nodeToTransitionOut: ASDisplayNode?
                if let animationNode = self.animationNode {
                    nodeToTransitionOut = animationNode
                } else if !self.imageNode.isHidden {
                    nodeToTransitionOut = self.imageNode
                }
                
                if let nodeToTransitionOut, let snapshot = nodeToTransitionOut.view.snapshotView(afterScreenUpdates: false) {
                    snapshot.frame = nodeToTransitionOut.frame
                    snapshot.layer.transform = nodeToTransitionOut.transform
                    snapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        snapshot.removeFromSuperview()
                    })
                    snapshot.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                    self.addSubview(snapshot)
                }
                
                self.animationNode?.removeFromSupernode()
                self.animationNode = nil
                self.didSetUpAnimationNode = false
                self.isPlaying = false
                self.currentSize = nil
                
                self.setup()
                self.applyVisibility()
                self.setNeedsLayout()
                
                let nodeToTransitionIn: ASDisplayNode?
                if let animationNode = self.animationNode {
                    nodeToTransitionIn = animationNode
                } else {
                    nodeToTransitionIn = self.imageNode
                }
                
                if let nodeToTransitionIn {
                    nodeToTransitionIn.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    nodeToTransitionIn.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                }
                
                let _ = self.dismissReactionSelection()
            }
            
            switch updateReaction {
            case .builtin:
                let _ = (self.context.engine.stickers.availableReactions()
                |> take(1)
                |> deliverOnMainQueue).start(next: { availableReactions in
                    guard let availableReactions else {
                        return
                    }
                    var animation: TelegramMediaFile?
                    for reaction in availableReactions.reactions {
                        if reaction.value == updateReaction.reaction {
                            animation = reaction.selectAnimation._parse()
                            break
                        }
                    }
                    if let animation {
                        continueWithAnimationFile(animation)
                    }
                })
            case let .custom(fileId, file):
                if let file {
                    continueWithAnimationFile(file)
                } else {
                    let _ = (self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                    |> deliverOnMainQueue).start(next: { files in
                        if let itemFile = files[fileId] {
                            continueWithAnimationFile(itemFile)
                        }
                    })
                }
            case .stars:
                let _ = (self.context.engine.stickers.availableReactions()
                |> take(1)
                |> deliverOnMainQueue).start(next: { availableReactions in
                    guard let availableReactions else {
                        return
                    }
                    var animation: TelegramMediaFile?
                    for reaction in availableReactions.reactions {
                        if reaction.value == updateReaction.reaction {
                            animation = reaction.selectAnimation._parse()
                            break
                        }
                    }
                    if let animation {
                        continueWithAnimationFile(animation)
                    }
                })
            }
        }
        
        reactionContextNode.premiumReactionsSelected = { [weak self] file in
            guard let self else {
                return
            }

            if let file {
                let context = self.context
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let controller = UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, loop: true, title: nil, text: presentationData.strings.Story_Editor_TooltipPremiumReaction, undoText: nil, customAction: nil), elevatedLayout: true, animateInAsReplacement: false, appearance: UndoOverlayController.Appearance(isBlurred: true), action: { [weak self] action in
                    if case .info = action, let self {
                        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .storiesExpirationDurations, forceDark: true, dismissed: nil)
                        self.containerView?.push(controller)
                    }
                    return false
                })
                self.containerView?.present(controller)
            } else {
                let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .storiesExpirationDurations, forceDark: true, dismissed: nil)
                self.containerView?.push(controller)
            }
        }
        
        let anchorRect = self.convert(self.bounds, to: superview).offsetBy(dx: 0.0, dy: -20.0)
        reactionContextNodeTransition.setFrame(view: reactionContextNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
        reactionContextNode.updateLayout(size: availableSize, insets: insets, anchorRect: anchorRect, centerAligned: true, isCoveredByInput: false, isAnimatingOut: false, transition: reactionContextNodeTransition.containedViewLayoutTransition)
        
        superview.addSubnode(reactionContextNode)
        reactionContextNode.animateIn(from: anchorRect)
    }
    
    fileprivate func dismissReactionSelection() -> Bool {
        if let reactionContextNode = self.reactionContextNode {
            reactionContextNode.animateOut(to: nil, animatingOutToReaction: false)
            self.reactionContextNode = nil
            
            Queue.mainQueue().after(0.35) {
                reactionContextNode.view.removeFromSuperview()
            }
            
            return false
        } else {
            return true
        }
    }
        
    override func selectedTapAction() -> Bool {
        if case let .file(file, type) = self.stickerEntity.content, case let .reaction(reaction, style) = type {
            guard self.reactionContextNode == nil else {
                let values = [self.entity.scale, self.entity.scale * 0.93, self.entity.scale]
                let keyTimes = [0.0, 0.33, 1.0]
                self.layer.animateKeyframes(values: values as [NSNumber], keyTimes: keyTimes as [NSNumber], duration: 0.3, keyPath: "transform.scale")
            
                let updatedStyle: DrawingStickerEntity.Content.FileType.ReactionStyle
                switch style {
                case .white:
                    updatedStyle = .black
                case .black:
                    updatedStyle = .white
                }
                self.stickerEntity.content = .file(file, .reaction(reaction, updatedStyle))

                self.update(animated: false)
                
                return true
            }
            
            self.presentReactionSelection()
            
            return true
        } else {
            return super.selectedTapAction()
        }
    }
    
    override func innerLayoutSubview(boundingSize: CGSize) -> CGSize {
        self.backgroundView.frame = CGRect(origin: .zero, size: boundingSize).insetBy(dx: -5.0, dy: -5.0)
        self.outlineView.frame = backgroundView.bounds
        return CGSize(width: floor(boundingSize.width * 0.63), height: floor(boundingSize.width * 0.63))
    }
}
