import Foundation
import UIKit
import Display
import ComponentFlow

public final class TimeoutContentComponent: Component {
    public let color: UIColor
    public let accentColor: UIColor
    public let isSelected: Bool
    public let value: String
    
    public init(
        color: UIColor,
        accentColor: UIColor,
        isSelected: Bool,
        value: String
    ) {
        self.color = color
        self.accentColor = accentColor
        self.isSelected = isSelected
        self.value = value
    }
    
    public static func ==(lhs: TimeoutContentComponent, rhs: TimeoutContentComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: TimeoutContentComponent?
        private weak var state: EmptyComponentState?
                
        private let background: UIImageView
        private let foreground: UIImageView
        private let text = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            self.background = UIImageView(image: UIImage(bundleImageName: "Media Editor/Timeout"))
            self.foreground = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.background)
            self.addSubview(self.foreground)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: TimeoutContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let size = CGSize(width: 20.0, height: 20.0)
            if previousComponent?.accentColor != component.accentColor {
                self.foreground.image = generateFilledCircleImage(diameter: size.width, color: component.accentColor)
            }
            
            var updated = false
            if let previousComponent {
                if previousComponent.isSelected != component.isSelected {
                    updated = true
                }
                if previousComponent.value != component.value {
                    if let textView = self.text.view, let snapshotView = textView.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = textView.frame
                        self.addSubview(snapshotView)
                        snapshotView.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: -3.0), duration: 0.2, removeOnCompletion: false, additive: true)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                            snapshotView.removeFromSuperview()
                        })
                        
                        textView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        textView.layer.animatePosition(from: CGPoint(x: 0.0, y: 3.0), to: .zero, duration: 0.2, additive: true)
                    }
                }
            }
                        
            let fontSize: CGFloat
            let textOffset: CGFloat
            if component.value.count == 1 {
                fontSize = 12.0
                textOffset = UIScreenPixel
            } else {
                fontSize = 10.0
                textOffset = -UIScreenPixel
            }
            
            let font = Font.with(size: fontSize, design: .round, weight: .semibold)
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.value, font: font, color: .white)),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                let textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0) + UIScreenPixel, y: floorToScreenPixels((size.height - textSize.height) / 2.0) + textOffset), size: textSize)
                transition.setPosition(view: textView, position: textFrame.center)
                textView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            }
            
            self.background.frame = CGRect(origin: .zero, size: size)
            
            self.foreground.bounds = CGRect(origin: .zero, size: size)
            self.foreground.center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            
            let foregroundTransition: Transition = updated ? .easeInOut(duration: 0.2) : transition
            foregroundTransition.setScale(view: self.foreground, scale: component.isSelected ? 1.0 : 0.001)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
