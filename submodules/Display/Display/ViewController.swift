import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

#if BUCK
import DisplayPrivate
#endif

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

private func findWindow(_ view: UIView) -> WindowHost? {
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

@objc open class ViewController: UIViewController, ContainableController {
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
            }
        }
    }
    
    public final var isOpaqueWhenInOverlay: Bool = false
    public final var blocksBackgroundWhenInOverlay: Bool = false
    public final var automaticallyControlPresentationContextLayout: Bool = true
    
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
    
    public final var preferNavigationUIHidden: Bool = false {
        didSet {
            if self.preferNavigationUIHidden != oldValue {
                self.window?.invalidatePreferNavigationUIHidden()
            }
        }
    }
    
    override open func prefersHomeIndicatorAutoHidden() -> Bool {
        return self.preferNavigationUIHidden
    }
    
    public var presentationArguments: Any?
    
    public var tabBarItemDebugTapAction: (() -> Void)?
    
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
    private(set) var toolbar: Toolbar?
    
    private var previewingContext: Any?
    
    public var displayNavigationBar = true
    open var navigationBarRequiresEntireLayoutUpdate: Bool {
        return true
    }
    
    private weak var activeInputViewCandidate: UIResponder?
    private weak var activeInputView: UIResponder?
    
    open var hasActiveInput: Bool = false
    
    private var navigationBarOrigin: CGFloat = 0.0
    
    public var navigationOffset: CGFloat = 0.0 {
        didSet {
            if let navigationBar = self.navigationBar {
                var navigationBarFrame = navigationBar.frame
                navigationBarFrame.origin.y = self.navigationBarOrigin + self.navigationOffset
                navigationBar.frame = navigationBarFrame
            }
        }
    }
    
    open var navigationHeight: CGFloat {
        if let navigationBar = self.navigationBar {
            return navigationBar.frame.maxY
        } else {
            return 0.0
        }
    }
    
    open var navigationInsetHeight: CGFloat {
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
    
    open var visualNavigationInsetHeight: CGFloat {
        if let navigationBar = self.navigationBar {
            var height = navigationBar.frame.maxY
            if let contentNode = navigationBar.contentNode, case .expansion = contentNode.mode {
                //height += contentNode.height
            }
            return height
        } else {
            return 0.0
        }
    }
    
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
    
    open func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
    
    open var customData: Any? {
        get {
            return nil
        }
    }

    public var attemptNavigation: (@escaping () -> Void) -> Bool = { _ in
        return true
    }
    
    private func updateScrollToTopView() {
        if self.scrollToTop != nil {
            if let displayNode = self._displayNode , self.scrollToTopView == nil {
                let scrollToTopView = ScrollToTopView(frame: CGRect(x: 0.0, y: -1.0, width: displayNode.frame.size.width, height: 1.0))
                scrollToTopView.action = { [weak self] in
                    if let scrollToTop = self?.scrollToTop {
                        scrollToTop()
                    }
                }
                self.scrollToTopView = scrollToTopView
                self.view.addSubview(scrollToTopView)
            }
        } else if let scrollToTopView = self.scrollToTopView {
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
                self?.navigationController?.popViewController(animated: true)
            }) {
                strongSelf.navigationController?.popViewController(animated: true)
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
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.scrollToTopWithTabBar = { [weak self] in
            self?.scrollToTop?()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
    }
    
    private func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let statusBarHeight: CGFloat = layout.statusBarHeight ?? 0.0
        let navigationBarHeight: CGFloat = max(20.0, statusBarHeight) + (self.navigationBar?.contentHeight ?? 44.0)
        let navigationBarOffset: CGFloat
        if statusBarHeight.isZero {
            navigationBarOffset = -20.0
        } else {
            navigationBarOffset = 0.0
        }
        var navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarOffset), size: CGSize(width: layout.size.width, height: navigationBarHeight))
        if layout.statusBarHeight == nil {
            navigationBarFrame.size.height = (self.navigationBar?.contentHeight ?? 44.0) + 20.0
        }
        
        if !self.displayNavigationBar {
            navigationBarFrame.origin.y = -navigationBarFrame.size.height
        }
        
        self.navigationBarOrigin = navigationBarFrame.origin.y
        navigationBarFrame.origin.y += self.navigationOffset
        
        if let navigationBar = self.navigationBar {
            if let contentNode = navigationBar.contentNode, case .expansion = contentNode.mode, !self.displayNavigationBar {
                navigationBarFrame.origin.y += contentNode.height + statusBarHeight
            }
            navigationBar.updateLayout(size: navigationBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
            if !transition.isAnimated {
                navigationBar.layer.cancelAnimationsRecursive(key: "bounds")
                navigationBar.layer.cancelAnimationsRecursive(key: "position")
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
        transition.updateFrame(node: self.displayNode, frame: CGRect(origin: self.view.frame.origin, size: layout.size))
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
        if let layer = self.displayNode.layer as? CATracingLayer {
            layer.setTraceableInfo(CATracingLayerInfo(shouldBeAdjustedToInverseTransform: false, userData: self.displayNode.layer, tracingTag: WindowTracingTags.keyboard, disableChildrenTracingTags: 0))
        }
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
    
    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        super.present(viewControllerToPresent, animated: flag, completion: completion)
        return
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.dismiss(animated: flag, completion: completion)
        } else {
            super.dismiss(animated: flag, completion: completion)
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
    
    public func present(_ controller: ViewController, in context: PresentationContextType, with arguments: Any? = nil, blockInteraction: Bool = false, completion: @escaping () -> Void = {}) {
        controller.presentationArguments = arguments
        switch context {
            case .current:
                self.presentationContext.present(controller, on: PresentationSurfaceLevel(rawValue: 0), completion: completion)
            case let .window(level):
                self.window?.present(controller, on: level, blockInteraction: blockInteraction, completion: completion)
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
    
    open override func viewWillDisappear(_ animated: Bool) {
        self.activeInputViewCandidate = findCurrentResponder(self.view)
        
        super.viewWillDisappear(animated)
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        self.activeInputView = self.activeInputViewCandidate
        
        super.viewDidDisappear(animated)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        self.activeInputView = nil
        
        super.viewDidAppear(animated)
    }
    
    open func dismiss(completion: (() -> Void)? = nil) {
    }
    
    @available(iOSApplicationExtension 9.0, iOS 9.0, *)
    open func registerForPreviewing(with delegate: UIViewControllerPreviewingDelegate, sourceView: UIView, theme: PeekControllerTheme, onlyNative: Bool) {
        if self.traitCollection.forceTouchCapability == .available {
            let _ = super.registerForPreviewing(with: delegate, sourceView: sourceView)
        } else if !onlyNative {
            if self.previewingContext == nil {
                let previewingContext = SimulatedViewControllerPreviewing(theme: theme, delegate: delegate, sourceView: sourceView, node: self.displayNode, present: { [weak self] c, a in
                    self?.presentInGlobalOverlay(c, with: a)
                })
                self.previewingContext = previewingContext
            }
        }
    }
    
    @available(iOSApplicationExtension 9.0, iOS 9.0, *)
    public func registerForPreviewingNonNative(with delegate: UIViewControllerPreviewingDelegate, sourceView: UIView, theme: PeekControllerTheme) {
        if self.traitCollection.forceTouchCapability != .available {
            if self.previewingContext == nil {
                let previewingContext = SimulatedViewControllerPreviewing(theme: theme, delegate: delegate, sourceView: sourceView, node: self.displayNode, present: { [weak self] c, a in
                    self?.presentInGlobalOverlay(c, with: a)
                })
                self.previewingContext = previewingContext
            }
        }
    }
    
    @available(iOSApplicationExtension 9.0, iOS 9.0, *)
    open override func unregisterForPreviewing(withContext previewing: UIViewControllerPreviewing) {
        if self.previewingContext != nil {
            self.previewingContext = nil
        } else {
            super.unregisterForPreviewing(withContext: previewing)
        }
    }
    
    public final func navigationNextSibling() -> UIViewController? {
        if let navigationController = self.navigationController as? NavigationController {
            if let index = navigationController.viewControllers.index(where: { $0 === self }) {
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
        if let index = siblings.index(where: { $0 === view.layer }) {
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
