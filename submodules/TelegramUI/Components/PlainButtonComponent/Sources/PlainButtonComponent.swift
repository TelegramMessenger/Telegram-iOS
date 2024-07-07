import Foundation
import UIKit
import Display
import ComponentFlow

public final class PlainButtonComponent: Component {
    public enum EffectAlignment {
        case left
        case right
        case center
    }
    
    public let content: AnyComponent<Empty>
    public let background: AnyComponent<Empty>?
    public let effectAlignment: EffectAlignment
    public let minSize: CGSize?
    public let contentInsets: UIEdgeInsets
    public let action: () -> Void
    public let isEnabled: Bool
    public let animateAlpha: Bool
    public let animateScale: Bool
    public let animateContents: Bool
    public let tag: AnyObject?
    
    public init(
        content: AnyComponent<Empty>,
        background: AnyComponent<Empty>? = nil,
        effectAlignment: EffectAlignment,
        minSize: CGSize? = nil,
        contentInsets: UIEdgeInsets = UIEdgeInsets(),
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        animateAlpha: Bool = true,
        animateScale: Bool = true,
        animateContents: Bool = true,
        tag: AnyObject? = nil
    ) {
        self.content = content
        self.background = background
        self.effectAlignment = effectAlignment
        self.minSize = minSize
        self.contentInsets = contentInsets
        self.action = action
        self.isEnabled = isEnabled
        self.animateAlpha = animateAlpha
        self.animateScale = animateScale
        self.animateContents = animateContents
        self.tag = tag
    }
    
    public static func ==(lhs: PlainButtonComponent, rhs: PlainButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.background != rhs.background {
            return false
        }
        if lhs.effectAlignment != rhs.effectAlignment {
            return false
        }
        if lhs.minSize != rhs.minSize {
            return false
        }
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.animateAlpha != rhs.animateAlpha {
            return false
        }
        if lhs.animateScale != rhs.animateScale {
            return false
        }
        if lhs.animateContents != rhs.animateContents {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }

    public final class View: HighlightTrackingButton, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private var component: PlainButtonComponent?
        private weak var componentState: EmptyComponentState?

        private let contentContainer = UIView()
        private let content = ComponentView<Empty>()
        private var background: ComponentView<Empty>?
        
        public var contentView: UIView? {
            return self.content.view
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.isExclusiveTouch = true
            
            self.contentContainer.isUserInteractionEnabled = false
            self.addSubview(self.contentContainer)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let animateAlpha = self.component?.animateAlpha ?? true
                    let animateScale = self.component?.animateScale ?? true
                    
                    let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                    
                    if highlighted {
                        self.contentContainer.layer.removeAnimation(forKey: "opacity")
                        self.contentContainer.layer.removeAnimation(forKey: "transform.scale")
                        
                        if animateAlpha {
                            self.contentContainer.alpha = 0.7
                        }
                        if animateScale {
                            let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                            transition.setScale(layer: self.contentContainer.layer, scale: topScale)
                        }
                    } else {
                        if animateAlpha {
                            self.contentContainer.alpha = 1.0
                            self.contentContainer.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                        }
                        
                        if animateScale {
                            let transition = ComponentTransition(animation: .none)
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
            if self.isHidden || self.alpha == 0.0 {
                return nil
            }
            
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

        func update(component: PlainButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
            
            self.isEnabled = component.isEnabled
            
            let contentAlpha: CGFloat = 1.0

            let contentSize = self.content.update(
                transition: component.animateContents ? transition : transition.withAnimation(.none),
                component: component.content,
                environment: {},
                containerSize: availableSize
            )

            var size = contentSize
            if let minSize = component.minSize {
                size.width = max(size.width, minSize.width)
                size.height = max(size.height, minSize.height)
            }
            size.width += component.contentInsets.left + component.contentInsets.right
            size.height += component.contentInsets.top + component.contentInsets.bottom

            if let contentView = self.content.view {
                var contentTransition = transition
                if contentView.superview == nil {
                    let anchorX: CGFloat
                    switch component.effectAlignment {
                    case .left:
                        anchorX = 0.0
                    case .center:
                        anchorX = 0.5
                    case .right:
                        anchorX = 1.0
                    }
                    contentView.layer.anchorPoint = CGPoint(x: anchorX, y: 0.5)
                    
                    contentTransition = .immediate
                    contentView.isUserInteractionEnabled = false
                    self.contentContainer.addSubview(contentView)
                }
                let contentFrame = CGRect(origin: CGPoint(x: component.contentInsets.left + floor((size.width - component.contentInsets.left - component.contentInsets.right - contentSize.width) * 0.5), y: component.contentInsets.top + floor((size.height - component.contentInsets.top - component.contentInsets.bottom - contentSize.height) * 0.5)), size: contentSize)
                
                let contentPosition = CGPoint(x: contentFrame.minX + contentFrame.width * contentView.layer.anchorPoint.x, y: contentFrame.minY + contentFrame.height * contentView.layer.anchorPoint.y)
                if !component.animateContents && (abs(contentView.center.x - contentPosition.x) <= 2.0 && abs(contentView.center.y - contentPosition.y) <= 2.0){
                    contentView.center = contentPosition
                } else {
                    contentTransition.setPosition(view: contentView, position: contentPosition)
                }
                
                if component.animateContents {
                    contentTransition.setBounds(view: contentView, bounds: CGRect(origin: CGPoint(), size: contentFrame.size))
                } else {
                    contentView.bounds = CGRect(origin: CGPoint(), size: contentFrame.size)
                }
                contentTransition.setAlpha(view: contentView, alpha: contentAlpha)
            }
            
            let anchorX: CGFloat
            switch component.effectAlignment {
            case .left:
                anchorX = 0.0
            case .center:
                anchorX = 0.5
            case .right:
                anchorX = 1.0
            }
            self.contentContainer.layer.anchorPoint = CGPoint(x: anchorX, y: 0.5)
            transition.setBounds(view: self.contentContainer, bounds: CGRect(origin: CGPoint(), size: size))
            transition.setPosition(view: self.contentContainer, position: CGPoint(x: size.width * anchorX, y: size.height * 0.5))
            
            if let backgroundValue = component.background {
                var backgroundTransition = transition
                let background: ComponentView<Empty>
                if let current = self.background {
                    background = current
                } else {
                    backgroundTransition = .immediate
                    background = ComponentView()
                    self.background = background
                }
                let _ = background.update(
                    transition: backgroundTransition,
                    component: backgroundValue,
                    environment: {},
                    containerSize: size
                )
                if let backgroundView = background.view {
                    if backgroundView.superview == nil {
                        self.contentContainer.insertSubview(backgroundView, at: 0)
                    }
                    backgroundTransition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: size))
                }
            } else if let background = self.background {
                self.background = nil
                background.view?.removeFromSuperview()
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
