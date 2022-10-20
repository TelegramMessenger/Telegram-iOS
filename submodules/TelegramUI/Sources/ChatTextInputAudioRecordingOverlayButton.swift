import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle
import ObjCRuntimeUtils

private let innerCircleDiameter: CGFloat = 110.0
private let outerCircleDiameter = innerCircleDiameter + 50.0
private let outerCircleMinScale = innerCircleDiameter / outerCircleDiameter
private let innerCircleImage = generateFilledCircleImage(diameter: innerCircleDiameter, color: UIColor(rgb: 0x007aff))
private let outerCircleImage = generateFilledCircleImage(diameter: outerCircleDiameter, color: UIColor(rgb: 0x007aff, alpha: 0.2))
private let micIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/IconMicrophone"), color: .white)!

private final class ChatTextInputAudioRecordingOverlayDisplayLinkTarget: NSObject {
    private let f: () -> Void
    
    init(_ f: @escaping () -> Void) {
        self.f = f
        
        super.init()
    }
    
    @objc func displayLinkEvent() {
        self.f()
    }
}

final class ChatTextInputAudioRecordingOverlay {
    private weak var anchorView: UIView?
    
    private let containerNode: ASDisplayNode
    private let circleContainerNode: ASDisplayNode
    private let innerCircleNode: ASImageNode
    private let outerCircleNode: ASImageNode
    private let iconNode: ASImageNode
    
    var animationStartTime: Double?
    var displayLink: CADisplayLink?
    var currentLevel: CGFloat = 0.0
    var inputLevel: CGFloat = 0.0
    var animatedIn = false
    
    var dismissFactor: CGFloat = 1.0 {
        didSet {
            let scale = max(0.3, min(self.dismissFactor, 1.0))
            self.circleContainerNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
        }
    }
    
    init(anchorView: UIView) {
        self.anchorView = anchorView
        
        self.containerNode = ASDisplayNode()
        self.containerNode.isLayerBacked = true
        
        self.circleContainerNode = ASDisplayNode()
        self.circleContainerNode.isLayerBacked = true
        
        self.outerCircleNode = ASImageNode()
        self.outerCircleNode.displayWithoutProcessing = true
        self.outerCircleNode.displaysAsynchronously = false
        self.outerCircleNode.isLayerBacked = true
        self.outerCircleNode.image = outerCircleImage
        self.outerCircleNode.frame = CGRect(origin: CGPoint(x: -outerCircleDiameter / 2.0, y: -outerCircleDiameter / 2.0), size: CGSize(width: outerCircleDiameter, height: outerCircleDiameter))
        
        self.innerCircleNode = ASImageNode()
        self.innerCircleNode.displayWithoutProcessing = true
        self.innerCircleNode.displaysAsynchronously = false
        self.innerCircleNode.isLayerBacked = true
        self.innerCircleNode.image = innerCircleImage
        self.innerCircleNode.frame = CGRect(origin: CGPoint(x: -innerCircleDiameter / 2.0, y: -innerCircleDiameter / 2.0), size: CGSize(width: innerCircleDiameter, height: innerCircleDiameter))
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isLayerBacked = true
        self.iconNode.image = micIcon
        self.iconNode.frame = CGRect(origin: CGPoint(x: -micIcon.size.width / 2.0, y: -micIcon.size.height / 2.0), size: micIcon.size)
        
        self.circleContainerNode.addSubnode(self.outerCircleNode)
        self.circleContainerNode.addSubnode(self.innerCircleNode)
        self.containerNode.addSubnode(self.circleContainerNode)
        self.containerNode.addSubnode(self.iconNode)
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    func present(in window: UIWindow) {
        if let anchorView = self.anchorView, let anchorSuperview = anchorView.superview {
            if let displayLink = self.displayLink {
                displayLink.invalidate()
            }
            self.displayLink = CADisplayLink(target: ChatTextInputAudioRecordingOverlayDisplayLinkTarget({ [weak self] in
                self?.displayLinkEvent()
            }), selector: #selector(ChatTextInputAudioRecordingOverlayDisplayLinkTarget.displayLinkEvent))
            
            let convertedCenter = anchorSuperview.convert(anchorView.center, to: window)
            self.containerNode.position = CGPoint(x: convertedCenter.x, y: convertedCenter.y)
            window.addSubnode(self.containerNode)
            
            self.innerCircleNode.layer.animateSpring(from: 0.2 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
            self.outerCircleNode.layer.transform = CATransform3DMakeScale(outerCircleMinScale, outerCircleMinScale, 1.0)
            self.outerCircleNode.layer.animateSpring(from: 0.2 as NSNumber, to: outerCircleMinScale as NSNumber, keyPath: "transform.scale", duration: 0.5)
            self.innerCircleNode.layer.animateAlpha(from: 0.2, to: 1.0, duration: 0.15)
            self.outerCircleNode.layer.animateAlpha(from: 0.2, to: 1.0, duration: 0.15)
            self.iconNode.layer.animateAlpha(from: 0.2, to: 1.0, duration: 0.15)
            
            self.animatedIn = true
            self.animationStartTime = CACurrentMediaTime()
            self.displayLink?.add(to: RunLoop.main, forMode: .common)
            self.displayLink?.isPaused = false
        }
    }
    
    func dismiss() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        
        var innerCompleted = false
        var outerCompleted = false
        var iconCompleted = false
        
        var containerNodeRef: ASDisplayNode? = self.containerNode
        
        let completion: () -> Void = {
            if let containerNode = containerNodeRef, innerCompleted, outerCompleted, iconCompleted {
                containerNode.removeFromSupernode()
                containerNodeRef = nil
            }
        }
        
        self.innerCircleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false)
        self.innerCircleNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.18, removeOnCompletion: false, completion: { _ in
            innerCompleted = true
            completion()
        })
        
        var currentScaleValue: CGFloat = outerCircleMinScale
        if let currentScale = self.outerCircleNode.layer.floatValue(forKeyPath: "transform.scale") {
            currentScaleValue = CGFloat(currentScale.floatValue)
        }
        
        self.outerCircleNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false)
        self.outerCircleNode.layer.animateScale(from: currentScaleValue, to: 0.2, duration: 0.18, removeOnCompletion: false, completion: { _ in
            outerCompleted = true
            completion()
        })
        
        self.iconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { _ in
            iconCompleted = true
            completion()
        })
    }
    
    private func displayLinkEvent() {
        let t = CACurrentMediaTime()
        if let animationStartTime = self.animationStartTime {
            if t > animationStartTime + 0.5 {
                self.currentLevel = self.currentLevel * 0.8 + self.inputLevel * 0.2
                
                let scale = outerCircleMinScale + self.currentLevel * (1.0 - outerCircleMinScale)
                self.outerCircleNode.transform = CATransform3DMakeScale(scale, scale, 1.0)
            }
        }
    }
    
    func addImmediateMicLevel(_ level: CGFloat) {
        self.inputLevel = level
    }
}
