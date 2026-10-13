import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent

final class WalletTooltipComponent: Component {
    let text: String

    init(text: String) {
        self.text = text
    }

    static func ==(lhs: WalletTooltipComponent, rhs: WalletTooltipComponent) -> Bool {
        return lhs.text == rhs.text
    }

    final class View: UIView {
        private let containerView = UIView()
        private let backgroundView = UIView()
        private let backgroundGradientLayer = CAGradientLayer()
        private let arrowView = UIView()
        private let arrowGradientLayer = CAGradientLayer()
        private let arrowMaskLayer = CAShapeLayer()
        private let text = ComponentView<Empty>()
        private var arrowPosition: CGFloat = 0.0

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.backgroundView)
            self.containerView.addSubview(self.arrowView)

            self.backgroundView.clipsToBounds = true
            self.backgroundView.layer.cornerRadius = 14.0
            if #available(iOS 13.0, *) {
                self.backgroundView.layer.cornerCurve = .continuous
            }
            self.backgroundView.layer.addSublayer(self.backgroundGradientLayer)
            self.arrowView.layer.addSublayer(self.arrowGradientLayer)
            for layer in [self.backgroundGradientLayer, self.arrowGradientLayer] {
                layer.colors = [UIColor(rgb: 0x47bafe).cgColor, UIColor(rgb: 0x44b5ff).cgColor]
                layer.startPoint = CGPoint(x: 0.0, y: 0.0)
                layer.endPoint = CGPoint(x: 1.0, y: 0.0)
            }

            // The small, rounded arrow used by the original Gram tooltip.
            let arrowPath = UIBezierPath()
            arrowPath.move(to: CGPoint(x: 85.882251, y: 0.0))
            arrowPath.addCurve(to: CGPoint(x: 68.9116882, y: 7.02834833), controlPoint1: CGPoint(x: 79.5170552, y: 0.0), controlPoint2: CGPoint(x: 73.4125613, y: 2.52817247))
            arrowPath.addLine(to: CGPoint(x: 51.4264069, y: 24.5109211))
            arrowPath.addCurve(to: CGPoint(x: 34.4558441, y: 24.5109211), controlPoint1: CGPoint(x: 46.7401154, y: 29.1964866), controlPoint2: CGPoint(x: 39.1421356, y: 29.1964866))
            arrowPath.addLine(to: CGPoint(x: 16.9705627, y: 7.02834833))
            arrowPath.addCurve(to: .zero, controlPoint1: CGPoint(x: 12.4696897, y: 2.52817247), controlPoint2: CGPoint(x: 6.36519576, y: 0.0))
            arrowPath.close()
            arrowPath.apply(CGAffineTransform(scaleX: 0.333333 * 0.62, y: 0.333333 * 0.62))
            self.arrowMaskLayer.path = arrowPath.cgPath
            self.arrowMaskLayer.fillColor = UIColor.black.cgColor
            self.arrowView.layer.mask = self.arrowMaskLayer
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func updateArrowPosition(_ position: CGFloat) {
            self.arrowPosition = position
            let size = self.containerView.bounds.size
            let arrowSize = CGSize(width: 18.0, height: 7.0)
            let arrowCenter = max(arrowSize.width * 0.5, min(size.width - arrowSize.width * 0.5, position))
            let arrowFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels(arrowCenter - arrowSize.width * 0.5), y: size.height),
                size: arrowSize
            )
            ComponentTransition.immediate.setFrame(view: self.arrowView, frame: arrowFrame)
            ComponentTransition.immediate.setFrame(layer: self.arrowMaskLayer, frame: CGRect(origin: .zero, size: arrowSize))
            // Sample the same horizontal gradient as the bubble at the arrow's position.
            ComponentTransition.immediate.setFrame(layer: self.arrowGradientLayer, frame: CGRect(origin: CGPoint(x: -arrowFrame.minX, y: 0.0), size: size))
        }

        private var animationOffset: CGPoint {
            return CGPoint(
                x: self.arrowView.frame.midX - self.containerView.bounds.midX,
                y: self.arrowView.frame.maxY - self.containerView.bounds.midY
            )
        }

        func animateIn() {
            self.containerView.layer.animateSpring(from: NSNumber(value: Float(0.01)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.4, damping: 105.0)
            self.containerView.layer.animateSpring(from: NSValue(cgPoint: self.animationOffset), to: NSValue(cgPoint: .zero), keyPath: "position", duration: 0.4, damping: 105.0, additive: true)
            self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }

        func animateOut(completion: @escaping () -> Void) {
            self.containerView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            self.containerView.layer.animatePosition(from: .zero, to: self.animationOffset, duration: 0.2, removeOnCompletion: false, additive: true)
            self.containerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }

        func update(component: WalletTooltipComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.medium(11.0), textColor: .white)),
                    horizontalAlignment: .left,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, availableSize.width - 22.0), height: 10000.0)
            )
            let size = CGSize(width: textSize.width + 22.0, height: textSize.height + 12.0)
            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: size))
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            transition.setFrame(layer: self.backgroundGradientLayer, frame: CGRect(origin: .zero, size: size))
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.containerView.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: 11.0, y: 6.0), size: textSize))
            }
            self.updateArrowPosition(self.arrowPosition)
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
