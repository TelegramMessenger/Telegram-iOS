import Foundation
import UIKit
import Display

final class GlassHighlightGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var highlightContainerView: UIView?
    
    private var touchEffect: TouchEffect?
    private var initialTouchLocation: CGPoint?
    weak var touchEffectView: UIView?
    var parameters = TouchEffect.Parameters() {
        didSet {
            self.touchEffect?.setParameters(self.parameters, animated: false)
        }
    }
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
        self.cancelsTouchesInView = false
        self.delaysTouchesBegan = false
        self.delaysTouchesEnded = false
        self.requiresExclusiveTouchType = false
    }
    
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override func reset() {
        if let touchEffect = self.touchEffect {
            touchEffect.setIsTracking(false)
        }
        
        self.touchEffect = nil
        self.initialTouchLocation = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let view = self.touchEffectView ?? self.view, let touch = touches.first {
            let touchLocation = touch.location(in: view)
            let touchEffect = TouchEffect(view: view, highlightContainerView: self.highlightContainerView)
            touchEffect.setParameters(self.parameters, animated: false)
            if let highlightContainerView = self.highlightContainerView {
                touchEffect.setTouchLocation(touch.location(in: highlightContainerView), animated: false)
            }
            touchEffect.setStretchVector(.zero, animated: false)
            self.touchEffect = touchEffect
            self.initialTouchLocation = touchLocation
            touchEffect.setIsTracking(true)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touchEffect = self.touchEffect {
            touchEffect.setIsTracking(false)
        }
        self.touchEffect = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touchEffect = self.touchEffect {
            touchEffect.setIsTracking(false)
        }
        self.touchEffect = nil
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touchEffect = self.touchEffect,
              let view = self.touchEffectView ?? self.view,
              let touch = touches.first,
              let initialTouchLocation = self.initialTouchLocation else {
            return
        }
        let touchLocation = touch.location(in: view)
        if let highlightContainerView = self.highlightContainerView {
            touchEffect.setTouchLocation(touch.location(in: highlightContainerView), animated: false)
        }
        touchEffect.setStretchVector(
            CGPoint(
                x: touchLocation.x - initialTouchLocation.x,
                y: touchLocation.y - initialTouchLocation.y
            ),
            animated: false
        )
    }
}

final class TouchEffect {
    private struct State: Equatable {
        var isTracking: Bool
        var stretchVector: CGPoint
        var touchLocation: CGPoint?
    }

    struct SpringParameters {
        var mass: CGFloat
        var stiffness: CGFloat
        var damping: CGFloat
        var initialVelocity: CGFloat
    }

    struct Parameters {
        var liftOn = SpringParameters(
            mass: 1.36,
            stiffness: 568.0,
            damping: 39.7,
            initialVelocity: 0.0
        )
        var liftOff = SpringParameters(
            mass: 2.0,
            stiffness: 460.0,
            damping: 21.8,
            initialVelocity: 0.0
        )
        var pressedSizeIncrease: CGFloat = 20.0
    }

    private weak var view: UIView?
    private weak var highlightContainerView: UIView?
    private let radialHighlightLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.type = .radial
        
        let baseGradientAlpha: CGFloat = 0.5
        let numSteps = 8
        let firstStep = 1
        let firstLocation = 0.5
        let colors = (0 ..< numSteps).map { i -> UIColor in
            if i < firstStep {
                return UIColor(white: 1.0, alpha: 1.0)
            } else {
                let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
            }
        }
        let locations = (0 ..< numSteps).map { i -> CGFloat in
            if i < firstStep {
                return 0.0
            } else {
                let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                return (firstLocation + (1.0 - firstLocation) * step)
            }
        }
        
        layer.colors = colors.map(\.cgColor)
        layer.locations = locations.map { $0 as NSNumber }
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.opacity = 0.0
        layer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "opacity": NSNull()
        ]
        return layer
    }()
    private var state = State(isTracking: false, stretchVector: .zero, touchLocation: nil)
    private var appliedState: State?

    var parameters = Parameters()

    init(view: UIView, highlightContainerView: UIView?) {
        self.view = view
        self.highlightContainerView = highlightContainerView
        
        if let highlightContainerView {
            highlightContainerView.layer.addSublayer(self.radialHighlightLayer)
        }
    }
    
    deinit {
        self.radialHighlightLayer.removeFromSuperlayer()
    }

    private func currentTransform(for state: State, view: UIView) -> CATransform3D {
        let referenceView = self.highlightContainerView ?? view
        let viewWidth = max(1.0, referenceView.bounds.width)
        let viewHeight = max(1.0, referenceView.bounds.height)
        let aspectRatio = viewWidth / viewHeight

        let baseScaleX: CGFloat
        let baseScaleY: CGFloat
        if state.isTracking {
            if viewWidth < viewHeight {
                baseScaleY = 1.0 + self.parameters.pressedSizeIncrease / viewHeight
                baseScaleX = baseScaleY
            } else {
                baseScaleX = 1.0 + self.parameters.pressedSizeIncrease / viewWidth
                baseScaleY = baseScaleX
            }
        } else {
            baseScaleX = 1.0
            baseScaleY = 1.0
        }

        guard state.isTracking else {
            return CATransform3DScale(CATransform3DIdentity, baseScaleX, baseScaleY, 1.0)
        }

        let stretchVector = state.stretchVector
        let adjustedX = stretchVector.x / aspectRatio
        let length = sqrt(pow(adjustedX, 2) + pow(stretchVector.y, 2))

        guard length != 0.0 else {
            return CATransform3DScale(CATransform3DIdentity, baseScaleX, baseScaleY, 1.0)
        }

        let normal = CGPoint(
            x: adjustedX / length,
            y: stretchVector.y / length
        )
        let k: CGFloat = -1.0 / ((length / viewHeight) / (5.0 * aspectRatio) + 1.0) + 1.0
        let additionalMaxScale = (viewHeight + 16.0 / aspectRatio) / viewHeight - 1.0
        let t = additionalMaxScale * k * aspectRatio
        let maxOffset: CGFloat = 24.0

        if abs(normal.x) > abs(normal.y) {
            let diff = abs(normal.x) - abs(normal.y)
            var transform = CATransform3DIdentity
            transform.m11 = baseScaleX * (1.0 + t * diff)
            transform.m22 = baseScaleY * (1.0 / (1.0 + t * diff))
            transform.m41 = normal.x * maxOffset * k
            transform.m42 = normal.y * maxOffset * k
            return transform
        } else {
            let diff = abs(normal.y) - abs(normal.x)
            var transform = CATransform3DIdentity
            transform.m11 = baseScaleX * (1.0 / (1.0 + t * diff))
            transform.m22 = baseScaleY * (1.0 + t * diff)
            transform.m41 = normal.x * maxOffset * k
            transform.m42 = normal.y * maxOffset * k
            return transform
        }
    }

    private func currentSpringParameters(from previousState: State?, to state: State) -> SpringParameters {
        guard let previousState, previousState != state else {
            return state.isTracking ? self.parameters.liftOn : self.parameters.liftOff
        }
        if !previousState.isTracking && state.isTracking {
            return self.parameters.liftOn
        } else {
            return self.parameters.liftOff
        }
    }
    
    private func updateRadialHighlight(animated: Bool) {
        guard self.highlightContainerView != nil else {
            return
        }
        
        let baseAlpha: Float = 0.1
        let targetOpacity: Float = self.state.isTracking ? baseAlpha : 0.0
        let size = CGSize(width: 300.0, height: 300.0)
        if let touchLocation = self.state.touchLocation {
            self.radialHighlightLayer.bounds = CGRect(origin: CGPoint(), size: size)
            self.radialHighlightLayer.position = touchLocation
        }
        
        if animated {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = self.radialHighlightLayer.presentation()?.opacity ?? self.radialHighlightLayer.opacity
            self.radialHighlightLayer.opacity = targetOpacity
            animation.toValue = targetOpacity
            animation.duration = self.state.isTracking ? 0.12 : 0.22
            animation.timingFunction = CAMediaTimingFunction(name: self.state.isTracking ? .easeOut : .easeInEaseOut)
            self.radialHighlightLayer.add(animation, forKey: "opacity")
        } else {
            self.radialHighlightLayer.opacity = targetOpacity
        }
    }

    func applyCurrentTransform(animated: Bool = true) {
        guard let view = self.view else {
            return
        }

        let targetTransform = self.currentTransform(for: self.state, view: view)

        if !animated {
            view.layer.removeAnimation(forKey: "sublayerTransform")
            view.layer.sublayerTransform = targetTransform
            self.updateRadialHighlight(animated: false)
            self.appliedState = self.state
            return
        }

        let springParameters = self.currentSpringParameters(from: self.appliedState, to: self.state)
        let animation = CASpringAnimation(keyPath: "sublayerTransform")
        animation.fromValue = NSValue(caTransform3D: view.layer.presentation()?.sublayerTransform ?? view.layer.sublayerTransform)
        animation.toValue = NSValue(caTransform3D: targetTransform)
        animation.mass = springParameters.mass
        animation.stiffness = springParameters.stiffness
        animation.damping = springParameters.damping
        animation.initialVelocity = springParameters.initialVelocity
        animation.duration = animation.settlingDuration
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false

        view.layer.sublayerTransform = targetTransform
        view.layer.add(animation, forKey: "sublayerTransform")
        self.updateRadialHighlight(animated: true)
        self.appliedState = self.state
    }

    func setParameters(_ parameters: Parameters, animated: Bool = false) {
        self.parameters = parameters
        self.applyCurrentTransform(animated: animated)
    }

    func setIsTracking(_ value: Bool, animated: Bool = true) {
        let nextState = State(
            isTracking: value,
            stretchVector: value ? self.state.stretchVector : .zero,
            touchLocation: value ? self.state.touchLocation : self.state.touchLocation
        )
        guard self.state != nextState else {
            return
        }
        self.state = nextState
        self.applyCurrentTransform(animated: animated)
    }

    func setTouchLocation(_ touchLocation: CGPoint, animated: Bool = false) {
        let nextState = State(isTracking: self.state.isTracking, stretchVector: self.state.stretchVector, touchLocation: touchLocation)
        guard self.state != nextState else {
            return
        }
        self.state = nextState
        self.applyCurrentTransform(animated: animated)
    }

    func setStretchVector(_ stretchVector: CGPoint, animated: Bool = false) {
        let nextState = State(isTracking: self.state.isTracking, stretchVector: stretchVector, touchLocation: self.state.touchLocation)
        guard self.state != nextState else {
            return
        }
        self.state = nextState
        self.applyCurrentTransform(animated: animated)
    }
}
