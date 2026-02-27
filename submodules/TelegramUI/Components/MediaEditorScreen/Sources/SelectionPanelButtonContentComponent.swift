import Foundation
import UIKit
import Display
import ComponentFlow

final class SelectionPanelButtonContentComponent: Component {
    let count: Int32
    let isSelected: Bool
    let tag: AnyObject?
    
    init(
        count: Int32,
        isSelected: Bool,
        tag: AnyObject?
    ) {
        self.count = count
        self.isSelected = isSelected
        self.tag = tag
    }
    
    static func ==(lhs: SelectionPanelButtonContentComponent, rhs: SelectionPanelButtonContentComponent) -> Bool {
        return lhs.count == rhs.count && lhs.isSelected == rhs.isSelected
    }
    
    final class View: UIView, ComponentTaggedView {
        private var component: SelectionPanelButtonContentComponent?
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        let backgroundView: BlurredBackgroundView
        private let outline = SimpleLayer()
        private let icon = SimpleLayer()
        private let label = ComponentView<Empty>()
        
        init() {
            self.backgroundView = BlurredBackgroundView(color: UIColor(white: 0.2, alpha: 0.45), enableBlur: true)
            self.icon.opacity = 0.0
            
            super.init(frame: CGRect())
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.icon)
            self.layer.addSublayer(self.outline)
            
            self.outline.contents = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                let lineWidth: CGFloat = 2.0 - UIScreenPixel
                context.setLineWidth(lineWidth)
                context.setStrokeColor(UIColor.white.cgColor)
                context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
            })?.cgImage
            
            self.icon.contents = generateImage(CGSize(width: 33.0, height: 33.0), rotatedContext: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                let lineWidth: CGFloat = 2.0 - UIScreenPixel
                context.setLineWidth(lineWidth)
                context.setStrokeColor(UIColor.white.cgColor)
                
                context.move(to: CGPoint(x: 11.0, y: 11.0))
                context.addLine(to: CGPoint(x: size.width - 11.0, y: size.height - 11.0))
                context.strokePath()
                
                context.move(to: CGPoint(x: size.width - 11.0, y: 11.0))
                context.addLine(to: CGPoint(x: 11.0, y: size.height - 11.0))
                context.strokePath()
            })?.cgImage
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: SelectionPanelButtonContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            let size = CGSize(width: 33.0, height: 33.0)
            let backgroundFrame = CGRect(origin: .zero, size: size)
            
            self.backgroundView.frame = backgroundFrame
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.width / 2.0, transition: .immediate)
            
            self.icon.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.icon.bounds = CGRect(origin: .zero, size: size)
            
            self.outline.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.outline.bounds = CGRect(origin: .zero, size: size)
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(
                    Text(
                        text: "\(component.count)",
                        font: Font.with(size: 18.0, design: .round, weight: .semibold),
                        color: .white
                    )
                ),
                environment: {},
                containerSize: size
            )
            let labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    self.addSubview(labelView)
                }
                labelView.center = labelFrame.center
                labelView.bounds = CGRect(origin: .zero, size: labelFrame.size)
            }
            
            if (previousComponent?.isSelected ?? false) != component.isSelected {
                let changeTransition: ComponentTransition = .easeInOut(duration: 0.2)
                changeTransition.setAlpha(layer: self.icon, alpha: component.isSelected ? 1.0 : 0.0)
                changeTransition.setTransform(layer: self.icon, transform: !component.isSelected ? CATransform3DMakeRotation(.pi / 4.0, 0.0, 0.0, 1.0) : CATransform3DIdentity)
                if let labelView = self.label.view {
                    changeTransition.setAlpha(view: labelView, alpha: component.isSelected ? 0.0 : 1.0)
                    changeTransition.setTransform(view: labelView, transform: component.isSelected ? CATransform3DMakeRotation(-.pi / 4.0, 0.0, 0.0, 1.0) : CATransform3DIdentity)
                }
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
