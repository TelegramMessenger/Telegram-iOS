import Foundation
import UIKit
import Display
import ComponentFlow

public final class TooltipComponent: Component {
    public let content: AnyComponent<Empty>
    public let contentInsets: UIEdgeInsets
    
    public init(
        content: AnyComponent<Empty>,
        contentInsets: UIEdgeInsets = UIEdgeInsets(top: 9.0, left: 14.0, bottom: 11.0, right: 14.0)
    ) {
        self.content = content
        self.contentInsets = contentInsets
    }
    
    public static func ==(lhs: TooltipComponent, rhs: TooltipComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private let backgroundShapeLayer: SimpleShapeLayer
        private let content = ComponentView<Empty>()
        
        private var component: TooltipComponent?

        private var backgroundFrame: CGRect?
        
        public override init(frame: CGRect) {
            self.backgroundShapeLayer = SimpleShapeLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundShapeLayer)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public func updateBackground(relativeArrowTargetPosition: CGPoint) {
            guard let backgroundFrame = self.backgroundFrame else {
                return
            }

            let cornerRadius: CGFloat = 12.0
            let verticalInset: CGFloat = 9.0
            let arrowWidth: CGFloat = 18.0
            let arrowTipRadius: CGFloat = 4.0
            let arrowBaseRadius: CGFloat = 3.0
            let sqrt2inv: CGFloat = 1.0 / sqrt(2.0)

            let arrowOnBottom = relativeArrowTargetPosition.y >= backgroundFrame.height * 0.5
            let arrowPosition = max(cornerRadius + arrowWidth / 2.0, min(backgroundFrame.width - cornerRadius - arrowWidth / 2.0, relativeArrowTargetPosition.x))

            let topInset: CGFloat = arrowOnBottom ? 0.0 : verticalInset
            let bottomInset: CGFloat = arrowOnBottom ? verticalInset : 0.0
            let totalHeight = backgroundFrame.height + verticalInset

            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0.0, y: topInset + cornerRadius))
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: topInset + cornerRadius), radius: cornerRadius, startAngle: CGFloat.pi, endAngle: CGFloat(3.0 * CGFloat.pi / 2.0), clockwise: true)
            if !arrowOnBottom {
                path.addLine(to: CGPoint(x: arrowPosition - arrowWidth / 2.0 - arrowBaseRadius, y: topInset))
                path.addQuadCurve(to: CGPoint(x: arrowPosition - arrowWidth / 2.0 + arrowBaseRadius * sqrt2inv, y: topInset - arrowBaseRadius * sqrt2inv), controlPoint: CGPoint(x: arrowPosition - arrowWidth / 2.0, y: topInset))
                path.addLine(to: CGPoint(x: arrowPosition - arrowTipRadius * sqrt2inv, y: arrowTipRadius * sqrt2inv))
                path.addQuadCurve(to: CGPoint(x: arrowPosition + arrowTipRadius * sqrt2inv, y: arrowTipRadius * sqrt2inv), controlPoint: CGPoint(x: arrowPosition, y: 0.0))
                path.addLine(to: CGPoint(x: arrowPosition + arrowWidth / 2.0 - arrowBaseRadius * sqrt2inv, y: topInset - arrowBaseRadius * sqrt2inv))
                path.addQuadCurve(to: CGPoint(x: arrowPosition + arrowWidth / 2.0 + arrowBaseRadius, y: topInset), controlPoint: CGPoint(x: arrowPosition + arrowWidth / 2.0, y: topInset))
            }
            path.addLine(to: CGPoint(x: backgroundFrame.width - cornerRadius, y: topInset))
            path.addArc(withCenter: CGPoint(x: backgroundFrame.width - cornerRadius, y: topInset + cornerRadius), radius: cornerRadius, startAngle: CGFloat(3.0 * CGFloat.pi / 2.0), endAngle: 0.0, clockwise: true)
            path.addLine(to: CGPoint(x: backgroundFrame.width, y: totalHeight - bottomInset - cornerRadius))
            path.addArc(withCenter: CGPoint(x: backgroundFrame.width - cornerRadius, y: totalHeight - bottomInset - cornerRadius), radius: cornerRadius, startAngle: 0.0, endAngle: CGFloat(CGFloat.pi / 2.0), clockwise: true)
            if arrowOnBottom {
                let arrowBaseY = totalHeight - bottomInset
                path.addLine(to: CGPoint(x: arrowPosition + arrowWidth / 2.0 + arrowBaseRadius, y: arrowBaseY))
                path.addQuadCurve(to: CGPoint(x: arrowPosition + arrowWidth / 2.0 - arrowBaseRadius * sqrt2inv, y: arrowBaseY + arrowBaseRadius * sqrt2inv), controlPoint: CGPoint(x: arrowPosition + arrowWidth / 2.0, y: arrowBaseY))
                path.addLine(to: CGPoint(x: arrowPosition + arrowTipRadius * sqrt2inv, y: totalHeight - arrowTipRadius * sqrt2inv))
                path.addQuadCurve(to: CGPoint(x: arrowPosition - arrowTipRadius * sqrt2inv, y: totalHeight - arrowTipRadius * sqrt2inv), controlPoint: CGPoint(x: arrowPosition, y: totalHeight))
                path.addLine(to: CGPoint(x: arrowPosition - arrowWidth / 2.0 + arrowBaseRadius * sqrt2inv, y: arrowBaseY + arrowBaseRadius * sqrt2inv))
                path.addQuadCurve(to: CGPoint(x: arrowPosition - arrowWidth / 2.0 - arrowBaseRadius, y: arrowBaseY), controlPoint: CGPoint(x: arrowPosition - arrowWidth / 2.0, y: arrowBaseY))
            }
            path.addLine(to: CGPoint(x: cornerRadius, y: totalHeight - bottomInset))
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: totalHeight - bottomInset - cornerRadius), radius: cornerRadius, startAngle: CGFloat(CGFloat.pi / 2.0), endAngle: CGFloat.pi, clockwise: true)
            path.close()

            self.backgroundShapeLayer.path = path.cgPath
            self.backgroundShapeLayer.fillColor = UIColor(rgb: 0x2f2f2f).cgColor
            self.backgroundShapeLayer.shadowColor = UIColor.black.cgColor
            self.backgroundShapeLayer.shadowOpacity = 0.3
            self.backgroundShapeLayer.shadowRadius = 20.0
            self.backgroundShapeLayer.shadowOffset = CGSize(width: 0.0, height: 4.0)
            self.backgroundShapeLayer.shadowPath = path.cgPath

            let shapeOriginY: CGFloat = arrowOnBottom ? backgroundFrame.origin.y : backgroundFrame.origin.y - verticalInset
            self.backgroundShapeLayer.frame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x, y: shapeOriginY), size: CGSize(width: backgroundFrame.width, height: totalHeight))
        }
        
        func update(component: TooltipComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let contentSize = self.content.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: CGSize(width: availableSize.width - component.contentInsets.left - component.contentInsets.right, height: availableSize.height - component.contentInsets.top - component.contentInsets.bottom)
            )

            let backgroundSize = CGSize(width: component.contentInsets.left + component.contentInsets.right + contentSize.width, height: component.contentInsets.top + component.contentInsets.bottom + contentSize.height)
            let backgroundFrame = CGRect(origin: CGPoint(), size: backgroundSize)
            self.backgroundFrame = backgroundFrame

            let contentFrame = CGRect(origin: CGPoint(x: component.contentInsets.left, y: component.contentInsets.top), size: contentSize)
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: contentFrame)
            }
            
            return backgroundSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
