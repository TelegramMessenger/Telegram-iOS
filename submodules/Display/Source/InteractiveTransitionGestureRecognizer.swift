import Foundation
import UIKit

private enum HorizontalGestures {
    case none
    case some
    case strict
}

private func hasHorizontalGestures(_ view: UIView, point: CGPoint?) -> HorizontalGestures {
    if let disablesInteractiveTransitionGestureRecognizerNow = view.disablesInteractiveTransitionGestureRecognizerNow, disablesInteractiveTransitionGestureRecognizerNow() {
        return .strict
    }
    
    if view.disablesInteractiveTransitionGestureRecognizer {
        return .some
    }
    
    if let point = point, let test = view.interactiveTransitionGestureRecognizerTest, test(point) {
        return .some
    }
    
    if let view = view as? ListViewBackingView {
        let transform = view.transform
        let angle: Double = Double(atan2f(Float(transform.b), Float(transform.a)))
        let term1: Double = abs(angle - Double.pi / 2.0)
        let term2: Double = abs(angle + Double.pi / 2.0)
        let term3: Double = abs(angle - Double.pi * 3.0 / 2.0)
        if term1 < 0.001 || term2 < 0.001 || term3 < 0.001 {
            return .some
        }
    }
    
    if let superview = view.superview {
        return hasHorizontalGestures(superview, point: point != nil ? view.convert(point!, to: superview) : nil)
    } else {
        return .none
    }
}

public struct InteractiveTransitionGestureRecognizerDirections: OptionSet {
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let leftEdge = InteractiveTransitionGestureRecognizerDirections(rawValue: 1 << 2)
    public static let rightEdge = InteractiveTransitionGestureRecognizerDirections(rawValue: 1 << 3)
    public static let leftCenter = InteractiveTransitionGestureRecognizerDirections(rawValue: 1 << 0)
    public static let rightCenter = InteractiveTransitionGestureRecognizerDirections(rawValue: 1 << 1)
    
    public static let left: InteractiveTransitionGestureRecognizerDirections = [.leftEdge, .leftCenter]
    public static let right: InteractiveTransitionGestureRecognizerDirections = [.rightEdge, .rightCenter]
}

public enum InteractiveTransitionGestureRecognizerEdgeWidth {
    case constant(CGFloat)
    case widthMultiplier(factor: CGFloat, min: CGFloat, max: CGFloat)
}

public class InteractiveTransitionGestureRecognizer: UIPanGestureRecognizer {
    private let edgeWidth: InteractiveTransitionGestureRecognizerEdgeWidth
    private let allowedDirections: (CGPoint) -> InteractiveTransitionGestureRecognizerDirections
    
    private var validatedGesture = false
    private var firstLocation: CGPoint = CGPoint()
    private var currentAllowedDirections: InteractiveTransitionGestureRecognizerDirections = []
    
    public init(target: Any?, action: Selector?, allowedDirections: @escaping (CGPoint) -> InteractiveTransitionGestureRecognizerDirections, edgeWidth: InteractiveTransitionGestureRecognizerEdgeWidth = .constant(16.0)) {
        self.allowedDirections = allowedDirections
        self.edgeWidth = edgeWidth
        
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override public func reset() {
        super.reset()
        
        self.validatedGesture = false
        self.currentAllowedDirections = []
    }

    public func cancel() {
        self.state = .cancelled
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        let touch = touches.first!
        let point = touch.location(in: self.view)
        
        var allowedDirections = self.allowedDirections(point)
        if allowedDirections.isEmpty {
            self.state = .failed
            return
        }
        
        super.touchesBegan(touches, with: event)
        
        self.firstLocation = point
        
        if let target = self.view?.hitTest(self.firstLocation, with: event) {
            let horizontalGestures = hasHorizontalGestures(target, point: self.view?.convert(self.firstLocation, to: target))
            switch horizontalGestures {
            case .some, .strict:
                if case .strict = horizontalGestures {
                    allowedDirections = []
                } else if allowedDirections.contains(.leftEdge) || allowedDirections.contains(.rightEdge) {
                    allowedDirections.remove(.leftCenter)
                    allowedDirections.remove(.rightCenter)
                }
            case .none:
                break
            }
        }
        
        if allowedDirections.isEmpty {
            self.state = .failed
        } else {
            self.currentAllowedDirections = allowedDirections
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
        
        let absTranslationX: CGFloat = abs(translation.x)
        let absTranslationY: CGFloat = abs(translation.y)
        
        let size = self.view?.bounds.size ?? CGSize()
        
        let edgeWidth: CGFloat
        switch self.edgeWidth {
        case let .constant(value):
            edgeWidth = value
        case let .widthMultiplier(factor, minValue, maxValue):
            edgeWidth = max(minValue, min(size.width * factor, maxValue))
        }
        
        if !self.validatedGesture {
            if self.firstLocation.x < edgeWidth && !self.currentAllowedDirections.contains(.rightEdge) {
                self.state = .failed
                return
            }
            if self.firstLocation.x > size.width - edgeWidth && !self.currentAllowedDirections.contains(.leftEdge) {
                self.state = .failed
                return
            }
            
            if self.currentAllowedDirections.contains(.rightEdge) && self.firstLocation.x < edgeWidth {
                self.validatedGesture = true
            } else if self.currentAllowedDirections.contains(.leftEdge) && self.firstLocation.x > size.width - edgeWidth {
                self.validatedGesture = true
            } else if !self.currentAllowedDirections.contains(.leftCenter) && translation.x < 0.0 {
                self.state = .failed
            } else if !self.currentAllowedDirections.contains(.rightCenter) && translation.x > 0.0 {
                self.state = .failed
            } else if absTranslationY > 2.0 && absTranslationY > absTranslationX * 2.0 {
                self.state = .failed
            } else if absTranslationX > 2.0 && absTranslationY * 2.0 < absTranslationX {
                self.validatedGesture = true
            }
        }
        
        if self.validatedGesture {
            super.touchesMoved(touches, with: event)
        }
    }
}
