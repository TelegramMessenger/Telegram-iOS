import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AvatarNode
import SwiftSignalKit
import AnimationUI
import ComponentFlow
import TelegramPresentationData

public struct ArchiveAnimationParams: Equatable {
    public let scrollOffset: CGFloat
    public let storiesFraction: CGFloat
    public private(set)var expandedHeight: CGFloat
    public private(set)var isRevealed: Bool = false
    public let finalizeAnimation: Bool
    public private(set)var isHiddenByDefault: Bool
    
    public static var emptyVisibleParams: ArchiveAnimationParams {
        return ArchiveAnimationParams(scrollOffset: .zero, storiesFraction: .zero, expandedHeight: .zero, finalizeAnimation: false, isHiddenByDefault: false)
    }
    
    public static var emptyDefaultHiddenParams: ArchiveAnimationParams {
        return ArchiveAnimationParams(scrollOffset: .zero, storiesFraction: .zero, expandedHeight: .zero, finalizeAnimation: false, isHiddenByDefault: true)
    }
    
//    public init(scrollOffset: CGFloat, storiesFraction: CGFloat, expandedHeight: CGFloat, finalizeAnimation: Bool, isHiddenByDefault: Bool) {
//
//    }
    
    public func withUpdatedFinalizeAnimation(_ finalizeAnimation: Bool) -> ArchiveAnimationParams {
        var newParams = ArchiveAnimationParams(
            scrollOffset: self.scrollOffset,
            storiesFraction: self.storiesFraction,
            expandedHeight: self.expandedHeight,
            finalizeAnimation: finalizeAnimation,
            isHiddenByDefault: self.isHiddenByDefault
        )
        if finalizeAnimation {
            if newParams.isArchiveGroupVisible {
                newParams.expandedHeight /= 1.2
                newParams.isRevealed = true
            } else {
                newParams = ArchiveAnimationParams(
                    scrollOffset: .zero,
                    storiesFraction: .zero,
                    expandedHeight: .zero,
                    finalizeAnimation: finalizeAnimation,
                    isHiddenByDefault: self.isHiddenByDefault
                )
                newParams.isRevealed = false
            }
        }
        return newParams
    }
    
    public mutating func updateVisibility(isRevealed: Bool? = nil, isHiddenByDefault: Bool? = nil) {
        if let isRevealed {
            self.isRevealed = isRevealed
        }
        if let isHiddenByDefault {
            self.isHiddenByDefault = isHiddenByDefault
        }
    }
    
    var isArchiveGroupVisible: Bool {
        return (storiesFraction >= 0.85 && finalizeAnimation) || !isHiddenByDefault
    }
    
}

class ChatListArchiveTransitionNode: ASDisplayNode {
    let backgroundNode: ASDisplayNode
    let gradientContainerNode: ASDisplayNode
    let gradientImageNode: ASImageNode
    let topShadowNode: ASImageNode
    let bottomShadowNode: ASImageNode
    let titleNode: ASTextNode //centered
    let arrowBackgroundNode: ASDisplayNode //20 with insets 10
    let arrowContainerNode: ASDisplayNode
    let arrowAnimationNode: AnimationNode //20x20
    let arrowImageNode: ASImageNode
    var arrowSwipeDownIcon: UIImage?
    var arrowReleaseBackgroundColor: UIColor?
    var arrowReleaseIcon: UIImage?
    
    var animation: TransitionAnimation
    var presentationData: ChatListPresentationData?
    var hapticFeedback: HapticFeedback?
    
    required override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = .clear
        self.backgroundNode.isLayerBacked = true
        
        self.animation = .init(state: .swipeDownInit, params: .emptyDefaultHiddenParams)
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true

        self.gradientContainerNode = ASDisplayNode()
        self.gradientContainerNode.isLayerBacked = true
        self.gradientImageNode = ASImageNode()
        self.gradientImageNode.isLayerBacked = true

        self.topShadowNode = ASImageNode()
        self.topShadowNode.isLayerBacked = true
        self.topShadowNode.displayWithoutProcessing = true
        self.topShadowNode.alpha = 0.5

        self.bottomShadowNode = ASImageNode()
        self.bottomShadowNode.isLayerBacked = true
        self.bottomShadowNode.displayWithoutProcessing = true
        self.bottomShadowNode.alpha = 0.5
        
        self.arrowBackgroundNode = ASDisplayNode()
        self.arrowBackgroundNode.backgroundColor = .white.withAlphaComponent(0.4)
        self.arrowBackgroundNode.isLayerBacked = true
                
        self.arrowContainerNode = ASDisplayNode()
        self.arrowContainerNode.isLayerBacked = true
        
        self.arrowImageNode = ASImageNode()
        self.arrowImageNode.isLayerBacked = true
        
        self.arrowAnimationNode = AnimationNode(animation: "anim_arrow_to_archive", scale: 0.33)
        self.arrowAnimationNode.backgroundColor = .clear
        self.arrowAnimationNode.isHidden = true
        
        super.init()
        self.addSubnode(self.gradientContainerNode)
        self.gradientContainerNode.addSubnode(self.gradientImageNode)
        self.gradientContainerNode.addSubnode(self.topShadowNode)
        self.gradientContainerNode.addSubnode(self.bottomShadowNode)
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.titleNode)
        self.backgroundNode.addSubnode(self.arrowBackgroundNode)
        self.backgroundNode.addSubnode(self.arrowContainerNode)
        self.arrowContainerNode.addSubnode(self.arrowImageNode)
        self.addSubnode(self.arrowAnimationNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.arrowBackgroundNode.layer.cornerRadius = 11
        self.arrowBackgroundNode.layer.masksToBounds = true
    }
    
    override func layout() {
        super.layout()
        guard let theme = presentationData?.theme else { return }
        print("bounds: \(self.bounds)")
        let gradientImageSize = self.bounds.size
        let greyColors = theme.chatList.unpinnedArchiveAvatarColor.backgroundColors.colors
        if self.gradientImageNode.image == nil {
            let greyGradientImage = generateGradientImage(size: gradientImageSize, colors: [greyColors.0, greyColors.1], locations: [1.0, 0.0], direction: .horizontal)
            self.gradientImageNode.image = greyGradientImage
        }
        
        let blueColors = theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
        if self.animation.gradientImage == nil {
            let blueGradientImage = generateGradientImage(size: gradientImageSize, colors: [blueColors.0, blueColors.1], locations: [1.0, 0.0], direction: .horizontal)
            self.animation.gradientImage = blueGradientImage
        }
        
        if self.animation.rotatedGradientImage == nil {
            let blueRotatedGradientImage = generateGradientImage(size: gradientImageSize, colors: [blueColors.1, blueColors.1, blueColors.0, blueColors.0], locations: [1.0, 0.65, 0.15, 0.0], direction: .vertical)
            self.animation.rotatedGradientImage = blueRotatedGradientImage
        }
        
        let greyGradientColorAtFraction = greyColors.0.interpolateTo(greyColors.1, fraction: 40 / gradientImageSize.width)
        if let greyGradientColorAtFraction, self.arrowSwipeDownIcon == nil {
            self.arrowSwipeDownIcon = PresentationResourcesItemList.archiveTransitionArrowIcon(theme, backgroundColor: greyGradientColorAtFraction)
        }

        let blueGradientColorAtFraction = blueColors.0.interpolateTo(blueColors.1, fraction: 40 / gradientImageSize.width)
        if let blueGradientColorAtFraction {
            if self.arrowReleaseIcon == nil {
                self.arrowReleaseIcon = PresentationResourcesItemList.archiveTransitionArrowIcon(theme, backgroundColor: blueGradientColorAtFraction)
            }
            if self.arrowReleaseBackgroundColor == nil {
                arrowAnimationNode.setAnimation(name: "anim_arrow_to_archive", colors: [
                    "Arrow 1.Arrow 1.Stroke 1": blueGradientColorAtFraction,
                    "Arrow 2.Arrow 2.Stroke 1": blueGradientColorAtFraction,
                    "Cap.cap2.Fill 1": .white,
                    "Cap.cap1.Fill 1": .white,
                    "Box.box1.Fill 1": .white
                ])
                self.arrowReleaseBackgroundColor = blueGradientColorAtFraction
            }
        }
        if self.topShadowNode.image == nil {
            let shadowGradient = generateGradientImage(size: CGSize(width: gradientImageSize.width, height: 20), colors: [.black.withAlphaComponent(0.1), .black.withAlphaComponent(0.0)], locations: [0.0, 1.0], direction: .vertical)
            self.topShadowNode.image = shadowGradient
            self.bottomShadowNode.image = shadowGradient
        }
    }
        
    func updateLayout(transition: ContainedViewLayoutTransition, size: CGSize, params: ArchiveAnimationParams, presentationData: ChatListPresentationData, avatarNode: AvatarNode) {
        let frame = CGRect(origin: self.bounds.origin, size: CGSize(width: self.bounds.width, height: self.bounds.height))
        
        guard !(self.animation.params.finalizeAnimation && params.finalizeAnimation) else {
            return
        }
        
        guard self.animation.params != params || self.frame.size != size else { return }
        
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }

        let updateLayers = self.animation.params != params
        
        self.animation.params = params
//        print("params: \(params) \nprevious params: \(self.animation.params) \nsize: \(size) previous size: \(self.frame.size)")
        let previousState = self.animation.state
        self.animation.state = .init(params: params, previousState: previousState)
        self.animation.presentationData = presentationData
        if self.presentationData?.theme != presentationData.theme {
            print("need to update gradients")
        }
        self.presentationData = presentationData
        
//        if updateLayers {
//            transition = .animated(duration: 1.0, curve: .easeInOut)
//        }
        
        transition.updatePosition(node: self.backgroundNode, position: frame.center)
        transition.updateBounds(node: self.backgroundNode, bounds: frame)

        transition.updatePosition(node: self.gradientContainerNode, position: frame.center)
        transition.updateBounds(node: self.gradientContainerNode, bounds: frame)
        
        transition.updatePosition(node: self.gradientImageNode, position: frame.center)
        transition.updateBounds(node: self.gradientImageNode, bounds: frame)

        
        let difference = (frame.height - params.expandedHeight).rounded()

        let topShadowFrame = CGRect(x: .zero, y: difference - 10, width: frame.width, height: 20)
        transition.updatePosition(node: self.topShadowNode, position: topShadowFrame.center, beginWithCurrentState: true)
        transition.updateBounds(node: self.topShadowNode, bounds: topShadowFrame, force: true, beginWithCurrentState: true)
        
        let bottomShadowFrame = CGRect(x: .zero, y: frame.height - 10, width: frame.width, height: 20)
        transition.updateTransformRotation(node: self.bottomShadowNode, angle: TransitionAnimation.degreesToRadians(180))
        transition.updatePosition(node: self.bottomShadowNode, position: bottomShadowFrame.center, beginWithCurrentState: true)
        transition.updateBounds(node: self.bottomShadowNode, bounds: bottomShadowFrame, force: true, beginWithCurrentState: true)

        let arrowBackgroundHeight = max(0, (frame.height - difference - 22))
        let arrowBackgroundFrame = CGRect(x: 29, y: frame.height - arrowBackgroundHeight - 11, width: 22, height: arrowBackgroundHeight)
        let arrowFrame = CGRect(x: arrowBackgroundFrame.minX, y: arrowBackgroundFrame.maxY - 22, width: 22, height: 22)
        if self.arrowBackgroundNode.position == .zero || self.arrowBackgroundNode.bounds.height == .zero {
            self.arrowBackgroundNode.position = arrowBackgroundFrame.center
            self.arrowBackgroundNode.bounds = arrowBackgroundFrame
        }
        
        transition.updatePosition(node: self.arrowBackgroundNode, position: arrowBackgroundFrame.center, beginWithCurrentState: true)
        transition.updateBounds(node: self.arrowBackgroundNode, bounds: arrowBackgroundFrame, force: true, beginWithCurrentState: true)
        
        transition.updatePosition(node: self.arrowContainerNode, position: arrowFrame.center)
        transition.updateBounds(node: self.arrowContainerNode, bounds: arrowFrame)
        switch self.animation.state {
        case .swipeDownInit, .swipeDownAppear, .swipeDownDidAppear:
            self.arrowImageNode.image = self.arrowSwipeDownIcon
        case .releaseDidAppear, .releaseAppear:
            self.arrowImageNode.image = self.arrowReleaseIcon
        }
        transition.updatePosition(node: self.arrowImageNode, position: arrowFrame.center)
        transition.updateBounds(node: self.arrowImageNode, bounds: arrowFrame)
        
        if let size = self.arrowAnimationNode.preferredSize(), !params.finalizeAnimation {
            let arrowAnimationFrame = CGRect(x: arrowFrame.midX - size.width / 2, y: arrowFrame.midY - size.height / 2, width: size.width, height: size.height)
            transition.updatePosition(node: arrowAnimationNode, position: arrowAnimationFrame.center)
            transition.updateBounds(node: arrowAnimationNode, bounds: arrowAnimationFrame)
        }

        if self.titleNode.attributedText == nil {
            self.titleNode.attributedText = NSAttributedString(string: "Swipe down for archive", attributes: [
                .foregroundColor: UIColor.white,
                .font: Font.medium(floor(presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            ])
        }
        
        if updateLayers {
            let nodesToHide: [ASDisplayNode] = [self.gradientImageNode, self.backgroundNode]
            nodesToHide.filter({ $0.isHidden }).forEach({ $0.isHidden = false })

            if animation.state == .releaseAppear {
                self.hapticFeedback?.impact(.medium)
            } else if animation.state == .swipeDownAppear && previousState == .releaseDidAppear {
                self.hapticFeedback?.impact(.medium)
            }
            
            self.animation.animateLayers(gradientNode: self.gradientContainerNode,
                                         textNode: self.titleNode,
                                         arrowContainerNode: self.arrowContainerNode,
                                         arrowAnimationNode: self.arrowAnimationNode,
                                         avatarNode: avatarNode,
                                         transition: transition, finalizeCompletion: { [weak self] isFinished in
                guard let self else { return }
                if !isFinished {
                    self.hapticFeedback?.impact(.medium)
                    nodesToHide.forEach({ $0.isHidden = true })
                }
            })
        }
    }
    
    
    
    struct TransitionAnimation {
        enum TextPosition {
            case centered
            case left
            case right
        }
        
        enum State: Int {
            case swipeDownInit
            case releaseAppear
            case releaseDidAppear
            case swipeDownAppear
            case swipeDownDidAppear
            
            init(params: ArchiveAnimationParams, previousState: TransitionAnimation.State) {
                let fraction = params.storiesFraction
                if params.storiesFraction < 0.85 {
                    switch previousState {
                    case .swipeDownAppear, .swipeDownInit, .swipeDownDidAppear:
                        self = .swipeDownDidAppear
                    default:
                        self = .swipeDownAppear
                    }
                } else if fraction >= 0.85 && fraction <= 1.0 {
                    switch previousState {
                    case .releaseAppear, .releaseDidAppear:
                        self = .releaseDidAppear
                    default:
                        self = .releaseAppear
                    }
                } else {
                    self = .swipeDownInit
                }
            }
            
            func animationProgress(fraction: CGFloat) -> CGFloat {
                switch self {
                case .swipeDownAppear:
                    return max(0.01, min(0.99, fraction / 0.85))
                case .releaseAppear:
                    return max(0.01, min(0.99, (fraction - 0.85) / 0.15))
                default:
                    return 1.0
                }
            }
        }
        
        var state: State
        var params: ArchiveAnimationParams
        var presentationData: ChatListPresentationData?
        
        var isAnimated = false
        var gradientMaskLayer: CAShapeLayer?
        var gradientLayer: CALayer?
        var releaseTextNode: ASTextNode?
        
        var gradientImage: UIImage? {
            didSet {
                if let gradientLayer,
                    gradientLayer.contents == nil {
                    gradientLayer.contents = self.gradientImage
                }
            }
        }
        var rotatedGradientImage: UIImage?
        
        static func degreesToRadians(_ x: CGFloat) -> CGFloat {
            return .pi * x / 180.0
        }
        
        static func distance(from: CGPoint, to point: CGPoint) -> CGFloat {
            return sqrt(pow((point.x - from.x), 2) + pow((point.y - from.y), 2))
        }
        
        mutating func animateLayers(
            gradientNode: ASDisplayNode,
            textNode: ASTextNode,
            arrowContainerNode: ASDisplayNode,
            arrowAnimationNode: AnimationNode,
            avatarNode: AvatarNode,
            transition: ContainedViewLayoutTransition,
            finalizeCompletion: ((Bool) -> Void)?
        ) {
            print("""
            animate layers with fraction: \(self.params.storiesFraction) animation progress: \(self.state.animationProgress(fraction: self.params.storiesFraction))
            state: \(self.state), offset: \(self.params.scrollOffset) height: \(self.params.expandedHeight)
            ##
            """)
            
            if !arrowAnimationNode.isHidden, state != .releaseDidAppear {
                arrowAnimationNode.isHidden = true
            }
            
            switch state {
            case .releaseAppear:
                updateReleaseTextNode(from: textNode)
                makeGradientOverlay(gradientContainerNode: gradientNode, arrowContainerNode: arrowContainerNode)
//                let animationProgress = self.state.animationProgress(fraction: self.params.storiesFraction)
                
                if let releaseTextNode { transition.updateAlpha(node: releaseTextNode, alpha: 1.0) }
                self.animateTextNodePositionIfNeeded(textNode: releaseTextNode, targetTextPosition: .centered, transition: transition, needShake: true)
                
                if let gradientMaskLayer, let gradientLayer {
                    transition.updateAlpha(layer: gradientLayer, alpha: 1.0)
                    let targetPath = generateGradientMaskPath(gradientContainerNode: gradientNode, arrowContainerNode: arrowContainerNode, fraction: 1.0)
                    transition.updatePath(layer: gradientMaskLayer, path: targetPath.cgPath)
                }
                
                transition.updateTransformRotation(node: arrowContainerNode, angle: TransitionAnimation.degreesToRadians(-180))
                transition.updateTransformRotation(node: arrowContainerNode, angle: TransitionAnimation.degreesToRadians(180))
                self.animateTextNodePositionIfNeeded(textNode: textNode, targetTextPosition: .right, transition: transition)
                transition.updateAlpha(node: textNode, alpha: .zero)
            case .releaseDidAppear:
                if params.finalizeAnimation, gradientLayer?.superlayer != nil {
                    print("should finalize animation")
                    //duration = 0.5
                    //show animation arrow node
                    //play animation arrow to archive
                    //update gradient mask path to avatar node frame
                    //scale up then scale down avatar node gradient
                    finalizeCompletion?(false)
                    arrowAnimationNode.isHidden = false
                    
                    let avatarNodeFrame = gradientNode.convert(avatarNode.contentNode.layer.frame, from: avatarNode.contentNode)
                    let avatarContentTranform = avatarNode.contentNode.layer.affineTransform()
                    
                    arrowAnimationNode.completion = { //[weak gradientLayer] in
                        print("arrow animation node finish animation")
//                        guard let gradientLayer else { return }
                    }
                    
                    avatarNode.transform = CATransform3DMakeAffineTransform(avatarContentTranform)
                    
                    transition.updatePosition(node: arrowAnimationNode, position: avatarNodeFrame.center)
                    transition.updateTransform(node: arrowAnimationNode, transform: avatarContentTranform, beginWithCurrentState: true) { _ in
                        transition.updateTransform(node: arrowAnimationNode, transform: avatarContentTranform.scaledBy(x: 1.0, y: 0.9)) { finished in
                            guard finished else { return }
                            transition.updateTransform(node: arrowAnimationNode, transform: avatarContentTranform.scaledBy(x: 0.9, y: 1.0)) { finished in
                                guard finished else { return }
                                transition.updateTransform(node: arrowAnimationNode, transform: avatarContentTranform) { _ in
                                    arrowAnimationNode.isHidden = true
                                    arrowAnimationNode.reset()
                                    finalizeCompletion?(true)
                                }
                            }
                        }
                    }
                    arrowAnimationNode.play()
                    
                    
                    if let gradientMaskLayer, let gradientLayer {
                        gradientLayer.contents = rotatedGradientImage?.cgImage
                        let targetPath = UIBezierPath(roundedRect: avatarNodeFrame, cornerRadius: avatarNodeFrame.width / 2)
                        let scaledInset = avatarNodeFrame.width - avatarNodeFrame.width * 0.83
                        let scaledAvatarNodeFrame = avatarNodeFrame.insetBy(dx: scaledInset, dy: scaledInset)//.applying(CGAffineTransform(scaleX: 0.83, y: 0.83))
                        
                        let scaledTargetPath = UIBezierPath(roundedRect: scaledAvatarNodeFrame, cornerRadius: scaledAvatarNodeFrame.width / 2)
                        transition.updatePath(layer: gradientMaskLayer, path: scaledTargetPath.cgPath) { _ in
                            transition.updatePath(layer: gradientMaskLayer, path: targetPath.cgPath)
                            transition.updateTransform(node: avatarNode, transform: .identity) { _ in
                                transition.updateAlpha(layer: gradientLayer, alpha: .zero) { _ in
                                    gradientLayer.removeFromSuperlayer()
                                    gradientLayer.opacity = 1.0
                                    gradientLayer.contents = nil
                                }
                            }
                        }
                    }
                    print("avatar node frame: \(avatarNode.convert(avatarNode.frame, to: gradientNode))")
                } else {
                    self.animateTextNodePositionIfNeeded(textNode: releaseTextNode, targetTextPosition: .centered, transition: transition)
                }
            case .swipeDownAppear, .swipeDownInit:
//                let animationProgress: CGFloat = 0.0
                
                transition.updateTransform(node: arrowContainerNode, transform: .identity)
                transition.updateAlpha(node: textNode, alpha: 1.0)
                
                animateTextNodePositionIfNeeded(textNode: textNode, targetTextPosition: .centered, transition: transition, needShake: true)
                self.animateTextNodePositionIfNeeded(textNode: releaseTextNode, targetTextPosition: .left, transition: transition)
                
                if let releaseTextNode { transition.updateAlpha(node: releaseTextNode, alpha: .zero) }
                
                if let gradientMaskLayer, let gradientLayer {
                    let targetPath = generateGradientMaskPath(gradientContainerNode: gradientNode, arrowContainerNode: arrowContainerNode, fraction: 0.02)
                    transition.updatePath(layer: gradientMaskLayer, path: targetPath.cgPath)
                    transition.updateAlpha(layer: gradientLayer, alpha: 0.6)
                }
            case .swipeDownDidAppear:
                if !params.finalizeAnimation {
                    updateReleaseTextNode(from: textNode)
                    makeGradientOverlay(gradientContainerNode: gradientNode, arrowContainerNode: arrowContainerNode)
                    self.animateTextNodePositionIfNeeded(textNode: textNode, targetTextPosition: .centered, transition: transition)
                }
            }
            self.isAnimated = true
        }
        
        private func animateTextNodePositionIfNeeded(textNode: ASTextNode?, targetTextPosition: TextPosition, transition: ContainedViewLayoutTransition, needShake: Bool = false) {
            guard let textNode, let supernode = textNode.supernode else { return }
            
            let textLayout = textNode.calculateLayoutThatFits(ASSizeRange(
                min: .zero,
                max: CGSize(width: supernode.bounds.width - 120, height: 25)
            ))
            
            let targetX: CGFloat
            switch targetTextPosition {
            case .centered:
                targetX = (supernode.bounds.width - textLayout.size.width) / 2
            case .left:
                targetX = -textLayout.size.width
            case .right:
                targetX = supernode.bounds.width
            }
            
            let targetFrame = CGRect(
                x: targetX,
                y: supernode.bounds.height - textLayout.size.height - 10,
                width: textLayout.size.width,
                height: textLayout.size.height
            )
            
            let positionDifference = textNode.position.x - targetFrame.center.x
            
            guard textNode.position != targetFrame.center || textNode.bounds != targetFrame else { return }
            
            transition.updateBounds(node: textNode, bounds: targetFrame, beginWithCurrentState: true)
            transition.updatePosition(node: textNode, position: targetFrame.center, beginWithCurrentState: true)

            if needShake {
                transition.updateTransform(node: textNode, transform: .init(translationX: positionDifference < 0 ? 10 : -10, y: .zero)) { _ in
                    transition.updateTransform(node: textNode, transform: .identity)
                }
            }
        }
    }
}
    
extension ChatListArchiveTransitionNode.TransitionAnimation {
    
    private mutating func updateReleaseTextNode(from textNode: ASTextNode) {
        if self.releaseTextNode == nil {
            self.releaseTextNode = ASTextNode()
            self.releaseTextNode?.isLayerBacked = true
            guard let supernode = textNode.supernode, let releaseTextNode else { return }
            
            let attributes: [NSAttributedString.Key: Any] = textNode.attributedText?.attributes(at: 0, effectiveRange: nil) ?? [:]
            releaseTextNode.attributedText = NSAttributedString(string: "Release for archive", attributes: attributes)

            let textLayout = textNode.calculateLayoutThatFits(ASSizeRange(
                min: .zero,
                max: CGSize(width: supernode.bounds.width - 120, height: 25)
            ))
            
            releaseTextNode.frame = CGRect(
                x: -textLayout.size.width,
                y: supernode.bounds.height - textLayout.size.height - 10,
                width: textLayout.size.width,
                height: textLayout.size.height
            )
            releaseTextNode.alpha = 0.0

            supernode.addSubnode(self.releaseTextNode!)
        }
    }
    
    mutating internal func makeGradientOverlay(gradientContainerNode: ASDisplayNode, arrowContainerNode: ASDisplayNode) {
        if self.gradientLayer == nil {
            self.gradientLayer = CALayer()
            self.gradientLayer?.contentsGravity = .resizeAspect
            self.gradientLayer?.contentsScale = 3.0
        }
        
        if self.gradientMaskLayer == nil {
            self.gradientMaskLayer = CAShapeLayer()
        }
        
        guard let gradientLayer, let gradientMaskLayer else { return }
        
        if gradientLayer.superlayer == nil {
            gradientContainerNode.layer.addSublayer(gradientLayer)
        }
        
        if gradientMaskLayer.frame != gradientContainerNode.bounds {
            gradientMaskLayer.frame = gradientContainerNode.bounds
            gradientMaskLayer.path = generateGradientMaskPath(gradientContainerNode: gradientContainerNode, arrowContainerNode: arrowContainerNode, fraction: 0.02).cgPath
        }
        
        if gradientLayer.frame != gradientContainerNode.bounds {
            gradientLayer.frame = gradientContainerNode.bounds
            gradientLayer.opacity = 0.6
        }
        
        if gradientLayer.mask == nil {
            gradientLayer.mask = gradientMaskLayer
        }
        
        gradientLayer.contents = self.gradientImage?.cgImage
    }
    
    internal func generateGradientMaskPath(gradientContainerNode: ASDisplayNode, arrowContainerNode: ASDisplayNode, fraction: CGFloat) -> UIBezierPath {
        let startRect = arrowContainerNode.convert(arrowContainerNode.bounds, to: gradientContainerNode)
        let startRadius = startRect.width / 2
        
        let finalScale = gradientContainerNode.bounds.width/startRect.width + gradientContainerNode.bounds.width/startRect.width*(gradientContainerNode.bounds.width - startRect.midX)/gradientContainerNode.bounds.width
        let scale: CGFloat = (finalScale * fraction)//max(1.0, (finalScale * fraction))
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        var transformedRect = startRect.applying(scaleTransform)
        let translation = CGPoint(x: startRect.center.x - transformedRect.center.x, y: startRect.center.y - transformedRect.center.y)
        let translateTransform = CGAffineTransform(translationX: translation.x, y: translation.y)
        let scaledRadius = startRadius * scale
        transformedRect = transformedRect.applying(translateTransform)
        
        let path = UIBezierPath(roundedRect: transformedRect, cornerRadius: scaledRadius)
        return path
    }
}
