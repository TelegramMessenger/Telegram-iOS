import Foundation
import AsyncDisplayKit
import AnimationUI
import Display
import Postbox
import TelegramCore

private let shadowBlur: CGFloat = 8.0
private let minimizedReactionSize: CGFloat = 30.0
private let maximizedReactionSize: CGFloat = 60.0

private func generateBubbleImage(foreground: UIColor, diameter: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

private func generateBubbleShadowImage(shadow: UIColor, diameter: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setShadow(offset: CGSize(), blur: 1.0, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

private final class ReactionNode: ASDisplayNode {
    let reaction: ReactionGestureItem
    private let animationNode: AnimatedStickerNode
    var isMaximized: Bool?
    private let intrinsicSize: CGSize
    private let intrinsicOffset: CGPoint
    
    init(account: Account, reaction: ReactionGestureItem) {
        self.reaction = reaction
        
        self.animationNode = AnimatedStickerNode()
        self.animationNode.automaticallyLoadFirstFrame = true
        self.animationNode.playToCompletionOnStop = true
        //self.animationNode.backgroundColor = .lightGray
        
        var intrinsicSize = CGSize(width: maximizedReactionSize + 18.0, height: maximizedReactionSize + 18.0)
        switch reaction.value.value {
        case "😳":
            intrinsicSize.width += 8.0
            intrinsicSize.height += 8.0
            self.intrinsicOffset = CGPoint(x: 0.0, y: -4.0)
        case "👍":
            intrinsicSize.width += 20.0
            intrinsicSize.height += 20.0
            self.intrinsicOffset = CGPoint(x: 0.0, y: 4.0)
        default:
            self.intrinsicOffset = CGPoint(x: 0.0, y: 0.0)
        }
        self.intrinsicSize = intrinsicSize
        
        super.init()
        
        //self.backgroundColor = .green
        
        self.addSubnode(self.animationNode)
        self.animationNode.visibility = true
        self.animationNode.setup(account: account, resource: reaction.value.file.resource, width: Int(self.intrinsicSize.width) * 2, height: Int(self.intrinsicSize.height) * 2, mode: .direct)
        self.animationNode.updateLayout(size: self.intrinsicSize)
        self.animationNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicSize)
    }
    
    func updateLayout(size: CGSize, scale: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(node: self.animationNode, position: CGPoint(x: size.width / 2.0 + self.intrinsicOffset.x * scale, y: size.height / 2.0 + self.intrinsicOffset.y * scale), beginWithCurrentState: true)
        transition.updateTransformScale(node: self.animationNode, scale: scale, beginWithCurrentState: true)
    }
    
    func updateIsAnimating(_ isAnimating: Bool, animated: Bool) {
        if isAnimating {
            self.animationNode.visibility = true
        } else {
            self.animationNode.visibility = false
        }
    }
}

final class ReactionSelectionNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let backgroundShadowNode: ASImageNode
    private let bubbleNodes: [(ASImageNode, ASImageNode)]
    private let reactionNodes: [ReactionNode]
    private var hasSelectedNode = false
    
    private let hapticFeedback = HapticFeedback()
    
    public init(account: Account, reactions: [ReactionGestureItem]) {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateBubbleImage(foreground: .white, diameter: 42.0)
        
        self.backgroundShadowNode = ASImageNode()
        self.backgroundShadowNode.displaysAsynchronously = false
        self.backgroundShadowNode.displayWithoutProcessing = true
        self.backgroundShadowNode.image = generateBubbleShadowImage(shadow: UIColor(white: 0.0, alpha: 0.2), diameter: 42.0)
        
        self.bubbleNodes = (0 ..< 2).map { i -> (ASImageNode, ASImageNode) in
            let imageNode = ASImageNode()
            imageNode.image = generateBubbleImage(foreground: .white, diameter: CGFloat(i + 1) * 8.0)
            imageNode.displaysAsynchronously = false
            imageNode.displayWithoutProcessing = true
            
            let shadowNode = ASImageNode()
            shadowNode.image = generateBubbleShadowImage(shadow: UIColor(white: 0.0, alpha: 0.2), diameter: CGFloat(i + 1) * 8.0)
            shadowNode.displaysAsynchronously = false
            shadowNode.displayWithoutProcessing = true
            
            return (imageNode, shadowNode)
        }
        
        self.reactionNodes = reactions.map { reaction -> ReactionNode in
            return ReactionNode(account: account, reaction: reaction)
        }
        
        super.init()
        
        self.bubbleNodes.forEach { _, shadow in
            self.addSubnode(shadow)
        }
        self.addSubnode(self.backgroundShadowNode)
        self.bubbleNodes.forEach { foreground, _ in
            self.addSubnode(foreground)
        }
        self.addSubnode(self.backgroundNode)
        self.reactionNodes.forEach(self.addSubnode(_:))
    }
    
    func updateLayout(constrainedSize: CGSize, startingPoint: CGPoint, offsetFromStart: CGFloat, isInitial: Bool) {
        let backgroundHeight: CGFloat = 42.0
        let reactionSpacing: CGFloat = 6.0
        let minimizedReactionVerticalInset: CGFloat = floor((backgroundHeight - minimizedReactionSize) / 2.0)
        
        let contentWidth: CGFloat = CGFloat(self.reactionNodes.count - 1) * (minimizedReactionSize) + maximizedReactionSize + CGFloat(self.reactionNodes.count + 1) * reactionSpacing
        
        var backgroundFrame = CGRect(origin: CGPoint(x: -shadowBlur, y: -shadowBlur), size: CGSize(width: contentWidth + shadowBlur * 2.0, height: backgroundHeight + shadowBlur * 2.0))
        backgroundFrame = backgroundFrame.offsetBy(dx: startingPoint.x - contentWidth + backgroundHeight / 2.0 - 52.0, dy: startingPoint.y - backgroundHeight - 16.0)
        
        self.backgroundNode.frame = backgroundFrame
        self.backgroundShadowNode.frame = backgroundFrame
        
        let anchorMinX = backgroundFrame.minX + shadowBlur + backgroundHeight / 2.0
        let anchorMaxX = backgroundFrame.maxX - shadowBlur - backgroundHeight / 2.0
        let anchorX = max(anchorMinX, min(anchorMaxX, offsetFromStart))
        
        var reactionX: CGFloat = backgroundFrame.minX + shadowBlur + reactionSpacing
        if offsetFromStart > backgroundFrame.maxX - shadowBlur {
            self.hasSelectedNode = false
        } else {
            self.hasSelectedNode = true
        }
            
        var maximizedIndex = Int(((anchorX - anchorMinX) / (anchorMaxX - anchorMinX)) * CGFloat(self.reactionNodes.count))
        maximizedIndex = max(0, min(self.reactionNodes.count - 1, maximizedIndex))
        
        for i in 0 ..< self.reactionNodes.count {
            let isMaximized = i == maximizedIndex
            
            let reactionSize: CGFloat
            if isMaximized {
                reactionSize = maximizedReactionSize
            } else {
                reactionSize = minimizedReactionSize
            }
            
            let transition: ContainedViewLayoutTransition
            if isInitial {
                transition = .immediate
            } else {
                transition = .animated(duration: 0.18, curve: .easeInOut)
            }
            
            if self.reactionNodes[i].isMaximized != isMaximized {
                self.reactionNodes[i].isMaximized = isMaximized
                self.reactionNodes[i].updateIsAnimating(isMaximized, animated: !isInitial)
                if isMaximized {
                    self.hapticFeedback.tap()
                }
            }
            
            var reactionFrame = CGRect(origin: CGPoint(x: reactionX, y: backgroundFrame.maxY - shadowBlur - minimizedReactionVerticalInset - reactionSize), size: CGSize(width: reactionSize, height: reactionSize))
            if isMaximized {
                reactionFrame.origin.x -= 9.0
                reactionFrame.size.width += 18.0
            }
            self.reactionNodes[i].updateLayout(size: reactionFrame.size, scale: reactionFrame.size.width / (maximizedReactionSize + 18.0), transition: transition)
            
            transition.updateFrame(node: self.reactionNodes[i], frame: reactionFrame, beginWithCurrentState: true)
            
            reactionX += reactionSize + reactionSpacing
        }
        
        let mainBubbleFrame = CGRect(origin: CGPoint(x: anchorX - 8.0 - shadowBlur, y: backgroundFrame.maxY - shadowBlur - 8.0 - shadowBlur), size: CGSize(width: 16.0 + shadowBlur * 2.0, height: 16.0 + shadowBlur * 2.0))
        self.bubbleNodes[1].0.frame = mainBubbleFrame
        self.bubbleNodes[1].1.frame = mainBubbleFrame
        
        let secondaryBubbleFrame = CGRect(origin: CGPoint(x: mainBubbleFrame.midX - 9.0 - (8.0 + shadowBlur * 2.0) / 2.0, y: mainBubbleFrame.midY + 12.0 - (8.0 + shadowBlur * 2.0) / 2.0), size: CGSize(width: 8.0 + shadowBlur * 2.0, height: 8.0 + shadowBlur * 2.0))
        self.bubbleNodes[0].0.frame = secondaryBubbleFrame
        self.bubbleNodes[0].1.frame = secondaryBubbleFrame
    }
    
    func animateIn() {
        self.bubbleNodes[1].0.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        self.bubbleNodes[1].1.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        
        self.bubbleNodes[0].0.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.05, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        self.bubbleNodes[0].1.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.05, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        
        let backgroundOffset = CGPoint(x: (self.backgroundNode.frame.width - shadowBlur) / 2.0 - 42.0, y: (self.backgroundNode.frame.height - shadowBlur) / 2.0)
        let damping: CGFloat = 100.0
        
        for i in 0 ..< self.reactionNodes.count {
            let animationOffset: Double = 1.0 - Double(i) / Double(self.reactionNodes.count - 1)
            var nodeOffset = CGPoint(x: self.reactionNodes[i].frame.minX - (self.backgroundNode.frame.maxX - shadowBlur) / 2.0 - 42.0, y: self.reactionNodes[i].frame.minY - self.backgroundNode.frame.maxY - shadowBlur)
            nodeOffset.x = -nodeOffset.x
            nodeOffset.y = 30.0
            self.reactionNodes[i].layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5 + animationOffset * 0.08, initialVelocity: 0.0, damping: damping)
            self.reactionNodes[i].layer.animateSpring(from: NSValue(cgPoint: nodeOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, initialVelocity: 0.0, damping: damping, additive: true)
        }
        
        self.backgroundNode.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, damping: damping)
        self.backgroundNode.layer.animateSpring(from: NSValue(cgPoint: backgroundOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, initialVelocity: 0.0, damping: damping, additive: true)
        self.backgroundShadowNode.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, damping: damping)
        self.backgroundShadowNode.layer.animateSpring(from: NSValue(cgPoint: backgroundOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, initialVelocity: 0.0, damping: damping, additive: true)
    }
    
    func animateOut(into targetNode: ASImageNode?, hideTarget: Bool, completion: @escaping () -> Void) {
        self.hapticFeedback.prepareTap()
        
        var completedContainer = false
        var completedTarget = true
        
        let intermediateCompletion: () -> Void = {
            if completedContainer && completedTarget {
                completion()
            }
        }
        
        if let targetNode = targetNode {
            for i in 0 ..< self.reactionNodes.count {
                if let isMaximized = self.reactionNodes[i].isMaximized, isMaximized {
                    if let snapshotView = self.reactionNodes[i].view.snapshotContentTree() {
                        let targetSnapshotView = UIImageView()
                        targetSnapshotView.image = targetNode.image
                        targetSnapshotView.frame = self.view.convert(targetNode.bounds, from: targetNode.view)
                        self.reactionNodes[i].isHidden = true
                        self.view.addSubview(targetSnapshotView)
                        self.view.addSubview(snapshotView)
                        completedTarget = false
                        let targetPosition = self.view.convert(targetNode.bounds.center, from: targetNode.view)
                        let duration: Double = 0.3
                        if hideTarget {
                            targetNode.isHidden = true
                        }
                        
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
                        targetSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        targetSnapshotView.layer.animateScale(from: snapshotView.bounds.width / targetSnapshotView.bounds.width, to: 0.5, duration: 0.3, removeOnCompletion: false)
                        
                        
                        let sourcePoint = snapshotView.center
                        let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - 30.0)
                        
                        let x1 = sourcePoint.x
                        let y1 = sourcePoint.y
                        let x2 = midPoint.x
                        let y2 = midPoint.y
                        let x3 = targetPosition.x
                        let y3 = targetPosition.y
                        
                        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
                        
                        var keyframes: [AnyObject] = []
                        for i in 0 ..< 10 {
                            let k = CGFloat(i) / CGFloat(10 - 1)
                            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
                            let y = a * x * x + b * x + c
                            keyframes.append(NSValue(cgPoint: CGPoint(x: x, y: y)))
                        }
                        
                        snapshotView.layer.animateKeyframes(values: keyframes, duration: 0.3, keyPath: "position", removeOnCompletion: false, completion: { [weak self] _ in
                            if let strongSelf = self {
                                strongSelf.hapticFeedback.tap()
                            }
                            completedTarget = true
                            if hideTarget {
                                targetNode.isHidden = false
                                targetNode.layer.animateSpring(from: 0.5 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, initialVelocity: 0.0, damping: 90.0)
                            }
                            intermediateCompletion()
                        })
                        targetSnapshotView.layer.animateKeyframes(values: keyframes, duration: 0.3, keyPath: "position", removeOnCompletion: false)
                        
                        snapshotView.layer.animateScale(from: 1.0, to: (targetSnapshotView.bounds.width * 0.5) / snapshotView.bounds.width, duration: 0.3, removeOnCompletion: false)
                    }
                    break
                }
            }
        }
        
        self.backgroundNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
        self.backgroundShadowNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
        self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.backgroundShadowNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completedContainer = true
            intermediateCompletion()
        })
        for (node, shadow) in self.bubbleNodes {
            node.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            shadow.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            shadow.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        for i in 0 ..< self.reactionNodes.count {
            self.reactionNodes[i].layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            self.reactionNodes[i].layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    func selectedReaction() -> ReactionGestureItem? {
        if !self.hasSelectedNode {
            return nil
        }
        for i in 0 ..< self.reactionNodes.count {
            if let isMaximized = self.reactionNodes[i].isMaximized, isMaximized {
                return self.reactionNodes[i].reaction
            }
        }
        return nil
    }
}
