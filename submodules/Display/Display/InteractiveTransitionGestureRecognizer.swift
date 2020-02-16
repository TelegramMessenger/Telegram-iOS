import Foundation
import UIKit

private func hasHorizontalGestures(_ view: UIView, point: CGPoint?) -> Bool {
    if view.disablesInteractiveTransitionGestureRecognizer {
        return true
    }
    if let disablesInteractiveTransitionGestureRecognizerNow = view.disablesInteractiveTransitionGestureRecognizerNow, disablesInteractiveTransitionGestureRecognizerNow() {
        return true
    }
    
    if let point = point, let test = view.interactiveTransitionGestureRecognizerTest, test(point) {
        return true
    }
    
    if let view = view as? ListViewBackingView {
        let transform = view.transform
        let angle: Double = Double(atan2f(Float(transform.b), Float(transform.a)))
        let term1: Double = abs(angle - Double.pi / 2.0)
        let term2: Double = abs(angle + Double.pi / 2.0)
        let term3: Double = abs(angle - Double.pi * 3.0 / 2.0)
        if term1 < 0.001 || term2 < 0.001 || term3 < 0.001 {
            return true
        }
    }
    
    if let superview = view.superview {
        return hasHorizontalGestures(superview, point: point != nil ? view.convert(point!, to: superview) : nil)
    } else {
        return false
    }
}

public struct InteractiveTransitionGestureRecognizerDirections: OptionSet {
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let left = InteractiveTransitionGestureRecognizerDirections(rawValue: 1 << 0)
    public static let right = InteractiveTransitionGestureRecognizerDirections(rawValue: 1 << 1)
}

public class InteractiveTransitionGestureRecognizer: UIPanGestureRecognizer {
    private let allowedDirections: () -> InteractiveTransitionGestureRecognizerDirections
    
    private var validatedGesture = false
    private var firstLocation: CGPoint = CGPoint()
    private var currentAllowedDirections: InteractiveTransitionGestureRecognizerDirections = []
    
    public init(target: Any?, action: Selector?, allowedDirections: @escaping () -> InteractiveTransitionGestureRecognizerDirections) {
        self.allowedDirections = allowedDirections
        
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override public func reset() {
        super.reset()
        
        self.validatedGesture = false
        self.currentAllowedDirections = []
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        self.currentAllowedDirections = self.allowedDirections()
        if self.currentAllowedDirections.isEmpty {
            self.state = .failed
            return
        }
        
        super.touchesBegan(touches, with: event)
        
        let touch = touches.first!
        self.firstLocation = touch.location(in: self.view)
        
        if let target = self.view?.hitTest(self.firstLocation, with: event) {
            if hasHorizontalGestures(target, point: self.view?.convert(self.firstLocation, to: target)) {
                self.state = .cancelled
            }
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - firstLocation.x, y: location.y - firstLocation.y)
        
        let absTranslationX: CGFloat = abs(translation.x)
        let absTranslationY: CGFloat = abs(translation.y)
        
        if !self.validatedGesture {
            if self.currentAllowedDirections.contains(.right) && self.firstLocation.x < 16.0 {
                self.validatedGesture = true
            } else if !self.currentAllowedDirections.contains(.left) && translation.x < 0.0 {
                self.state = .failed
            } else if !self.currentAllowedDirections.contains(.right) && translation.x > 0.0 {
                self.state = .failed
            } else if absTranslationY > 2.0 && absTranslationY > absTranslationX * 2.0 {
                self.state = .failed
            } else if absTranslationX > 2.0 && absTranslationY * 2.0 < absTranslationX {
                self.validatedGesture = true
            }
        }
        
        if validatedGesture {
            super.touchesMoved(touches, with: event)
        }
    }
}
