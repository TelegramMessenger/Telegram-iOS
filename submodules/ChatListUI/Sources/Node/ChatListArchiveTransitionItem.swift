//import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AnimationUI
import ComponentFlow
import TelegramPresentationData

public struct ArchiveAnimationParams: Equatable {
    public let scrollOffset: CGFloat
    public let storiesFraction: CGFloat
    public let expandedHeight: CGFloat
    
    public static var empty: ArchiveAnimationParams{
        return ArchiveAnimationParams(scrollOffset: .zero, storiesFraction: .zero, expandedHeight: .zero)
    }
}

class ChatListArchiveTransitionNode: ASDisplayNode {
        
    struct TransitionAnimation {
        enum Direction {
            case left
            case right
        }
        
        enum State {
            case swipeDownInit
            case releaseAppear
            case swipeDownAppear
            case transitionToArchive
            
            init(params: ArchiveAnimationParams, previousState: TransitionAnimation.State) {
                let fraction = params.storiesFraction
                if params.storiesFraction < 0.7 {
                    self = .swipeDownAppear
                } else if fraction >= 0.7 && fraction < 1.0 {
                    self = .releaseAppear
                } else if fraction >= 1.0 {
                    self = .transitionToArchive
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
        var rotationPausedTime: CFTimeInterval = .zero
        var releaseSwipePausedTime: CFTimeInterval = .zero
        var swipeTextPausedTime: CFTimeInterval = .zero
        
        var isAnimated = false
        var gradientShapeLayer: CAShapeLayer?
        var gradientMaskLayer: CAShapeLayer?
        var gradientLayer: CALayer?
        var releaseTextNode: ASTextNode?
        lazy var gradientImage: UIImage? = {
            guard let gradientShapeLayer, gradientShapeLayer.frame.size.height > 0, self.params.storiesFraction > 0 else { return nil }
            var size = gradientShapeLayer.frame.size
            let fraction = params.storiesFraction
            if fraction < 1.0  {
                size.height = self.params.expandedHeight / fraction
            }
            return generateGradientImage(size: gradientShapeLayer.frame.size,
                                         colors: [UIColor(hexString: "#0E7AF1")!, UIColor(hexString: "#69BEFE")!],
                                         locations: [0.0, 1.0], direction: .horizontal)
        }()
        
        
        static func degreesToRadians(_ x: CGFloat) -> CGFloat {
            return .pi * x / 180.0
        }
        
        static func distance(from: CGPoint, to point: CGPoint) -> CGFloat {
            return sqrt(pow((point.x - from.x), 2) + pow((point.y - from.y), 2))
        }
        
        
        mutating func animateLayers(gradientNode: ASDisplayNode, textNode: ASTextNode, arrowContainerNode: ASDisplayNode, completion: (() -> Void)?) {
            print("""
            animate layers with fraction: \(self.params.storiesFraction) animation progress: \(self.state.animationProgress(fraction: self.params.storiesFraction))
            state: \(self.state), offset: \(self.params.scrollOffset) height: \(self.params.expandedHeight)
            ##
            """)
//            CATransaction.begin()
//            CATransaction.setCompletionBlock {
//                completion?()
//            }
//            CATransaction.completionBlock()
//            CATransaction.setAnimationDuration(1.0)
            if !(arrowContainerNode.layer.animationKeys()?.contains(where: { $0 == "arrow_rotation" }) ?? false) {
                let rotationAnimation = makeArrowRotationAnimation(arrowContainerNode: arrowContainerNode, isRotated: true)
                self.rotationPausedTime = arrowContainerNode.layer.convertTime(CACurrentMediaTime(), from: nil)
                arrowContainerNode.layer.speed = .zero
                arrowContainerNode.layer.timeOffset = self.rotationPausedTime
                arrowContainerNode.layer.add(rotationAnimation, forKey: "arrow_rotation")
            }
            
            updateReleaseTextNode(from: textNode)
            if let releaseTextNode, !(releaseTextNode.layer.animationKeys()?.contains(where: { $0 == "translate_text" }) ?? false) {
                let releaseTextAnimation = makeTextSwipeAnimation(textNode: releaseTextNode, direction: .right)
                self.releaseSwipePausedTime = releaseTextNode.layer.convertTime(CACurrentMediaTime(), from: nil)
                releaseTextNode.layer.speed = .zero
                releaseTextNode.layer.timeOffset = self.releaseSwipePausedTime
                releaseTextNode.layer.add(releaseTextAnimation, forKey: "translate_text")
            }
            
            if !(textNode.layer.animationKeys()?.contains(where: { $0 == "translate_text" }) ?? false) {
                let swipeAnimation = makeTextSwipeAnimation(textNode: textNode, direction: .right)
                self.swipeTextPausedTime = arrowContainerNode.layer.convertTime(CACurrentMediaTime(), from: nil)
                textNode.layer.speed = .zero
                textNode.layer.timeOffset = self.swipeTextPausedTime
                textNode.layer.add(swipeAnimation, forKey: "translate_text")
            }
            switch state {
            case .releaseAppear:
//                updateReleaseTextNode(from: textNode)
//                updateGradientOverlay(from: gradientNode)
                
                let animationProgress = self.state.animationProgress(fraction: self.params.storiesFraction)
                arrowContainerNode.layer.timeOffset = self.rotationPausedTime + animationProgress
                releaseTextNode?.layer.timeOffset = self.releaseSwipePausedTime + animationProgress
                textNode.layer.timeOffset = self.swipeTextPausedTime + animationProgress
                
//                let textSwipeAnimation = makeTextSwipeAnimation(textNode: textNode, direction: .right)
//                textSwipeAnimation.beginTime = .zero
                
//                if let releaseTextNode {
//                    let releaseTextAppearAnimation = makeTextSwipeAnimation(textNode: releaseTextNode, direction: .right)
//                    releaseTextAppearAnimation.beginTime = .zero
//                }
//
//                if let gradientShapeLayer {
//                    let overlayGradientAnimation = makeGradientOverlay(gradientContainer: gradientNode, arrowContainer: arrowContainerNode, gradientLayer: gradientShapeLayer)
//                    overlayGradientAnimation.beginTime = .zero
//                }
                
                
            case .swipeDownAppear, .swipeDownInit:
                arrowContainerNode.layer.beginTime = CACurrentMediaTime()
                arrowContainerNode.layer.speed = -1
                arrowContainerNode.layer.removeAllAnimations()
                
                textNode.layer.beginTime = CACurrentMediaTime()
                textNode.layer.speed = -1
                textNode.layer.removeAllAnimations()

                releaseTextNode?.layer.beginTime = CACurrentMediaTime()
                releaseTextNode?.layer.speed = -1
                releaseTextNode?.layer.removeAllAnimations()
                print("set speed -1")
                
//                let textSwipeAnimation = makeTextSwipeAnimation(textNode: textNode, direction: .left)
//                textSwipeAnimation.beginTime = .zero

//                if let releaseTextNode {
//                    let releaseTextAppearAnimation = makeTextSwipeAnimation(textNode: releaseTextNode, direction: .left)
//                    releaseTextAppearAnimation.beginTime = .zero
//                }
//
//                if let gradientShapeLayer {
//                    let overlayGradientAnimation = makeGradientOverlay(gradientContainer: gradientNode, arrowContainer: arrowContainerNode, gradientLayer: gradientShapeLayer)
//                    overlayGradientAnimation.completion = {  finished in
//                        guard finished else { return }
//                        gradientShapeLayer.isHidden = true
//                        gradientShapeLayer.removeFromSuperlayer()
//                    }
//                    overlayGradientAnimation.beginTime = .zero
//                }
//                updateGradientOverlay(from: gradientNode)

            case .transitionToArchive:
                arrowContainerNode.layer.timeOffset = self.rotationPausedTime + 0.99
                releaseTextNode?.layer.timeOffset = self.releaseSwipePausedTime + 0.99
                textNode.layer.timeOffset = self.swipeTextPausedTime + 0.99
            }
//            CATransaction.commit()
            self.isAnimated = true
        }
        
        private mutating func updateGradientOverlay(from gradientNode: ASDisplayNode) {
            switch state {
            case .releaseAppear:
                if (self.gradientShapeLayer == nil) {
                    self.gradientShapeLayer = CAShapeLayer()
                    self.gradientShapeLayer?.masksToBounds = true
                    self.gradientShapeLayer?.contentsGravity = .center
                    
                    self.gradientShapeLayer?.fillColor = UIColor.clear.cgColor
                    self.gradientShapeLayer?.strokeColor = UIColor.clear.cgColor
                    self.gradientShapeLayer?.lineWidth = 0.0
                    self.gradientShapeLayer?.fillRule = .evenOdd
                    
                }
                if (self.gradientMaskLayer == nil) {
                    self.gradientMaskLayer = CAShapeLayer()
                }
                
                if (self.gradientLayer == nil) {
                    self.gradientLayer = CALayer()
                }
                
                guard let gradientShapeLayer else { return }
                
                
                if gradientShapeLayer.superlayer == nil {
                    gradientNode.layer.addSublayer(gradientShapeLayer)
                }
                
                if let gradientMaskLayer, gradientMaskLayer.superlayer == nil {
                    gradientShapeLayer.addSublayer(gradientMaskLayer)
                }
                
                if (gradientShapeLayer.frame != gradientNode.bounds || gradientShapeLayer.contents == nil) {
                    gradientShapeLayer.frame = gradientNode.bounds
                    gradientShapeLayer.contents = self.getGradientImageOrUpdate()?.cgImage
                }
                
                if self.gradientLayer?.superlayer == nil {
                    gradientShapeLayer.addSublayer(self.gradientLayer!)
                }
                
                self.gradientMaskLayer?.path = gradientShapeLayer.path
                self.gradientMaskLayer?.frame = gradientShapeLayer.bounds
                gradientShapeLayer.mask = self.gradientMaskLayer
                gradientShapeLayer.frame = gradientShapeLayer.bounds
                
            case .swipeDownInit, .swipeDownAppear, .transitionToArchive:
                break
            }
        }
        
        mutating func getGradientImageOrUpdate() -> UIImage? {
            if let gradientImage, gradientImage.size.height > 100 {
                return gradientImage
            } else if let gradientShapeLayer, gradientShapeLayer.frame.size.height > 0, self.params.storiesFraction > 0 {
                self.gradientImage = generateGradientImage(
                    size: gradientShapeLayer.frame.size,
                    colors: [UIColor(hexString: "#0E7AF1")!, UIColor(hexString: "#69BEFE")!],
                    locations: [0.0, 1.0],
                    direction: .horizontal
                )
                return self.gradientImage
            } else {
                return nil
            }
        }
    
        
        private mutating func updateReleaseTextNode(from textNode: ASTextNode) {
            if self.releaseTextNode == nil {
                self.releaseTextNode = ASTextNode()
                self.releaseTextNode?.isLayerBacked = true
                let attributes: [NSAttributedString.Key: Any] = textNode.attributedText?.attributes(at: 0, effectiveRange: nil) ?? [:]
                self.releaseTextNode?.attributedText = NSAttributedString(string: "Release for archive", attributes: attributes)
                guard let supernode = textNode.supernode else { return }
                supernode.addSubnode(self.releaseTextNode!)
            }

            if let releaseTextNode, let supernode = releaseTextNode.supernode, state != .transitionToArchive {
                let textLayout = releaseTextNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: supernode.frame.width - 120, height: 25)))
                self.releaseTextNode?.frame = CGRect(x: -textLayout.size.width, y: supernode.frame.height - textLayout.size.height - 8, width: textLayout.size.width, height: textLayout.size.height)
            }
        }
        
        private func makeArrowRotationAnimation(arrowContainerNode: ASDisplayNode, isRotated: Bool) -> CAAnimation {
            let rotatedDegree = TransitionAnimation.degreesToRadians(isRotated ? -180 : 0)
            let animation = arrowContainerNode.layer.makeAnimation(
                from: 0.0 as NSNumber,
                to: rotatedDegree as NSNumber,
                keyPath: "transform.rotation.z",
                timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue,
                duration: 1.0,
                removeOnCompletion: false,
                additive: true
            )
            animation.fillMode = .forwards
            return animation
        }
        
        private func makeTextSwipeAnimation(textNode: ASTextNode, direction: TransitionAnimation.Direction) -> CAAnimation {
            guard let superNode = textNode.supernode else {
                return CAAnimation()
            }
            let targetPosition: CGPoint
            
            switch direction {
            case .left:
                if textNode.frame.origin.x > superNode.frame.width {
                    let distanceToCenter = TransitionAnimation.distance(from: textNode.frame.center, to: superNode.frame.center)
                    targetPosition = CGPoint(x: textNode.layer.position.x - distanceToCenter, y: textNode.layer.position.y)
                } else {
                    targetPosition = CGPoint(x: textNode.position.x - (superNode.frame.width - textNode.frame.center.x) + textNode.frame.width / 2, y: textNode.layer.position.y)
                }
            case .right:
                if textNode.frame.origin.x < 0 {
                    let distanceToCenter = TransitionAnimation.distance(from: textNode.frame.center, to: superNode.frame.center)
                    targetPosition = CGPoint(x: textNode.layer.position.x + distanceToCenter, y: textNode.layer.position.y)
                } else {
                    targetPosition = CGPoint(x: textNode.position.x + (superNode.frame.width - textNode.frame.center.x) + textNode.frame.width / 2, y: textNode.layer.position.y)
                }
            }
        
            print("makeTextSwipeAnimation from position: \(textNode.layer.position) to position: \(targetPosition)")
            let animation = textNode.layer.springAnimation(
                from: NSValue(cgPoint: textNode.layer.position),
                to: NSValue(cgPoint: targetPosition),
                keyPath: "position",
                duration: 1.0,
                removeOnCompletion: false,
                additive: false
            )
            animation.fillMode = .forwards
            return animation
        }
        
        private func makeGradientOverlay(gradientContainer: ASDisplayNode, arrowContainer: ASDisplayNode, gradientLayer: CAShapeLayer) -> CAAnimation {
            gradientLayer.frame = gradientContainer.bounds//arrowContainer.convert(arrowContainer.frame, to: gradientContainer)

            let startCirclePath: UIBezierPath
            let finalRectPath: UIBezierPath
            switch state {
            case .swipeDownInit, .swipeDownAppear:
                startCirclePath = UIBezierPath(roundedRect: gradientContainer.bounds, cornerRadius: 10)
                finalRectPath = UIBezierPath(roundedRect: arrowContainer.convert(arrowContainer.bounds, to: gradientContainer), cornerRadius: 10)
            case .releaseAppear:
                startCirclePath = UIBezierPath(roundedRect: arrowContainer.convert(arrowContainer.bounds, to: gradientContainer), cornerRadius: 10)
                finalRectPath = UIBezierPath(roundedRect: gradientContainer.bounds, cornerRadius: 10)
            case .transitionToArchive:
                //TODO: update gradient path
                startCirclePath = UIBezierPath(roundedRect: arrowContainer.convert(arrowContainer.bounds, to: gradientContainer), cornerRadius: 10)
                finalRectPath = UIBezierPath(roundedRect: gradientContainer.bounds, cornerRadius: 10)
            }
            
            startCirclePath.close()
            finalRectPath.close()
            
            gradientLayer.path = startCirclePath.cgPath
//            gradientLayer.mask =
//            let animation2 = gradientLayer.makeAnimation(from: gradientLayer.cornerRadius as NSNumber, to: 0 as NSNumber, keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 3.0, removeOnCompletion: false)
            let animation = gradientLayer.springAnimation(from: startCirclePath.cgPath, to: finalRectPath.cgPath, keyPath: "path", duration: 3.0, removeOnCompletion: false, additive: false)
            animation.fillMode = .forwards
            animation.speed = 0
//            animation.timeOffse
            gradientLayer.removeAllAnimations()
//            gradientLayer.add(animation2, forKey: "gradient_corner")
            gradientLayer.add(animation, forKey: "gradient_path_transition")
            
            gradientLayer.path = finalRectPath.cgPath
            
            return animation
        }
    }
    
    let backgroundNode: ASDisplayNode
    let gradientContainerNode: ASDisplayNode
    let gradientImageNode: ASImageNode
    let titleNode: ASTextNode //centered
    let arrowBackgroundNode: ASDisplayNode //20 with insets 10
    let arrowContainerNode: ASDisplayNode
    let arrowAnimationNode: AnimationNode //20x20
    let arrowImageNode: ASImageNode
    var animation: TransitionAnimation
    
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
        self.arrowImageNode.image = UIImage(bundleImageName: "Chat List/Archive/IconArrow")
        self.arrowImageNode.isLayerBacked = true
        
        let mixedBackgroundColor = UIColor(hexString: "#A9AFB7")!.mixedWith(.white, alpha: 0.4)
        self.arrowAnimationNode = AnimationNode(animation: "anim_arrow_to_archive", colors: [
            "Arrow 1.Arrow 1.Stroke 1": mixedBackgroundColor,
            "Arrow 2.Arrow 2.Stroke 1": mixedBackgroundColor,
            "Cap.cap2.Fill 1": .white,
            "Cap.cap1.Fill 1": .white,
            "Box.box1.Fill 1": .white
        ], scale: 0.11)
        self.arrowAnimationNode.backgroundColor = .clear
        
        super.init()
        self.backgroundColor = .red
        self.addSubnode(self.gradientContainerNode)
        self.gradientContainerNode.addSubnode(self.gradientImageNode)
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.titleNode)
        self.backgroundNode.addSubnode(self.arrowBackgroundNode)
        self.arrowBackgroundNode.addSubnode(self.arrowContainerNode)
        self.arrowContainerNode.addSubnode(self.arrowImageNode)
    }
    
    override func didLoad() {
        super.didLoad()
    }
        
    func updateLayout(transition: ContainedViewLayoutTransition, size: CGSize, params: ArchiveAnimationParams, presentationData: ChatListPresentationData) {
        let frame = self.bounds
        var transition = transition
        
        guard self.animation.params != params || self.frame.size != size else { return }
        let updateLayers = self.animation.params != params
        
        self.animation.params = params
//        print("params: \(params) previous params: \(self.animation.params) \nsize: \(size) previous size: \(self.frame.size)")
        let previousState = self.animation.state
        self.animation.state = .init(params: params, previousState: previousState)
        
        if self.animation.state != previousState {
            transition = .immediate
        }
        
        if self.gradientImageNode.image == nil || self.gradientImageNode.image?.size.width != size.width {
            let gradientImageSize = CGSize(width: size.width, height: 76.0)
            self.gradientImageNode.image = generateGradientImage(
                size: gradientImageSize,
                colors: [UIColor(hexString: "#A9AFB7")!, UIColor(hexString: "#D3D4DA")!],
                locations: [0.0, 1.0],
                direction: .horizontal
            )
        }
        
        transition.updatePosition(node: self.backgroundNode, position: frame.center)
        transition.updateBounds(node: self.backgroundNode, bounds: frame)

        transition.updatePosition(node: self.gradientContainerNode, position: frame.center)
        transition.updateBounds(node: self.gradientContainerNode, bounds: frame)
        
        transition.updatePosition(node: self.gradientImageNode, position: frame.center)
        transition.updateBounds(node: self.gradientImageNode, bounds: frame)
        
        if size.height >= 20 {
            let arrowBackgroundFrame = CGRect(x: 29, y: 10, width: 20, height: size.height - 20)
            let arrowFrame = CGRect(x: arrowBackgroundFrame.minX, y: arrowBackgroundFrame.maxY - 20, width: 20, height: 20)
            transition.updatePosition(node: self.arrowBackgroundNode, position: arrowBackgroundFrame.center)
            transition.updateBounds(node: self.arrowBackgroundNode, bounds: arrowBackgroundFrame)
            transition.updateCornerRadius(node: self.arrowBackgroundNode, cornerRadius: 10)
            transition.updatePosition(node: self.arrowContainerNode, position: arrowFrame.center)
            transition.updateBounds(node: self.arrowContainerNode, bounds: arrowFrame)
            transition.updatePosition(node: self.arrowImageNode, position: arrowFrame.center)
            transition.updateBounds(node: self.arrowImageNode, bounds: arrowFrame)
        }
        
//        if var size = self.arrowAnimationNode.preferredSize() {
//            let scale = 2.7//size.width / arrowBackgroundFrame.width
//            transition.updateTransformScale(layer: self.arrowBackgroundNode.layer, scale: scale) { [weak arrowNode] finished in
//                guard let arrowNode, finished else { return }
//                transition.updateTransformScale(layer: arrowNode.layer, scale: 1.0 / scale)
//            }
//            animationBackgroundNode.layer.animateScale(from: 1.0, to: 1.07, duration: 0.12, removeOnCompletion: false, completion: { [weak animationBackgroundNode] finished in
//                animationBackgroundNode?.layer.animateScale(from: 1.07, to: 1.0, duration: 0.12, removeOnCompletion: false)
//            })

//            print("size before: \(size)")
//            size = CGSize(width: ceil(arrowBackgroundFrame.width), height: ceil(arrowBackgroundFrame.width))
//            print("size after: \(size)")
//            size = CGSize(width: ceil(size.width), height: ceil(size.width))
//            let arrowFrame = CGRect(x: floor((arrowBackgroundFrame.width - size.width) / 2.0),
//                                    y: floor(arrowBackgroundFrame.height - size.height),
//                                    width: size.width, height: size.height)
//            transition.updateFrame(node: self.arrowNode, frame: arrowFrame)
//            self.arrowNode.play()
//            transition.updateTransformRotation(node: arrowAnimationNode, angle: TransitionAnimation.degreesToRadians(-180))
//
//            size = CGSize(width: ceil(size.width * scale), height: ceil(size.width * scale))
//
//            let arrowCenter = (size.height / scale)/2
//            let scaledArrowCenter = size.height / 2
//            let difference = scaledArrowCenter - arrowCenter
//
//            let arrowFrame = CGRect(x: floor((arrowBackgroundFrame.width - size.width) / 2.0),
//                                    y: floor(arrowBackgroundFrame.height - size.height/scale - difference),
//                                    width: size.width, height: size.height)
//            transition.updateFrame(node: arrowAnimationNode, frame: arrowFrame)
//        }

        if self.titleNode.attributedText == nil {
            self.titleNode.attributedText = NSAttributedString(string: "Swipe down for archive", attributes: [
                .foregroundColor: UIColor.white,
                .font: Font.medium(floor(presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            ])
        }

        let textLayout = self.titleNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: size.width - 120, height: 25)))
        let titleFrame = CGRect(x: (size.width - textLayout.size.width) / 2,
                                y: size.height - textLayout.size.height - 10,
                                width: textLayout.size.width,
                                height: textLayout.size.height)


        transition.updatePosition(node: self.titleNode, position: titleFrame.center)
        transition.updateBounds(node: self.titleNode, bounds: titleFrame)
        
        if updateLayers {
            self.animation.animateLayers(gradientNode: self.gradientContainerNode,
                                         textNode: self.titleNode,
                                         arrowContainerNode: self.arrowContainerNode) {

                print("animation finished")
            }
        }

    }
}
    
