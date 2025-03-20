import Foundation
import UIKit
import ComponentFlow
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ComponentDisplayAdapters

private func resolveTheme(baseTheme: PresentationTheme, theme: ViewControllerComponentContainer.Theme) -> PresentationTheme {
    switch theme {
    case .default:
        return baseTheme
    case let .custom(value):
        return value
    case .dark:
        return customizeDefaultDarkPresentationTheme(theme: defaultDarkPresentationTheme, editing: false, title: nil, accentColor: baseTheme.list.itemAccentColor, backgroundColors: [], bubbleColors: [], animateBubbleColors: false, wallpaper: nil, baseColor: nil)
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
    
    public enum PresentationMode {
        case `default`
        case modal
    }
    
    public enum Theme {
        case `default`
        case dark
        case custom(PresentationTheme)
    }
    
    public final class Environment: Equatable {
        public let statusBarHeight: CGFloat
        public let navigationHeight: CGFloat
        public let safeInsets: UIEdgeInsets
        public let additionalInsets: UIEdgeInsets
        public let inputHeight: CGFloat
        public let metrics: LayoutMetrics
        public let deviceMetrics: DeviceMetrics
        public let orientation: UIInterfaceOrientation?
        public let isVisible: Bool
        public let theme: PresentationTheme
        public let strings: PresentationStrings
        public let dateTimeFormat: PresentationDateTimeFormat
        public let controller: () -> ViewController?
        
        public init(
            statusBarHeight: CGFloat,
            navigationHeight: CGFloat,
            safeInsets: UIEdgeInsets,
            additionalInsets: UIEdgeInsets,
            inputHeight: CGFloat,
            metrics: LayoutMetrics,
            deviceMetrics: DeviceMetrics,
            orientation: UIInterfaceOrientation?,
            isVisible: Bool,
            theme: PresentationTheme,
            strings: PresentationStrings,
            dateTimeFormat: PresentationDateTimeFormat,
            controller: @escaping () -> ViewController?
        ) {
            self.statusBarHeight = statusBarHeight
            self.navigationHeight = navigationHeight
            self.safeInsets = safeInsets
            self.additionalInsets = additionalInsets
            self.inputHeight = inputHeight
            self.metrics = metrics
            self.deviceMetrics = deviceMetrics
            self.orientation = orientation
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
            if lhs.additionalInsets != rhs.additionalInsets {
                return false
            }
            if lhs.inputHeight != rhs.inputHeight {
                return false
            }
            if lhs.metrics != rhs.metrics {
                return false
            }
            if lhs.deviceMetrics != rhs.deviceMetrics {
                return false
            }
            if lhs.orientation != rhs.orientation {
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
        let theme: Theme
        var resolvedTheme: PresentationTheme
        public let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        init(context: AccountContext, controller: ViewControllerComponentContainer, component: AnyComponent<ViewControllerComponentContainer.Environment>, theme: Theme) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            self.theme = theme
            self.resolvedTheme = resolveTheme(baseTheme: self.presentationData.theme, theme: theme)
            self.hostView = ComponentHostView()
            
            super.init()
            
            self.view.addSubview(self.hostView)
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ComponentTransition) {
            self.currentLayout = (layout, navigationHeight)
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                additionalInsets: layout.additionalInsets,
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: layout.metrics.orientation,
                isVisible: self.currentIsVisible,
                theme: self.resolvedTheme,
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
                forceUpdate: self.controller?.forceNextUpdate ?? false,
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
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: animated ? ComponentTransition(animation: .none).withUserData(isVisible ? AnimateInTransition() : AnimateOutTransition()) : .immediate)
        }
        
        func updateComponent(component: AnyComponent<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) {
            self.component = component
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: transition)
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let result = super.hitTest(point, with: event) {
                if result === self.view {
                    return nil
                }
                return result
            }
            return nil
        }
    }
    
    public var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private var theme: Theme
    public private(set) var component: AnyComponent<ViewControllerComponentContainer.Environment>
    
    private var presentationDataDisposable: Disposable?
    public private(set) var validLayout: ContainerViewLayout?
    
    public var wasDismissed: (() -> Void)?
    
    public init<C: Component>(
        context: AccountContext,
        component: C,
        navigationBarAppearance: NavigationBarAppearance,
        statusBarStyle: StatusBarStyle = .default,
        presentationMode: PresentationMode = .default,
        theme: Theme = .default,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil
    ) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        self.theme = theme
        
        let presentationData: PresentationData
        if let updatedPresentationData {
            presentationData = updatedPresentationData.initial
        } else {
            presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        }
        
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
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? self.context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                var theme = presentationData.theme
                
                var resolvedTheme = resolveTheme(baseTheme: presentationData.theme, theme: strongSelf.theme)
                if case .modal = presentationMode {
                    theme = theme.withModalBlocksBackground()
                    resolvedTheme = resolvedTheme.withModalBlocksBackground()
                }
                
                let presentationData = presentationData.withUpdated(theme: theme)

                strongSelf.node.presentationData = presentationData
                strongSelf.node.resolvedTheme = resolvedTheme
                
                switch statusBarStyle {
                    case .none:
                        strongSelf.statusBar.statusBarStyle = .Hide
                    case .ignore:
                        strongSelf.statusBar.statusBarStyle = .Ignore
                    case .default:
                        strongSelf.statusBar.statusBarStyle = resolvedTheme.rootController.statusBarStyle.style
                }
                
                let navigationBarPresentationData: NavigationBarPresentationData?
                switch navigationBarAppearance {
                case .none:
                    navigationBarPresentationData = nil
                case .transparent:
                    navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: true, hideBadge: false, hideSeparator: true)
                case .default:
                    navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData)
                }
                if let navigationBarPresentationData {
                    strongSelf.navigationBar?.updatePresentationData(navigationBarPresentationData)
                }
                
                if let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .immediate)
                }
            }
        }).strict()
        
        let resolvedTheme = resolveTheme(baseTheme: presentationData.theme, theme: self.theme)
        switch statusBarStyle {
            case .none:
                self.statusBar.statusBarStyle = .Hide
            case .ignore:
                self.statusBar.statusBarStyle = .Ignore
            case .default:
                self.statusBar.statusBarStyle = resolvedTheme.rootController.statusBarStyle.style
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
    
    private var didDismiss = false
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !self.didDismiss {
            self.didDismiss = true
            self.wasDismissed?()
        }
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
        super.dismiss(animated: flag, completion: {
            completion?()
        })
    }
    
    fileprivate var forceNextUpdate = false
    public func requestLayout(forceUpdate: Bool, transition: ContainedViewLayoutTransition) {
        self.forceNextUpdate = forceUpdate
        self.requestLayout(transition: transition)
        self.forceNextUpdate = false
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        
        self.validLayout = layout
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
    }
    
    public func updateComponent(component: AnyComponent<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) {
        self.component = component
        self.node.updateComponent(component: component, transition: transition)
    }
}
