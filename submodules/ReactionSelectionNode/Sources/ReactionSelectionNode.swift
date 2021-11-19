import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import StickerResources
import AccountContext

private func generateBubbleImage(foreground: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

private func generateBubbleShadowImage(shadow: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
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

private let font = Font.medium(13.0)

final class ReactionNode: ASDisplayNode {
    let context: AccountContext
    let item: ReactionContextItem
    private let staticImageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
    private var fetchStickerDisposable: Disposable?
    private var fetchFullAnimationDisposable: Disposable?
    
    private var validSize: CGSize?
    
    var isExtracted: Bool = false
    
    init(context: AccountContext, theme: PresentationTheme, item: ReactionContextItem) {
        self.context = context
        self.item = item
        
        self.staticImageNode = TransformImageNode()
        
        super.init()
        
        //self.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
        
        self.addSubnode(self.staticImageNode)
        
        /*self.addSubnode(self.animationNode)
        
        self.animationNode.updateLayout(size: self.intrinsicSize)
        self.animationNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicSize)*/
        
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.listAnimation.resource)).start()
        self.fetchFullAnimationDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.applicationAnimation.resource)).start()
        //let _ = context.meshAnimationCache.get(resource: item.applicationAnimation.resource)
    }
    
    deinit {
        self.fetchStickerDisposable?.dispose()
        self.fetchFullAnimationDisposable?.dispose()
    }
    
    func updateLayout(size: CGSize, isExpanded: Bool, transition: ContainedViewLayoutTransition) {
        let intrinsicSize = size
        
        let animationSize = self.item.listAnimation.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
        var animationDisplaySize = animationSize.aspectFitted(intrinsicSize)
        
        var scalingFactor: CGFloat = 1.0
        var offsetFactor: CGFloat = 0.0
        switch self.item.reaction.rawValue {
        case "💸":
            scalingFactor = 1.25
            offsetFactor = -0.04
        case "👍":
            scalingFactor = 1.4
            offsetFactor = 0.02
        case "👎":
            scalingFactor = 1.4
            offsetFactor = -0.01
        case "😂":
            scalingFactor = 1.2
        case "🍆":
            scalingFactor = 1.1
            offsetFactor = -0.01
        case "👻":
            scalingFactor = 1.2
        case "🎃":
            scalingFactor = 1.15
            offsetFactor = -0.08
        case "🎈":
            offsetFactor = 0.03
        case "🎉":
            offsetFactor = -0.01
        default:
            break
        }
        
        animationDisplaySize.width = floor(animationDisplaySize.width * scalingFactor)
        animationDisplaySize.height = floor(animationDisplaySize.height * scalingFactor)
        
        var animationFrame = CGRect(origin: CGPoint(x: floor((intrinsicSize.width - animationDisplaySize.width) / 2.0), y: floor((intrinsicSize.height - animationDisplaySize.height) / 2.0)), size: animationDisplaySize)
        animationFrame.origin.y = floor(animationFrame.origin.y + animationFrame.height * offsetFactor)
        
        if isExpanded, self.animationNode == nil {
            let animationNode = AnimatedStickerNode()
            self.animationNode = animationNode
            self.addSubnode(animationNode)
            
            animationNode.started = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.staticImageNode.isHidden = true
            }
            
            animationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.listAnimation.resource), width: Int(size.width * 2.0), height: Int(size.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            animationNode.frame = animationFrame
            animationNode.updateLayout(size: animationFrame.size)
            if transition.isAnimated, !self.staticImageNode.frame.isEmpty {
                transition.animateTransformScale(node: animationNode, from: self.staticImageNode.bounds.width / animationFrame.width)
                transition.animatePositionAdditive(node: animationNode, offset: CGPoint(x: self.staticImageNode.frame.midX - animationFrame.midX, y: self.staticImageNode.frame.midY - animationFrame.midY))
            }
            animationNode.visibility = true
        }
        
        if self.validSize != size {
            self.validSize = size
            
            self.staticImageNode.setSignal(chatMessageAnimatedSticker(postbox: self.context.account.postbox, file: item.listAnimation, small: false, size: CGSize(width: animationDisplaySize.width * UIScreenScale, height: animationDisplaySize.height * UIScreenScale), fitzModifier: nil, fetched: false, onlyFullSize: false, thumbnail: false, synchronousLoad: false))
            let imageApply = self.staticImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: animationDisplaySize, boundingSize: animationDisplaySize, intrinsicInsets: UIEdgeInsets()))
            imageApply()
            transition.updateFrame(node: self.staticImageNode, frame: animationFrame)
        }
    }
    
    func didAppear() {
    }
}

/*final class ReactionSelectionNode: ASDisplayNode {
    private let account: Account
    private let theme: PresentationTheme
    private let reactions: [ReactionGestureItem]
    
    private let backgroundNode: ASImageNode
    private let backgroundShadowNode: ASImageNode
    private let bubbleNodes: [(ASImageNode, ASImageNode)]
    private var reactionNodes: [ReactionNode] = []
    private var hasSelectedNode = false
    
    private let hapticFeedback = HapticFeedback()
    
    private var shadowBlur: CGFloat = 8.0
    private var minimizedReactionSize: CGFloat = 28.0
    private var smallCircleSize: CGFloat = 14.0
    
    private var isRightAligned: Bool = false
    
    public init(account: Account, theme: PresentationTheme, reactions: [ReactionGestureItem]) {
        self.account = account
        self.theme = theme
        self.reactions = reactions
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.backgroundShadowNode = ASImageNode()
        self.backgroundShadowNode.displaysAsynchronously = false
        self.backgroundShadowNode.displayWithoutProcessing = true
        
        self.bubbleNodes = (0 ..< 2).map { i -> (ASImageNode, ASImageNode) in
            let imageNode = ASImageNode()
            imageNode.displaysAsynchronously = false
            imageNode.displayWithoutProcessing = true
            
            let shadowNode = ASImageNode()
            shadowNode.displaysAsynchronously = false
            shadowNode.displayWithoutProcessing = true
            
            return (imageNode, shadowNode)
        }
        
        super.init()
        
        self.bubbleNodes.forEach { _, shadow in
            //self.addSubnode(shadow)
        }
        self.addSubnode(self.backgroundShadowNode)
        self.bubbleNodes.forEach { foreground, _ in
            //self.addSubnode(foreground)
        }
        self.addSubnode(self.backgroundNode)
    }
    
    func updateLayout(constrainedSize: CGSize, startingPoint: CGPoint, offsetFromStart: CGFloat, isInitial: Bool, touchPoint: CGPoint) {
        let initialAnchorX = startingPoint.x
        
        var isRightAligned = false
        if initialAnchorX > constrainedSize.width / 2.0 {
            isRightAligned = true
        }
        
        let reactionSideInset: CGFloat = 10.0
        let reactionSpacing: CGFloat = 6.0
        let minReactionSpacing: CGFloat = 2.0
        let minimizedReactionSize = self.minimizedReactionSize
        let contentWidth: CGFloat = CGFloat(self.reactions.count) * (minimizedReactionSize) + CGFloat(self.reactions.count - 1) * reactionSpacing + reactionSideInset * 2.0
        let spaceForMaximizedReaction = CGFloat(self.reactions.count - 1) * reactionSpacing - CGFloat(self.reactions.count - 1) * minReactionSpacing
        let maximizedReactionSize: CGFloat = minimizedReactionSize + spaceForMaximizedReaction
        let backgroundHeight: CGFloat = floor(self.minimizedReactionSize * 1.8)
        
        var backgroundFrame = CGRect(origin: CGPoint(x: -shadowBlur, y: -shadowBlur), size: CGSize(width: contentWidth + shadowBlur * 2.0, height: backgroundHeight + shadowBlur * 2.0))
        if constrainedSize.width > 500.0 {
            backgroundFrame = backgroundFrame.offsetBy(dx: constrainedSize.width - contentWidth - 44.0, dy: startingPoint.y - backgroundHeight - 12.0)
        } else {
            backgroundFrame = backgroundFrame.offsetBy(dx: floor((constrainedSize.width - contentWidth) / 2.0), dy: startingPoint.y - backgroundHeight - 12.0)
        }
        backgroundFrame.origin.x = max(0.0, backgroundFrame.minX)
        backgroundFrame.origin.x = min(constrainedSize.width - backgroundFrame.width, backgroundFrame.minX)
        
        let anchorMinX = backgroundFrame.minX + shadowBlur + backgroundHeight / 2.0
        let anchorMaxX = backgroundFrame.maxX - shadowBlur - backgroundHeight / 2.0
        let anchorX = max(anchorMinX, min(anchorMaxX, offsetFromStart))
        
        var maximizedIndex = -1
        /*if let reaction = self.reactions.last, case .reply = reaction {
            maximizedIndex = self.reactions.count - 1
        }*/
        if backgroundFrame.insetBy(dx: -10.0, dy: -10.0).offsetBy(dx: 0.0, dy: 10.0).contains(touchPoint) {
            maximizedIndex = Int(((touchPoint.x - anchorMinX) / (anchorMaxX - anchorMinX)) * CGFloat(self.reactionNodes.count))
            maximizedIndex = max(0, min(self.reactionNodes.count - 1, maximizedIndex))
        }
        
        let interReactionSpacing: CGFloat
        if maximizedIndex != -1 {
            interReactionSpacing = minReactionSpacing
        } else {
            interReactionSpacing = reactionSpacing
        }
        
        if isInitial && self.reactionNodes.isEmpty {            
            self.shadowBlur = floor(minimizedReactionSize * 0.26)
            self.smallCircleSize = 14.0
            
            self.backgroundNode.image = generateBubbleImage(foreground: .white, diameter: backgroundHeight, shadowBlur: self.shadowBlur)
            self.backgroundShadowNode.image = generateBubbleShadowImage(shadow: UIColor(white: 0.0, alpha: 0.2), diameter: backgroundHeight, shadowBlur: self.shadowBlur)
            for i in 0 ..< self.bubbleNodes.count {
                self.bubbleNodes[i].0.image = generateBubbleImage(foreground: .white, diameter: CGFloat(i + 1) * self.smallCircleSize, shadowBlur: self.shadowBlur)
                self.bubbleNodes[i].1.image = generateBubbleShadowImage(shadow: UIColor(white: 0.0, alpha: 0.2), diameter: CGFloat(i + 1) * self.smallCircleSize, shadowBlur: self.shadowBlur)
            }
            
            self.reactionNodes = self.reactions.map { reaction -> ReactionNode in
                return ReactionNode(account: self.account, theme: self.theme, reaction: reaction, maximizedReactionSize: maximizedReactionSize - 12.0, loadFirstFrame: true)
            }
            self.reactionNodes.forEach(self.addSubnode(_:))
        }
        
        let minimizedReactionVerticalInset: CGFloat = floor((backgroundHeight - minimizedReactionSize) / 2.0)
        
        
        /*if maximizedIndex == -1 {
            backgroundFrame.size.width -= maximizedReactionSize - minimizedReactionSize
            backgroundFrame.origin.x += maximizedReactionSize - minimizedReactionSize
        }*/
        
        self.isRightAligned = isRightAligned
        
        let backgroundTransition: ContainedViewLayoutTransition
        if isInitial {
            backgroundTransition = .immediate
        } else {
            backgroundTransition = .animated(duration: 0.18, curve: .easeInOut)
        }
        backgroundTransition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        backgroundTransition.updateFrame(node: self.backgroundShadowNode, frame: backgroundFrame)
        
        var reactionX: CGFloat = backgroundFrame.minX + shadowBlur + reactionSideInset
        if maximizedIndex != -1 {
            self.hasSelectedNode = false
        } else {
            self.hasSelectedNode = true
        }
        
        for iterationIndex in 0 ..< self.reactionNodes.count {
            var i = iterationIndex
            let isMaximized = i == maximizedIndex
            if !isRightAligned {
                i = self.reactionNodes.count - 1 - i
            }
            
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
                if isMaximized && !isInitial {
                    self.hapticFeedback.tap()
                }
            }
            
            var reactionFrame = CGRect(origin: CGPoint(x: reactionX, y: backgroundFrame.maxY - shadowBlur - minimizedReactionVerticalInset - reactionSize), size: CGSize(width: reactionSize, height: reactionSize))
            if isMaximized {
                reactionFrame.origin.x -= 7.0
                reactionFrame.size.width += 14.0
            }
            self.reactionNodes[i].updateLayout(size: reactionFrame.size, scale: reactionFrame.size.width / (maximizedReactionSize + 14.0), transition: transition, displayText: isMaximized)
            
            transition.updateFrame(node: self.reactionNodes[i], frame: reactionFrame, beginWithCurrentState: true)
            
            reactionX += reactionSize + interReactionSpacing
        }
        
        let mainBubbleFrame = CGRect(origin: CGPoint(x: anchorX - self.smallCircleSize - shadowBlur, y: backgroundFrame.maxY - shadowBlur - self.smallCircleSize - shadowBlur), size: CGSize(width: self.smallCircleSize * 2.0 + shadowBlur * 2.0, height: self.smallCircleSize * 2.0 + shadowBlur * 2.0))
        self.bubbleNodes[1].0.frame = mainBubbleFrame
        self.bubbleNodes[1].1.frame = mainBubbleFrame
        
        let secondaryBubbleFrame = CGRect(origin: CGPoint(x: mainBubbleFrame.midX - 10.0 - (self.smallCircleSize + shadowBlur * 2.0) / 2.0, y: mainBubbleFrame.midY + 10.0 - (self.smallCircleSize + shadowBlur * 2.0) / 2.0), size: CGSize(width: self.smallCircleSize + shadowBlur * 2.0, height: self.smallCircleSize + shadowBlur * 2.0))
        self.bubbleNodes[0].0.frame = secondaryBubbleFrame
        self.bubbleNodes[0].1.frame = secondaryBubbleFrame
    }
    
    func animateIn() {
        self.bubbleNodes[1].0.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        self.bubbleNodes[1].1.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        
        self.bubbleNodes[0].0.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.05, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        self.bubbleNodes[0].1.layer.animateScale(from: 0.01, to: 1.0, duration: 0.11, delay: 0.05, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        
        let backgroundOffset: CGPoint
        if self.isRightAligned {
            backgroundOffset = CGPoint(x: (self.backgroundNode.frame.width - shadowBlur) / 2.0 - 42.0, y: 10.0)
        } else {
            backgroundOffset = CGPoint(x: -(self.backgroundNode.frame.width - shadowBlur) / 2.0 + 42.0, y: 10.0)
        }
        let damping: CGFloat = 100.0
        
        for i in 0 ..< self.reactionNodes.count {
            let animationOffset: Double = 1.0 - Double(i) / Double(self.reactionNodes.count - 1)
            var nodeOffset: CGPoint
            if self.isRightAligned {
                nodeOffset = CGPoint(x: self.reactionNodes[i].frame.minX - (self.backgroundNode.frame.maxX - shadowBlur) / 2.0 - 42.0, y: 10.0)
            } else {
                nodeOffset = CGPoint(x: self.reactionNodes[i].frame.minX - (self.backgroundNode.frame.minX + shadowBlur) / 2.0 - 42.0, y: 10.0)
            }
            nodeOffset.x = 0.0
            nodeOffset.y = 30.0
            self.reactionNodes[i].layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.04, delay: animationOffset * 0.1)
            self.reactionNodes[i].layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, delay: animationOffset * 0.1, initialVelocity: 0.0, damping: damping)
            //self.reactionNodes[i].layer.animateSpring(from: NSValue(cgPoint: nodeOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, delay: animationOffset * 0.1, initialVelocity: 0.0, damping: damping, additive: true)
        }
        
        self.backgroundNode.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, damping: damping)
        self.backgroundNode.layer.animateSpring(from: NSValue(cgPoint: backgroundOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, initialVelocity: 0.0, damping: damping, additive: true)
        self.backgroundShadowNode.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, damping: damping)
        self.backgroundShadowNode.layer.animateSpring(from: NSValue(cgPoint: backgroundOffset), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, initialVelocity: 0.0, damping: damping, additive: true)
    }
    
    func animateOut(into targetNode: ASDisplayNode?, hideTarget: Bool, completion: @escaping () -> Void) {
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
                    targetNode.recursivelyEnsureDisplaySynchronously(true)
                    if let snapshotView = self.reactionNodes[i].view.snapshotContentTree(), let targetSnapshotView = targetNode.view.snapshotContentTree() {
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
        
        //self.backgroundNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
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
        for i in 0 ..< self.reactionNodes.count {
            if let isMaximized = self.reactionNodes[i].isMaximized, isMaximized {
                return self.reactionNodes[i].reaction
            }
        }
        return nil
    }
}

*/
