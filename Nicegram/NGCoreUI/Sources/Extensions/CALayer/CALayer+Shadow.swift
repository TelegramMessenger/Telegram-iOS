import CoreGraphics
import QuartzCore
import UIKit

public extension CALayer {
    func applyShadow(color: UIColor, alpha: Float, x: CGFloat, y: CGFloat, blur: CGFloat) {
        self.masksToBounds = false
        self.shadowColor = color.cgColor
        self.shadowOpacity = alpha
        self.shadowOffset = CGSize(width: x, height: y)
        self.shadowRadius = blur / 2
    }
}
