import Foundation
import AsyncDisplayKit

open class ContextControllerSourceNode: ContextReferenceContentNode {
    public private(set) var contextGesture: ContextGesture?
    
    public var isGestureEnabled: Bool = true {
        didSet {
            self.contextGesture?.isEnabled = self.isGestureEnabled
        }
    }
    public var beginDelay: Double = 0.12 {
        didSet {
            self.contextGesture?.beginDelay = self.beginDelay
        }
    }
    public var animateScale: Bool = true
    
    public var activated: ((ContextGesture, CGPoint) -> Void)?
    public var shouldBegin: ((CGPoint) -> Bool)?
    public var customActivationProgress: ((CGFloat, ContextGestureTransition) -> Void)?
    public weak var additionalActivationProgressLayer: CALayer?
    public var targetNodeForActivationProgress: ASDisplayNode?
    public var targetNodeForActivationProgressContentRect: CGRect?
    
    public func cancelGesture() {
        self.contextGesture?.cancel()
        self.contextGesture?.isEnabled = false
        self.contextGesture?.isEnabled = self.isGestureEnabled
    }
    
    override open func didLoad() {
        super.didLoad()
        
        let contextGesture = ContextGesture(target: self, action: nil)
        self.contextGesture = contextGesture
        self.view.addGestureRecognizer(contextGesture)
        
        contextGesture.beginDelay = self.beginDelay
        contextGesture.isEnabled = self.isGestureEnabled
        
        contextGesture.shouldBegin = { [weak self] point in
            guard let strongSelf = self, !strongSelf.bounds.width.isZero else {
                return false
            }
            return strongSelf.shouldBegin?(point) ?? true
        }
        
        contextGesture.activationProgress = { [weak self] progress, update in
            guard let strongSelf = self, !strongSelf.bounds.width.isZero else {
                return
            }
            if let customActivationProgress = strongSelf.customActivationProgress {
                customActivationProgress(progress, update)
            } else if strongSelf.animateScale {
                let targetNode: ASDisplayNode
                let targetContentRect: CGRect
                if let targetNodeForActivationProgress = strongSelf.targetNodeForActivationProgress {
                    targetNode = targetNodeForActivationProgress
                    if let targetNodeForActivationProgressContentRect = strongSelf.targetNodeForActivationProgressContentRect {
                        targetContentRect = targetNodeForActivationProgressContentRect
                    } else {
                        targetContentRect = CGRect(origin: CGPoint(), size: targetNode.bounds.size)
                    }
                } else {
                    targetNode = strongSelf
                    targetContentRect = CGRect(origin: CGPoint(), size: targetNode.bounds.size)
                }
                
                let scaleSide = targetContentRect.width
                let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
                let currentScale = 1.0 * (1.0 - progress) + minScale * progress
                
                let originalCenterOffsetX: CGFloat = targetNode.bounds.width / 2.0 - targetContentRect.midX
                let scaledCenterOffsetX: CGFloat = originalCenterOffsetX * currentScale
                
                let originalCenterOffsetY: CGFloat = targetNode.bounds.height / 2.0 - targetContentRect.midY
                let scaledCenterOffsetY: CGFloat = originalCenterOffsetY * currentScale
                
                let scaleMidX: CGFloat = scaledCenterOffsetX - originalCenterOffsetX
                let scaleMidY: CGFloat = scaledCenterOffsetY - originalCenterOffsetY
                
                switch update {
                case .update:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    targetNode.layer.sublayerTransform = sublayerTransform
                    if let additionalActivationProgressLayer = strongSelf.additionalActivationProgressLayer {
                        additionalActivationProgressLayer.transform = sublayerTransform
                    }
                case .begin:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    targetNode.layer.sublayerTransform = sublayerTransform
                    if let additionalActivationProgressLayer = strongSelf.additionalActivationProgressLayer {
                        additionalActivationProgressLayer.transform = sublayerTransform
                    }
                case .ended:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    let previousTransform = targetNode.layer.sublayerTransform
                    targetNode.layer.sublayerTransform = sublayerTransform
                    
                    targetNode.layer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                    
                    if let additionalActivationProgressLayer = strongSelf.additionalActivationProgressLayer {
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: {
                            additionalActivationProgressLayer.transform = sublayerTransform
                        })
                    }
                }
            }
        }
        contextGesture.activated = { [weak self] gesture, location in
            guard let strongSelf = self else {
                gesture.cancel()
                return
            }
            if let customActivationProgress = strongSelf.customActivationProgress {
                customActivationProgress(0.0, .ended(0.0))
            }

            if let activated = strongSelf.activated {
                activated(gesture, location)
            } else {
                gesture.cancel()
            }
        }
        contextGesture.isEnabled = self.isGestureEnabled
    }
}
