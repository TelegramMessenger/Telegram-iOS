import Foundation
import UIKit
import ComponentFlow
import Display
import SwiftSignalKit

public extension Transition.Animation.Curve {
    init(_ curve: ContainedViewLayoutTransitionCurve) {
        switch curve {
        case .linear:
            self = .easeInOut
        case .easeInOut:
            self = .easeInOut
        case .custom:
            self = .spring
        case .customSpring:
            self = .spring
        case .spring:
            self = .spring
        }
    }
}

public extension Transition {
    init(_ transition: ContainedViewLayoutTransition) {
        switch transition {
        case .immediate:
            self.init(animation: .none)
        case let .animated(duration, curve):
            self.init(animation: .curve(duration: duration, curve: Transition.Animation.Curve(curve)))
        }
    }
}

open class ViewControllerComponentContainer: ViewController {
    public final class Environment: Equatable {
        public let statusBarHeight: CGFloat
        public let safeInsets: UIEdgeInsets
        
        public init(
            statusBarHeight: CGFloat,
            safeInsets: UIEdgeInsets
        ) {
            self.statusBarHeight = statusBarHeight
            self.safeInsets = safeInsets
        }
        
        public static func ==(lhs: Environment, rhs: Environment) -> Bool {
            if lhs.statusBarHeight != rhs.statusBarHeight {
                return false
            }
            if lhs.safeInsets != rhs.safeInsets {
                return false
            }
            
            return true
        }
    }
    
    private final class Node: ViewControllerTracingNode {
        private weak var controller: ViewControllerComponentContainer?
        
        private let component: AnyComponent<ViewControllerComponentContainer.Environment>
        private let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        init(controller: ViewControllerComponentContainer, component: AnyComponent<ViewControllerComponentContainer.Environment>) {
            self.controller = controller
            
            self.component = component
            self.hostView = ComponentHostView()
            
            super.init()
            
            self.view.addSubview(self.hostView)
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                safeInsets: layout.intrinsicInsets
            )
            let _ = self.hostView.update(
                transition: Transition(transition),
                component: self.component,
                environment: {
                    environment
                },
                containerSize: layout.size
            )
            transition.updateFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
    }
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    
    public init<C: Component>(_ component: C) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.component = AnyComponent(component)
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(controller: self, component: self.component)
        
        self.displayNodeDidLoad()
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout, transition: transition)
    }
}
