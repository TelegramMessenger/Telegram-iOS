import Foundation
import AsyncDisplayKit
import Display

public final class ContextControllerSourceNode: ASDisplayNode {
    private var contextGesture: ContextGesture?
    
    public var isGestureEnabled: Bool = true {
        didSet {
            self.contextGesture?.isEnabled = self.isGestureEnabled
        }
    }
    public var activated: ((ContextGesture) -> Void)?
    public var shouldBegin: ((CGPoint) -> Bool)?
    public var customActivationProgress: ((CGFloat, ContextGestureTransition) -> Void)?
    
    override public func didLoad() {
        super.didLoad()
        
        let contextGesture = ContextGesture(target: self, action: nil)
        self.contextGesture = contextGesture
        self.view.addGestureRecognizer(contextGesture)
        
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
            } else {
                let minScale: CGFloat = (strongSelf.bounds.width - 10.0) / strongSelf.bounds.width
                let currentScale = 1.0 * (1.0 - progress) + minScale * progress
                switch update {
                case .update:
                    strongSelf.layer.sublayerTransform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
                case .begin:
                    strongSelf.layer.sublayerTransform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
                case let .ended(previousProgress):
                    let previousScale = 1.0 * (1.0 - previousProgress) + minScale * previousProgress
                    strongSelf.layer.sublayerTransform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
                    strongSelf.layer.animateSpring(from: previousScale as NSNumber, to: currentScale as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.5, delay: 0.0, initialVelocity: 0.0, damping: 90.0)
                }
            }
        }
        contextGesture.activated = { [weak self] gesture in
            if let activated = self?.activated {
                activated(gesture)
            } else {
                gesture.cancel()
            }
        }
        contextGesture.isEnabled = self.isGestureEnabled
    }
}
