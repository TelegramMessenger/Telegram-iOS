import Foundation
import UIKit
import ComponentFlow
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

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
        public let isVisible: Bool
        public let strings: PresentationStrings
        public let controller: () -> ViewController?
        
        public init(
            statusBarHeight: CGFloat,
            safeInsets: UIEdgeInsets,
            isVisible: Bool,
            strings: PresentationStrings,
            controller: @escaping () -> ViewController?
        ) {
            self.statusBarHeight = statusBarHeight
            self.safeInsets = safeInsets
            self.isVisible = isVisible
            self.strings = strings
            self.controller = controller
        }
        
        public static func ==(lhs: Environment, rhs: Environment) -> Bool {
            if lhs === rhs {
                return true
            }
            
            if lhs.statusBarHeight != rhs.statusBarHeight {
                return false
            }
            if lhs.safeInsets != rhs.safeInsets {
                return false
            }
            if lhs.isVisible != rhs.isVisible {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            
            return true
        }
    }
    
    private final class Node: ViewControllerTracingNode {
        private var presentationData: PresentationData
        private weak var controller: ViewControllerComponentContainer?
        
        private let component: AnyComponent<ViewControllerComponentContainer.Environment>
        private let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        private var currentIsVisible: Bool = false
        private var currentLayout: ContainerViewLayout?
        
        init(context: AccountContext, controller: ViewControllerComponentContainer, component: AnyComponent<ViewControllerComponentContainer.Environment>) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            self.hostView = ComponentHostView()
            
            super.init()
            
            self.view.addSubview(self.hostView)
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: Transition) {
            self.currentLayout = layout
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.intrinsicInsets.left + layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.intrinsicInsets.right + layout.safeInsets.right),
                isVisible: self.currentIsVisible,
                strings: self.presentationData.strings,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            let _ = self.hostView.update(
                transition: transition,
                component: self.component,
                environment: {
                    environment
                },
                containerSize: layout.size
            )
            transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: layout.size), completion: nil)
        }
        
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(currentLayout, transition: .immediate)
        }
    }
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    
    public init<C: Component>(context: AccountContext, component: C) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, component: self.component)
        
        self.displayNodeDidLoad()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout, transition: Transition(transition))
    }
}
