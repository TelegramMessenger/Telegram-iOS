import Foundation
import UIKit

extension CALayer {
    func addShakeAnimation() {
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        let duration = 0.3
        let amplitude: CGFloat = 3.0
        
        let animation = CAKeyframeAnimation(keyPath: "position.x")
        let values: [CGFloat] = [0.0, amplitude, -amplitude, amplitude, -amplitude, 0.0]
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
