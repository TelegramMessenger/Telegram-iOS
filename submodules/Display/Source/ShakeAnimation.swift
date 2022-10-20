import Foundation
import UIKit

// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public extension CALayer {
    func addShakeAnimation(amplitude: CGFloat = 3.0, duration: Double = 0.3, count: Int = 4, decay: Bool = false) {
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
                
        let animation = CAKeyframeAnimation(keyPath: "position.x")
        var values: [CGFloat] = []
        values.append(0.0)
        for i in 0 ..< count {
            let sign: CGFloat = (i % 2 == 0) ? 1.0 : -1.0
            let multiplier = decay ? 1.0 / CGFloat(i + 1) : 1.0
            values.append(amplitude * sign * multiplier)
        }
        values.append(0.0)
        animation.values = values.map { ($0 as NSNumber) as AnyObject }
        var keyTimes: [NSNumber] = []
        for i in 0 ..< values.count {
            if i == 0 {
                keyTimes.append(0.0)
            } else if i == values.count - 1 {
                keyTimes.append(1.0)
            } else {
                keyTimes.append((Double(i) / Double(values.count - 1)) as NSNumber)
            }
        }
        animation.keyTimes = keyTimes
        animation.speed = speed
        animation.duration = duration
        animation.isAdditive = true
        
        self.add(animation, forKey: "shake")
    }
}
