import UIKit
import AsyncDisplayKit

public enum ContainedViewLayoutTransitionCurve {
    case easeInOut
    case spring
}

public extension ContainedViewLayoutTransitionCurve {
    var timingFunction: String {
        switch self {
            case .easeInOut:
                return kCAMediaTimingFunctionEaseInEaseOut
            case .spring:
                return kCAMediaTimingFunctionSpring
        }
    }
}

public enum ContainedViewLayoutTransition {
    case immediate
    case animated(duration: Double, curve: ContainedViewLayoutTransitionCurve)
}

public extension ContainedViewLayoutTransition {
    func updateFrame(node: ASDisplayNode, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        switch self {
            case .immediate:
                node.frame = frame
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousFrame = node.frame
                node.frame = frame
                node.layer.animateFrame(from: previousFrame, to: frame, duration: duration, timingFunction: curve.timingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
    
    func animateOffsetAdditive(node: ASDisplayNode, offset: CGFloat) {
        switch self {
            case .immediate:
                break
            case let .animated(duration, curve):
                let timingFunction: String
                switch curve {
                    case .easeInOut:
                        timingFunction = kCAMediaTimingFunctionEaseInEaseOut
                    case .spring:
                        timingFunction = kCAMediaTimingFunctionSpring
                }
                node.layer.animateBoundsOriginYAdditive(from: offset, to: 0.0, duration: duration, timingFunction: timingFunction)
                break
        }
    }
    
    func updateFrame(layer: CALayer, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        switch self {
            case .immediate:
                layer.frame = frame
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousFrame = layer.frame
                layer.frame = frame
                layer.animateFrame(from: previousFrame, to: frame, duration: duration, timingFunction: curve.timingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
    
    func updateAlpha(node: ASDisplayNode, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        switch self {
            case .immediate:
                node.alpha = alpha
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousAlpha = node.alpha
                node.alpha = alpha
                node.layer.animateAlpha(from: previousAlpha, to: alpha, duration: duration, timingFunction: curve.timingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
}

public protocol ContainableController: class {
    var view: UIView! { get }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
}
