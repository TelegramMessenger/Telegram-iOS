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
                if params.storiesFraction <= 0.92 {
                    self = .swipeDownAppear
                } else if fraction > 0.92 && fraction < 1.0 {
                    self = .releaseAppear
                } else if fraction >= 1.0 {
                    self = .transitionToArchive
                } else {
                    self = .swipeDownInit
                }
            }
        }
        
        var state: State
        var params: ArchiveAnimationParams
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
            print("animate layers with fraction: \(self.params.storiesFraction) state: \(self.state), offset: \(self.params.scrollOffset) height: \(self.params.expandedHeight)")
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion?()
            }
            CATransaction.completionBlock()
            CATransaction.setAnimationDuration(1.0)
            switch state {
            case .swipeDownInit:
                print("swipe dowm init transition called")
//                self.gradientLayer
            case .releaseAppear:
                updateReleaseTextNode(from: textNode)
                updateGradientOverlay(from: gradientNode)
                
                let rotationAnimation = makeArrowRotationAnimation(arrowContainerNode: arrowContainerNode, isRotated: true)
                rotationAnimation.beginTime = .zero
                
                let textSwipeAnimation = makeTextSwipeAnimation(textNode: textNode, direction: .right)
                textSwipeAnimation.beginTime = .zero
                
                if let releaseTextNode {
                    let releaseTextAppearAnimation = makeTextSwipeAnimation(textNode: releaseTextNode, direction: .right)
                    releaseTextAppearAnimation.beginTime = .zero
                }
                
                if let gradientShapeLayer {
                    let overlayGradientAnimation = makeGradientOverlay(gradientContainer: gradientNode, arrowContainer: arrowContainerNode, gradientLayer: gradientShapeLayer)
                    overlayGradientAnimation.beginTime = .zero
                }
                
                
            case .swipeDownAppear:
                let rotationAnimation = makeArrowRotationAnimation(arrowContainerNode: arrowContainerNode, isRotated: false)
                rotationAnimation.beginTime = .zero
                
                let textSwipeAnimation = makeTextSwipeAnimation(textNode: textNode, direction: .left)
                textSwipeAnimation.beginTime = .zero

                if let releaseTextNode {
                    let releaseTextAppearAnimation = makeTextSwipeAnimation(textNode: releaseTextNode, direction: .left)
                    releaseTextAppearAnimation.beginTime = .zero
                }

                if let gradientShapeLayer {
                    let overlayGradientAnimation = makeGradientOverlay(gradientContainer: gradientNode, arrowContainer: arrowContainerNode, gradientLayer: gradientShapeLayer)
                    overlayGradientAnimation.completion = {  finished in
                        guard finished else { return }
                        gradientShapeLayer.isHidden = true
                        gradientShapeLayer.removeFromSuperlayer()
                    }
                    overlayGradientAnimation.beginTime = .zero
                }
                updateGradientOverlay(from: gradientNode)

            case .transitionToArchive:
                let rotationAnimation = makeArrowRotationAnimation(arrowContainerNode: arrowContainerNode, isRotated: true)
                rotationAnimation.beginTime = .zero

            }
            CATransaction.commit()
            self.isAnimated = true
        }
        
        private mutating func updateGradientOverlay(from gradientNode: ASDisplayNode) {
            switch state {
            case .releaseAppear:
                if (self.gradientShapeLayer == nil) {
                    self.gradientShapeLayer = CAShapeLayer()
                    self.gradientShapeLayer?.masksToBounds = true
                    self.gradientShapeLayer?.cornerRadius = 10
                    self.gradientShapeLayer?.contentsGravity = .center
                    
                    self.gradientShapeLayer?.fillColor = UIColor.clear.cgColor
                    self.gradientShapeLayer?.strokeColor = UIColor.red.cgColor
                    self.gradientShapeLayer?.lineWidth = 3.0
                    self.gradientShapeLayer?.fillRule = .evenOdd
                    
                }
                
                if let gradientShapeLayer, gradientShapeLayer.superlayer == nil {
                    gradientNode.layer.addSublayer(gradientShapeLayer)
                }
                
                if (self.gradientShapeLayer?.frame != gradientNode.bounds || self.gradientShapeLayer?.contents == nil) {
                    self.gradientShapeLayer?.frame = gradientNode.bounds
                    self.gradientShapeLayer?.contents = self.getGradientImageOrUpdate()?.cgImage
                }
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
                duration: 0.5,
                removeOnCompletion: false,
                additive: true
            )
            arrowContainerNode.layer.animationKeys()?.filter({ $0 == "arrow_rotation" }).forEach({ arrowContainerNode.layer.cancelAnimationsRecursive(key: $0) })
            arrowContainerNode.layer.add(animation, forKey: "arrow_rotation")
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
        
            let animation = textNode.layer.springAnimation(
                from: NSValue(cgPoint: textNode.layer.position),
                to: NSValue(cgPoint: targetPosition),
                keyPath: "position",
                duration: 1.0,
                removeOnCompletion: false,
                additive: false
            )
            textNode.layer.animationKeys()?.filter({ $0 == "translate_text" }).forEach({ textNode.layer.cancelAnimationsRecursive(key: $0) })
            textNode.layer.add(animation, forKey: "translate_text")
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
            gradientLayer.removeAllAnimations()
//            gradientLayer.add(animation2, forKey: "gradient_corner")
            gradientLayer.add(animation, forKey: "gradient_path_transition")
            
            gradientLayer.path = finalRectPath.cgPath
            
            return animation
        }
    }
    
    let backgroundNode: ASDisplayNode
    let gradientContainerNode: ASDisplayNode
    let gradientComponent: RoundedRectangle
    var gradientContainerView: ComponentHostView<Empty>?
    let titleNode: ASTextNode //centered
    let arrowBackgroundNode: ASDisplayNode //20 with insets 10
    let arrowContainerNode: ASDisplayNode
    let arrowAnimationNode: AnimationNode //20x20
    let arrowImageNode: ASImageNode
    var animation: TransitionAnimation
    
    required override init() {
        self.backgroundNode = ASDisplayNode()
//        self.backgroundNode.isLayerBacked = true
//        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.backgroundColor = .clear
        
        self.gradientContainerNode = ASDisplayNode()
        self.animation = .init(state: .swipeDownInit, params: .empty)
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        
        self.gradientComponent = RoundedRectangle(colors: [UIColor(hexString: "#A9AFB7")!,
                                                           UIColor(hexString: "#D3D4DA")!],
                                                  cornerRadius: 0,
                                                  gradientDirection: .horizontal)

        self.arrowBackgroundNode = ASDisplayNode()
        self.arrowBackgroundNode.backgroundColor = .white.withAlphaComponent(0.4)
                
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
        self.arrowAnimationNode.isUserInteractionEnabled = false
        
        super.init()
        self.addSubnode(self.gradientContainerNode)
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
        let frame = CGRect(origin: .zero, size: size)
        print("frame: \(frame)")
        
        var transition = transition
        
        guard self.animation.params != params || self.frame.size != size else { return }
        if self.animation.params != params { print("new params") }
        if self.frame.size != size { print("new size") }

        self.animation.params = params
        let previousState = self.animation.state
        self.animation.state = .init(params: params, previousState: previousState)
        
        if self.animation.state != previousState {
            transition = .immediate
        }
        
        if self.gradientContainerView == nil {
            self.gradientContainerView = ComponentHostView<Empty>()
            self.gradientContainerNode.view.addSubview(self.gradientContainerView!)
        }

        let _ = self.gradientContainerView?.update(
            transition: .immediate,
            component: AnyComponent(self.gradientComponent),
            environment: {},
            containerSize: size
        )
        
        transition.updateFrame(node: self, frame: frame)
        transition.updateFrame(node: self.gradientContainerNode, frame: frame)
        transition.updateFrame(node: self.backgroundNode, frame: frame)
        if let gradientContainerView {
            transition.updateFrame(view: gradientContainerView, frame: frame)
        }
        let arrowBackgroundFrame = CGRect(x: 29, y: 10, width: 20, height: size.height - 20)
        let arrowFrame = CGRect(x: 0, y: arrowBackgroundFrame.height - 20, width: 20, height: 20)
        transition.updateFrame(node: self.arrowBackgroundNode, frame: arrowBackgroundFrame)
        transition.updateCornerRadius(node: self.arrowBackgroundNode, cornerRadius: arrowBackgroundFrame.width / 2, completion: nil)
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

//        transition.updateFrame(node: self.arrowNode, frame: CGRect(x: .zero, y: arrowBackgroundFrame.height - arrowBackgroundFrame.width, width: arrowBackgroundFrame.width, height: arrowBackgroundFrame.width))
        
        transition.updateFrame(node: self.arrowContainerNode, frame: arrowFrame)
        transition.updateFrame(node: self.arrowImageNode, frame: self.arrowContainerNode.bounds)
        self.titleNode.attributedText = NSAttributedString(string: "Swipe down for archive", attributes: [
            .foregroundColor: UIColor.white,
            .font: Font.medium(floor(presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
        ])

        let textLayout = self.titleNode.calculateLayoutThatFits(ASSizeRange(min: CGSize(width: 100, height: 25), max: CGSize(width: size.width - 120, height: 25)))
        
        transition.updateFrame(node: titleNode, frame: CGRect(x: (size.width - textLayout.size.width) / 2,
                                                              y: size.height - textLayout.size.height - 10,
                                                              width: textLayout.size.width,
                                                              height: textLayout.size.height))
        
        if self.animation.state != previousState {
            self.animation.animateLayers(gradientNode: self.gradientContainerNode,
                                         textNode: self.titleNode,
                                         arrowContainerNode: self.arrowContainerNode) {

                print("animation finished")
            }
        }

    }
}
    
