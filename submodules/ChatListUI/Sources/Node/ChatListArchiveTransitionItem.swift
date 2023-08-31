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
    public let finalizeAnimation: Bool
    
    public static var empty: ArchiveAnimationParams {
        return ArchiveAnimationParams(scrollOffset: .zero, storiesFraction: .zero, expandedHeight: .zero, finalizeAnimation: false)
    }
    
    public func withUpdatedFinalizeAnimation(_ finalizeAnimation: Bool) -> ArchiveAnimationParams {
        var newParams = ArchiveAnimationParams(
            scrollOffset: self.scrollOffset,
            storiesFraction: self.storiesFraction,
            expandedHeight: self.expandedHeight,
            finalizeAnimation: finalizeAnimation
        )
        if finalizeAnimation {
            if newParams.isArchiveGroupVisible {
                newParams.expandedHeight /= 1.2
            } else {
                newParams = ArchiveAnimationParams(scrollOffset: .zero, storiesFraction: .zero, expandedHeight: .zero, finalizeAnimation: finalizeAnimation)
            }
        }
        return newParams
    }
    
    var isArchiveGroupVisible: Bool {
        return storiesFraction >= 0.8 && finalizeAnimation
    }
    
}

class ChatListArchiveTransitionNode: ASDisplayNode {
    let backgroundNode: ASDisplayNode
    let gradientContainerNode: ASDisplayNode
    let gradientImageNode: ASImageNode
//    let topShadowNode: ASImageNode
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
        
        self.animation = .init(state: .swipeDownInit, params: .empty)
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true

        self.gradientContainerNode = ASDisplayNode()
        self.gradientContainerNode.isLayerBacked = true
        self.gradientImageNode = ASImageNode()
        self.gradientImageNode.isLayerBacked = true

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
//            let blueRotatedGradientImage = generateGradientFilledCircleImage(diameter: 60, colors: [blueColors.1.cgColor, blueColors.0.cgColor])
            let blueRotatedGradientImage = generateGradientImage(size: gradientImageSize, colors: [blueColors.1, blueColors.1, blueColors.0, blueColors.0], locations: [1.0, 0.65, 0.25, 0.05], direction: .vertical)
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
    }
        
    func updateLayout(transition: ContainedViewLayoutTransition, size: CGSize, params: ArchiveAnimationParams, presentationData: ChatListPresentationData, avatarNode: AvatarNode) {
        let frame = CGRect(origin: self.bounds.origin, size: CGSize(width: self.bounds.width, height: self.bounds.height))
//        var transition = transition
        
        
        guard !(self.animation.params.finalizeAnimation && params.finalizeAnimation) else {
            return
        }
        guard self.animation.params != params || self.frame.size != size else { return }
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
        
        if params.expandedHeight >= 22 {
            let difference = (frame.height - params.expandedHeight).rounded()
            let arrowBackgroundHeight = frame.height - difference - 22
            let arrowBackgroundFrame = CGRect(x: 29, y: frame.height - arrowBackgroundHeight - 11, width: 22, height: arrowBackgroundHeight)
            let arrowFrame = CGRect(x: arrowBackgroundFrame.minX, y: arrowBackgroundFrame.maxY - 22, width: 22, height: 22)
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
        }
        
        if self.titleNode.attributedText == nil {
            self.titleNode.attributedText = NSAttributedString(string: "Swipe down for archive", attributes: [
                .foregroundColor: UIColor.white,
                .font: Font.medium(floor(presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            ])
        }
        
        if updateLayers {
            self.animation.animateLayers(gradientNode: self.gradientContainerNode,
                                         textNode: self.titleNode,
                                         arrowContainerNode: self.arrowContainerNode,
                                         arrowAnimationNode: self.arrowAnimationNode,
                                         avatarNode: avatarNode,
                                         transition: transition, finalizeCompletion: { [weak self] isFinished in
                guard let self else { return }
                if !isFinished {
                    if self.hapticFeedback == nil {
                        self.hapticFeedback = HapticFeedback()
                    }
                    self.hapticFeedback?.impact(.medium)
                }
                print("finalize compeltion: \(isFinished)")
            })

            let nodesToHide: [ASDisplayNode] = [self.gradientImageNode, self.backgroundNode]

            if self.animation.state == .releaseDidAppear && params.finalizeAnimation {
                nodesToHide.forEach({ $0.isHidden = true })
            } else {
                nodesToHide.forEach({ $0.isHidden = false })
            }
        }
    }
    
    
    
    struct TransitionAnimation {
        enum Direction {
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
                if params.storiesFraction < 0.8 {
                    switch previousState {
                    case .swipeDownAppear, .swipeDownInit, .swipeDownDidAppear:
                        self = .swipeDownDidAppear
                    default:
                        self = .swipeDownAppear
                    }
                } else if fraction >= 0.8 && fraction <= 1.0 {
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
                    return max(0.01, min(0.99, fraction / 0.8))
                case .releaseAppear:
                    return max(0.01, min(0.99, (fraction - 0.8) / 0.3))
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

                let animationProgress = 1.0//self.state.animationProgress(fraction: self.params.storiesFraction)
                
//                let rotationDegree = TransitionAnimation.degreesToRadians(CGFloat(0).interpolate(to: CGFloat(-180), amount: animationProgress))
                transition.updateTransformRotation(node: arrowContainerNode, angle: TransitionAnimation.degreesToRadians(-180))
                transition.updateTransformRotation(node: arrowContainerNode, angle: TransitionAnimation.degreesToRadians(180))
                
                if let releaseTextNode, let supernode = releaseTextNode.supernode {
                    let textLayout = textNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: supernode.bounds.width - 120, height: 25)))
                    let titleFrame = CGRect(x: supernode.bounds.width + textLayout.size.width/2,
                                            y: supernode.bounds.height - textLayout.size.height - 10,
                                            width: textLayout.size.width,
                                            height: textLayout.size.height)

                    let releaseTextLayout = releaseTextNode
                        .calculateLayoutThatFits(ASSizeRange(
                            min: .zero,
                            max: CGSize(width: supernode.bounds.width - 120, height: 25)
                        ))
                    let releaseNodeFrame = CGRect(
                        x: (supernode.bounds.width - releaseTextLayout.size.width) / 2,
                        y: supernode.bounds.height - releaseTextLayout.size.height - 10,
                        width: releaseTextLayout.size.width,
                        height: releaseTextLayout.size.height
                    )

                    transition.updatePosition(node: releaseTextNode, position: releaseNodeFrame.center)
                    transition.updateBounds(node: releaseTextNode, bounds: releaseNodeFrame)
                    
                    transition.updatePosition(node: textNode, position: titleFrame.center)
                    transition.updateBounds(node: textNode, bounds: titleFrame)
                }
                                
                if let gradientMaskLayer {
                    let targetPath = generateGradientMaskPath(gradientContainerNode: gradientNode, arrowContainerNode: arrowContainerNode, fraction: animationProgress)
                    transition.updatePath(layer: gradientMaskLayer, path: targetPath.cgPath)
                }
                
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
                    let newPosition = CGPoint(x: arrowAnimationNode.position.x, y: gradientNode.position.y)
                    transition.updatePosition(node: arrowAnimationNode, position: newPosition)
                    
                    let avatarNodeFrame = gradientNode.convert(avatarNode.contentNode.layer.frame, from: avatarNode.contentNode)
//                    avatarNodeFrame = avatarNode.supernode?.convert(avatarNodeFrame, to: gradientNode) ?? avatarNodeFrame
                    if let gradientMaskLayer, let gradientLayer {
                        let targetPath = UIBezierPath(roundedRect: avatarNodeFrame, cornerRadius: avatarNodeFrame.width / 2).cgPath
                        transition.updatePath(layer: gradientMaskLayer, path: targetPath)
                        
                        gradientLayer.contents = rotatedGradientImage?.cgImage
                    }
                    print("avatar node frame: \(avatarNode.convert(avatarNode.frame, to: gradientNode))")

                    arrowAnimationNode.completion = { [weak arrowAnimationNode, weak gradientLayer] in
                        print("arrow animation node finish animation")
                        arrowAnimationNode?.isHidden = true
                        gradientLayer?.removeFromSuperlayer()
                        finalizeCompletion?(true)
                    }

                    arrowAnimationNode.play()
                } else {
                    if let releaseTextNode, let supernode = releaseTextNode.supernode {
                        let releaseTextLayout = releaseTextNode
                            .calculateLayoutThatFits(ASSizeRange(
                                min: .zero,
                                max: CGSize(width: supernode.bounds.width - 120, height: 25)
                            ))
                        let releaseNodeFrame = CGRect(
                            x: (supernode.bounds.width - releaseTextLayout.size.width) / 2,
                            y: supernode.bounds.height - releaseTextLayout.size.height - 10,
                            width: releaseTextLayout.size.width,
                            height: releaseTextLayout.size.height
                        )
                        
                        print("release node frame: \(releaseNodeFrame)")

                        transition.updatePosition(node: releaseTextNode, position: releaseNodeFrame.center, beginWithCurrentState: true)
                        transition.updateBounds(node: releaseTextNode, bounds: releaseNodeFrame, beginWithCurrentState: true)
                    }
                }
            case .swipeDownAppear, .swipeDownInit:
                let animationProgress: CGFloat = 0.0
                
                transition.updateTransform(node: arrowContainerNode, transform: .identity)
                
                if let releaseTextNode, let supernode = releaseTextNode.supernode {
                    let releaseTextLayout = releaseTextNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 20, height: .zero),
                                                                                                max: CGSize(width: supernode.bounds.width - 120, height: 25)))
                    let releaseNodeFrame = CGRect(x: -releaseTextLayout.size.width,
                                                  y: supernode.bounds.height - releaseTextLayout.size.height - 8,
                                                  width: releaseTextLayout.size.width,
                                                  height: releaseTextLayout.size.height)

                    
//                    let targetPosition = supernode.bounds.center.offsetBy(dx: -supernode.bounds.width, dy: .zero).interpolate(to: supernode.bounds.center, amount: animationProgress)
                    transition.updatePosition(node: releaseTextNode, position: releaseNodeFrame.center)
                    transition.updateBounds(node: releaseTextNode, bounds: releaseNodeFrame)

                    let textLayout = textNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 20, height: .zero), max: CGSize(width: supernode.bounds.width - 120, height: 25)))
                    let titleFrame = CGRect(x: (supernode.bounds.width - textLayout.size.width)/2,
                                            y: supernode.bounds.height - textLayout.size.height - 10,
                                            width: textLayout.size.width,
                                            height: textLayout.size.height)

                    print("title frame: \(titleFrame) release node frame: \(releaseNodeFrame)")
//                    let textNodeTargetPosition = textNode.position.interpolate(to: textNode.position.offsetBy(dx: supernode.bounds.width, dy: .zero), amount: animationProgress)
                    transition.updatePosition(node: textNode, position: titleFrame.center)
                    transition.updateBounds(node: textNode, bounds: titleFrame)
                }
                                
                if let gradientMaskLayer {
                    let targetPath = generateGradientMaskPath(gradientContainerNode: gradientNode, arrowContainerNode: arrowContainerNode, fraction: animationProgress)
                    transition.updatePath(layer: gradientMaskLayer, path: targetPath.cgPath)
                }
            case .swipeDownDidAppear:
                if params.finalizeAnimation {
                    print("should finalize animation")
                    //duration = 0.5
                    //show animation arrow node
                    //play animation arrow to archive
                    //update gradient mask path to avatar node frame
                    //scale up then scale down avatar node gradient
                } else {
                    if let supernode = textNode.supernode {
                        let textLayout = textNode.calculateLayoutThatFits(ASSizeRange(min: .zero, max: CGSize(width: supernode.bounds.width - 120, height: 25)))
                        let titleFrame = CGRect(x: (supernode.bounds.width - textLayout.size.width)/2,
                                                y: supernode.bounds.height - textLayout.size.height - 10,
                                                width: textLayout.size.width,
                                                height: textLayout.size.height)

                        print("title frame: \(titleFrame)")
    //                    let textNodeTargetPosition = textNode.position.interpolate(to: textNode.position.offsetBy(dx: supernode.bounds.width, dy: .zero), amount: animationProgress)
                        transition.updatePosition(node: textNode, position: titleFrame.center, beginWithCurrentState: true)
                        transition.updateBounds(node: textNode, bounds: titleFrame, beginWithCurrentState: true)
                    }
                }
            }
            self.isAnimated = true
        }
    }
}
    
extension ChatListArchiveTransitionNode.TransitionAnimation {
    
    private mutating func updateReleaseTextNode(from textNode: ASTextNode) {
        if self.releaseTextNode == nil {
            self.releaseTextNode = ASTextNode()
            self.releaseTextNode?.isLayerBacked = true
            let attributes: [NSAttributedString.Key: Any] = textNode.attributedText?.attributes(at: 0, effectiveRange: nil) ?? [:]
            self.releaseTextNode?.attributedText = NSAttributedString(string: "Release for archive", attributes: attributes)
            guard let supernode = textNode.supernode else { return }
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
            gradientMaskLayer.path = generateGradientMaskPath(gradientContainerNode: gradientContainerNode, arrowContainerNode: arrowContainerNode, fraction: 0).cgPath
        }
        
        if gradientLayer.frame != gradientContainerNode.bounds {
            gradientLayer.frame = gradientContainerNode.bounds
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
