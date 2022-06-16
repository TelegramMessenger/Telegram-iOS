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
    
    var containedViewLayoutTransitionCurve: ContainedViewLayoutTransitionCurve {
        switch self {
            case .easeInOut:
                return .easeInOut
            case .spring:
                return .spring
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
    
    var containedViewLayoutTransition: ContainedViewLayoutTransition {
        switch self.animation {
            case .none:
                return .immediate
            case let .curve(duration, curve):
                return .animated(duration: duration, curve: curve.containedViewLayoutTransitionCurve)
        }
    }
}

open class ViewControllerComponentContainer: ViewController {
    public enum NavigationBarAppearance {
        case none
        case transparent
        case `default`
    }
    
    public enum StatusBarStyle {
        case none
        case ignore
        case `default`
    }
    
    public final class Environment: Equatable {
        public let statusBarHeight: CGFloat
        public let navigationHeight: CGFloat
        public let safeInsets: UIEdgeInsets
        public let metrics: LayoutMetrics
        public let isVisible: Bool
        public let theme: PresentationTheme
        public let strings: PresentationStrings
        public let dateTimeFormat: PresentationDateTimeFormat
        public let controller: () -> ViewController?
        
        public init(
            statusBarHeight: CGFloat,
            navigationHeight: CGFloat,
            safeInsets: UIEdgeInsets,
            metrics: LayoutMetrics,
            isVisible: Bool,
            theme: PresentationTheme,
            strings: PresentationStrings,
            dateTimeFormat: PresentationDateTimeFormat,
            controller: @escaping () -> ViewController?
        ) {
            self.statusBarHeight = statusBarHeight
            self.navigationHeight = navigationHeight
            self.safeInsets = safeInsets
            self.metrics = metrics
            self.isVisible = isVisible
            self.theme = theme
            self.strings = strings
            self.dateTimeFormat = dateTimeFormat
            self.controller = controller
        }
        
        public static func ==(lhs: Environment, rhs: Environment) -> Bool {
            if lhs === rhs {
                return true
            }
            
            if lhs.statusBarHeight != rhs.statusBarHeight {
                return false
            }
            if lhs.navigationHeight != rhs.navigationHeight {
                return false
            }
            if lhs.safeInsets != rhs.safeInsets {
                return false
            }
            if lhs.metrics != rhs.metrics {
                return false
            }
            if lhs.isVisible != rhs.isVisible {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            if lhs.strings !== rhs.strings {
                return false
            }
            if lhs.dateTimeFormat != rhs.dateTimeFormat {
                return false
            }
            
            return true
        }
    }
    
    public final class AnimateInTransition {
    }
    
    public final class AnimateOutTransition {
    }
    
    public final class Node: ViewControllerTracingNode {
        fileprivate var presentationData: PresentationData
        private weak var controller: ViewControllerComponentContainer?
        
        private var component: AnyComponent<ViewControllerComponentContainer.Environment>
        var theme: PresentationTheme?
        public let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        init(context: AccountContext, controller: ViewControllerComponentContainer, component: AnyComponent<ViewControllerComponentContainer.Environment>, theme: PresentationTheme?) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            self.theme = theme
            self.hostView = ComponentHostView()
            
            super.init()
            
            self.view.addSubview(self.hostView)
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: Transition) {
            self.currentLayout = (layout, navigationHeight)
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                metrics: layout.metrics,
                isVisible: self.currentIsVisible,
                theme: self.theme ?? self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
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
        
        func updateIsVisible(isVisible: Bool, animated: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: animated ? Transition(animation: .none).withUserData(isVisible ? AnimateInTransition() : AnimateOutTransition()) : .immediate)
        }
        
        func updateComponent(component: AnyComponent<ViewControllerComponentContainer.Environment>, transition: Transition) {
            self.component = component
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: transition)
        }
    }
    
    public var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private var theme: PresentationTheme?
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    
    private var presentationDataDisposable: Disposable?
    private var validLayout: ContainerViewLayout?
    
    public init<C: Component>(context: AccountContext, component: C, navigationBarAppearance: NavigationBarAppearance, statusBarStyle: StatusBarStyle = .default, theme: PresentationTheme? = nil) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        self.theme = theme
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let navigationBarPresentationData: NavigationBarPresentationData?
        switch navigationBarAppearance {
        case .none:
            navigationBarPresentationData = nil
        case .transparent:
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: true, hideBadge: false, hideSeparator: true)
        case .default:
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData)
        }
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.presentationDataDisposable = (self.context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.node.presentationData = presentationData
        
                switch statusBarStyle {
                    case .none:
                        strongSelf.statusBar.statusBarStyle = .Hide
                    case .ignore:
                        strongSelf.statusBar.statusBarStyle = .Ignore
                    case .default:
                        strongSelf.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
                }
                
                if let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                }
            }
        })
        
        switch statusBarStyle {
            case .none:
                self.statusBar.statusBarStyle = .Hide
            case .ignore:
                self.statusBar.statusBarStyle = .Ignore
            case .default:
                self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, component: self.component, theme: self.theme)
        
        self.displayNodeDidLoad()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true, animated: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false, animated: animated)
    }
    
    open override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        
        self.validLayout = layout
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
    }
    
    public func updateComponent(component: AnyComponent<ViewControllerComponentContainer.Environment>, transition: Transition) {
        self.node.updateComponent(component: component, transition: transition)
    }
}
