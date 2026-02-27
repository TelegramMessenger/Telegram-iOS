import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import GlassBackgroundComponent

public final class GlassBarButtonComponent: Component {
    public enum DisplayState: Equatable {
        case generic
        case glass
        case tintedGlass
    }
    
    public let size: CGSize?
    public let backgroundColor: UIColor?
    public let isDark: Bool
    public let state: DisplayState?
    public let isEnabled: Bool
    public let isVisible: Bool
    public let animateScale: Bool
    public let component: AnyComponentWithIdentity<Empty>
    public let action: ((UIView) -> Void)?
    public let tag: AnyObject?

    public init(
        size: CGSize?,
        backgroundColor: UIColor?,
        isDark: Bool,
        state: DisplayState? = nil,
        isEnabled: Bool = true,
        isVisible: Bool = true,
        animateScale: Bool = true,
        component: AnyComponentWithIdentity<Empty>,
        action: ((UIView) -> Void)?,
        tag: AnyObject? = nil
    ) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.isDark = isDark
        self.state = state
        self.isEnabled = isEnabled
        self.isVisible = isVisible
        self.animateScale = animateScale
        self.component = component
        self.action = action
        self.tag = tag
    }

    public static func ==(lhs: GlassBarButtonComponent, rhs: GlassBarButtonComponent) -> Bool {
        if lhs.size != rhs.size {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.isDark != rhs.isDark {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if lhs.animateScale != rhs.animateScale {
            return false
        }
        if lhs.component != rhs.component {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        return true
    }

    public final class View: UIView, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let containerView: HighlightTrackingButton
        private let genericContainerView: UIView
        private let genericBackgroundView: SimpleGlassView
        private let glassContainerView: UIView
        private var glassBackgroundView: GlassBackgroundView?
        private var componentView: ComponentView<Empty>?
        
        private var component: GlassBarButtonComponent?
        
        public override init(frame: CGRect) {
            self.containerView = HighlightTrackingButton()
            self.genericContainerView = UIView()
            self.genericBackgroundView = SimpleGlassView()
            self.glassContainerView = UIView()
            
            super.init(frame: frame)
            
            self.containerView.layer.rasterizationScale = UIScreenScale
            
            self.addSubview(self.genericContainerView)
            self.addSubview(self.glassContainerView)
            
            self.genericContainerView.addSubview(self.genericBackgroundView)
                        
            self.containerView.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.containerView.highligthedChanged = { [weak self] highlighted in
                guard let self, let component = self.component, component.animateScale else {
                    return
                }
                if [.glass, .tintedGlass].contains(component.state) {
                    return
                }
                
                if highlighted {
                    self.containerView.layer.animateSpring(from: CGFloat((self.containerView.layer.presentation()?.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0) as NSNumber, to: 1.3636 as NSNumber, keyPath: "transform.scale", duration: 0.5, removeOnCompletion: false)
                } else {
                    self.containerView.layer.animateSpring(from: CGFloat((self.containerView.layer.presentation()?.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.3636) as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6)
                }
            }
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component, let action = component.action else {
                return
            }
            action(self)
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let component = self.component, let action = component.action else {
                    return
                }
                action(self)
            }
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            if result === self.glassContainerView || result === self.genericContainerView {
                return self.containerView
            }
            return result
        }
        
        func update(component: GlassBarButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            
            self.containerView.isEnabled = component.isEnabled
            
            var componentView: ComponentView<Empty>
            var animateAppearance = false
            if previousComponent?.component.id != component.component.id {
                if let componentView = self.componentView {
                    animateAppearance = true
                    self.componentView = nil
                    if let view = componentView.view {
                        transition.setScale(view: view, scale: 0.01)
                        transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                            view.removeFromSuperview()
                        })
                    }
                }
            }
            
            var componentTransition = transition
            if let current = self.componentView {
                componentView = current
            } else {
                componentTransition = .immediate
                componentView = ComponentView()
                self.componentView = componentView
            }
            
            let componentSize = componentView.update(
                transition: componentTransition,
                component: component.component.component,
                environment: {},
                containerSize: component.size ?? availableSize
            )
            
            let containerSize: CGSize
            if let size = component.size {
                containerSize = size
            } else {
                containerSize = CGSize(width: componentSize.width + 25.0, height: max(availableSize.height, componentSize.height + 19.0))
            }
            
            let componentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((containerSize.width - componentSize.width) / 2.0), y: floorToScreenPixels((containerSize.height - componentSize.height) / 2.0)), size: componentSize)
            if let view = componentView.view {
                if view.superview == nil {
                    view.isUserInteractionEnabled = false
                    self.containerView.addSubview(view)
                    if animateAppearance {
                        transition.animateScale(view: view, from: 0.01, to: 1.0)
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                    }
                }
                componentTransition.setFrame(view: view, frame: componentFrame)
            }
            
            let effectiveState: DisplayState = component.state ?? .glass
            /*if "".isEmpty {
                effectiveState = .glass
            }*/
            
            var genericAlpha: CGFloat = 1.0
            var glassAlpha: CGFloat = 1.0
            switch effectiveState {
            case .generic:
                genericAlpha = 1.0
                glassAlpha = 0.0
            case .glass, .tintedGlass:
                glassAlpha = 1.0
                genericAlpha = 0.0
            }
            
            let cornerRadius = containerSize.height * 0.5
            if let backgroundColor = component.backgroundColor {
                self.genericBackgroundView.update(size: containerSize, cornerRadius: cornerRadius, isDark: component.isDark, tintColor: .init(kind: .custom(style: .default, color: backgroundColor)), transition: transition)
            }
                        
            let bounds = CGRect(origin: .zero, size: containerSize)
            transition.setFrame(view: self.containerView, frame: bounds)
                        
            transition.setAlpha(view: self.genericContainerView, alpha: genericAlpha)
            transition.setFrame(view: self.genericContainerView, frame: bounds)
            
            //transition.setAlpha(view: self.glassContainerView, alpha: glassAlpha)
            transition.setFrame(view: self.glassContainerView, frame: bounds)
            //self.glassContainerView.update(size: bounds.size, isDark: component.isDark, transition: transition)
            
            transition.setFrame(view: self.genericBackgroundView, frame: bounds)
            
            if glassAlpha == 1.0, let backgroundColor = component.backgroundColor {
                let glassBackgroundView: GlassBackgroundView
                var glassBackgroundTransition = transition
                if let current = self.glassBackgroundView {
                    glassBackgroundView = current
                } else {
                    glassBackgroundTransition = .immediate
                    glassBackgroundView = GlassBackgroundView()
                    self.glassContainerView.addSubview(glassBackgroundView)
                    self.glassBackgroundView = glassBackgroundView
                    
                    glassBackgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
                    
                    transition.animateAlpha(view: glassBackgroundView, from: 0.0, to: 1.0)
                }
                glassBackgroundView.update(size: containerSize, cornerRadius: cornerRadius, isDark: component.isDark, tintColor: .init(kind: effectiveState == .tintedGlass ? .custom(style: .default, color: backgroundColor.withMultipliedAlpha(effectiveState == .tintedGlass ? 1.0 : 0.7)) : .panel), isInteractive: true, isVisible: component.isVisible, transition: glassBackgroundTransition)
                glassBackgroundTransition.setFrame(view: glassBackgroundView, frame: bounds)
            } else if case .glass = component.state {
                let glassBackgroundView: GlassBackgroundView
                var glassBackgroundTransition = transition
                if let current = self.glassBackgroundView {
                    glassBackgroundView = current
                } else {
                    glassBackgroundTransition = .immediate
                    glassBackgroundView = GlassBackgroundView()
                    self.glassContainerView.addSubview(glassBackgroundView)
                    self.glassBackgroundView = glassBackgroundView
                    
                    glassBackgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
                    
                    transition.animateAlpha(view: glassBackgroundView, from: 0.0, to: 1.0)
                }
                glassBackgroundView.update(size: containerSize, cornerRadius: cornerRadius, isDark: component.isDark, tintColor: .init(kind: .panel), isInteractive: true, isVisible: component.isVisible, transition: glassBackgroundTransition)
                glassBackgroundTransition.setFrame(view: glassBackgroundView, frame: bounds)
            } else if let glassBackgroundView = self.glassBackgroundView {
                self.glassBackgroundView = nil
                transition.setAlpha(view: glassBackgroundView, alpha: 0.0, completion: { _ in
                    glassBackgroundView.removeFromSuperview()
                })
            }
            
            if let glassBackgroundView = self.glassBackgroundView {
                if self.containerView.superview !== glassBackgroundView.contentView {
                    glassBackgroundView.contentView.addSubview(self.containerView)
                }
            } else if self.containerView.superview !== self {
                self.addSubview(self.containerView)
            }
            
            return containerSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}



public final class BarComponentHostView: UIView {
    private let hostView = ComponentHostView<Empty>()
    
    public func update(component: AnyComponent<Empty>, transition: ComponentTransition) {
        let _ = self.hostView.update(
            transition: transition,
            component: component,
            environment: {},
            containerSize: CGSize(width: 120.0, height: 40.0)
        )
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize()
    }
}

public final class BarComponentHostNode: ASDisplayNode {
    public var component: AnyComponentWithIdentity<Empty>? {
        didSet {
            self.updateComponent(previousComponent: oldValue, transition: .spring(duration: 0.4))
        }
    }
    private var componentView: ComponentView<Empty>?
    
    private let size: CGSize
    
    public init(component: AnyComponentWithIdentity<Empty>?, size: CGSize) {
        self.component = component
        self.size = size
        
        super.init()
        self.clipsToBounds = false
        
        self.updateComponent(previousComponent: nil, transition: .immediate)
    }
    
    private func updateComponent(previousComponent: AnyComponentWithIdentity<Empty>?, transition: ComponentTransition) {
        if previousComponent?.id != self.component?.id {
            if let componentView = self.componentView {
                self.componentView = nil
                if let view = componentView.view {
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                    transition.setScale(view: view, scale: 0.01)
                }
            }
        }
        
        if let component = self.component {
            var componentTransition = transition
            let componentView: ComponentView<Empty>
            if let current = self.componentView {
                componentView = current
            } else {
                componentTransition = .immediate
                componentView = ComponentView()
                self.componentView = componentView
            }
            
            let _ = componentView.update(
                transition: componentTransition,
                component: component.component,
                environment: {},
                containerSize: self.size
            )
            if let view = componentView.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                    
                    if !transition.animation.isImmediate {
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        transition.animateScale(view: view, from: 0.01, to: 1.0)
                    }
                }
                view.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: self.size)
            }
        }
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return self.size
    }
}

private class SimpleGlassView: UIView {
    private let backgroundNode: NavigationBackgroundNode
    private let foregroundView: UIImageView
    
    private struct Params: Equatable {
        let size: CGSize
        let cornerRadius: CGFloat
        let isDark: Bool
        let tintColor: GlassBackgroundView.TintColor
        
        init(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: GlassBackgroundView.TintColor) {
            self.size = size
            self.cornerRadius = cornerRadius
            self.isDark = isDark
            self.tintColor = tintColor
        }
    }
    
    private var params: Params?
    
    public override init(frame: CGRect) {
        self.backgroundNode = NavigationBackgroundNode(color: .black, enableBlur: true, customBlurRadius: 8.0)
        self.foregroundView = UIImageView()
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundNode.view)
        self.addSubview(self.foregroundView)
    }
        
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: GlassBackgroundView.TintColor, isInteractive: Bool = false, transition: ComponentTransition) {
        let colorValue: UIColor
        switch tintColor.kind {
        case .clear, .panel:
            if isDark {
                colorValue = UIColor(white: 1.0, alpha: 0.025)
            } else {
                colorValue = UIColor(white: 1.0, alpha: 0.1)
            }
        case let .custom(_, color):
            colorValue = color
        }
        self.backgroundNode.updateColor(color: colorValue, forceKeepBlur: colorValue.alpha != 1.0, transition: transition.containedViewLayoutTransition)
        self.backgroundNode.update(size: size, cornerRadius: cornerRadius, transition: transition.containedViewLayoutTransition)
        transition.setFrame(view: self.backgroundNode.view, frame: CGRect(origin: CGPoint(), size: size))
                
        transition.setFrame(view: self.foregroundView, frame: CGRect(origin: CGPoint(), size: size))
        
        let params = Params(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: tintColor)
        if self.params != params {
            self.params = params
            self.foregroundView.image = GlassBackgroundView.generateForegroundImage(size: size, isDark: isDark, fillColor: .clear)
        }
    }
}
