import Foundation
import UIKit
import AsyncDisplayKit

open class ContextControllerSourceNode: ContextReferenceContentNode {
    public enum ShouldBegin {
        case none
        case `default`
        case customActivationProcess
    }
    
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
    public var shouldBeginWithCustomActivationProcess: ((CGPoint) -> ShouldBegin)?
    public var customActivationProgress: ((CGFloat, ContextGestureTransition) -> Void)?
    public weak var additionalActivationProgressLayer: CALayer?
    public var targetNodeForActivationProgress: ASDisplayNode?
    public var targetNodeForActivationProgressContentRect: CGRect?
    
    private var ignoreCurrentActivationProcess: Bool = false
    
    public func cancelGesture() {
        self.contextGesture?.cancel()
        self.contextGesture?.isEnabled = false
        self.contextGesture?.isEnabled = self.isGestureEnabled
        self.ignoreCurrentActivationProcess = false
    }
    
    override open func didLoad() {
        super.didLoad()
        
        let contextGesture = ContextGesture(target: self, action: nil)
        self.contextGesture = contextGesture
        self.view.addGestureRecognizer(contextGesture)
        
        contextGesture.beginDelay = self.beginDelay
        contextGesture.isEnabled = self.isGestureEnabled
        
        contextGesture.shouldBegin = { [weak self] point in
            guard let self, !self.bounds.width.isZero else {
                return false
            }
            if let shouldBeginWithCustomActivationProcess = self.shouldBeginWithCustomActivationProcess {
                let result = shouldBeginWithCustomActivationProcess(point)
                switch result {
                case .none:
                    self.ignoreCurrentActivationProcess = false
                    return false
                case .default:
                    self.ignoreCurrentActivationProcess = false
                    return true
                case .customActivationProcess:
                    self.ignoreCurrentActivationProcess = true
                    return true
                }
            } else {
                self.ignoreCurrentActivationProcess = false
                return self.shouldBegin?(point) ?? true
            }
        }
        
        contextGesture.activationProgress = { [weak self] progress, update in
            guard let strongSelf = self, !strongSelf.bounds.width.isZero else {
                return
            }
            if let customActivationProgress = strongSelf.customActivationProgress {
                customActivationProgress(progress, update)
            } else if strongSelf.animateScale && !strongSelf.ignoreCurrentActivationProcess {
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

open class ContextControllerSourceView: UIView {
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
    public var targetViewForActivationProgress: UIView?
    public weak var targetLayerForActivationProgress: CALayer?
    public var targetNodeForActivationProgressContentRect: CGRect?
    public var useSublayerTransformForActivation: Bool = true
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isMultipleTouchEnabled = false
        self.isExclusiveTouch = true
        
        let contextGesture = ContextGesture(target: self, action: nil)
        self.contextGesture = contextGesture
        self.addGestureRecognizer(contextGesture)
        
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
                let targetLayer: CALayer
                let targetContentRect: CGRect
                if let targetNodeForActivationProgress = strongSelf.targetNodeForActivationProgress {
                    targetLayer = targetNodeForActivationProgress.layer
                    if let targetNodeForActivationProgressContentRect = strongSelf.targetNodeForActivationProgressContentRect {
                        targetContentRect = targetNodeForActivationProgressContentRect
                    } else {
                        targetContentRect = CGRect(origin: CGPoint(), size: targetLayer.bounds.size)
                    }
                } else if let targetViewForActivationProgress = strongSelf.targetViewForActivationProgress {
                    targetLayer = targetViewForActivationProgress.layer
                    if let targetNodeForActivationProgressContentRect = strongSelf.targetNodeForActivationProgressContentRect {
                        targetContentRect = targetNodeForActivationProgressContentRect
                    } else {
                        targetContentRect = CGRect(origin: CGPoint(), size: targetLayer.bounds.size)
                    }
                } else if let targetLayerForActivationProgress = strongSelf.targetLayerForActivationProgress {
                    targetLayer = targetLayerForActivationProgress
                    if let targetNodeForActivationProgressContentRect = strongSelf.targetNodeForActivationProgressContentRect {
                        targetContentRect = targetNodeForActivationProgressContentRect
                    } else {
                        targetContentRect = CGRect(origin: CGPoint(), size: targetLayer.bounds.size)
                    }
                } else {
                    targetLayer = strongSelf.layer
                    targetContentRect = CGRect(origin: CGPoint(), size: targetLayer.bounds.size)
                }
                
                let scaleSide = targetContentRect.width
                let minScale: CGFloat = max(0.7, (scaleSide - 15.0) / scaleSide)
                let currentScale = 1.0 * (1.0 - progress) + minScale * progress
                
                let originalCenterOffsetX: CGFloat = targetLayer.bounds.width / 2.0 - targetContentRect.midX
                let scaledCenterOffsetX: CGFloat = originalCenterOffsetX * currentScale
                
                let originalCenterOffsetY: CGFloat = targetLayer.bounds.height / 2.0 - targetContentRect.midY
                let scaledCenterOffsetY: CGFloat = originalCenterOffsetY * currentScale
                
                let scaleMidX: CGFloat = scaledCenterOffsetX - originalCenterOffsetX
                let scaleMidY: CGFloat = scaledCenterOffsetY - originalCenterOffsetY
                
                switch update {
                case .update:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    if strongSelf.useSublayerTransformForActivation {
                        targetLayer.sublayerTransform = sublayerTransform
                    } else {
                        targetLayer.transform = sublayerTransform
                    }
                    if let additionalActivationProgressLayer = strongSelf.additionalActivationProgressLayer {
                        additionalActivationProgressLayer.transform = sublayerTransform
                    }
                case .begin:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    if strongSelf.useSublayerTransformForActivation {
                        targetLayer.sublayerTransform = sublayerTransform
                    } else {
                        targetLayer.transform = sublayerTransform
                    }
                    if let additionalActivationProgressLayer = strongSelf.additionalActivationProgressLayer {
                        additionalActivationProgressLayer.transform = sublayerTransform
                    }
                case .ended:
                    let sublayerTransform = CATransform3DTranslate(CATransform3DScale(CATransform3DIdentity, currentScale, currentScale, 1.0), scaleMidX, scaleMidY, 0.0)
                    
                    if strongSelf.useSublayerTransformForActivation {
                        let previousTransform = targetLayer.sublayerTransform
                        targetLayer.sublayerTransform = sublayerTransform
                        
                        targetLayer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                    } else {
                        let previousTransform = targetLayer.transform
                        targetLayer.transform = sublayerTransform
                        
                        targetLayer.animate(from: NSValue(caTransform3D: previousTransform), to: NSValue(caTransform3D: sublayerTransform), keyPath: "transform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                    }
                    
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
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func cancelGesture() {
        self.contextGesture?.cancel()
        self.contextGesture?.isEnabled = false
        self.contextGesture?.isEnabled = self.isGestureEnabled
    }
}
