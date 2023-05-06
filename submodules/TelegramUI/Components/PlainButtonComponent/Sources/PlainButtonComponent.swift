import Foundation
import UIKit
import Display
import ComponentFlow

public final class PlainButtonComponent: Component {
    public enum EffectAlignment {
        case left
        case right
    }
    
    public let content: AnyComponent<Empty>
    public let effectAlignment: EffectAlignment
    public let action: () -> Void
    
    public init(
        content: AnyComponent<Empty>,
        effectAlignment: EffectAlignment,
        action: @escaping () -> Void
    ) {
        self.content = content
        self.effectAlignment = effectAlignment
        self.action = action
    }

    public static func ==(lhs: PlainButtonComponent, rhs: PlainButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.effectAlignment != rhs.effectAlignment {
            return false
        }
        return true
    }

    public final class View: HighlightTrackingButton {
        private var component: PlainButtonComponent?
        private weak var componentState: EmptyComponentState?

        private let contentContainer = UIView()
        private let content = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.contentContainer.isUserInteractionEnabled = false
            self.addSubview(self.contentContainer)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                    
                    if highlighted {
                        self.contentContainer.layer.removeAnimation(forKey: "opacity")
                        self.contentContainer.layer.removeAnimation(forKey: "sublayerTransform")
                        self.contentContainer.alpha = 0.7
                        let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
                        transition.setScale(layer: self.contentContainer.layer, scale: topScale)
                    } else {
                        self.contentContainer.alpha = 1.0
                        self.contentContainer.layer.animateAlpha(from: 7, to: 1.0, duration: 0.2)
                        
                        let transition = Transition(animation: .none)
                        transition.setScale(layer: self.contentContainer.layer, scale: 1.0)
                        
                        self.contentContainer.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            
                            self.contentContainer.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                        })
                    }
                }
            }
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result != nil {
                return result
            }
            
            if !self.isEnabled {
                return nil
            }
            
            if self.bounds.insetBy(dx: -8.0, dy: -8.0).contains(point) {
                return self
            }
            
            return nil
        }

        func update(component: PlainButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.componentState = state
            
            self.isEnabled = true
            
            let contentAlpha: CGFloat = 1.0

            let contentSize = self.content.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )

            let size = contentSize

            if let contentView = self.content.view {
                var contentTransition = transition
                if contentView.superview == nil {
                    contentTransition = .immediate
                    contentView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(contentView)
                }
                let contentFrame = CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) * 0.5), y: floor((size.height - contentSize.height) * 0.5)), size: contentSize)
                
                contentTransition.setFrame(view: contentView, frame: contentFrame)
                contentTransition.setAlpha(view: contentView, alpha: contentAlpha)
            }
            
            self.contentContainer.layer.anchorPoint = CGPoint(x: component.effectAlignment == .left ? 0.0 : 1.0, y: 0.5)
            transition.setBounds(view: self.contentContainer, bounds: CGRect(origin: CGPoint(), size: size))
            transition.setPosition(view: self.contentContainer, position: CGPoint(x: component.effectAlignment == .left ? 0.0 : size.width, y: size.height * 0.5))
            
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
