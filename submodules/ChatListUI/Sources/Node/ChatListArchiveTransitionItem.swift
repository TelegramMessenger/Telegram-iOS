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
    public let expandedHeight: CGFloat
    public let finalizeAnimation: Bool
    
    public static var empty: ArchiveAnimationParams{
        return ArchiveAnimationParams(scrollOffset: .zero, storiesFraction: .zero, expandedHeight: .zero, finalizeAnimation: false)
    }
}

class ChatListArchiveTransitionNode: ASDisplayNode {
    let backgroundNode: ASDisplayNode
    let gradientContainerNode: ASDisplayNode
    let gradientImageNode: ASImageNode
    let titleNode: ASTextNode //centered
    let arrowBackgroundNode: ASDisplayNode //20 with insets 10
    let arrowContainerNode: ASDisplayNode
    let arrowAnimationNode: AnimationNode //20x20
    let arrowImageNode: ASImageNode
    var animation: TransitionAnimation
    var presentationData: ChatListPresentationData?
    
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
        self.arrowBackgroundNode.addSubnode(self.arrowContainerNode)
        self.arrowContainerNode.addSubnode(self.arrowImageNode)
        self.addSubnode(self.arrowAnimationNode)
    }
    
    override func didLoad() {
        super.didLoad()
    }
        
    func updateLayout(transition: ContainedViewLayoutTransition, size: CGSize, params: ArchiveAnimationParams, presentationData: ChatListPresentationData, avatarNode: AvatarNode) {
        let frame = CGRect(origin: self.bounds.origin, size: CGSize(width: self.bounds.width, height: self.bounds.height))
//        var transition = transition
        
//        guard self.animation.params != params || self.frame.size != size else { return }
        let updateLayers = self.animation.params != params
        
        self.animation.params = params
//        print("params: \(params) \nprevious params: \(self.animation.params) \nsize: \(size) previous size: \(self.frame.size)")
        let previousState = self.animation.state
        self.animation.state = .init(params: params, previousState: previousState)
        self.animation.presentationData = presentationData
        self.presentationData = presentationData
        
//        if updateLayers {
//            transition = .animated(duration: 1.0, curve: .easeInOut)
//        }
        
        if self.gradientImageNode.image == nil || self.gradientImageNode.image?.size.width != size.width {
            let gradientImageSize = CGSize(width: size.width, height: 76.0)
            let gradientColors: [UIColor] = [UIColor(hexString: "#A9AFB7")!, UIColor(hexString: "#D3D4DA")!]
            self.gradientImageNode.image = generateGradientImage(
                size: gradientImageSize,
                colors: gradientColors,
                locations: [0.0, 0.1],
                direction: .horizontal
            )
        }
        
        transition.updatePosition(node: self.backgroundNode, position: frame.center)
        transition.updateBounds(node: self.backgroundNode, bounds: frame)

        transition.updatePosition(node: self.gradientContainerNode, position: frame.center)
        transition.updateBounds(node: self.gradientContainerNode, bounds: frame)
        
        transition.updatePosition(node: self.gradientImageNode, position: frame.center)
        transition.updateBounds(node: self.gradientImageNode, bounds: frame)
        
        if params.expandedHeight >= 20 {
            let yOffset = size.height - params.expandedHeight
            let arrowBackgroundFrame = CGRect(x: 29, y: yOffset + 10, width: 20, height: params.expandedHeight - 20)
            let arrowFrame = CGRect(x: arrowBackgroundFrame.minX, y: arrowBackgroundFrame.maxY - 20, width: 20, height: 20)
            transition.updatePosition(node: self.arrowBackgroundNode, position: arrowBackgroundFrame.center)
            transition.updateBounds(node: self.arrowBackgroundNode, bounds: arrowBackgroundFrame)
            transition.updateCornerRadius(node: self.arrowBackgroundNode, cornerRadius: 10)
            transition.updatePosition(node: self.arrowContainerNode, position: arrowFrame.center)
            transition.updateBounds(node: self.arrowContainerNode, bounds: arrowFrame)
            switch self.animation.state {
            case .swipeDownInit, .swipeDownAppear, .swipeDownDidAppear:
                guard previousState == .releaseAppear || previousState == .releaseDidAppear || self.arrowImageNode.image == nil else { return }
                let gradientColorAtFraction = UIColor(hexString: "#A9AFB7")!.interpolateTo(UIColor(hexString: "#D3D4DA")!, fraction: arrowFrame.midX / frame.size.width)
                if let gradientColorAtFraction {
                    print("arrowImageNode set color: \(gradientColorAtFraction.hexString)")
                    self.arrowImageNode.image = PresentationResourcesItemList.archiveTransitionArrowIcon(presentationData.theme, backgroundColor: gradientColorAtFraction)
                }
            case .releaseDidAppear, .releaseAppear:
                guard previousState == .swipeDownInit || previousState == .swipeDownAppear || previousState == .swipeDownDidAppear || self.arrowImageNode.image == nil else { return }
                let backgrpundColors = presentationData.theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
                let gradientColorAtFraction = backgrpundColors.1.interpolateTo(backgrpundColors.0, fraction: arrowFrame.midX / frame.size.width)
                if let gradientColorAtFraction {
                    print("arrowImageNode set color: \(gradientColorAtFraction.hexString)")
                    self.arrowImageNode.image = PresentationResourcesItemList.archiveTransitionArrowIcon(presentationData.theme, backgroundColor: gradientColorAtFraction)
                }
            }
//            self.arrowImageNode.layer.cornerRadius = arrowFrame.width / 2
//            self.arrowImageNode.layer.masksToBounds = true
            transition.updatePosition(node: self.arrowImageNode, position: arrowFrame.center)
            transition.updateBounds(node: self.arrowImageNode, bounds: arrowFrame)
            
            if let size = self.arrowAnimationNode.preferredSize(), !params.finalizeAnimation {
                let arrowAnimationFrame = CGRect(x: arrowFrame.midX - size.width / 2, y: arrowFrame.midY - size.height / 2, width: size.width, height: size.height)
                let arrowCenterFraction = arrowAnimationFrame.midX / frame.size.width
                let backgrpundColors = presentationData.theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
                let gradientColorAtFraction = backgrpundColors.1.interpolateTo(backgrpundColors.0, fraction: arrowCenterFraction)
                if let gradientColorAtFraction, arrowAnimationNode.position != arrowAnimationFrame.center {
                    print("animation node set color: \(gradientColorAtFraction.hexString)")
                    arrowAnimationNode.setAnimation(name: "anim_arrow_to_archive", colors: [
                        "Arrow 1.Arrow 1.Stroke 1": gradientColorAtFraction,
                        "Arrow 2.Arrow 2.Stroke 1": gradientColorAtFraction,
                        "Cap.cap2.Fill 1": .white,
                        "Cap.cap1.Fill 1": .white,
                        "Box.box1.Fill 1": .white
                    ])
                }
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
                                         transition: transition)

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
        
        lazy var gradientImage: UIImage? = {
            guard let presentationData, let gradientLayer, gradientLayer.frame.size.height > 0, self.params.storiesFraction > 0 else { return nil }
            let size = gradientLayer.frame.size
            let backgroundColors = presentationData.theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
            let gradientColors = [backgroundColors.0, backgroundColors.1]
            return generateGradientImage(size: size,
                                         colors: gradientColors,
                                         locations: [1.0, 0.0], direction: .horizontal)
        }()
        
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
            transition: ContainedViewLayoutTransition
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

                    let releaseTextLayout = releaseTextNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: supernode.bounds.width - 120, height: 25)))
                    let releaseNodeFrame = CGRect(x: (supernode.bounds.width - releaseTextLayout.size.width) / 2, y: supernode.bounds.height - releaseTextLayout.size.height - 8, width: releaseTextLayout.size.width, height: releaseTextLayout.size.height)

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
                if params.finalizeAnimation {
                    print("should finalize animation")
                    //duration = 0.5
                    //show animation arrow node
                    //play animation arrow to archive
                    //update gradient mask path to avatar node frame
                    //scale up then scale down avatar node gradient
                    arrowAnimationNode.isHidden = false
                    let newPosition = CGPoint(x: arrowAnimationNode.position.x, y: gradientNode.position.y)
                    transition.updatePosition(node: arrowAnimationNode, position: newPosition)
                    
                    arrowAnimationNode.completion = { [weak arrowAnimationNode, weak gradientLayer] in
                        print("arrow animation node finish animation")
                        arrowAnimationNode?.isHidden = true
                        gradientLayer?.removeFromSuperlayer()
                    }

                    arrowAnimationNode.play()
                    
                    let avatarNodeFrame = avatarNode.convert(avatarNode.frame, to: gradientNode)
                    if let gradientMaskLayer {
                        let targetPath = UIBezierPath(roundedRect: avatarNodeFrame, cornerRadius: avatarNodeFrame.width / 2).cgPath
                        transition.updatePath(layer: gradientMaskLayer, path: targetPath)
                    }
                    print("avatar node frame: \(avatarNode.convert(avatarNode.frame, to: gradientNode))")
                }
            case .swipeDownAppear, .swipeDownInit:
                let animationProgress: CGFloat = 0.0
                
                transition.updateTransform(node: arrowContainerNode, transform: .identity)
                
                if let releaseTextNode, let supernode = releaseTextNode.supernode {
                    let releaseTextLayout = releaseTextNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25),
                                                                                                max: CGSize(width: supernode.bounds.width - 120, height: 25)))
                    let releaseNodeFrame = CGRect(x: -releaseTextLayout.size.width,
                                                  y: supernode.bounds.height - releaseTextLayout.size.height - 8,
                                                  width: releaseTextLayout.size.width,
                                                  height: releaseTextLayout.size.height)

                    
//                    let targetPosition = supernode.bounds.center.offsetBy(dx: -supernode.bounds.width, dy: .zero).interpolate(to: supernode.bounds.center, amount: animationProgress)
                    transition.updatePosition(node: releaseTextNode, position: releaseNodeFrame.center)
                    transition.updateBounds(node: releaseTextNode, bounds: releaseNodeFrame)

                    let textLayout = textNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: supernode.bounds.width - 120, height: 25)))
                    let titleFrame = CGRect(x: (supernode.bounds.width - textLayout.size.width)/2,
                                            y: supernode.bounds.height - textLayout.size.height - 10,
                                            width: textLayout.size.width,
                                            height: textLayout.size.height)

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
            
//            let textLayout = releaseTextNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: supernode.frame.width - 120, height: 25)))
//            self.releaseTextNode?.frame = CGRect(x: -textLayout.size.width, y: supernode.frame.height - textLayout.size.height - 8, width: textLayout.size.width, height: textLayout.size.height)
        }

    }
    
    mutating internal func makeGradientOverlay(gradientContainerNode: ASDisplayNode, arrowContainerNode: ASDisplayNode) {
        if self.gradientLayer == nil {
            self.gradientLayer = CALayer()
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
        
        if gradientLayer.contents == nil {
            gradientLayer.contents = self.getGradientImageOrUpdate()?.cgImage
        }
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

    mutating func getGradientImageOrUpdate() -> UIImage? {
        if let gradientImage, gradientImage.size.height > 1 {
            return gradientImage
        } else if let presentationData, let gradientLayer, gradientLayer.frame.size.height > 0, self.params.storiesFraction > 0 {
            let size = gradientLayer.frame.size
            let backgroundColors = presentationData.theme.chatList.pinnedArchiveAvatarColor.backgroundColors.colors
            let gradientColors: [UIColor] = [backgroundColors.0, backgroundColors.1]
            self.gradientImage = generateGradientImage(
                size: size,
                colors: gradientColors,
                locations: [1.0, 0.0],
                direction: .horizontal
            )
            return self.gradientImage
        } else {
            return nil
        }
    }
}
