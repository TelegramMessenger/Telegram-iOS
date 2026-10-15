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
    
    public enum Style {
        case glass
        case legacy
    }
    
    public final class Environment: Equatable {
        public let statusBarHeight: CGFloat
        /// The status bar height including a top-right status island, for full-screen content that must clear
        /// the island entirely (a story card). Equal to `statusBarHeight` except on iPhone Duo's unfolded screen
        /// in portrait, where `statusBarHeight` is the compact height a navigation bar sits under beside the island.
        public let fullStatusBarHeight: CGFloat
        public let navigationHeight: CGFloat
        public let safeInsets: UIEdgeInsets
        /// The blocks the system reserves in the screen's corners (iPhone Duo's status corner); `.none` elsewhere.
        public let reservedCorners: ContainerViewLayoutCorners
        /// How much further left a control at the top of the right edge sits to clear a top-right status island
        /// (iPhone Duo's unfolded screen in portrait); 0 elsewhere. See `ContainerViewLayout.navigationBarTrailingButtonsInset`.
        public let navigationBarTrailingButtonsInset: CGFloat
        /// Where a screen that draws its own back or close button puts it when there is a side strip (iPhone Duo), in the
        /// screen's coordinates: the strip's top, where a standard navigation bar's button goes; nil without a strip.
        /// See `ContainerViewLayout.sideColumnNavigationButtonFrame`.
        public let sideColumnNavigationButtonFrame: CGRect?
        public let additionalInsets: UIEdgeInsets
        public let inputHeight: CGFloat
        public let metrics: LayoutMetrics
        public let deviceMetrics: DeviceMetrics
        /// The screen's four corner radii in this layout's coordinates (`ContainerViewLayout.screenCornerRadii`): they
        /// differ per corner on iPhone Duo's cover screen, so a sheet reaching the bottom edge rounds each bottom corner
        /// by its own (`CornerRadii.sheetBottomCornerRadii`); elsewhere the device's uniform `screenCornerRadius`.
        public let screenCornerRadii: CornerRadii
        public let orientation: UIInterfaceOrientation?
        public let isVisible: Bool
        public let theme: PresentationTheme
        public let strings: PresentationStrings
        public let dateTimeFormat: PresentationDateTimeFormat
        public let controller: () -> ViewController?
        
        public init(
            statusBarHeight: CGFloat,
            fullStatusBarHeight: CGFloat? = nil,
            navigationHeight: CGFloat,
            safeInsets: UIEdgeInsets,
            reservedCorners: ContainerViewLayoutCorners = .none,
            navigationBarTrailingButtonsInset: CGFloat = 0.0,
            sideColumnNavigationButtonFrame: CGRect? = nil,
            additionalInsets: UIEdgeInsets,
            inputHeight: CGFloat,
            metrics: LayoutMetrics,
            deviceMetrics: DeviceMetrics,
            screenCornerRadii: CornerRadii? = nil,
            orientation: UIInterfaceOrientation?,
            isVisible: Bool,
            theme: PresentationTheme,
            strings: PresentationStrings,
            dateTimeFormat: PresentationDateTimeFormat,
            controller: @escaping () -> ViewController?
        ) {
            self.statusBarHeight = statusBarHeight
            self.fullStatusBarHeight = fullStatusBarHeight ?? statusBarHeight
            self.navigationHeight = navigationHeight
            self.safeInsets = safeInsets
            self.reservedCorners = reservedCorners
            self.navigationBarTrailingButtonsInset = navigationBarTrailingButtonsInset
            self.sideColumnNavigationButtonFrame = sideColumnNavigationButtonFrame
            self.additionalInsets = additionalInsets
            self.inputHeight = inputHeight
            self.metrics = metrics
            self.deviceMetrics = deviceMetrics
            self.screenCornerRadii = screenCornerRadii ?? CornerRadii(uniform: deviceMetrics.screenCornerRadius)
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
            if lhs.fullStatusBarHeight != rhs.fullStatusBarHeight {
                return false
            }
            if lhs.navigationHeight != rhs.navigationHeight {
                return false
            }
            if lhs.safeInsets != rhs.safeInsets {
                return false
            }
            if lhs.reservedCorners != rhs.reservedCorners {
                return false
            }
            if lhs.navigationBarTrailingButtonsInset != rhs.navigationBarTrailingButtonsInset {
                return false
            }
            if lhs.sideColumnNavigationButtonFrame != rhs.sideColumnNavigationButtonFrame {
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
            if lhs.screenCornerRadii != rhs.screenCornerRadii {
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

        /// A horizontal band's side insets (`bandSideInsets`) in a container `containerHeight` tall: beside iPhone Duo's
        /// side strip a side's inset applies only where the band reaches that side's corner block, so a row away from
        /// the camera (a bottom action button in folded portrait) spans the strip; elsewhere the safe insets.
        public func sideInsets(forBandFrom minY: CGFloat, to maxY: CGFloat, containerHeight: CGFloat) -> (left: CGFloat, right: CGFloat) {
            return bandSideInsets(forBandFrom: minY, to: maxY, containerHeight: containerHeight, safeInsets: self.safeInsets, reservedCorners: self.reservedCorners)
        }

        /// The side insets of a button or panel anchored to the bottom edge (`Display.bottomEdgeSideInsets`): beside
        /// iPhone Duo's side strip a side keeps its inset only where its corner block is at the bottom (folded
        /// landscape-left), so a bottom action button spans the strip elsewhere; the safe insets on every other device.
        public func bottomEdgeSideInsets() -> (left: CGFloat, right: CGFloat) {
            return Display.bottomEdgeSideInsets(safeInsets: self.safeInsets, reservedCorners: self.reservedCorners)
        }

        /// This environment with other left and right safe insets: what a sheet hands its content when the
        /// sheet itself keeps clear of a side strip (iPhone Duo), so the content has no strip of its own to avoid
        /// (nor to put its close button in).
        public func withSideSafeInsets(left: CGFloat, right: CGFloat) -> Environment {
            if self.safeInsets.left == left && self.safeInsets.right == right {
                return self
            }
            var safeInsets = self.safeInsets
            safeInsets.left = left
            safeInsets.right = right
            return Environment(
                statusBarHeight: self.statusBarHeight,
                fullStatusBarHeight: self.fullStatusBarHeight,
                navigationHeight: self.navigationHeight,
                safeInsets: safeInsets,
                reservedCorners: self.reservedCorners,
                navigationBarTrailingButtonsInset: self.navigationBarTrailingButtonsInset,
                sideColumnNavigationButtonFrame: nil,
                additionalInsets: self.additionalInsets,
                inputHeight: self.inputHeight,
                metrics: self.metrics,
                deviceMetrics: self.deviceMetrics,
                screenCornerRadii: self.screenCornerRadii,
                orientation: self.orientation,
                isVisible: self.isVisible,
                theme: self.theme,
                strings: self.strings,
                dateTimeFormat: self.dateTimeFormat,
                controller: self.controller
            )
        }
    }
    
    public final class AnimateInTransition {
        public init() {
        }
    }
    
    public final class AnimateOutTransition {
        public init() {
        }
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
        
        init(presentationData: PresentationData, controller: ViewControllerComponentContainer, component: AnyComponent<ViewControllerComponentContainer.Environment>, theme: Theme) {
            self.presentationData = presentationData
            
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
                // The status height the navigation bar is laid out under, so a screen that mixes it with
                // `navigationHeight` stays consistent (iPhone Duo unfolded portrait: compact beside the status island).
                statusBarHeight: layout.navigationBarStatusBarHeight ?? 0.0,
                fullStatusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                reservedCorners: layout.reservedCorners,
                navigationBarTrailingButtonsInset: layout.navigationBarTrailingButtonsInset,
                sideColumnNavigationButtonFrame: layout.sideColumnNavigationButtonFrame,
                additionalInsets: layout.additionalInsets,
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                screenCornerRadii: layout.screenCornerRadii,
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
    
    public enum BaseNavigationColors {
        case plain
        case blocks
    }
    
    public var node: Node {
        return self.displayNode as! Node
    }
    
    private var presentationData: PresentationData
    private var theme: Theme
    private let baseNavigationColors: BaseNavigationColors
    public private(set) var component: AnyComponent<ViewControllerComponentContainer.Environment>
    
    private var presentationDataDisposable: Disposable?
    public private(set) var validLayout: ContainerViewLayout?
    
    public var wasDismissed: (() -> Void)?
    public var customProceed: (() -> Void)?
    
    public init<C: Component>(
        context: AccountContext,
        component: C,
        navigationBarAppearance: NavigationBarAppearance,
        statusBarStyle: StatusBarStyle = .default,
        presentationMode: PresentationMode = .default,
        theme: Theme = .default,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        baseNavigationColors: BaseNavigationColors = .plain,
    ) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.component = AnyComponent(component)
        self.theme = theme
        self.baseNavigationColors = baseNavigationColors
        
        var effectiveUpdatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
        if let updatedPresentationData {
            effectiveUpdatedPresentationData = updatedPresentationData
        } else {
            effectiveUpdatedPresentationData = (initial: context.sharedContext.currentPresentationData.with { $0 }, signal: context.sharedContext.presentationData)
        }
        
        let presentationData = effectiveUpdatedPresentationData.initial
        self.presentationData = presentationData
        
        let navigationBarPresentationData: NavigationBarPresentationData?
        switch navigationBarAppearance {
        case .none:
            navigationBarPresentationData = nil
        case .transparent:
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: true, hideBadge: false)
        case .default:
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: false, hideBadge: false, edgeEffectColor: self.baseNavigationColors == .blocks ? self.presentationData.theme.list.itemBlocksBackgroundColor : nil)
        }
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self._hasGlassStyle = true
        
        self.setupPresentationData(effectiveUpdatedPresentationData, navigationBarAppearance: navigationBarAppearance, statusBarStyle: statusBarStyle, presentationMode: presentationMode)
    }
    
    public init<C: Component>(
        component: C,
        navigationBarAppearance: NavigationBarAppearance,
        statusBarStyle: StatusBarStyle = .default,
        presentationMode: PresentationMode = .default,
        theme: Theme = .default,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        baseNavigationColors: BaseNavigationColors = .plain
    ) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.component = AnyComponent(component)
        self.theme = theme
        self.baseNavigationColors = baseNavigationColors
        
        let presentationData = updatedPresentationData.initial
        self.presentationData = presentationData
        
        let navigationBarPresentationData: NavigationBarPresentationData?
        switch navigationBarAppearance {
        case .none:
            navigationBarPresentationData = nil
        case .transparent:
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: true, hideBadge: false)
        case .default:
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: false, hideBadge: false, edgeEffectColor: self.baseNavigationColors == .blocks ? self.presentationData.theme.list.itemBlocksBackgroundColor : nil)
        }
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.setupPresentationData(updatedPresentationData, navigationBarAppearance: navigationBarAppearance, statusBarStyle: statusBarStyle, presentationMode: presentationMode)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func setupPresentationData(_ updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>), navigationBarAppearance: NavigationBarAppearance, statusBarStyle: StatusBarStyle, presentationMode: PresentationMode) {
        self.presentationDataDisposable = (updatedPresentationData.signal
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
                    navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: true, hideBadge: false)
                case .default:
                    navigationBarPresentationData = NavigationBarPresentationData(presentationData: presentationData, hideBackground: false, hideBadge: false, edgeEffectColor: strongSelf.baseNavigationColors == .blocks ? strongSelf.presentationData.theme.list.itemBlocksBackgroundColor : nil)
                }
                if let navigationBarPresentationData {
                    strongSelf.navigationBar?.updatePresentationData(navigationBarPresentationData, transition: .immediate)
                }
                
                if let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: ContainedViewLayoutTransition.immediate)
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
    
    override open func loadDisplayNode() {
        self.displayNode = Node(presentationData: self.presentationData, controller: self, component: self.component, theme: self.theme)
        
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
    
    public func requestLayout(forceUpdate: Bool, transition: ComponentTransition) {
        self.forceNextUpdate = forceUpdate
        if self.isViewLoaded, let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout, transition: transition)
        }
        self.forceNextUpdate = false
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        
        self.validLayout = layout
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: ComponentTransition(transition))
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ComponentTransition) {
        super.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
        
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        
        self.validLayout = layout
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
    }
    
    public func updateComponent(component: AnyComponent<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) {
        self.component = component
        self.node.updateComponent(component: component, transition: transition)
    }
}

public extension ViewControllerComponentContainer.Environment {
    /// Whether this screen shows the floating form of an optional floating presentation (a centered sheet)
    /// instead of the phone one: wide layouts, except on a device that never shows floating panels (iPhone
    /// Duo, folded or unfolded). See `ContainerViewLayout.presentsFloatingPanels`.
    var presentsFloatingPanels: Bool {
        return self.metrics.widthClass == .regular && self.deviceMetrics.presentsFloatingPanels
    }
}
