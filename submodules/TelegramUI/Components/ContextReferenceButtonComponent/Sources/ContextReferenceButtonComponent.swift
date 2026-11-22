import Foundation
import UIKit
import Display
import ComponentFlow

public final class ContextReferenceButtonComponent: Component {
    let content: AnyComponent<Empty>
    let tag: AnyObject?
    let minSize: CGSize?
    let accessibility: ComponentAccessibility?
    /// VoiceOver: a custom action with this name runs `contextAccessibilityAction`, the path of the button's long press
    /// (a menu). Pass it only while the long press does something.
    let contextAccessibilityLabel: String?
    let contextAccessibilityAction: ((UIView) -> Void)?
    let action: (UIView, ContextGesture?) -> Void
    
    public init(
        content: AnyComponent<Empty>,
        tag: AnyObject? = nil,
        minSize: CGSize?,
        accessibility: ComponentAccessibility? = nil,
        contextAccessibilityLabel: String? = nil,
        contextAccessibilityAction: ((UIView) -> Void)? = nil,
        action: @escaping (UIView, ContextGesture?) -> Void
    ) {
        self.content = content
        self.tag = tag
        self.minSize = minSize
        self.accessibility = accessibility
        self.contextAccessibilityLabel = contextAccessibilityLabel
        self.contextAccessibilityAction = contextAccessibilityAction
        self.action = action
    }
    
    public static func ==(lhs: ContextReferenceButtonComponent, rhs: ContextReferenceButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.tag !== rhs.tag {
            return false
        }
        if lhs.minSize != rhs.minSize {
            return false
        }
        if lhs.accessibility != rhs.accessibility {
            return false
        }
        if lhs.contextAccessibilityLabel != rhs.contextAccessibilityLabel {
            return false
        }
        if (lhs.contextAccessibilityAction == nil) != (rhs.contextAccessibilityAction == nil) {
            return false
        }
        return true
    }

    public final class View: UIView, ComponentTaggedView {
        let buttonView: HighlightableButtonNode
        let sourceView: ContextControllerSourceNode
        let contextContentView: ContextReferenceContentNode
        
        private let componentView: ComponentView<Empty>
        
        private var component: ContextReferenceButtonComponent?
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        public init() {
            self.componentView = ComponentView()
            self.buttonView = HighlightableButtonNode()
            self.sourceView = ContextControllerSourceNode()
            self.contextContentView = ContextReferenceContentNode()
            
            super.init(frame: CGRect())
                        
            self.buttonView.allowsGroupOpacity = true
            self.addSubview(self.buttonView.view)
            self.buttonView.addSubnode(self.sourceView)
            self.sourceView.addSubnode(self.contextContentView)
            
            self.sourceView.activated = { [weak self] gesture, _ in
                if let self, let component = self.component {
                    component.action(self, gesture)
                }
            }
            self.buttonView.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            self.component?.action(self, nil)
        }
        
        private var contextAccessibilityCustomAction: (name: String, action: UIAccessibilityCustomAction)?
        
        override public var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
            get {
                guard let component = self.component, let name = component.contextAccessibilityLabel, component.contextAccessibilityAction != nil else {
                    return super.accessibilityCustomActions
                }
                if let current = self.contextAccessibilityCustomAction, current.name == name {
                    return [current.action]
                }
                let action = UIAccessibilityCustomAction(name: name, actionHandler: { [weak self] _ in
                    guard let self, let contextAction = self.component?.contextAccessibilityAction else {
                        return false
                    }
                    contextAction(self)
                    return true
                })
                self.contextAccessibilityCustomAction = (name, action)
                return [action]
            } set(value) {
                super.accessibilityCustomActions = value
            }
        }
        
        override public func accessibilityActivate() -> Bool {
            guard let component = self.component, component.accessibility != nil else {
                return super.accessibilityActivate()
            }
            component.action(self, nil)
            return true
        }

        public func update(component: ContextReferenceButtonComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            if let accessibility = component.accessibility {
                // One element for the button (its glyph and the context source inside are not read separately).
                self.apply(accessibility: accessibility, defaultTraits: .button)
            }
            
            let componentSize = self.componentView.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )
            
            var size = componentSize
            if let minSize = component.minSize {
                size.width = max(size.width, minSize.width)
                size.height = max(size.height, minSize.height)
            }
            
            if let componentView = self.componentView.view {
                componentView.isUserInteractionEnabled = false
                if componentView.superview == nil {
                    self.contextContentView.view.addSubview(componentView)
                }
                transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(x: floor((size.width - componentSize.width) / 2.0), y: floor((size.height - componentSize.height) / 2.0)), size: componentSize))
            }
            
            transition.setFrame(view: self.buttonView.view, frame: CGRect(origin: .zero, size: size))
            transition.setFrame(view: self.sourceView.view, frame: CGRect(origin: .zero, size: size))
            transition.setFrame(view: self.contextContentView.view, frame: CGRect(origin: .zero, size: size))
         
            return size
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
