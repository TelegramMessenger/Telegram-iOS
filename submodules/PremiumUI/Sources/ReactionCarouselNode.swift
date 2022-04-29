import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import AccountContext
import ReactionSelectionNode
import TelegramPresentationData
import AccountContext

private let itemSize = CGSize(width: 110.0, height: 110.0)

final class ReactionCarouselNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let theme: PresentationTheme
    private let reactions: [AvailableReactions.Reaction]
    private var itemNodes: [ReactionNode] = []
    private let scrollNode: ASScrollNode
    private let tapNode: ASDisplayNode
    
    private var standaloneReactionAnimation: StandaloneReactionAnimation?
    private var animator: DisplayLinkAnimator?
    private var currentPosition: CGFloat = 0.0
    
    private var validLayout: CGSize?
    
    init(context: AccountContext, theme: PresentationTheme, reactions: [AvailableReactions.Reaction]) {
        self.context = context
        self.theme = theme
        self.reactions = Array(reactions.shuffled().prefix(6))
        
        self.scrollNode = ASScrollNode()
        self.tapNode = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.tapNode)
        
        self.setup()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.canCancelContentTouches = true
        
        self.tapNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.reactionTapped(_:))))
    }
    
    @objc private func reactionTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        guard self.animator == nil, self.standaloneReactionAnimation == nil, self.scrollStartPosition == nil else {
            return
        }
        
        let point = gestureRecognizer.location(in: self.view)
        guard let index = self.itemNodes.firstIndex(where: { $0.frame.contains(point) }) else {
            return
        }
        
        self.scrollTo(index, playReaction: true, duration: 0.4)
    }
    
    func animateIn() {
        self.scrollTo(1, playReaction: true, duration: 0.5, clockwise: true)
    }
    
    func scrollTo(_ index: Int, playReaction: Bool, duration: Double, clockwise: Bool? = nil) {
        guard index >= 0 && index < self.itemNodes.count else {
            return
        }
        let delta = 1.0 / CGFloat(self.itemNodes.count)
        
        let startPosition = self.currentPosition
        let newPosition = delta * CGFloat(index)
        var change = newPosition - startPosition
        if let clockwise = clockwise {
            if clockwise {
                if change > 0.0 {
                    change = change - 1.0
                }
            } else {
                if change < 0.0 {
                    change = 1.0 + change
                }
            }
        } else {
            if change > 0.5 {
                change = change - 1.0
            } else if change < -0.5 {
                change = 1.0 + change
            }
        }
        
        self.animator = DisplayLinkAnimator(duration: duration * UIView.animationDurationFactor(), from: 0.0, to: 1.0, update: { [weak self] t in
            let t = listViewAnimationCurveSystem(t)
            var updatedPosition = startPosition + change * t
            while updatedPosition >= 1.0 {
                updatedPosition -= 1.0
            }
            while updatedPosition < 0.0 {
                updatedPosition += 1.0
            }
            self?.currentPosition = updatedPosition
            if let size = self?.validLayout {
                self?.updateLayout(size: size, transition: .immediate)
            }
        }, completion: { [weak self] in
            self?.animator = nil
            if playReaction {
                self?.playReaction()
            }
        })
    }
    
    func setup() {
        for reaction in self.reactions {
            guard let centerAnimation = reaction.centerAnimation else {
                continue
            }
            guard let aroundAnimation = reaction.aroundAnimation else {
                continue
            }
            let itemNode = ReactionNode(context: self.context, theme: self.theme, item: ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation
            ), hasAppearAnimation: false)
            itemNode.isUserInteractionEnabled = false
            self.addSubnode(itemNode)
                        
            self.itemNodes.append(itemNode)
        }
    }
    
    private var ignoreContentOffsetChange = false
    private func resetScrollPosition() {
        self.scrollStartPosition = nil
        self.ignoreContentOffsetChange = true
        self.scrollNode.view.contentOffset = CGPoint(x: 5000.0 - self.scrollNode.frame.width * 0.5, y: 0.0)
        self.ignoreContentOffsetChange = false
    }
    
    func playReaction() {
        guard self.standaloneReactionAnimation == nil else {
            return
        }
        
        let delta = 1.0 / CGFloat(self.itemNodes.count)
        let index = max(0, min(self.itemNodes.count - 1, Int(round(self.currentPosition / delta))))
        
        let reaction = self.reactions[index]
        let targetView = self.itemNodes[index].view
        
        let standaloneReactionAnimation = StandaloneReactionAnimation()
        self.standaloneReactionAnimation = standaloneReactionAnimation
        guard let supernode = self.supernode else {
            return
        }
        
        guard let centerAnimation = reaction.centerAnimation else {
            return
        }
        guard let aroundAnimation = reaction.aroundAnimation else {
            return
        }
        
        self.scrollNode.view.isScrollEnabled = false
        
        supernode.addSubnode(standaloneReactionAnimation)
        standaloneReactionAnimation.frame = supernode.bounds
        standaloneReactionAnimation.animateReactionSelection(
            context: self.context, theme: self.theme, reaction: ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation
            ),
            avatarPeers: [],
            playHaptic: false,
            isLarge: true,
            targetView: targetView,
            addStandaloneReactionAnimation: nil,
            completion: { [weak standaloneReactionAnimation, weak self] in
                standaloneReactionAnimation?.removeFromSupernode()
                self?.standaloneReactionAnimation = nil
                self?.scrollNode.view.isScrollEnabled = true
            }
        )
    }
    
    private var scrollStartPosition: (contentOffset: CGFloat, position: CGFloat)?
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if self.scrollStartPosition == nil {
            self.scrollStartPosition = (scrollView.contentOffset.x, self.currentPosition)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.ignoreContentOffsetChange, let (startContentOffset, startPosition) = self.scrollStartPosition else {
            return
        }

        let delta = scrollView.contentOffset.x - startContentOffset
        let positionDelta = delta * -0.001
        var updatedPosition = startPosition + positionDelta
        while updatedPosition >= 1.0 {
            updatedPosition -= 1.0
        }
        while updatedPosition < 0.0 {
            updatedPosition += 1.0
        }
        self.currentPosition = updatedPosition
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let (startContentOffset, _) = self.scrollStartPosition, abs(velocity.x) > 0.0 else {
            return
        }
        
        let delta = 1.0 / CGFloat(self.itemNodes.count)
        let scrollDelta = targetContentOffset.pointee.x - startContentOffset
        let positionDelta = scrollDelta * -0.001
        let positionCounts = round(positionDelta / delta)
        let adjustedPositionDelta = delta * positionCounts
        let adjustedScrollDelta = adjustedPositionDelta * -1000.0
        
        targetContentOffset.pointee = CGPoint(x: startContentOffset + adjustedScrollDelta, y: 0.0)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.resetScrollPosition()
            
            let delta = 1.0 / CGFloat(self.itemNodes.count)
            let index = max(0, min(self.itemNodes.count - 1, Int(round(self.currentPosition / delta))))
            self.scrollTo(index, playReaction: true, duration: 0.2)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.resetScrollPosition()
        self.playReaction()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: size)
        if self.scrollNode.view.contentSize.width.isZero {
            self.scrollNode.view.contentSize = CGSize(width: 10000000, height: size.height)
            self.tapNode.frame = CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize)
            self.resetScrollPosition()
        }
        
        let delta = 1.0 / CGFloat(self.itemNodes.count)
    
        let areaSize = CGSize(width: floor(size.width * 0.7), height: size.height * 0.5)
        
        var i = 0
        for itemNode in self.itemNodes {
            var angle = CGFloat.pi * 0.5 + CGFloat(i) * delta * CGFloat.pi * 2.0 - self.currentPosition * CGFloat.pi * 2.0
            if angle < 0.0 {
                angle = CGFloat.pi * 2.0 + angle
            }
            if angle > CGFloat.pi * 2.0 {
                angle = angle - CGFloat.pi * 2.0
            }
            
            func calculateRelativeAngle(_ angle: CGFloat) -> CGFloat {
                var relativeAngle = angle - CGFloat.pi * 0.5
                if relativeAngle > CGFloat.pi {
                    relativeAngle = (2.0 * CGFloat.pi - relativeAngle) * -1.0
                }
                return relativeAngle
            }
            
            let relativeAngle = calculateRelativeAngle(angle)
            let distance = abs(relativeAngle) / CGFloat.pi
            
            let point = CGPoint(
                x: cos(angle),
                y: sin(angle)
            )
            
            let itemFrame = CGRect(origin: CGPoint(x: size.width * 0.5 + point.x * areaSize.width * 0.5 - itemSize.width * 0.5, y: size.height * 0.5 + point.y * areaSize.height * 0.5 - itemSize.height * 0.5), size: itemSize)
            itemNode.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
            itemNode.position = itemFrame.center
            itemNode.updateLayout(size: itemFrame.size, isExpanded: false, largeExpanded: false, isPreviewing: false, transition: transition)
            transition.updateTransformScale(node: itemNode, scale: 1.0 - distance * 0.45)
            
            i += 1
        }
    }
}
