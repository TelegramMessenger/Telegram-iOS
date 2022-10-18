import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public enum NavigationStatusBarStyle {
    case black
    case white
}

public final class NavigationControllerTheme {
    public let statusBar: NavigationStatusBarStyle
    public let navigationBar: NavigationBarTheme
    public let emptyAreaColor: UIColor
    
    public init(statusBar: NavigationStatusBarStyle, navigationBar: NavigationBarTheme, emptyAreaColor: UIColor) {
        self.statusBar = statusBar
        self.navigationBar = navigationBar
        self.emptyAreaColor = emptyAreaColor
    }
}

public struct NavigationAnimationOptions : OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let removeOnMasterDetails = NavigationAnimationOptions(rawValue: 1 << 0)
}

public enum NavigationEmptyDetailsBackgoundMode {
    case image(UIImage)
    case wallpaper(UIImage)
}

private enum ControllerTransition {
    case none
    case appearance
}

private final class ControllerRecord {
    let controller: UIViewController
    var transition: ControllerTransition = .none
    
    init(controller: UIViewController) {
        self.controller = controller
    }
}

public enum NavigationControllerMode {
    case single
    case automaticMasterDetail
}

public enum MasterDetailLayoutBlackout : Equatable {
    case master
    case details
}

private enum RootContainer {
    case flat(NavigationContainer)
    case split(NavigationSplitContainer)
}

private final class GlobalOverlayContainerParent: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let subnodes = self.subnodes {
            for node in subnodes.reversed() {
                if let result = node.view.hitTest(point, with: event) {
                    return result
                }
            }
        }
        return nil
    }
}

private final class NavigationControllerNode: ASDisplayNode {
    private weak var controller: NavigationController?
    
    init(controller: NavigationController) {
        self.controller = controller
        
        super.init()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let controller = self.controller, controller.isInteractionDisabled() {
            return self.view
        } else {
            return super.hitTest(point, with: event)
        }
    }
    
    override func accessibilityPerformEscape() -> Bool {
        if let controller = self.controller, controller.viewControllers.count > 1 {
            let _ = self.controller?.popViewController(animated: true)
            return true
        }
        return false
    }
}

public protocol NavigationControllerDropContentItem: AnyObject {
}

public final class NavigationControllerDropContent {
    public let position: CGPoint
    public let item: NavigationControllerDropContentItem
    
    public init(position: CGPoint, item: NavigationControllerDropContentItem) {
        self.position = position
        self.item = item
    }
}

open class NavigationController: UINavigationController, ContainableController, UIGestureRecognizerDelegate {
    public var isOpaqueWhenInOverlay: Bool = true
    public var blocksBackgroundWhenInOverlay: Bool = true
    public var updateTransitionWhenPresentedAsModal: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let _ready = Promise<Bool>(true)
    open var ready: Promise<Bool> {
        return self._ready
    }
    
    private var masterDetailsBlackout: MasterDetailLayoutBlackout?
    private var backgroundDetailsMode: NavigationEmptyDetailsBackgoundMode?
    
    public var lockOrientation: Bool = false
    
    public var deferScreenEdgeGestures: UIRectEdge = UIRectEdge()
    public var prefersOnScreenNavigationHidden: Bool {
        return (self.topViewController as? ViewController)?.prefersOnScreenNavigationHidden ?? false
    }
    
    private let mode: NavigationControllerMode
    private var theme: NavigationControllerTheme
    private let isFlat: Bool
    
    var inCallNavigate: (() -> Void)?
    private var inCallStatusBar: StatusBar?
    private var updateInCallStatusBarState: CallStatusBarNode?
    private var globalScrollToTopNode: ScrollToTopNode?
    private var rootContainer: RootContainer?
    private var rootModalFrame: NavigationModalFrame?
    private var modalContainers: [NavigationModalContainer] = []
    private var overlayContainers: [NavigationOverlayContainer] = []
    
    private var globalOverlayContainers: [NavigationOverlayContainer] = []
    private var globalOverlayBelowKeyboardContainerParent: GlobalOverlayContainerParent?
    private var globalOverlayContainerParent: GlobalOverlayContainerParent?
    public var globalOverlayControllersUpdated: (() -> Void)?
    
    public private(set) var validLayout: ContainerViewLayout?
    private var validStatusBarStyle: NavigationStatusBarStyle?
    private var validStatusBarHidden: Bool?
    
    private var ignoreInputHeight: Bool = false
    private var currentStatusBarExternalHidden: Bool = false
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private var _presentedViewController: UIViewController?
    open override var presentedViewController: UIViewController? {
        return self._presentedViewController
    }
    
    private var _viewControllers: [ViewController] = []
    override open var viewControllers: [UIViewController] {
        get {
            return self._viewControllers.map { $0 as UIViewController }
        } set(value) {
            self.setViewControllers(value, animated: false)
        }
    }
    
    private var _viewControllersPromise = ValuePromise<[UIViewController]>()
    public var viewControllersSignal: Signal<[UIViewController], NoError> {
        return _viewControllersPromise.get()
    }
    
    private var _overlayControllersPromise = ValuePromise<[UIViewController]>()
    public var overlayControllersSignal: Signal<[UIViewController], NoError> {
        return _overlayControllersPromise.get()
    }
    
    override open var topViewController: UIViewController? {
        return self._viewControllers.last
    }
    
    var topOverlayController: ViewController? {
        if let overlayContainer = self.overlayContainers.last {
            return overlayContainer.controller
        } else {
            return nil
        }
    }
    
    private var _displayNode: ASDisplayNode?
    public var displayNode: ASDisplayNode {
        if let value = self._displayNode {
            return value
        }
        if !self.isViewLoaded {
            self.loadView()
        }
        
        return self._displayNode!
    }
    
    public var statusBarHost: StatusBarHost? {
        didSet {
        }
    }
    var keyboardViewManager: KeyboardViewManager?
    
    var updateSupportedOrientations: (() -> Void)?
    
    public func updateMasterDetailsBlackout(_ blackout: MasterDetailLayoutBlackout?, transition: ContainedViewLayoutTransition) {
        self.masterDetailsBlackout = blackout
        if isViewLoaded {
            self.view.endEditing(true)
        }
        self.requestLayout(transition: transition)
    }
    
    public func updateBackgroundDetailsMode(_ mode: NavigationEmptyDetailsBackgoundMode?, transition: ContainedViewLayoutTransition) {
        self.backgroundDetailsMode = mode
        self.requestLayout(transition: transition)
    }
    
    public init(mode: NavigationControllerMode, theme: NavigationControllerTheme, isFlat: Bool = false, backgroundDetailsMode: NavigationEmptyDetailsBackgoundMode? = nil) {
        self.mode = mode
        self.theme = theme
        self.isFlat = isFlat
        self.backgroundDetailsMode = backgroundDetailsMode
        
        super.init(nibName: nil, bundle: nil)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        preconditionFailure()
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations {
        var supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .allButUpsideDown)
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .flat(container):
                supportedOrientations = supportedOrientations.intersection(container.combinedSupportedOrientations(currentOrientationToLock: currentOrientationToLock))
            case .split:
                break
            }
        }
        for modalContainer in self.modalContainers {
            supportedOrientations = supportedOrientations.intersection(modalContainer.container.combinedSupportedOrientations(currentOrientationToLock: currentOrientationToLock))
        }
        for overlayContrainer in self.overlayContainers {
            let controller = overlayContrainer.controller
            if controller.lockOrientation {
                if let lockedOrientation = controller.lockedOrientation {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: lockedOrientation, compactSize: lockedOrientation))
                } else {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: currentOrientationToLock, compactSize: currentOrientationToLock))
                }
            } else {
                supportedOrientations = supportedOrientations.intersection(controller.supportedOrientations)
            }
        }
        for overlayContrainer in self.globalOverlayContainers {
            let controller = overlayContrainer.controller
            if controller.lockOrientation {
                if let lockedOrientation = controller.lockedOrientation {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: lockedOrientation, compactSize: lockedOrientation))
                } else {
                    supportedOrientations = supportedOrientations.intersection(ViewControllerSupportedOrientations(regularSize: currentOrientationToLock, compactSize: currentOrientationToLock))
                }
            } else {
                supportedOrientations = supportedOrientations.intersection(controller.supportedOrientations)
            }
        }
        return supportedOrientations
    }
    
    fileprivate func isInteractionDisabled() -> Bool {
        for overlayContainer in self.overlayContainers {
            if overlayContainer.blocksInteractionUntilReady && !overlayContainer.isReady {
                return true
            }
        }
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .flat(container):
                if container.hasNonReadyControllers() {
                    return true
                }
            case let .split(splitContainer):
                if splitContainer.hasNonReadyControllers() {
                    return true
                }
            }
        }
        return false
    }
    
    public func updateTheme(_ theme: NavigationControllerTheme) {
        self.theme = theme
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .split(container):
                container.updateTheme(theme: theme)
            case .flat:
                break
            }
        }
        if self.isViewLoaded {
            self.displayNode.backgroundColor = theme.emptyAreaColor
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .immediate)
            }
        }
    }
    
    open func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        return nil
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        if !self.isViewLoaded {
            self.loadView()
        }
        self.validLayout = layout
        self.updateContainers(layout: layout, transition: transition)
    }
    
    private weak var currentTopVisibleOverlayContainerStatusBar: NavigationOverlayContainer? = nil
    
    private var isUpdatingContainers: Bool = false
    
    func updateContainersNonReentrant(transition: ContainedViewLayoutTransition) {
        if self.isUpdatingContainers {
            return
        }
        if let layout = self.validLayout {
            self.updateContainers(layout: layout, transition: transition)
        }
    }
        
    private func updateContainers(layout rawLayout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.isUpdatingContainers = true
                
        var layout = rawLayout
        
        if self.ignoreInputHeight {
            if layout.inputHeight == nil {
                self.ignoreInputHeight = false
            } else {
                layout = layout.withUpdatedInputHeight(nil)
            }
        }
        
        let initialPrefersOnScreenNavigationHidden = self.collectPrefersOnScreenNavigationHidden()
        
        let belowKeyboardOverlayLayout = layout
        var globalOverlayLayout = layout
//        globalOverlayLayout.inputHeight = nil
        
        if let globalOverlayBelowKeyboardContainerParent = self.globalOverlayBelowKeyboardContainerParent {
            if globalOverlayBelowKeyboardContainerParent.view.superview != self.displayNode.view {
                self.displayNode.addSubnode(globalOverlayBelowKeyboardContainerParent)
            }
            
            /*overlayLayout.size.height = overlayLayout.size.height - (layout.inputHeight ?? 0.0)
            overlayLayout.inputHeight = nil
            overlayLayout.inputHeightIsInteractivellyChanging = false*/
        }
        
        if let globalOverlayContainerParent = self.globalOverlayContainerParent {
            let portraitSize = CGSize(width: min(layout.size.width, layout.size.height), height: max(layout.size.width, layout.size.height))
            let screenSize = UIScreen.main.bounds.size
            let portraitScreenSize = CGSize(width: min(screenSize.width, screenSize.height), height: max(screenSize.width, screenSize.height))
            if portraitSize.width != portraitScreenSize.width || portraitSize.height != portraitScreenSize.height {
                if globalOverlayContainerParent.view.superview != self.displayNode.view {
                    self.displayNode.addSubnode(globalOverlayContainerParent)
                }
                
                globalOverlayLayout.size.height = globalOverlayLayout.size.height - (layout.inputHeight ?? 0.0)
                globalOverlayLayout.inputHeight = nil
                globalOverlayLayout.inputHeightIsInteractivellyChanging = false
            } else if layout.inputHeight == nil {
                if globalOverlayContainerParent.view.superview != self.displayNode.view {
                    self.displayNode.addSubnode(globalOverlayContainerParent)
                }
            } else {
                if let statusBarHost = self.statusBarHost, let keyboardWindow = statusBarHost.keyboardWindow, let keyboardView = statusBarHost.keyboardView, !keyboardView.frame.height.isZero, isViewVisibleInHierarchy(keyboardView) {
                    if globalOverlayContainerParent.view.superview != keyboardWindow {
                        globalOverlayContainerParent.layer.zPosition = 1000.0
                        keyboardWindow.addSubnode(globalOverlayContainerParent)
                    }
                } else if globalOverlayContainerParent.view.superview !== self.displayNode.view {
                    self.displayNode.addSubnode(globalOverlayContainerParent)
                }
            }
        }
        
        if let globalScrollToTopNode = self.globalScrollToTopNode {
            globalScrollToTopNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -1.0), size: CGSize(width: layout.size.width, height: 1.0))
        }
        
        let overlayContainerLayout = layout
        
        if let inCallStatusBar = self.inCallStatusBar {
            let isLandscape = layout.size.width > layout.size.height
            var minHeight: CGFloat
            if case .compact = layout.metrics.widthClass, isLandscape {
                minHeight = 22.0
            } else {
                minHeight = 40.0
            }
            var inCallStatusBarFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: max(layout.statusBarHeight ?? 0.0, max(minHeight, layout.safeInsets.top))))
            if (layout.deviceMetrics.hasTopNotch || layout.deviceMetrics.hasDynamicIsland) && !isLandscape {
                inCallStatusBarFrame.size.height += 12.0
            }
            if inCallStatusBar.frame.isEmpty {
                inCallStatusBar.frame = inCallStatusBarFrame
            } else {
                transition.updateFrame(node: inCallStatusBar, frame: inCallStatusBarFrame)
            }
            inCallStatusBar.callStatusBarNode?.update(size: inCallStatusBarFrame.size)
            inCallStatusBar.callStatusBarNode?.frame = inCallStatusBarFrame
            layout.statusBarHeight = inCallStatusBarFrame.height
            inCallStatusBar.frame = inCallStatusBarFrame
            
            if let forceInCallStatusBar = self.updateInCallStatusBarState {
                self.updateInCallStatusBarState = nil
                inCallStatusBar.updateState(statusBar: nil, withSafeInsets: !layout.safeInsets.top.isZero, inCallNode: forceInCallStatusBar, animated: false)
            }
        }
        
        if let globalOverlayBelowKeyboardContainerParent = self.globalOverlayBelowKeyboardContainerParent {
            transition.updateFrame(node: globalOverlayBelowKeyboardContainerParent, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        if let globalOverlayContainerParent = self.globalOverlayContainerParent {
            transition.updateFrame(node: globalOverlayContainerParent, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        
        let navigationLayout = makeNavigationLayout(mode: self.mode, layout: layout, controllers: self._viewControllers)
        
        var transition = transition
        var statusBarStyle: StatusBarStyle = .Ignore
        var statusBarHidden = false
        var animateStatusBarStyleTransition = transition.isAnimated
        
        var modalContainers: [NavigationModalContainer] = []
        for i in 0 ..< navigationLayout.modal.count {
            var existingModalContainer: NavigationModalContainer?
            loop: for currentModalContainer in self.modalContainers {
                for controller in navigationLayout.modal[i].controllers {
                    if currentModalContainer.container.controllers.contains(where: { $0 === controller }) {
                        existingModalContainer = currentModalContainer
                        break loop
                    }
                }
            }
            
            let modalContainer: NavigationModalContainer
            if let existingModalContainer = existingModalContainer {
                modalContainer = existingModalContainer
            } else {
                modalContainer = NavigationModalContainer(theme: self.theme, isFlat: navigationLayout.modal[i].isFlat, controllerRemoved: { [weak self] controller in
                    self?.controllerRemoved(controller)
                })
                modalContainer.container.statusBarStyleUpdated = { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateContainersNonReentrant(transition: transition)
                }
                self.modalContainers.append(modalContainer)
                if !modalContainer.isReady {
                    modalContainer.isReadyUpdated = { [weak self, weak modalContainer] in
                        guard let strongSelf = self, let _ = modalContainer else {
                            return
                        }
                        strongSelf.updateContainersNonReentrant(transition: .animated(duration: 0.5, curve: .spring))
                    }
                }
                modalContainer.updateDismissProgress = { [weak self, weak modalContainer] _, transition in
                    guard let strongSelf = self, let _ = modalContainer else {
                        return
                    }
                    strongSelf.updateContainersNonReentrant(transition: transition)
                }
                modalContainer.interactivelyDismissed = { [weak self, weak modalContainer] hadInputFocus in
                    guard let strongSelf = self, let modalContainer = modalContainer else {
                        return
                    }
                    let controllers = strongSelf._viewControllers.filter { controller in
                        return !modalContainer.container.controllers.contains(where: { $0 === controller })
                    }
                    strongSelf.ignoreInputHeight = hadInputFocus
                    strongSelf.setViewControllers(controllers, animated: false)
                    strongSelf.ignoreInputHeight = false
                }
            }
            modalContainers.append(modalContainer)
        }
        
        for container in self.modalContainers {
            if !modalContainers.contains(where: { $0 === container }) {
                if viewTreeContainsFirstResponder(view: container.view) {
                    self.ignoreInputHeight = true
                    container.view.endEditing(true)
                }
                
                transition = container.dismiss(transition: transition, completion: { [weak container] in
                    container?.removeFromSupernode()
                })
            }
        }
        self.modalContainers = modalContainers
        
        var topVisibleOverlayContainerWithStatusBar: NavigationOverlayContainer?
        
        var notifyGlobalOverlayControllersUpdated = false
        
        var additionalSideInsets = UIEdgeInsets()
        
        var modalStyleOverlayTransitionFactor: CGFloat = 0.0
        var previousGlobalOverlayBelowKeyboardContainer: NavigationOverlayContainer?
        var previousGlobalOverlayContainer: NavigationOverlayContainer?
        for i in (0 ..< self.globalOverlayContainers.count).reversed() {
            let overlayContainer = self.globalOverlayContainers[i]
            
            let containerTransition: ContainedViewLayoutTransition
            if overlayContainer.supernode == nil {
                containerTransition = .immediate
            } else {
                containerTransition = transition
            }
            
            let overlayWantsToBeBelowKeyboard = overlayContainer.controller.overlayWantsToBeBelowKeyboard
            let overlayLayout: ContainerViewLayout
            if overlayWantsToBeBelowKeyboard {
                overlayLayout = belowKeyboardOverlayLayout
            } else {
                overlayLayout = globalOverlayLayout
            }
            
            containerTransition.updateFrame(node: overlayContainer, frame: CGRect(origin: CGPoint(), size: overlayLayout.size))
            overlayContainer.update(layout: overlayLayout, transition: containerTransition)
            
            modalStyleOverlayTransitionFactor = max(modalStyleOverlayTransitionFactor, overlayContainer.controller.modalStyleOverlayTransitionFactor)
            
            if overlayContainer.isReady {
                let wasNotAdded = overlayContainer.supernode == nil
                
                if overlayWantsToBeBelowKeyboard {
                    if overlayContainer.supernode !== self.globalOverlayBelowKeyboardContainerParent {
                        if let previousGlobalOverlayBelowKeyboardContainer = previousGlobalOverlayBelowKeyboardContainer {
                            self.globalOverlayBelowKeyboardContainerParent?.insertSubnode(overlayContainer, belowSubnode: previousGlobalOverlayBelowKeyboardContainer)
                        } else {
                            self.globalOverlayBelowKeyboardContainerParent?.addSubnode(overlayContainer)
                        }
                    }
                } else {
                    if overlayContainer.supernode !== self.globalOverlayContainerParent {
                        if let previousGlobalOverlayContainer = previousGlobalOverlayContainer {
                            self.globalOverlayContainerParent?.insertSubnode(overlayContainer, belowSubnode: previousGlobalOverlayContainer)
                        } else {
                            self.globalOverlayContainerParent?.addSubnode(overlayContainer)
                        }
                    }
                }
                
                if wasNotAdded {
                    overlayContainer.transitionIn()
                    notifyGlobalOverlayControllersUpdated = true
                    overlayContainer.controller.internalOverlayWantsToBeBelowKeyboardUpdated = { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateContainersNonReentrant(transition: transition)
                    }
                }
            }
            
            let controllerAdditionalSideInsets = overlayContainer.controller.additionalSideInsets
            additionalSideInsets = UIEdgeInsets(top: 0.0, left: max(additionalSideInsets.left, controllerAdditionalSideInsets.left), bottom: 0.0, right: max(additionalSideInsets.right, controllerAdditionalSideInsets.right))
            
            if overlayContainer.supernode != nil {
                if overlayContainer.controller.overlayWantsToBeBelowKeyboard {
                    previousGlobalOverlayBelowKeyboardContainer = overlayContainer
                } else {
                    previousGlobalOverlayContainer = overlayContainer
                }
                let controllerStatusBarStyle = overlayContainer.controller.statusBar.statusBarStyle
                switch controllerStatusBarStyle {
                case .Black, .White, .Hide:
                    if topVisibleOverlayContainerWithStatusBar == nil {
                        topVisibleOverlayContainerWithStatusBar = overlayContainer
                    }
                    if case .Hide = controllerStatusBarStyle {
                        statusBarHidden = true
                    } else {
                        statusBarHidden = overlayContainer.controller.statusBar.alpha.isZero
                    }
                case .Ignore:
                    break
                }
            }
        }
                
        var previousOverlayContainer: NavigationOverlayContainer?
        for i in (0 ..< self.overlayContainers.count).reversed() {
            let overlayContainer = self.overlayContainers[i]
            
            let containerTransition: ContainedViewLayoutTransition
            if overlayContainer.supernode == nil {
                containerTransition = .immediate
            } else {
                containerTransition = transition
            }
            
            containerTransition.updateFrame(node: overlayContainer, frame: CGRect(origin: CGPoint(), size: overlayContainerLayout.size))
            overlayContainer.update(layout: overlayContainerLayout, transition: containerTransition)
            
            modalStyleOverlayTransitionFactor = max(modalStyleOverlayTransitionFactor, overlayContainer.controller.modalStyleOverlayTransitionFactor)
            
            if overlayContainer.supernode == nil && overlayContainer.isReady {
                if let previousOverlayContainer = previousOverlayContainer {
                    self.displayNode.insertSubnode(overlayContainer, belowSubnode: previousOverlayContainer)
                } else if let globalScrollToTopNode = self.globalScrollToTopNode {
                    self.displayNode.insertSubnode(overlayContainer, belowSubnode: globalScrollToTopNode)
                } else if let globalOverlayBelowKeyboardContainerParent = self.globalOverlayBelowKeyboardContainerParent {
                    self.displayNode.insertSubnode(overlayContainer, belowSubnode: globalOverlayBelowKeyboardContainerParent)
                } else if let globalOverlayContainerParent = self.globalOverlayContainerParent {
                    self.displayNode.insertSubnode(overlayContainer, belowSubnode: globalOverlayContainerParent)
                } else {
                    self.displayNode.addSubnode(overlayContainer)
                }
                overlayContainer.transitionIn()
            }
            
            let controllerAdditionalSideInsets = overlayContainer.controller.additionalSideInsets
            additionalSideInsets = UIEdgeInsets(top: 0.0, left: max(additionalSideInsets.left, controllerAdditionalSideInsets.left), bottom: 0.0, right: max(additionalSideInsets.right, controllerAdditionalSideInsets.right))
            
            if overlayContainer.supernode != nil {
                previousOverlayContainer = overlayContainer
                let controllerStatusBarStyle = overlayContainer.controller.statusBar.statusBarStyle
                switch controllerStatusBarStyle {
                case .Black, .White, .Hide:
                    if topVisibleOverlayContainerWithStatusBar == nil {
                        topVisibleOverlayContainerWithStatusBar = overlayContainer
                    }
                    if case .Hide = controllerStatusBarStyle {
                        statusBarHidden = true
                    } else {
                        statusBarHidden = overlayContainer.controller.statusBar.alpha.isZero
                    }
                case .Ignore:
                    break
                }
            }
        }
                
        if self.currentTopVisibleOverlayContainerStatusBar !== topVisibleOverlayContainerWithStatusBar {
            animateStatusBarStyleTransition = true
            self.currentTopVisibleOverlayContainerStatusBar = topVisibleOverlayContainerWithStatusBar
        }
        
        var previousModalContainer: NavigationModalContainer?
        var topVisibleModalContainerWithStatusBar: NavigationModalContainer?
        var visibleModalCount = 0
        var topModalIsFlat = false
        var topFlatModalHasProgress = false
        let isLandscape = layout.orientation == .landscape
        var hasVisibleStandaloneModal = false
        var topModalDismissProgress: CGFloat = 0.0
        
        for i in (0 ..< navigationLayout.modal.count).reversed() {
            let modalContainer = self.modalContainers[i]
            
            var isStandaloneModal = false
            if let controller = modalContainer.container.controllers.first, case .standaloneModal = controller.navigationPresentation {
                isStandaloneModal = true
            }
            
            let containerTransition: ContainedViewLayoutTransition
            if modalContainer.supernode == nil {
                containerTransition = .immediate
            } else {
                containerTransition = transition
            }
            
            let effectiveModalTransition: CGFloat
            if visibleModalCount == 0 || navigationLayout.modal[i].isFlat {
                effectiveModalTransition = 0.0
            } else if visibleModalCount == 1 {
                effectiveModalTransition = 1.0 - topModalDismissProgress
            } else {
                effectiveModalTransition = 1.0
            }
            
            if navigationLayout.modal[i].isFlat, let lastController = navigationLayout.modal[i].controllers.last {
                lastController.modalStyleOverlayTransitionFactorUpdated = { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateContainersNonReentrant(transition: transition)
                }
                modalStyleOverlayTransitionFactor = max(modalStyleOverlayTransitionFactor, lastController.modalStyleOverlayTransitionFactor)
                topFlatModalHasProgress = modalStyleOverlayTransitionFactor > 0.0
            }
            
            containerTransition.updateFrame(node: modalContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
            modalContainer.update(layout: modalContainer.isFlat ? globalOverlayLayout : layout, controllers: navigationLayout.modal[i].controllers, coveredByModalTransition: effectiveModalTransition, transition: containerTransition)
            
            if modalContainer.supernode == nil && modalContainer.isReady {
                if let previousModalContainer = previousModalContainer {
                    self.displayNode.insertSubnode(modalContainer, belowSubnode: previousModalContainer)
                } else if let inCallStatusBar = self.inCallStatusBar {
                    self.displayNode.insertSubnode(modalContainer, belowSubnode: inCallStatusBar)
                } else if let previousOverlayContainer = previousOverlayContainer {
                    self.displayNode.insertSubnode(modalContainer, belowSubnode: previousOverlayContainer)
                } else if let globalScrollToTopNode = self.globalScrollToTopNode {
                    self.displayNode.insertSubnode(modalContainer, belowSubnode: globalScrollToTopNode)
                } else {
                    self.displayNode.addSubnode(modalContainer)
                }
                modalContainer.animateIn(transition: transition)
            }
            
            if modalContainer.supernode != nil {
                if !hasVisibleStandaloneModal && !isStandaloneModal && !modalContainer.isFlat {
                    visibleModalCount += 1
                }
                if isStandaloneModal {
                    hasVisibleStandaloneModal = true
                    visibleModalCount = 0
                }
                if previousModalContainer == nil {
                    topModalIsFlat = modalContainer.isFlat
                    
                    topModalDismissProgress = modalContainer.dismissProgress
                    if case .compact = layout.metrics.widthClass {
                        modalContainer.keyboardViewManager = self.keyboardViewManager
                        modalContainer.canHaveKeyboardFocus = true
                    } else {
                        modalContainer.keyboardViewManager = nil
                        modalContainer.canHaveKeyboardFocus = true
                    }
                    
                    if modalContainer.isFlat {
                        let controllerStatusBarStyle = modalContainer.container.statusBarStyle
                        switch controllerStatusBarStyle {
                        case .Black, .White, .Hide:
                            if topVisibleModalContainerWithStatusBar == nil {
                                topVisibleModalContainerWithStatusBar = modalContainer
                            }
                            if case .Hide = controllerStatusBarStyle {
                                statusBarHidden = true
                            } else {
                                statusBarHidden = false
                            }
                        case .Ignore:
                            break
                        }
                    }
                } else {
                    modalContainer.keyboardViewManager = nil
                    modalContainer.canHaveKeyboardFocus = false
                }
                previousModalContainer = modalContainer
                if isStandaloneModal {
                    switch modalContainer.container.statusBarStyle {
                    case .Hide:
                        statusBarHidden = true
                    default:
                        break
                    }
                }
            }
        }
        
        layout.additionalInsets.left = max(layout.intrinsicInsets.left, additionalSideInsets.left)
        layout.additionalInsets.right = max(layout.intrinsicInsets.right, additionalSideInsets.right)
        
        switch navigationLayout.root {
        case let .flat(controllers):
            if let rootContainer = self.rootContainer {
                switch rootContainer {
                case let .flat(flatContainer):
                    if previousModalContainer == nil {
                        flatContainer.keyboardViewManager = self.keyboardViewManager
                        flatContainer.canHaveKeyboardFocus = true
                    } else {
                        flatContainer.keyboardViewManager = nil
                        flatContainer.canHaveKeyboardFocus = false
                    }
                    transition.updateFrame(node: flatContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
                    flatContainer.update(layout: layout, canBeClosed: false, controllers: controllers, transition: transition)
                case let .split(splitContainer):
                    let flatContainer = NavigationContainer(isFlat: self.isFlat, controllerRemoved: { [weak self] controller in
                        self?.controllerRemoved(controller)
                    })
                    flatContainer.statusBarStyleUpdated = { [weak self] transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateContainersNonReentrant(transition: transition)
                    }
                    if previousModalContainer == nil {
                        flatContainer.keyboardViewManager = self.keyboardViewManager
                        flatContainer.canHaveKeyboardFocus = true
                    } else {
                        flatContainer.keyboardViewManager = nil
                        flatContainer.canHaveKeyboardFocus = false
                    }
                    self.displayNode.insertSubnode(flatContainer, at: 0)
                    self.rootContainer = .flat(flatContainer)
                    flatContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
                    flatContainer.update(layout: layout, canBeClosed: false, controllers: controllers, transition: .immediate)
                    splitContainer.removeFromSupernode()
                }
            } else {
                let flatContainer = NavigationContainer(isFlat: self.isFlat, controllerRemoved: { [weak self] controller in
                    self?.controllerRemoved(controller)
                })
                flatContainer.statusBarStyleUpdated = { [weak self] transition in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateContainersNonReentrant(transition: transition)
                }
                if previousModalContainer == nil {
                    flatContainer.keyboardViewManager = self.keyboardViewManager
                    flatContainer.canHaveKeyboardFocus = true
                } else {
                    flatContainer.keyboardViewManager = nil
                    flatContainer.canHaveKeyboardFocus = false
                }
                self.displayNode.insertSubnode(flatContainer, at: 0)
                self.rootContainer = .flat(flatContainer)
                flatContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
                flatContainer.update(layout: layout, canBeClosed: false, controllers: controllers, transition: .immediate)
            }
        case let .split(masterControllers, detailControllers):
            if let rootContainer = self.rootContainer {
                switch rootContainer {
                case let .flat(flatContainer):
                    let splitContainer = NavigationSplitContainer(theme: self.theme, controllerRemoved: { [weak self] controller in
                        self?.controllerRemoved(controller)
                    }, scrollToTop: { [weak self] subject in
                        self?.scrollToTop(subject)
                    })
                    self.displayNode.insertSubnode(splitContainer, at: 0)
                    self.rootContainer = .split(splitContainer)
                    if previousModalContainer == nil {
                        splitContainer.canHaveKeyboardFocus = true
                    } else {
                        splitContainer.canHaveKeyboardFocus = false
                    }
                    splitContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
                    splitContainer.update(layout: layout, masterControllers: masterControllers, detailControllers: detailControllers, transition: .immediate)
                    flatContainer.statusBarStyleUpdated = nil
                    flatContainer.removeFromSupernode()
                case let .split(splitContainer):
                    if previousModalContainer == nil {
                        splitContainer.canHaveKeyboardFocus = true
                    } else {
                        splitContainer.canHaveKeyboardFocus = false
                    }
                    transition.updateFrame(node: splitContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
                    splitContainer.update(layout: layout, masterControllers: masterControllers, detailControllers: detailControllers, transition: transition)
                }
            } else {
                let splitContainer = NavigationSplitContainer(theme: self.theme, controllerRemoved: { [weak self] controller in
                    self?.controllerRemoved(controller)
                }, scrollToTop: { [weak self] subject in
                    self?.scrollToTop(subject)
                })
                self.displayNode.insertSubnode(splitContainer, at: 0)
                self.rootContainer = .split(splitContainer)
                if previousModalContainer == nil {
                    splitContainer.canHaveKeyboardFocus = true
                } else {
                    splitContainer.canHaveKeyboardFocus = false
                }
                splitContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
                splitContainer.update(layout: layout, masterControllers: masterControllers, detailControllers: detailControllers, transition: .immediate)
            }
        }
        
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .flat(container):
                statusBarStyle = container.statusBarStyle
                self.globalScrollToTopNode?.isHidden = false
            case .split:
                self.globalScrollToTopNode?.isHidden = true
            }
        }
        
        if self._keepModalDismissProgress {
            modalStyleOverlayTransitionFactor = 0.0
            self._keepModalDismissProgress = false
        }
        
        topModalDismissProgress = max(topModalDismissProgress, modalStyleOverlayTransitionFactor)
        
        switch layout.metrics.widthClass {
        case .compact:
            if visibleModalCount != 0 || !modalStyleOverlayTransitionFactor.isZero {
                let effectiveRootModalDismissProgress: CGFloat
                let visibleRootModalDismissProgress: CGFloat
                var additionalModalFrameProgress: CGFloat
                if visibleModalCount == 1 {
                    if topFlatModalHasProgress {
                        effectiveRootModalDismissProgress = 0.0
                        visibleRootModalDismissProgress = effectiveRootModalDismissProgress
                        additionalModalFrameProgress = 1.0 - topModalDismissProgress
                    } else {
                        effectiveRootModalDismissProgress = topModalDismissProgress
                        visibleRootModalDismissProgress = effectiveRootModalDismissProgress
                        additionalModalFrameProgress = 0.0
                    }
                } else if visibleModalCount >= 2 {
                    effectiveRootModalDismissProgress = 0.0
                    visibleRootModalDismissProgress = topModalDismissProgress
                    additionalModalFrameProgress = 1.0 - topModalDismissProgress
                } else {
                    effectiveRootModalDismissProgress = 1.0 - modalStyleOverlayTransitionFactor
                    visibleRootModalDismissProgress = effectiveRootModalDismissProgress
                    if visibleModalCount == 0 {
                        additionalModalFrameProgress = 0.0
                    } else {
                        additionalModalFrameProgress = 1.0
                    }
                }
                
                let rootModalFrame: NavigationModalFrame
                let modalFrameTransition: ContainedViewLayoutTransition = transition
                var forceStatusBarAnimation = false
                if let current = self.rootModalFrame {
                    rootModalFrame = current
                    transition.updateFrame(node: rootModalFrame, frame: CGRect(origin: CGPoint(), size: layout.size))
                    rootModalFrame.update(layout: layout, transition: modalFrameTransition)
                    rootModalFrame.updateDismissal(transition: transition, progress: effectiveRootModalDismissProgress, additionalProgress: additionalModalFrameProgress, completion: {})
                    forceStatusBarAnimation = true
                } else {
                    rootModalFrame = NavigationModalFrame()
                    self.rootModalFrame = rootModalFrame
                    if let rootContainer = self.rootContainer {
                        var rootContainerNode: ASDisplayNode
                        switch rootContainer {
                        case let .flat(container):
                            rootContainerNode = container
                        case let .split(container):
                            rootContainerNode = container
                        }
                        self.displayNode.insertSubnode(rootModalFrame, aboveSubnode: rootContainerNode)
                    }
                    rootModalFrame.frame = CGRect(origin: CGPoint(), size: layout.size)
                    rootModalFrame.update(layout: layout, transition: .immediate)
                    rootModalFrame.updateDismissal(transition: transition, progress: effectiveRootModalDismissProgress, additionalProgress: additionalModalFrameProgress, completion: {})
                }
                if effectiveRootModalDismissProgress < 0.5 {
                    statusBarStyle = .White
                    if forceStatusBarAnimation {
                        animateStatusBarStyleTransition = true
                    }
                } else {
                    if forceStatusBarAnimation {
                        animateStatusBarStyleTransition = true
                    }
                }
                if let rootContainer = self.rootContainer {
                    var rootContainerNode: ASDisplayNode
                    switch rootContainer {
                    case let .flat(container):
                        rootContainerNode = container
                    case let .split(container):
                        rootContainerNode = container
                    }
                    var topInset: CGFloat = 0.0
                    if let statusBarHeight = layout.statusBarHeight {
                        topInset += statusBarHeight
                    }
                    let maxScale: CGFloat
                    let maxOffset: CGFloat
                    if (topModalIsFlat && !topFlatModalHasProgress) || isLandscape {
                        maxScale = 1.0
                        maxOffset = 0.0
                    } else if visibleModalCount <= 1 {
                        maxScale = (layout.size.width - 16.0 * 2.0) / layout.size.width
                        maxOffset = (topInset - (layout.size.height - layout.size.height * maxScale) / 2.0)
                    } else {
                        maxScale = (layout.size.width - 16.0 * 2.0 * 2.0) / layout.size.width
                        maxOffset = (topInset + 10.0 - (layout.size.height - layout.size.height * maxScale) / 2.0)
                    }
                    
                    let scale = 1.0 * visibleRootModalDismissProgress + (1.0 - visibleRootModalDismissProgress) * maxScale
                    let offset = (1.0 - visibleRootModalDismissProgress) * maxOffset
                    transition.updateSublayerTransformScaleAndOffset(node: rootContainerNode, scale: scale, offset: CGPoint(x: 0.0, y: offset), beginWithCurrentState: true)
                }
            } else {
                if let rootModalFrame = self.rootModalFrame {
                    self.rootModalFrame = nil
                    rootModalFrame.updateDismissal(transition: transition, progress: 1.0, additionalProgress: 0.0, completion: { [weak rootModalFrame] in
                        rootModalFrame?.removeFromSupernode()
                    })
                }
                if let rootContainer = self.rootContainer {
                    var rootContainerNode: ASDisplayNode
                    switch rootContainer {
                    case let .flat(container):
                        rootContainerNode = container
                    case let .split(container):
                        rootContainerNode = container
                    }
                    transition.updateSublayerTransformScaleAndOffset(node: rootContainerNode, scale: 1.0, offset: CGPoint())
                }
            }
        case .regular:
            if let rootModalFrame = self.rootModalFrame {
                self.rootModalFrame = nil
                rootModalFrame.updateDismissal(transition: .immediate, progress: 1.0, additionalProgress: 0.0, completion: { [weak rootModalFrame] in
                    rootModalFrame?.removeFromSupernode()
                })
            }
            if let rootContainer = self.rootContainer {
                var rootContainerNode: ASDisplayNode
                switch rootContainer {
                case let .flat(container):
                    rootContainerNode = container
                case let .split(container):
                    rootContainerNode = container
                }
                ContainedViewLayoutTransition.immediate.updateSublayerTransformScaleAndOffset(node: rootContainerNode, scale: 1.0, offset: CGPoint())
            }
        }
        
        if self.inCallStatusBar != nil {
            statusBarStyle = .White
        }
        
        if let topVisibleOverlayContainerWithStatusBar = topVisibleOverlayContainerWithStatusBar {
            statusBarStyle = topVisibleOverlayContainerWithStatusBar.controller.statusBar.statusBarStyle
        }
        
        if let topVisibleModalContainerWithStatusBar = topVisibleModalContainerWithStatusBar {
            statusBarStyle = topVisibleModalContainerWithStatusBar.container.statusBarStyle
        }
        
        if self.currentStatusBarExternalHidden {
            statusBarHidden = true
        }
        
        let resolvedStatusBarStyle: NavigationStatusBarStyle
        switch statusBarStyle {
        case .Ignore, .Hide:
            if self.inCallStatusBar != nil {
                resolvedStatusBarStyle = .white
            } else {
                resolvedStatusBarStyle = self.theme.statusBar
            }
        case .Black:
            resolvedStatusBarStyle = .black
        case .White:
            resolvedStatusBarStyle = .white
        }
        
        if self.validStatusBarStyle != resolvedStatusBarStyle {
            self.validStatusBarStyle = resolvedStatusBarStyle
            let normalStatusBarStyle: UIStatusBarStyle
            switch resolvedStatusBarStyle {
            case .black:
                if #available(iOS 13.0, *) {
                    normalStatusBarStyle = .darkContent
                } else {
                    normalStatusBarStyle = .default
                }
            case .white:
                normalStatusBarStyle = .lightContent
            }
            self.statusBarHost?.setStatusBarStyle(normalStatusBarStyle, animated: animateStatusBarStyleTransition)
        }
        
        if self.validStatusBarHidden != statusBarHidden {
            self.validStatusBarHidden = statusBarHidden
            self.statusBarHost?.setStatusBarHidden(statusBarHidden, animated: animateStatusBarStyleTransition)
        }
        
        var topHasOpaque = false
        var foundControllerInFocus = false
        
        for container in self.globalOverlayContainers.reversed() {
            let controller = container.controller
            if topHasOpaque {
                controller.displayNode.accessibilityElementsHidden = true
            } else {
                if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                    topHasOpaque = true
                }
                controller.displayNode.accessibilityElementsHidden = false
            }
        }
        
        for container in self.overlayContainers.reversed() {
            if foundControllerInFocus {
                container.controller.isInFocus = false
            } else if container.controller.acceptsFocusWhenInOverlay {
                foundControllerInFocus = true
                container.controller.isInFocus = true
            }
            
            let controller = container.controller
            if topHasOpaque {
                controller.displayNode.accessibilityElementsHidden = true
            } else {
                if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                    topHasOpaque = true
                }
                controller.displayNode.accessibilityElementsHidden = false
            }
        }
        
        for container in self.modalContainers.reversed() {
            if foundControllerInFocus {
                container.container.isInFocus = false
            } else {
                foundControllerInFocus = true
                container.container.isInFocus = true
            }
            
            if let controller = container.container.controllers.last {
                if topHasOpaque {
                    controller.displayNode.accessibilityElementsHidden = true
                } else {
                    if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                        topHasOpaque = true
                    }
                    controller.displayNode.accessibilityElementsHidden = false
                }
            }
        }
        
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .flat(container):
                if foundControllerInFocus {
                    container.isInFocus = false
                } else {
                    foundControllerInFocus = true
                    container.isInFocus = true
                }
                
                if let controller = container.controllers.last {
                    if topHasOpaque {
                        controller.displayNode.accessibilityElementsHidden = true
                    } else {
                        if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                            topHasOpaque = true
                        }
                        controller.displayNode.accessibilityElementsHidden = false
                    }
                }
            case let .split(split):
                if foundControllerInFocus {
                    split.isInFocus = false
                } else {
                    foundControllerInFocus = true
                    split.isInFocus = true
                }
                
                if let controller = split.masterControllers.last {
                    if topHasOpaque {
                        controller.displayNode.accessibilityElementsHidden = true
                    } else {
                        if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                            topHasOpaque = true
                        }
                        controller.displayNode.accessibilityElementsHidden = false
                    }
                }
                if let controller = split.detailControllers.last {
                    if topHasOpaque {
                        controller.displayNode.accessibilityElementsHidden = true
                    } else {
                        if controller.isOpaqueWhenInOverlay || controller.blocksBackgroundWhenInOverlay {
                            topHasOpaque = true
                        }
                        controller.displayNode.accessibilityElementsHidden = false
                    }
                }
            }
        }
        
        self.isUpdatingContainers = false
        
        if notifyGlobalOverlayControllersUpdated {
            self.internalGlobalOverlayControllersUpdated()
        }
        
        self.updateSupportedOrientations?()
        
        let updatedPrefersOnScreenNavigationHidden = self.collectPrefersOnScreenNavigationHidden()
        if initialPrefersOnScreenNavigationHidden != updatedPrefersOnScreenNavigationHidden {
            self.currentWindow?.invalidatePrefersOnScreenNavigationHidden()
        }
    }
    
    private func controllerRemoved(_ controller: ViewController) {
        self.filterController(controller, animated: false)
    }
    
    public func updateModalTransition(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    private func scrollToTop(_ subject: NavigationSplitContainerScrollToTop) {
        if let _ = self.inCallStatusBar {
            self.inCallNavigate?()
        } else if let rootContainer = self.rootContainer {
            if let modalContainer = self.modalContainers.last {
                modalContainer.container.controllers.last?.scrollToTop?()
            } else {
                switch rootContainer {
                case let .flat(container):
                    container.controllers.last?.scrollToTop?()
                case let .split(container):
                    switch subject {
                    case .master:
                        container.masterControllers.last?.scrollToTop?()
                    case .detail:
                        container.detailControllers.last?.scrollToTop?()
                    }
                }
            }
        }
    }
    
    public func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        /*for record in self._viewControllers {
            if let controller = record.controller as? ContainableController {
                controller.updateToInterfaceOrientation(orientation)
            }
        }*/
    }
    
    open override func loadView() {
        self._displayNode = NavigationControllerNode(controller: self)
        
        self.view = self.displayNode.view
        self.view.clipsToBounds = true
        self.view.autoresizingMask = []
        
        self.displayNode.backgroundColor = self.theme.emptyAreaColor
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.navigationBar.prefersLargeTitles = false
        }
        self.navigationBar.removeFromSuperview()
        
        let globalScrollToTopNode = ScrollToTopNode(action: { [weak self] in
            self?.scrollToTop(.master)
        })
        self.displayNode.addSubnode(globalScrollToTopNode)
        self.globalScrollToTopNode = globalScrollToTopNode
        
        let globalOverlayBelowKeyboardContainerParent = GlobalOverlayContainerParent()
        self.displayNode.addSubnode(globalOverlayBelowKeyboardContainerParent)
        self.globalOverlayBelowKeyboardContainerParent = globalOverlayBelowKeyboardContainerParent
        
        let globalOverlayContainerParent = GlobalOverlayContainerParent()
        self.displayNode.addSubnode(globalOverlayContainerParent)
        self.globalOverlayContainerParent = globalOverlayContainerParent
        
        if let inCallStatusBar = self.inCallStatusBar, inCallStatusBar.supernode == nil {
            if let globalScrollToTopNode = self.globalScrollToTopNode {
                self.displayNode.insertSubnode(inCallStatusBar, belowSubnode: globalScrollToTopNode)
            } else {
                self.displayNode.addSubnode(inCallStatusBar)
            }
        }
    }
        
    public func pushViewController(_ controller: ViewController) {
        self.pushViewController(controller, completion: {})
    }
    
    public func pushViewController(_ controller: ViewController, animated: Bool = true, completion: @escaping () -> Void) {
        self.pushViewController(controller, animated: animated)
        completion()
    }
    
    public func updateContainerPulled(_ pushed: Bool) {
        guard self.modalContainers.isEmpty else {
            return
        }
        if let rootContainer = self.rootContainer, case let .flat(container) = rootContainer {
            let scale: CGFloat = pushed ? 1.06 : 1.0
            
            container.view.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            container.view.layer.animateScale(from: pushed ? 1.0 : 1.06, to: scale, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        var controllers = self.viewControllers
        controllers.append(viewController)
        self.setViewControllers(controllers, animated: animated)
    }
    
    public func replaceTopController(_ controller: ViewController, animated: Bool, ready: Promise<Bool>? = nil) {
        ready?.set(.single(true))
        var controllers = self.viewControllers
        controllers.removeLast()
        controllers.append(controller)
        self.setViewControllers(controllers, animated: animated)
    }
    
    public func filterController(_ controller: ViewController, animated: Bool) {
        let controllers = self.viewControllers.filter({ $0 !== controller })
        if controllers.count != self.viewControllers.count {
            if controller.isViewLoaded && viewTreeContainsFirstResponder(view: controller.view) {
                self.ignoreInputHeight = true
            }
            self.setViewControllers(controllers, animated: animated)
            self.ignoreInputHeight = false
        }
    }
    
    public func replaceController(_ controller: ViewController, with other: ViewController, animated: Bool) {
        var controllers = self._viewControllers
        for i in 0 ..< controllers.count {
            if controllers[i] === controller {
                controllers[i] = other
                break
            }
        }
        self.setViewControllers(controllers, animated: animated)
    }
    
    public func replaceControllersAndPush(controllers: [UIViewController], controller: ViewController, animated: Bool, options: NavigationAnimationOptions = [], ready: ValuePromise<Bool>? = nil, completion: @escaping () -> Void = {}) {
        ready?.set(true)
        var controllers = controllers
        controllers.append(controller)
        self.setViewControllers(controllers, animated: animated)
        completion()
    }
    
    public func replaceControllers(controllers: [UIViewController], animated: Bool, options: NavigationAnimationOptions = [], ready: ValuePromise<Bool>? = nil, completion: @escaping () -> Void = {}) {
        ready?.set(true)
        self.setViewControllers(controllers, animated: animated)
        completion()
    }
    
    public func replaceAllButRootController(_ controller: ViewController, animated: Bool, animationOptions: NavigationAnimationOptions = [], ready: ValuePromise<Bool>? = nil, completion: @escaping () -> Void = {}) {
        ready?.set(true)
        var controllers = self.viewControllers
        while controllers.count > 1 {
            controllers.removeLast()
        }
        controllers.append(controller)
        self.setViewControllers(controllers, animated: animated)
        completion()
    }

    public func popToRoot(animated: Bool) {
        var controllers = self.viewControllers
        while controllers.count > 1 {
            controllers.removeLast()
        }
        self.setViewControllers(controllers, animated: animated)
    }
    
    override open func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        var poppedControllers: [UIViewController] = []
        var found = false
        var controllers = self.viewControllers
        if !controllers.contains(where: { $0 === viewController }) {
            return nil
        }
        while !controllers.isEmpty {
            if controllers[controllers.count - 1] === viewController {
                found = true
                break
            }
            poppedControllers.insert(controllers[controllers.count - 1], at: 0)
            controllers.removeLast()
        }
        if found {
            self.setViewControllers(controllers, animated: animated)
            return poppedControllers
        } else {
            return nil
        }
    }
    
    open override func popViewController(animated: Bool) -> UIViewController? {
        var controller: UIViewController?
        var controllers = self.viewControllers
        if controllers.count != 0 {
            controller = controllers[controllers.count - 1] as UIViewController
            controllers.remove(at: controllers.count - 1)
            self.setViewControllers(controllers, animated: animated)
        }
        return controller
    }
    
    open override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        for i in 0 ..< viewControllers.count {
            guard let controller = viewControllers[i] as? ViewController else {
                continue
            }
            if self.viewControllers.contains(where: { $0 === controller }) {
                continue
            }
            if let customNavigationData = controller.customNavigationData {
                var found = false
                for previousIndex in (0 ..< self.viewControllers.count).reversed() {
                    let previousController = self.viewControllers[previousIndex]
                    
                    if let previousController = previousController as? ViewController, let previousCustomNavigationDataSummary = previousController.customNavigationDataSummary {
                        controller.customNavigationDataSummary = customNavigationData.combine(summary: previousCustomNavigationDataSummary)
                        found = true
                        break
                    }
                }
                if !found {
                    controller.customNavigationDataSummary = customNavigationData.combine(summary: nil)
                }
            }
        }
        
        self._viewControllers = viewControllers.map { controller in
            let controller = controller as! ViewController
            controller.navigation_setNavigationController(self)
            return controller
        }
        if let layout = self.validLayout {
            self.updateContainers(layout: layout, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
        }
        self._viewControllersPromise.set(self.viewControllers)
    }
    
    public var _keepModalDismissProgress = false
    public func presentOverlay(controller: ViewController, inGlobal: Bool = false, blockInteraction: Bool = false) {
        let container = NavigationOverlayContainer(controller: controller, blocksInteractionUntilReady: blockInteraction, controllerRemoved: { [weak self] controller in
            guard let strongSelf = self else {
                return
            }
            if inGlobal {
                for i in 0 ..< strongSelf.globalOverlayContainers.count {
                    let overlayContainer = strongSelf.globalOverlayContainers[i]
                    if overlayContainer.controller === controller {
                        overlayContainer.removeFromSupernode()
                        strongSelf.globalOverlayContainers.remove(at: i)
                        strongSelf.internalGlobalOverlayControllersUpdated()
                        break
                    }
                }
            } else {
                for i in 0 ..< strongSelf.overlayContainers.count {
                    let overlayContainer = strongSelf.overlayContainers[i]
                    if overlayContainer.controller === controller {
                        overlayContainer.removeFromSupernode()
                        strongSelf.overlayContainers.remove(at: i)
                        strongSelf._overlayControllersPromise.set(strongSelf.overlayContainers.map({ $0.controller }))
                        strongSelf.internalOverlayControllersUpdated()
                        break
                    }
                }
            }

            strongSelf.updateContainersNonReentrant(transition: .immediate)
        }, statusBarUpdated: { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateContainersNonReentrant(transition: transition)
        }, modalStyleOverlayTransitionFactorUpdated: { [weak self] transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateContainersNonReentrant(transition: transition)
        })
        if inGlobal {
            self.globalOverlayContainers.append(container)
        } else {
            self.overlayContainers.append(container)
            self._overlayControllersPromise.set(self.overlayContainers.map({ $0.controller }))
        }
        container.isReadyUpdated = { [weak self, weak container] in
            guard let strongSelf = self, let _ = container else {
                return
            }
            strongSelf.updateContainersNonReentrant(transition: .immediate)
        }
        if let layout = self.validLayout {
            self.updateContainers(layout: layout, transition: .immediate)
        }
    }
    
    func updateExternalStatusBarHidden(_ value: Bool, transition: ContainedViewLayoutTransition) {
        if self.currentStatusBarExternalHidden != value {
            self.currentStatusBarExternalHidden = value
            if let layout = self.validLayout {
                self.updateContainers(layout: layout, transition: transition)
            }
        }
    }
    
    public func updatePossibleControllerDropContent(content: NavigationControllerDropContent?) {
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .flat(container):
                if let controller = container.controllers.last {
                    controller.updatePossibleControllerDropContent(content: content)
                }
            case .split:
                break
            }
        }
    }
    
    public func acceptPossibleControllerDropContent(content: NavigationControllerDropContent) -> Bool {
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .flat(container):
                if let controller = container.controllers.last {
                    if controller.acceptPossibleControllerDropContent(content: content) {
                        return true
                    }
                }
            case .split:
                break
            }
        }
        return false
    }
    
    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        preconditionFailure()
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: false, completion: nil)
        }
        if let controller = self.presentedViewController {
            if flag {
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions(rawValue: 7 << 16), animations: {
                    controller.view.frame = self.view.bounds.offsetBy(dx: 0.0, dy: self.view.bounds.height)
                }, completion: { _ in
                    controller.view.removeFromSuperview()
                    self._presentedViewController = nil
                    if let completion = completion {
                        completion()
                    }
                })
            } else {
                controller.view.removeFromSuperview()
                self._presentedViewController = nil
                if let completion = completion {
                    completion()
                }
            }
        }
    }
    
    public final var currentWindow: WindowHost? {
        if let window = self.view.window as? WindowHost {
            return window
        } else if let superwindow = self.view.window {
            for subview in superwindow.subviews {
                if let subview = subview as? WindowHost {
                    return subview
                }
            }
        }
        return nil
    }
    
    private func scheduleAfterLayout(_ f: @escaping () -> Void) {
        (self.view as? UITracingLayerView)?.schedule(layout: {
            f()
        })
        self.view.setNeedsLayout()
    }
    
    private func scheduleLayoutTransitionRequest(_ transition: ContainedViewLayoutTransition) {
        let requestId = self.scheduledLayoutTransitionRequestId
        self.scheduledLayoutTransitionRequestId += 1
        self.scheduledLayoutTransitionRequest = (requestId, transition)
        (self.view as? UITracingLayerView)?.schedule(layout: { [weak self] in
            if let strongSelf = self {
                if let (currentRequestId, currentRequestTransition) = strongSelf.scheduledLayoutTransitionRequest, currentRequestId == requestId {
                    strongSelf.scheduledLayoutTransitionRequest = nil
                    strongSelf.requestLayout(transition: currentRequestTransition)
                }
            }
        })
        self.view.setNeedsLayout()
    }
    
    public func requestLayout(transition: ContainedViewLayoutTransition) {
        if self.isViewLoaded, let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout, transition: transition)
        }
    }
    
    public func setForceInCallStatusBar(_ forceInCallStatusBar: CallStatusBarNode?, transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)) {
        if let forceInCallStatusBar = forceInCallStatusBar {
            let inCallStatusBar: StatusBar
            if let current = self.inCallStatusBar {
                inCallStatusBar = current
            } else {
                inCallStatusBar = StatusBar()
                inCallStatusBar.clipsToBounds = false
                inCallStatusBar.inCallNavigate = { [weak self] in
                    self?.scrollToTop(.master)
                }
                self.inCallStatusBar = inCallStatusBar
                
                var bottomOverlayContainer: NavigationOverlayContainer?
                for overlayContainer in self.overlayContainers {
                    if overlayContainer.supernode != nil {
                        bottomOverlayContainer = overlayContainer
                        break
                    }
                }
                
                if self._displayNode != nil {
                    if let bottomOverlayContainer = bottomOverlayContainer {
                        self.displayNode.insertSubnode(inCallStatusBar, belowSubnode: bottomOverlayContainer)
                    } else if let globalScrollToTopNode = self.globalScrollToTopNode {
                        self.displayNode.insertSubnode(inCallStatusBar, belowSubnode: globalScrollToTopNode)
                    } else {
                        self.displayNode.addSubnode(inCallStatusBar)
                    }
                }
                if case let .animated(duration, _) = transition {
                    inCallStatusBar.layer.animatePosition(from: CGPoint(x: 0.0, y: -64.0), to: CGPoint(), duration: duration, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, additive: true)
                }
            }
            if let layout = self.validLayout {
                inCallStatusBar.updateState(statusBar: nil, withSafeInsets: !layout.safeInsets.top.isZero, inCallNode: forceInCallStatusBar, animated: false)
                self.containerLayoutUpdated(layout, transition: transition)
            } else {
                self.updateInCallStatusBarState = forceInCallStatusBar
            }
        } else if let inCallStatusBar = self.inCallStatusBar {
            self.inCallStatusBar = nil
            transition.updatePosition(node: inCallStatusBar, position: CGPoint(x: inCallStatusBar.position.x, y: -64.0), completion: { [weak inCallStatusBar] _ in
                inCallStatusBar?.removeFromSupernode()
            })
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: transition)
            }
        }
    }
    
    public var overlayControllers: [ViewController] {
        return self.overlayContainers.compactMap { container in
            if container.isReady {
                return container.controller
            } else {
                return nil
            }
        }
    }
    
    public var globalOverlayControllers: [ViewController] {
        return self.globalOverlayContainers.compactMap { container in
            if container.isReady {
                return container.controller
            } else {
                return nil
            }
        }
    }
    
    private func internalGlobalOverlayControllersUpdated() {
        self.globalOverlayControllersUpdated?()
        self.currentWindow?.invalidatePrefersOnScreenNavigationHidden()
    }
    
    private func internalOverlayControllersUpdated() {
        self.currentWindow?.invalidatePrefersOnScreenNavigationHidden()
    }
    
    private func collectPrefersOnScreenNavigationHidden() -> Bool {
        var hidden = false
        if let overlayController = self.topOverlayController {
            hidden = hidden || overlayController.prefersOnScreenNavigationHidden
        }
        return hidden
    }
}
