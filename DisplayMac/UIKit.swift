import Foundation
import QuartzCore

public struct UIEdgeInsets: Equatable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat
    
    public init() {
        self.top = 0.0
        self.left = 0.0
        self.bottom = 0.0
        self.right = 0.0
    }
    
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
    
    public static func ==(lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> Bool {
        if !lhs.top.isEqual(to: rhs.top) {
            return false
        }
        if !lhs.left.isEqual(to: rhs.left) {
            return false
        }
        if !lhs.bottom.isEqual(to: rhs.bottom) {
            return false
        }
        if !lhs.right.isEqual(to: rhs.right) {
            return false
        }
        return true
    }
}

public final class UIColor: NSObject {
    let cgColor: CGColor
    
    init(rgb: Int32) {
        preconditionFailure()
    }
    
    init(cgColor: CGColor) {
        self.cgColor = cgColor
    }
}

open class CASeeThroughTracingLayer: CALayer {
    
}

open class CASeeThroughTracingView: UIView {
    
}

func makeSpringAnimation(_ keyPath: String) -> CABasicAnimation {
    return CABasicAnimation(keyPath: keyPath)
}

func makeSpringBounceAnimation(_ keyPath: String, _ initialVelocity: CGFloat, _ damping: CGFloat) -> CABasicAnimation {
    return CABasicAnimation(keyPath: keyPath)
}

func springAnimationValueAt(_ animation: CABasicAnimation, _ t: CGFloat) -> CGFloat {
    return t
}
