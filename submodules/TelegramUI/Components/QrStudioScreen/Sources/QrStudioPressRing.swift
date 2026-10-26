import Foundation
import UIKit
import Display

final class QrStudioPressRing {
    static let lineWidth: CGFloat = 2.0
    static let gap: CGFloat = 2.0
    private static let duration: Double = 0.2

    let layer = CAShapeLayer()
    private var isSelected: Bool?

    init() {
        self.layer.fillColor = nil
        self.layer.lineWidth = 0.0
    }

    static func pressedScale(side: CGFloat) -> CGFloat {
        guard side > 0.0 else {
            return 1.0
        }
        return max(0.0, side - (QrStudioPressRing.lineWidth + QrStudioPressRing.gap) * 2.0) / side
    }

    private func path(size: CGSize, cornerRadius: CGFloat?, inset: CGFloat) -> CGPath {
        let rect = CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset)
        if let cornerRadius {
            return UIBezierPath(roundedRect: rect, cornerRadius: max(0.0, cornerRadius - inset)).cgPath
        }
        return UIBezierPath(ovalIn: rect).cgPath
    }

    func update(frame: CGRect, cornerRadius: CGFloat?, color: UIColor, isSelected: Bool, target: CALayer?, animated: Bool) {
        let wasSelected = self.isSelected ?? false
        self.isSelected = isSelected
        let animates = animated && wasSelected != isSelected

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.layer.frame = frame
        self.layer.strokeColor = color.cgColor
        let lineWidth = isSelected ? QrStudioPressRing.lineWidth : 0.0
        let path = self.path(size: frame.size, cornerRadius: cornerRadius, inset: isSelected ? QrStudioPressRing.lineWidth * 0.5 : 0.0)
        let previousPath = self.layer.presentation()?.path ?? self.layer.path
        let previousLineWidth = self.layer.presentation()?.lineWidth ?? self.layer.lineWidth
        self.layer.path = path
        self.layer.lineWidth = lineWidth

        let scale = isSelected ? QrStudioPressRing.pressedScale(side: min(frame.width, frame.height)) : 1.0
        var previousScale: CGFloat = 1.0
        if let target {
            previousScale = (target.presentation()?.value(forKeyPath: "transform.scale") as? CGFloat) ?? (target.value(forKeyPath: "transform.scale") as? CGFloat) ?? 1.0
            target.transform = CATransform3DMakeScale(scale, scale, 1.0)
        }
        CATransaction.commit()

        guard animates else {
            return
        }
        let timing = CAMediaTimingFunctionName.easeInEaseOut.rawValue
        if let previousPath {
            self.layer.animate(from: previousPath, to: path, keyPath: "path", timingFunction: timing, duration: QrStudioPressRing.duration)
        }
        self.layer.animate(from: previousLineWidth as NSNumber, to: lineWidth as NSNumber, keyPath: "lineWidth", timingFunction: timing, duration: QrStudioPressRing.duration)
        target?.animate(from: previousScale as NSNumber, to: scale as NSNumber, keyPath: "transform.scale", timingFunction: timing, duration: QrStudioPressRing.duration)
    }
}
