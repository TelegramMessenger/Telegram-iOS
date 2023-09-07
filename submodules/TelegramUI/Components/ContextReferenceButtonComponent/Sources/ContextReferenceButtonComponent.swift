import Foundation
import UIKit
import Display
import ComponentFlow

public final class ContextReferenceButtonComponent: Component {
    let content: AnyComponent<Empty>
    let tag: AnyObject?
    let minSize: CGSize?
    let action: (UIView, ContextGesture?) -> Void
    
    public init(
        content: AnyComponent<Empty>,
        tag: AnyObject? = nil,
        minSize: CGSize?,
        action: @escaping (UIView, ContextGesture?) -> Void
    ) {
        self.content = content
        self.tag = tag
        self.minSize = minSize
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

        public func update(component: ContextReferenceButtonComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
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

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
