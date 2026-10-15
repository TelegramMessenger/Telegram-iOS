import UIKit
import Display

final class WalletCardStickerSelectionView: UIView {
    private let content = CALayer()
    private let border = CAShapeLayer()
    private let leftHandle = CAShapeLayer()
    private let rightHandle = CAShapeLayer()
    private var radius: CGFloat = 0
    private(set) var isShown = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.layer.addSublayer(self.content)
        self.content.opacity = 0

        self.border.lineCap = .round
        self.border.fillColor = UIColor.clear.cgColor
        self.border.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.75).cgColor
        self.border.lineWidth = 2
        self.border.shadowColor = UIColor.black.cgColor
        self.border.shadowRadius = 1
        self.border.shadowOpacity = 0.5
        self.border.shadowOffset = .zero
        self.content.addSublayer(self.border)

        let handleSize: CGFloat = 9
        for handle in [self.leftHandle, self.rightHandle] {
            handle.bounds = CGRect(x: 0, y: 0, width: handleSize, height: handleSize)
            handle.path = CGPath(ellipseIn: handle.bounds, transform: nil)
            handle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
            handle.strokeColor = UIColor.white.cgColor
            handle.lineWidth = 1 + UIScreenPixel
            self.content.addSublayer(handle)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setShown(_ shown: Bool, animated: Bool) {
        guard shown != self.isShown else { return }
        self.isShown = shown
        let from = self.content.presentation()?.opacity ?? self.content.opacity
        self.content.opacity = shown ? 1 : 0
        if animated {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = from
            fade.toValue = self.content.opacity
            fade.duration = shown ? 0.18 : 0.25
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.content.add(fade, forKey: "opacity")
            if shown {
                let grow = CABasicAnimation(keyPath: "transform.scale")
                grow.fromValue = 0.88
                grow.toValue = 1
                grow.duration = 0.22
                grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.content.add(grow, forKey: "scale")
            }
        } else {
            self.content.removeAllAnimations()
        }
    }

    func update(center: CGPoint, radius: CGFloat, angle: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.transform = .identity
        self.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        self.center = center
        self.transform = CGAffineTransform(rotationAngle: angle)
        self.content.frame = self.bounds
        if abs(radius - self.radius) > 0.01 {
            self.radius = radius
            let rect = self.bounds
            self.border.frame = rect
            self.border.path = UIBezierPath(ovalIn: rect).cgPath
            let dash = 2 * .pi * radius / 10 * 0.25
            self.border.lineDashPattern = [NSNumber(value: Double(dash)), NSNumber(value: Double(dash))]
        }
        self.leftHandle.position = CGPoint(x: 0, y: radius)
        self.rightHandle.position = CGPoint(x: radius * 2, y: radius)
        CATransaction.commit()
    }
}
