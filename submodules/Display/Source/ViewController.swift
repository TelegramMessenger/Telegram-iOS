import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public protocol StandalonePresentableController: ViewController {
}

private func findCurrentResponder(_ view: UIView) -> UIResponder? {
    if view.isFirstResponder {
        return view
    } else {
        for subview in view.subviews {
            if let result = findCurrentResponder(subview) {
                return result
            }
        }
        return nil
    }
}

func findWindow(_ view: UIView) -> WindowHost? {
    if let view = view as? WindowHost {
        return view
    } else if let superview = view.superview {
        return findWindow(superview)
    } else {
        return nil
    }
}

public enum ViewControllerPresentationAnimation {
    case none
    case modalSheet
}

public struct ViewControllerSupportedOrientations: Equatable {
    public var regularSize: UIInterfaceOrientationMask
    public var compactSize: UIInterfaceOrientationMask
    
    public init(regularSize: UIInterfaceOrientationMask, compactSize: UIInterfaceOrientationMask) {
        self.regularSize = regularSize
        self.compactSize = compactSize
    }
    
    public func intersection(_ other: ViewControllerSupportedOrientations) -> ViewControllerSupportedOrientations {
        return ViewControllerSupportedOrientations(regularSize: self.regularSize.intersection(other.regularSize), compactSize: self.compactSize.intersection(other.compactSize))
    }
}

open class ViewControllerPresentationArguments {
    public let presentationAnimation: ViewControllerPresentationAnimation
    public let completion: (() -> Void)?
    
    public init(presentationAnimation: ViewControllerPresentationAnimation, completion: (() -> Void)? = nil) {
        self.presentationAnimation = presentationAnimation
        self.completion = completion
    }
}

public enum ViewControllerNavigationPresentation {
    case `default`
    case master
    case modal
    case flatModal
    case standaloneModal
    case modalInLargeLayout
}

public enum TabBarItemContextActionType {
    case none
    case always
    case whenActive
}

public protocol CustomViewControllerNavigationData: AnyObject {
    func combine(summary: CustomViewControllerNavigationDataSummary?) -> CustomViewControllerNavigationDataSummary?
}

public protocol CustomViewControllerNavigationDataSummary: AnyObject {
}

@objc open class ViewController: UIViewController, ContainableController {
    public struct NavigationLayout {
        public var navigationFrame: CGRect
        public var defaultContentHeight: CGFloat

        public init(navigationFrame: CGRect, defaultContentHeight: CGFloat) {
            self.navigationFrame = navigationFrame
            self.defaultContentHeight = defaultContentHeight
        }
    }

    private var validLayout: ContainerViewLayout?
    public var currentlyAppliedLayout: ContainerViewLayout? {
        return self.validLayout
    }
    
    public let presentationContext: PresentationContext
    
    public final var supportedOrientations: ViewControllerSupportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown) {
        didSet {
            if self.supportedOrientations != oldValue {
                self.window?.invalidateSupportedOrientations()
            }
        }
    }
    public final var lockedOrientation: UIInterfaceOrientationMask?
    public final var lockOrientation: Bool = false {
        didSet {
            if self.lockOrientation != oldValue {
                if !self.lockOrientation {
                    self.lockedOrientation = nil
                }
                if let window = self.window {
                    window.invalidateSupportedOrientations()
                }
            }
        }
    }
    
    var blocksInteractionUntilReady: Bool = false
    
    public final var isOpaqueWhenInOverlay: Bool = false
    public final var blocksBackgroundWhenInOverlay: Bool = false
    public final var acceptsFocusWhenInOverlay: Bool = false
    public final var automaticallyControlPresentationContextLayout: Bool = true
    public var updateTransitionWhenPresentedAsModal: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    public func requestUpdateParameters() {
        self.modalStyleOverlayTransitionFactorUpdated?(.immediate)
    }
    
    public func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations {
        return self.supportedOrientations
    }
    
    public final var deferScreenEdgeGestures: UIRectEdge = [] {
        didSet {
            if self.deferScreenEdgeGestures != oldValue {
                self.window?.invalidateDeferScreenEdgeGestures()
            }
        }
    }
    
    public final var prefersOnScreenNavigationHidden: Bool = false {
        didSet {
            if self.prefersOnScreenNavigationHidden != oldValue {
                self.window?.invalidatePrefersOnScreenNavigationHidden()
            }
        }
    }
    
    override open var prefersHomeIndicatorAutoHidden: Bool {
        return self.prefersOnScreenNavigationHidden
    }
    
    open var navigationPresentation: ViewControllerNavigationPresentation = .default
    open var _presentedInModal: Bool = false
    
    public var presentedOverCoveringView: Bool = false
    
    public var presentationArguments: Any?
    
    public var tabBarItemDebugTapAction: (() -> Void)?
    
    public private(set) var modalStyleOverlayTransitionFactor: CGFloat = 0.0
    public var modalStyleOverlayTransitionFactorUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public func updateModalStyleOverlayTransitionFactor(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.modalStyleOverlayTransitionFactor != value {
            self.modalStyleOverlayTransitionFactor = value
            self.modalStyleOverlayTransitionFactorUpdated?(transition)
        }
    }
    
    private var _displayNode: ASDisplayNode?
    public final var displayNode: ASDisplayNode {
        get {
            if let value = self._displayNode {
                return value
            }
            else {
                self.loadDisplayNode()
                if self._displayNode == nil {
                    fatalError("displayNode should be initialized after loadDisplayNode()")
                }
                return self._displayNode!
            }
        }
        set(value) {
            self._displayNode = value
        }
    }
    
    public final var isNodeLoaded: Bool {
        return self._displayNode != nil
    }
    
    public let statusBar: StatusBar
    public let navigationBar: NavigationBar?
    public private(set) var toolbar: Toolbar?
    
    public var displayNavigationBar = true
    open var navigationBarRequiresEntireLayoutUpdate: Bool {
        return true
    }
    
    private weak var activeInputViewCandidate: UIResponder?
    private weak var activeInputView: UIResponder?
    
    open var hasActiveInput: Bool = false
    
    open var overlayWantsToBeBelowKeyboard: Bool {
        return false
    }
    
    var internalOverlayWantsToBeBelowKeyboardUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public func overlayWantsToBeBelowKeyboardUpdated(transition: ContainedViewLayoutTransition) {
        self.internalOverlayWantsToBeBelowKeyboardUpdated?(transition)
    }
    
    private var navigationBarOrigin: CGFloat = 0.0

    open func navigationLayout(layout: ContainerViewLayout) -> NavigationLayout {
        let statusBarHeight: CGFloat = layout.statusBarHeight ?? 0.0
        var defaultNavigationBarHeight: CGFloat
        if self._presentedInModal && layout.orientation == .portrait {
            defaultNavigationBarHeight = 56.0
        } else {
            defaultNavigationBarHeight = 44.0
        }
        let navigationBarHeight: CGFloat = statusBarHeight + (self.navigationBar?.contentHeight(defaultHeight: defaultNavigationBarHeight) ?? defaultNavigationBarHeight)

        var navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: navigationBarHeight))

        navigationBarFrame.size.height += self.additionalNavigationBarHeight

        if !self.displayNavigationBar {
            navigationBarFrame.origin.y = -navigationBarFrame.size.height
        }

        self.navigationBarOrigin = navigationBarFrame.origin.y

        return NavigationLayout(navigationFrame: navigationBarFrame, defaultContentHeight: defaultNavigationBarHeight)
    }
    
    open var cleanNavigationHeight: CGFloat {
        if let navigationBar = self.navigationBar {
            var height = navigationBar.frame.maxY
            if let contentNode = navigationBar.contentNode, case .expansion = contentNode.mode {
                height += contentNode.nominalHeight - contentNode.height
            }
            return height
        } else {
            return 0.0
        }
    }

    open var additionalNavigationBarHeight: CGFloat {
        return 0.0
    }
    
    public var additionalSideInsets: UIEdgeInsets = UIEdgeInsets()
    
    private let _ready = Promise<Bool>(true)
    open var ready: Promise<Bool> {
        return self._ready
    }
    
    private var scrollToTopView: ScrollToTopView?
    public var scrollToTop: (() -> Void)? {
        didSet {
            if self.isViewLoaded {
                self.updateScrollToTopView()
            }
        }
    }
    public var scrollToTopWithTabBar: (() -> Void)?
    public var longTapWithTabBar: (() -> Void)?
    
    public var customPresentPreviewingController: ((ViewController, ASDisplayNode) -> ViewController?)?
    
    open func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
    
    open var customData: Any? {
        get {
            return nil
        }
    }
    
    open var customNavigationData: CustomViewControllerNavigationData? {
        get {
            return nil
        }
    }
    open var customNavigationDataSummary: CustomViewControllerNavigationDataSummary?
    
    public internal(set) var isInFocus: Bool = false {
        didSet {
            if self.isInFocus != oldValue {
                self.inFocusUpdated(isInFocus: self.isInFocus)
            }
        }
    }
    open func inFocusUpdated(isInFocus: Bool) {
    }

    public var attemptNavigation: (@escaping () -> Void) -> Bool = { _ in
        return true
    }
    
    open func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        return nil
    }
    
    open func didAppearInContextPreview() {
    }
    
    private func updateScrollToTopView() {
        /*if self.scrollToTop != nil {
            if let displayNode = self._displayNode , self.scrollToTopView == nil {
                let scrollToTopView = ScrollToTopView(frame: CGRect(x: 0.0, y: -1.0, width: displayNode.bounds.size.width, height: 1.0))
                scrollToTopView.action = { [weak self] in
                    if let scrollToTop = self?.scrollToTop {
                        scrollToTop()
                    }
                }
                self.scrollToTopView = scrollToTopView
                self.view.addSubview(scrollToTopView)
            }
        } else*/ if let scrollToTopView = self.scrollToTopView {
            scrollToTopView.removeFromSuperview()
            self.scrollToTopView = nil
        }
    }
    
    public init(navigationBarPresentationData: NavigationBarPresentationData?) {
        self.statusBar = StatusBar()
        if let navigationBarPresentationData = navigationBarPresentationData {
            self.navigationBar = NavigationBar(presentationData: navigationBarPresentationData)
        } else {
            self.navigationBar = nil
        }
        self.presentationContext = PresentationContext()
        
        super.init(nibName: nil, bundle: nil)
        
        self.navigationBar?.backPressed = { [weak self] in
            if let strongSelf = self, strongSelf.attemptNavigation({
                guard let strongSelf = self else {
                    return
                }
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    navigationController.filterController(strongSelf, animated: true)
                } else {
                    strongSelf.navigationController?.popViewController(animated: true)
                }
            }) {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    navigationController.filterController(strongSelf, animated: true)
                } else {
                    strongSelf.navigationController?.popViewController(animated: true)
                }
            }
        }
        self.navigationBar?.requestContainerLayout = { [weak self] transition in
            if let strongSelf = self, strongSelf.isNodeLoaded, let validLayout = strongSelf.validLayout {
                if strongSelf.navigationBarRequiresEntireLayoutUpdate {
                    strongSelf.containerLayoutUpdated(validLayout, transition: transition)
                } else {
                    strongSelf.updateNavigationBarLayout(validLayout, transition: transition)
                }
            }
        }
        self.navigationBar?.item = self.navigationItem
        //self.automaticallyAdjustsScrollViewInsets = false
        
        self.scrollToTopWithTabBar = { [weak self] in
            self?.scrollToTop?()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
    }

    open func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.applyNavigationBarLayout(layout, navigationLayout: self.navigationLayout(layout: layout), additionalBackgroundHeight: 0.0, transition: transition)
    }
    
    public func applyNavigationBarLayout(_ layout: ContainerViewLayout, navigationLayout: NavigationLayout, additionalBackgroundHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let statusBarHeight: CGFloat = layout.statusBarHeight ?? 0.0

        var navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: navigationLayout.navigationFrame.maxY))
        
        if !self.displayNavigationBar {
            navigationBarFrame.origin.y = -navigationBarFrame.size.height
        }
        
        self.navigationBarOrigin = navigationBarFrame.origin.y

        let isLandscape = layout.size.width > layout.size.height
        
        if let navigationBar = self.navigationBar {
            if let contentNode = navigationBar.contentNode, case .expansion = contentNode.mode, !self.displayNavigationBar {
                navigationBarFrame.origin.y -= navigationLayout.defaultContentHeight
                navigationBarFrame.size.height += contentNode.height + navigationLayout.defaultContentHeight + statusBarHeight
                //navigationBarFrame.origin.y += contentNode.height + statusBarHeight
            }
            if let _ = navigationBar.contentNode, let _ = navigationBar.secondaryContentNode, !self.displayNavigationBar {
                navigationBarFrame.size.height += NavigationBar.defaultSecondaryContentHeight
                //navigationBarFrame.origin.y += NavigationBar.defaultSecondaryContentHeight
            }
            navigationBar.updateLayout(size: navigationBarFrame.size, defaultHeight: navigationLayout.defaultContentHeight, additionalTopHeight: statusBarHeight, additionalContentHeight: self.additionalNavigationBarHeight, additionalBackgroundHeight: additionalBackgroundHeight, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, appearsHidden: !self.displayNavigationBar, isLandscape: isLandscape, transition: transition)
            if !transition.isAnimated {
                navigationBar.layer.removeAnimation(forKey: "bounds")
                navigationBar.layer.removeAnimation(forKey: "position")
            }
            transition.updateFrame(node: navigationBar, frame: navigationBarFrame)
            navigationBar.setHidden(!self.displayNavigationBar, animated: transition.isAnimated)
        }
    }
    
    open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        if !self.isViewLoaded {
            self.loadView()
        }
        if let _ = layout.statusBarHeight {
            self.statusBar.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: 40.0))
        }
        
        self.updateNavigationBarLayout(layout, transition: transition)
        
        if self.automaticallyControlPresentationContextLayout {
            self.presentationContext.containerLayoutUpdated(layout, transition: transition)
        }
        
        if let scrollToTopView = self.scrollToTopView {
            scrollToTopView.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: 10.0)
        }
    }
    
    open func updateModalTransition(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
    
    open func navigationStackConfigurationUpdated(next: [ViewController]) {
    }
    
    open override func loadView() {
        self.view = self.displayNode.view
        if let navigationBar = self.navigationBar {
            if navigationBar.supernode == nil {
                self.displayNode.addSubnode(navigationBar)
            }
        }
        self.view.autoresizingMask = []
        self.view.addSubview(self.statusBar.view)
        self.presentationContext.view = self.view
    }
    
    open func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNodeDidLoad()
    }
    
    open func displayNodeDidLoad() {
        self.updateScrollToTopView()
        if let backgroundColor = self.displayNode.backgroundColor, backgroundColor.alpha.isEqual(to: 1.0) {
            self.blocksBackgroundWhenInOverlay = true
            self.isOpaqueWhenInOverlay = true
        }
    }
    
    public func requestLayout(transition: ContainedViewLayoutTransition) {
        if self.isViewLoaded, let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout, transition: transition)
        }
    }
    
    open func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        
    }
    
    public func setDisplayNavigationBar(_ displayNavigationBar: Bool, transition: ContainedViewLayoutTransition = .immediate) {
        if displayNavigationBar != self.displayNavigationBar {
            self.displayNavigationBar = displayNavigationBar
            if let parent = self.parent as? TabBarController {
                if parent.currentController === self {
                    parent.displayNavigationBar = displayNavigationBar
                    parent.requestLayout(transition: transition)
                }
            } else {
                self.requestLayout(transition: transition)
            }
        }
    }
    
    public func setNavigationBarPresentationData(_ presentationData: NavigationBarPresentationData, animated: Bool) {
        if animated, let navigationBar = self.navigationBar {
            UIView.transition(with: navigationBar.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
            }, completion: nil)
        }
        self.navigationBar?.updatePresentationData(presentationData)
        if let parent = self.parent as? TabBarController {
            if parent.currentController === self {
                if animated, let navigationBar = parent.navigationBar {
                    UIView.transition(with: navigationBar.view, duration: 0.3, options: [.transitionCrossDissolve], animations: {
                    }, completion: nil)
                }
                parent.navigationBar?.updatePresentationData(presentationData)
            }
        }
    }
    
    public func setStatusBarStyle(_ style: StatusBarStyle, animated: Bool) {
        self.statusBar.updateStatusBarStyle(style, animated: animated)
        if let parent = self.parent as? TabBarController {
            if parent.currentController === self {
                parent.statusBar.updateStatusBarStyle(style, animated: animated)
            }
        }
    }
    
    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.window?.rootViewController?.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController as? NavigationController {
            var animated = flag
            if case .standaloneModal = self.navigationPresentation {
                animated = false
            }
            navigationController.filterController(self, animated: animated)
        } else {
            self.presentingViewController?.dismiss(animated: flag, completion: nil)
        }
    }
    
    public final var window: WindowHost? {
        if let window = self.view.window as? WindowHost {
            return window
        } else if let result = findWindow(self.view) {
            return result
        } else {
            if let parent = self.parent as? ViewController {
                return parent.window
            }
            return nil
        }
    }
    
    public func push(_ controller: ViewController) {
        (self.navigationController as? NavigationController)?.pushViewController(controller)
    }
    
    public func replace(with controller: ViewController) {
        if let navigationController = self.navigationController as? NavigationController {
            var controllers = navigationController.viewControllers
            controllers.removeAll(where: { $0 === self })
            controllers.append(controller)
            navigationController.setViewControllers(controllers, animated: true)
        }
    }
    
    open func present(_ controller: ViewController, in context: PresentationContextType, with arguments: Any? = nil, blockInteraction: Bool = false, completion: @escaping () -> Void = {}) {
        if !(controller is StandalonePresentableController), case .window = context, let arguments = arguments as? ViewControllerPresentationArguments, case .modalSheet = arguments.presentationAnimation, self.navigationController != nil {
            controller.navigationPresentation = .modal
            self.push(controller)
        } else {
            controller.presentationArguments = arguments
            switch context {
            case .current:
                self.presentationContext.present(controller, on: PresentationSurfaceLevel(rawValue: 0), completion: completion)
            case let .window(level):
                self.window?.present(controller, on: level, blockInteraction: blockInteraction, completion: completion)
            }
        }
    }
    
    public func forEachController(_ f: (ContainableController) -> Bool) {
        for (controller, _) in self.presentationContext.controllers {
            if !f(controller) {
                break
            }
        }
    }
    
    public func presentInGlobalOverlay(_ controller: ViewController, with arguments: Any? = nil) {
        controller.presentationArguments = arguments
        self.window?.presentInGlobalOverlay(controller)
    }
    
    public func addGlobalPortalHostView(sourceView: PortalSourceView) {
        self.window?.addGlobalPortalHostView(sourceView: sourceView)
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        self.activeInputViewCandidate = findCurrentResponder(self.view)
        
        super.viewWillDisappear(animated)
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        self.activeInputView = self.activeInputViewCandidate
        
        super.viewDidDisappear(animated)
    }
    
    open func viewWillLeaveNavigation() {
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        self.activeInputView = nil
        
        super.viewDidAppear(animated)
    }
    
    open func dismiss(completion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.filterController(self, animated: true)
        } else {
            self.presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    public final func navigationNextSibling() -> UIViewController? {
        if let navigationController = self.navigationController as? NavigationController {
            if let index = navigationController.viewControllers.firstIndex(where: { $0 === self }) {
                if index != navigationController.viewControllers.count - 1 {
                    return navigationController.viewControllers[index + 1]
                }
            }
        }
        return nil
    }
    
    public func traceVisibility() -> Bool {
        if !self.isViewLoaded {
            return false
        }
        return traceViewVisibility(view: self.view, rect: self.view.bounds)
    }
    
    open func setToolbar(_ toolbar: Toolbar?, transition: ContainedViewLayoutTransition) {
        if self.toolbar != toolbar {
            self.toolbar = toolbar
            if let parent = self.parent as? TabBarController {
                if parent.currentController === self {
                    parent.requestLayout(transition: transition)
                }
            }
        }
    }
    
    open func toolbarActionSelected(action: ToolbarActionOption) {
    }
    
    open var tabBarItemContextActionType: TabBarItemContextActionType = .none
    
    open func tabBarItemContextAction(sourceNode: ContextExtractedContentContainingNode, gesture: ContextGesture) {
    }
    
    open func tabBarDisabledAction() {
    }
    
    open func tabBarItemSwipeAction(direction: TabBarItemSwipeDirection) {
    }
    
    open func updatePossibleControllerDropContent(content: NavigationControllerDropContent?) {
    }
    
    open func acceptPossibleControllerDropContent(content: NavigationControllerDropContent) -> Bool {
        return false
    }
}

func traceIsOpaque(layer: CALayer, rect: CGRect) -> Bool {
    if layer.bounds.contains(rect) {
        if layer.isHidden {
            return false
        }
        if layer.opacity < 0.01 {
            return false
        }
        if let backgroundColor = layer.backgroundColor {
            var alpha: CGFloat = 0.0
            UIColor(cgColor: backgroundColor).getRed(nil, green: nil, blue: nil, alpha: &alpha)
            if alpha > 0.95 {
                return true
            }
        }
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                let sublayerRect = layer.convert(rect, to: sublayer)
                if traceIsOpaque(layer: sublayer, rect: sublayerRect) {
                    return true
                }
            }
        }
        return false
    } else {
        return false
    }
}

private func traceViewVisibility(view: UIView, rect: CGRect) -> Bool {
    if view.isHidden {
        return false
    }
    if view is UIWindow {
        return true
    } else if let superview = view.superview, let siblings = superview.layer.sublayers {
        if view.window == nil {
            return false
        }
        if let index = siblings.firstIndex(where: { $0 === view.layer }) {
            let viewFrame = view.convert(rect, to: superview)
            for i in (index + 1) ..< siblings.count {
                if siblings[i].frame.contains(viewFrame) {
                    let siblingSubframe = view.layer.convert(viewFrame, to: siblings[i])
                    if traceIsOpaque(layer: siblings[i], rect: siblingSubframe) {
                        return false
                    }
                }
            }
            return traceViewVisibility(view: superview, rect: viewFrame)
        } else {
            return false
        }
    } else {
        return false
    }
}
