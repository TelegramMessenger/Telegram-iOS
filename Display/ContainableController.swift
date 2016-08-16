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
}

public protocol ContainableController: class {
    var view: UIView! { get }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
}
