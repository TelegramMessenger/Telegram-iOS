import Foundation
import UIKit

struct ViewportItemSpring {
    let stiffness: CGFloat
    let damping: CGFloat
    let mass: CGFloat
    var velocity: CGFloat = 0.0
    
    init(stiffness: CGFloat, damping: CGFloat, mass: CGFloat) {
        self.stiffness = stiffness
        self.damping = damping
        self.mass = mass
    }
}

private func a(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 1.0 - 3.0 * a2 + 3.0 * a1
}

private func b(_ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 3.0 * a2 - 6.0 * a1
}

private func c(_ a1: CGFloat) -> CGFloat
{
    return 3.0 * a1
}

private func calcBezier(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return ((a(a1, a2)*t + b(a1, a2))*t + c(a1)) * t
}

private func calcSlope(_ t: CGFloat, _ a1: CGFloat, _ a2: CGFloat) -> CGFloat
{
    return 3.0 * a(a1, a2) * t * t + 2.0 * b(a1, a2) * t + c(a1)
}

private func getTForX(_ x: CGFloat, _ x1: CGFloat, _ x2: CGFloat) -> CGFloat {
    var t = x
    var i = 0
    while i < 4 {
        let currentSlope = calcSlope(t, x1, x2)
        if currentSlope == 0.0 {
            return t
        } else {
            let currentX = calcBezier(t, x1, x2) - x
            t -= currentX / currentSlope
        }
        
        i += 1
    }
    
    return t
}

public func bezierPoint(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat) -> CGFloat
{
    var value = calcBezier(getTForX(x, x1, x2), y1, y2)
    if value >= 0.997 {
        value = 1.0
    }
    return value
}
