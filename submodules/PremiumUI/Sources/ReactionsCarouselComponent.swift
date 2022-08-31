import Foundation
import UIKit
import Display
import SwiftSignalKit
import AsyncDisplayKit
import ComponentFlow
import TelegramCore
import AccountContext
import ReactionSelectionNode
import TelegramPresentationData
import AccountContext
import AnimationCache
import Postbox
import MultiAnimationRenderer

final class ReactionsCarouselComponent: Component {
    public typealias EnvironmentType = DemoPageEnvironment
    
    let context: AccountContext
    let theme: PresentationTheme
    let reactions: [AvailableReactions.Reaction]
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        reactions: [AvailableReactions.Reaction]
    ) {
        self.context = context
        self.theme = theme
        self.reactions = reactions
    }
    
    public static func ==(lhs: ReactionsCarouselComponent, rhs: ReactionsCarouselComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.reactions != rhs.reactions {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: ReactionsCarouselComponent?
        private var node: ReactionCarouselNode?
        
        private var isVisible = false
                
        public func update(component: ReactionsCarouselComponent, availableSize: CGSize, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
            let isDisplaying = environment[DemoPageEnvironment.self].isDisplaying
            
            if self.node == nil && !component.reactions.isEmpty {
                let node = ReactionCarouselNode(
                    context: component.context,
                    theme: component.theme,
                    reactions: component.reactions
                )
                self.node = node
                self.addSubnode(node)
            }
            
            self.component = component
                        
            if let node = self.node {
                node.frame = CGRect(origin: CGPoint(x: 0.0, y: -20.0), size: availableSize)
                node.updateLayout(size: availableSize, transition: .immediate)
            }
            
            if isDisplaying && !self.isVisible {
                var fast = false
                if let _ = transition.userData(DemoAnimateInTransition.self) {
                    fast = true
                }
                self.node?.setVisible(true, fast: fast)
            } else if !isDisplaying && self.isVisible {
                self.node?.setVisible(false)
            }
            self.isVisible = isDisplaying
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private let itemSize = CGSize(width: 110.0, height: 110.0)

private let order = ["😍","👌","🥴","🐳","🥱","🕊","🤡"]

private class ReactionCarouselNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let theme: PresentationTheme
    private let reactions: [AvailableReactions.Reaction]
    private var itemContainerNodes: [ASDisplayNode] = []
    private var itemNodes: [ReactionNode] = []
    private let scrollNode: ASScrollNode
    private let tapNode: ASDisplayNode
    
    private var standaloneReactionAnimation: StandaloneReactionAnimation?
    private var animator: DisplayLinkAnimator?
    private var currentPosition: CGFloat = 0.0
    private var currentIndex: Int = 0
    
    private var validLayout: CGSize?
    
    private var playingIndices = Set<Int>()
    
    private let positionDelta: Double
    
    private var previousInteractionTimestamp: Double = 0.0
    private var timer: SwiftSignalKit.Timer?
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    init(context: AccountContext, theme: PresentationTheme, reactions: [AvailableReactions.Reaction]) {
        self.context = context
        self.theme = theme
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        var reactionMap: [MessageReaction.Reaction: AvailableReactions.Reaction] = [:]
        for reaction in reactions {
            reactionMap[reaction.value] = reaction
        }
        
        var addedReactions = Set<MessageReaction.Reaction>()
        var sortedReactions: [AvailableReactions.Reaction] = []
        for emoji in order {
            if let reaction = reactionMap[.builtin(emoji)] {
                sortedReactions.append(reaction)
                addedReactions.insert(.builtin(emoji))
            }
        }
        
        for reaction in reactions {
            if !addedReactions.contains(reaction.value) {
                sortedReactions.append(reaction)
            }
        }
        
        self.reactions = sortedReactions
        
        self.scrollNode = ASScrollNode()
        self.tapNode = ASDisplayNode()
        
        self.positionDelta = 1.0 / CGFloat(self.reactions.count)
        
        super.init()
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.tapNode)
        
        self.setup()
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.canCancelContentTouches = true
        
        self.tapNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.reactionTapped(_:))))
    }
    
    @objc private func reactionTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
        
        if let animator = self.animator {
            animator.invalidate()
            self.animator = nil
        }
        
        guard self.scrollStartPosition == nil else {
            return
        }
        
        let point = gestureRecognizer.location(in: self.view)
        guard let index = self.itemContainerNodes.firstIndex(where: { $0.frame.contains(point) }) else {
            return
        }
        
        self.scrollTo(index, playReaction: true, immediately: true, duration: 0.85)
        self.hapticFeedback.impact(.light)
    }
    
    func setVisible(_ visible: Bool, fast: Bool = false) {
        if visible {
            self.animateIn(fast: fast)
        } else {
            self.animator?.invalidate()
            self.animator = nil
            
            self.scrollTo(0, playReaction: false, immediately: false, duration: 0.0, clockwise: false)
            self.timer?.invalidate()
            self.timer = nil
            
            self.playingIndices.removeAll()
            self.standaloneReactionAnimation?.removeFromSupernode()
        }
    }
    
    func animateIn(fast: Bool) {
        let duration: Double = fast ? 1.4 : 2.2
        let delay: Double = fast ? 0.5 : 0.8
        self.scrollTo(1, playReaction: false, immediately: true, duration: duration, damping: 0.75, clockwise: true)
        Queue.mainQueue().after(delay, {
            self.playReaction(index: 1)
        })
        
        if self.timer == nil {
            self.previousInteractionTimestamp = CACurrentMediaTime()
            self.timer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: { [weak self] in
                if let strongSelf = self {
                    let currentTimestamp = CACurrentMediaTime()
                    if currentTimestamp > strongSelf.previousInteractionTimestamp + 2.0 {
                        var nextIndex = strongSelf.currentIndex - 1
                        if nextIndex < 0 {
                            nextIndex = strongSelf.reactions.count + nextIndex
                        }
                        strongSelf.scrollTo(nextIndex, playReaction: true, immediately: true, duration: 0.85, clockwise: true)
                        strongSelf.previousInteractionTimestamp = currentTimestamp
                    }
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
    }
    
    func animateOut() {
        if let standaloneReactionAnimation = self.standaloneReactionAnimation {
            standaloneReactionAnimation.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    func springCurveFunc(_ t: Double, zeta: Double) -> Double {
        let v0 = 0.0
        let omega = 20.285

        let y: Double
        if abs(zeta - 1.0) < 1e-8 {
            let c1 = -1.0
            let c2 = v0 - omega
            y = (c1 + c2 * t) * exp(-omega * t)
        } else if zeta > 1 {
            let s1 = omega * (-zeta + sqrt(zeta * zeta - 1))
            let s2 = omega * (-zeta - sqrt(zeta * zeta - 1))
            let c1 = (-s2 - v0) / (s2 - s1)
            let c2 = (s1 + v0) / (s2 - s1)
            y = c1 * exp(s1 * t) + c2 * exp(s2 * t)
        } else {
            let a = -omega * zeta
            let b = omega * sqrt(1 - zeta * zeta)
            let c2 = (v0 + a) / b
            let theta = atan(c2)
            // Alternatively y = (-cos(b * t) + c2 * sin(b * t)) * exp(a * t)
            y = sqrt(1 + c2 * c2) * exp(a * t) * cos(b * t + theta + Double.pi)
        }

        return y + 1
    }
    
    func scrollTo(_ index: Int, playReaction: Bool, immediately: Bool, duration: Double, damping: Double = 0.6, clockwise: Bool? = nil) {
        guard index >= 0 && index < self.itemNodes.count else {
            return
        }
        self.currentIndex = index
        let delta = self.positionDelta
        
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
        
        if immediately {
            self.playReaction(index: index)
        }
        
        if duration.isZero {
            self.currentPosition = newPosition
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        } else {
            self.animator = DisplayLinkAnimator(duration: duration * UIView.animationDurationFactor(), from: 0.0, to: 1.0, update: { [weak self] t in
                var t = t
                if duration <= 0.2 {
                    t = listViewAnimationCurveSystem(t)
                } else {
                    t = self?.springCurveFunc(t, zeta: damping) ?? 0.0
                }
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
                if playReaction && !immediately {
                    self?.playReaction(index: nil)
                }
            })
        }
    }
    
    func setup() {
        for reaction in self.reactions {
            guard let centerAnimation = reaction.centerAnimation else {
                continue
            }
            guard let aroundAnimation = reaction.aroundAnimation else {
                continue
            }
            let containerNode = ASDisplayNode()
            
            let itemNode = ReactionNode(context: self.context, theme: self.theme, item: ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation,
                isCustom: false
            ), animationCache: self.animationCache, animationRenderer: self.animationRenderer, loopIdle: false, hasAppearAnimation: false, useDirectRendering: false)
            containerNode.isUserInteractionEnabled = false
            containerNode.addSubnode(itemNode)
            self.addSubnode(containerNode)
                        
            self.itemContainerNodes.append(containerNode)
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
    
    func playReaction(index: Int?) {
        let index = index ?? max(0, Int(round(self.currentPosition / self.positionDelta)) % self.itemNodes.count)
        
        guard !self.playingIndices.contains(index) else {
            return
        }
        
        if let current = self.standaloneReactionAnimation, let dismiss = current.currentDismissAnimation {
            dismiss()
            current.currentDismissAnimation = nil
            self.playingIndices.removeAll()
        }
        
        let reaction = self.reactions[index]
        let targetContainerNode = self.itemContainerNodes[index]
        let targetView = self.itemNodes[index].view
        
        guard let centerAnimation = reaction.centerAnimation else {
            return
        }
        guard let aroundAnimation = reaction.aroundAnimation else {
            return
        }
        
        self.playingIndices.insert(index)
        
        targetContainerNode.view.superview?.bringSubviewToFront(targetContainerNode.view)
        
        let standaloneReactionAnimation = StandaloneReactionAnimation(genericReactionEffect: nil, useDirectRendering: true)
        self.standaloneReactionAnimation = standaloneReactionAnimation
        
        targetContainerNode.addSubnode(standaloneReactionAnimation)
        standaloneReactionAnimation.frame = targetContainerNode.bounds
        standaloneReactionAnimation.animateReactionSelection(
            context: self.context, theme: self.theme, animationCache: self.animationCache, reaction: ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation,
                isCustom: false
            ),
            avatarPeers: [],
            playHaptic: false,
            isLarge: true,
            forceSmallEffectAnimation: true,
            targetView: targetView,
            addStandaloneReactionAnimation: nil,
            currentItemNode: self.itemNodes[index],
            completion: { [weak standaloneReactionAnimation, weak self] in
                standaloneReactionAnimation?.removeFromSupernode()
                if self?.standaloneReactionAnimation === standaloneReactionAnimation {
                    self?.standaloneReactionAnimation = nil
                    self?.playingIndices.remove(index)
                }
            }
        )
    }
    
    private var scrollStartPosition: (contentOffset: CGFloat, position: CGFloat, inverse: Bool)?
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        var inverse = false
        let tapLocation = scrollView.panGestureRecognizer.location(in: scrollView)
        if tapLocation.y < scrollView.frame.height / 2.0 {
            inverse = true
        }
        if let scrollStartPosition = self.scrollStartPosition {
            self.scrollStartPosition = (scrollStartPosition.contentOffset, scrollStartPosition.position, inverse)
        } else {
            self.scrollStartPosition = (scrollView.contentOffset.x, self.currentPosition, inverse)
        }
    }
     
    private let hapticFeedback = HapticFeedback()
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking {
            self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
        }
        
        if let animator = self.animator {
            animator.invalidate()
            self.animator = nil
        }
        
        guard !self.ignoreContentOffsetChange, let (startContentOffset, startPosition, inverse) = self.scrollStartPosition else {
            return
        }

        let delta = scrollView.contentOffset.x - startContentOffset
        var positionDelta = delta * -0.001
        if inverse {
            positionDelta *= -1.0
        }
        var updatedPosition = startPosition + positionDelta
        while updatedPosition >= 1.0 {
            updatedPosition -= 1.0
        }
        while updatedPosition < 0.0 {
            updatedPosition += 1.0
        }
        self.currentPosition = updatedPosition
        
        let indexDelta = self.positionDelta
        let index = max(0, Int(round(self.currentPosition / indexDelta)) % self.itemNodes.count)
        if index != self.currentIndex {
            self.currentIndex = index
            if self.scrollNode.view.isTracking || self.scrollNode.view.isDecelerating {
                self.hapticFeedback.tap()
            }
        }
        
        if let size = self.validLayout {
            self.ignoreContentOffsetChange = true
            self.updateLayout(size: size, transition: .immediate)
            self.ignoreContentOffsetChange = false
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let (startContentOffset, _, _) = self.scrollStartPosition, abs(velocity.x) > 0.0 else {
            return
        }
        
        let delta = self.positionDelta
        let scrollDelta = targetContentOffset.pointee.x - startContentOffset
        let positionDelta = scrollDelta * -0.001
        let positionCounts = round(positionDelta / delta)
        let adjustedPositionDelta = delta * positionCounts
        let adjustedScrollDelta = adjustedPositionDelta * -1000.0
        
        targetContentOffset.pointee = CGPoint(x: startContentOffset + adjustedScrollDelta, y: 0.0)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
            
            self.resetScrollPosition()
            
            let delta = self.positionDelta
            let index = max(0, Int(round(self.currentPosition / delta)) % self.itemNodes.count)
            self.scrollTo(index, playReaction: true, immediately: true, duration: 0.2)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
        
        self.resetScrollPosition()
        self.playReaction(index: nil)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: size)
        if self.scrollNode.view.contentSize.width.isZero {
            self.scrollNode.view.contentSize = CGSize(width: 10000000.0, height: size.height)
            self.tapNode.frame = CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize)
            self.resetScrollPosition()
        }
        
        let delta = self.positionDelta
    
        let areaSize = CGSize(width: floor(size.width * 0.7), height: size.height * 0.44)
                
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            let containerNode = self.itemContainerNodes[i]
            
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
                        
            let rotatedAngle = angle - CGFloat.pi / 2.0
            
            var updatedAngle = rotatedAngle + 0.5 * sin(rotatedAngle)
            updatedAngle = updatedAngle + CGFloat.pi / 2.0

            let relativeAngle = calculateRelativeAngle(updatedAngle)
            let distance = abs(relativeAngle) / CGFloat.pi
            
            let point = CGPoint(
                x: cos(updatedAngle),
                y: sin(updatedAngle)
            )
            
            let itemFrame = CGRect(origin: CGPoint(x: size.width * 0.5 + point.x * areaSize.width * 0.5 - itemSize.width * 0.5, y: size.height * 0.5 + point.y * areaSize.height * 0.5 - itemSize.height * 0.5), size: itemSize)
            containerNode.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
            containerNode.position = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
            transition.updateTransformScale(node: containerNode, scale: 1.0 - distance * 0.8)
            
            itemNode.frame = CGRect(origin: CGPoint(), size: itemFrame.size)
            itemNode.updateLayout(size: itemFrame.size, isExpanded: false, largeExpanded: false, isPreviewing: false, transition: transition)
        }
    }
}
