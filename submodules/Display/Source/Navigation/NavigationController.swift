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

private final class NavigationControllerContainerView: UIView {
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
    
    var inCallNavigate: (() -> Void)?
    private var inCallStatusBar: StatusBar?
    private var globalScrollToTopNode: ScrollToTopNode?
    private var rootContainer: RootContainer?
    private var rootModalFrame: NavigationModalFrame?
    private var modalContainers: [NavigationModalContainer] = []
    private var overlayContainers: [NavigationOverlayContainer] = []
    
    private var globalOverlayContainers: [NavigationOverlayContainer] = []
    private var globalOverlayContainerParent: GlobalOverlayContainerParent?
    public var globalOverlayControllersUpdated: (() -> Void)?
    
    private var validLayout: ContainerViewLayout?
    private var validStatusBarStyle: NavigationStatusBarStyle?
    private var validStatusBarHidden: Bool = false
    
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
    
    var statusBarHost: StatusBarHost? {
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
    
    public init(mode: NavigationControllerMode, theme: NavigationControllerTheme, backgroundDetailsMode: NavigationEmptyDetailsBackgoundMode? = nil) {
        self.mode = mode
        self.theme = theme
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
    
    private func updateContainersNonReentrant(transition: ContainedViewLayoutTransition) {
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
        
        var overlayLayout = layout
        
        if let globalOverlayContainerParent = self.globalOverlayContainerParent {
            let portraitSize = CGSize(width: min(layout.size.width, layout.size.height), height: max(layout.size.width, layout.size.height))
            let screenSize = UIScreen.main.bounds.size
            let portraitScreenSize = CGSize(width: min(screenSize.width, screenSize.height), height: max(screenSize.width, screenSize.height))
            if portraitSize.width != portraitScreenSize.width || portraitSize.height != portraitScreenSize.height {
                if globalOverlayContainerParent.view.superview != self.displayNode.view {
                    self.displayNode.addSubnode(globalOverlayContainerParent)
                }
                
                overlayLayout.size.height = overlayLayout.size.height - (layout.inputHeight ?? 0.0)
                overlayLayout.inputHeight = nil
                overlayLayout.inputHeightIsInteractivellyChanging = false
            } else if layout.inputHeight == nil {
                if globalOverlayContainerParent.view.superview != self.displayNode.view {
                    self.displayNode.addSubnode(globalOverlayContainerParent)
                }
            } else {
                if let statusBarHost = self.statusBarHost, let keyboardWindow = statusBarHost.keyboardWindow, let keyboardView = statusBarHost.keyboardView, !keyboardView.frame.height.isZero, isViewVisibleInHierarchy(keyboardView) {
                    if globalOverlayContainerParent.view.superview != keyboardWindow {
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
        
        if let inCallStatusBar = self.inCallStatusBar {
            let inCallStatusBarFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: max(40.0, layout.safeInsets.top)))
            if inCallStatusBar.frame.isEmpty {
                inCallStatusBar.frame = inCallStatusBarFrame
            } else {
                transition.updateFrame(node: inCallStatusBar, frame: inCallStatusBarFrame)
            }
            layout.statusBarHeight = inCallStatusBarFrame.height
            self.inCallStatusBar?.frame = inCallStatusBarFrame
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
        
        var modalStyleOverlayTransitionFactor: CGFloat = 0.0
        var previousGlobalOverlayContainer: NavigationOverlayContainer?
        for i in (0 ..< self.globalOverlayContainers.count).reversed() {
            let overlayContainer = self.globalOverlayContainers[i]
            
            let containerTransition: ContainedViewLayoutTransition
            if overlayContainer.supernode == nil {
                containerTransition = .immediate
            } else {
                containerTransition = transition
            }
            
            containerTransition.updateFrame(node: overlayContainer, frame: CGRect(origin: CGPoint(), size: overlayLayout.size))
            overlayContainer.update(layout: overlayLayout, transition: containerTransition)
            
            modalStyleOverlayTransitionFactor = max(modalStyleOverlayTransitionFactor, overlayContainer.controller.modalStyleOverlayTransitionFactor)
            
            if overlayContainer.supernode == nil && overlayContainer.isReady {
                if let previousGlobalOverlayContainer = previousGlobalOverlayContainer {
                    self.globalOverlayContainerParent?.insertSubnode(overlayContainer, belowSubnode: previousGlobalOverlayContainer)
                } else {
                    self.globalOverlayContainerParent?.addSubnode(overlayContainer)
                }
                overlayContainer.transitionIn()
                notifyGlobalOverlayControllersUpdated = true
            }
            
            if overlayContainer.supernode != nil {
                previousGlobalOverlayContainer = overlayContainer
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
            
            containerTransition.updateFrame(node: overlayContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
            overlayContainer.update(layout: layout, transition: containerTransition)
            
            modalStyleOverlayTransitionFactor = max(modalStyleOverlayTransitionFactor, overlayContainer.controller.modalStyleOverlayTransitionFactor)
            
            if overlayContainer.supernode == nil && overlayContainer.isReady {
                if let previousOverlayContainer = previousOverlayContainer {
                    self.displayNode.insertSubnode(overlayContainer, belowSubnode: previousOverlayContainer)
                } else if let globalScrollToTopNode = self.globalScrollToTopNode {
                    self.displayNode.insertSubnode(overlayContainer, belowSubnode: globalScrollToTopNode)
                 } else if let globalOverlayContainerParent = self.globalOverlayContainerParent {
                     self.displayNode.insertSubnode(overlayContainer, belowSubnode: globalOverlayContainerParent)
                 }else {
                    self.displayNode.addSubnode(overlayContainer)
                }
                overlayContainer.transitionIn()
            }
            
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
        var visibleModalCount = 0
        var topModalIsFlat = false
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
            if visibleModalCount == 0 {
                effectiveModalTransition = 0.0
            } else if visibleModalCount == 1 {
                effectiveModalTransition = 1.0 - topModalDismissProgress
            } else {
                effectiveModalTransition = 1.0
            }
            
            containerTransition.updateFrame(node: modalContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
            modalContainer.update(layout: layout, controllers: navigationLayout.modal[i].controllers, coveredByModalTransition: effectiveModalTransition, transition: containerTransition)
            
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
                if !hasVisibleStandaloneModal && !isStandaloneModal {
                    visibleModalCount += 1
                }
                if isStandaloneModal {
                    hasVisibleStandaloneModal = true
                    visibleModalCount = 0
                }
                if previousModalContainer == nil {
                    topModalDismissProgress = modalContainer.dismissProgress
                    if case .compact = layout.metrics.widthClass {
                        modalContainer.keyboardViewManager = self.keyboardViewManager
                        modalContainer.canHaveKeyboardFocus = true
                    } else {
                        modalContainer.keyboardViewManager = nil
                        modalContainer.canHaveKeyboardFocus = true
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
            
            topModalIsFlat = modalContainer.isFlat
        }
        
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
                    let flatContainer = NavigationContainer(controllerRemoved: { [weak self] controller in
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
                let flatContainer = NavigationContainer(controllerRemoved: { [weak self] controller in
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
        
        topModalDismissProgress = max(topModalDismissProgress, modalStyleOverlayTransitionFactor)
        
        switch layout.metrics.widthClass {
        case .compact:
            if visibleModalCount != 0 || !modalStyleOverlayTransitionFactor.isZero {
                let effectiveRootModalDismissProgress: CGFloat
                let visibleRootModalDismissProgress: CGFloat
                var additionalModalFrameProgress: CGFloat
                if visibleModalCount == 1 {
                    effectiveRootModalDismissProgress = topModalIsFlat ? 1.0 : topModalDismissProgress
                    visibleRootModalDismissProgress = effectiveRootModalDismissProgress
                    additionalModalFrameProgress = 0.0
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
                    rootModalFrame = NavigationModalFrame(theme: self.theme)
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
                    if topModalIsFlat {
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
        
        if self.currentStatusBarExternalHidden {
            statusBarHidden = true
        }
        
        let resolvedStatusBarStyle: NavigationStatusBarStyle
        switch statusBarStyle {
        case .Ignore, .Hide:
            resolvedStatusBarStyle = self.theme.statusBar
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
        
        var foundControllerInFocus = false
        for container in self.overlayContainers.reversed() {
            if foundControllerInFocus {
                container.controller.isInFocus = false
            } else if container.controller.acceptsFocusWhenInOverlay {
                foundControllerInFocus = true
                container.controller.isInFocus = true
            }
        }
        
        for container in self.modalContainers.reversed() {
            if foundControllerInFocus {
                container.container.isInFocus = false
            } else {
                foundControllerInFocus = true
                container.container.isInFocus = true
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
            case let .split(split):
                if foundControllerInFocus {
                    split.isInFocus = false
                } else {
                    foundControllerInFocus = true
                    split.isInFocus = true
                }
            }
        }
        
        self.isUpdatingContainers = false
        
        if notifyGlobalOverlayControllersUpdated {
            self.globalOverlayControllersUpdated?()
        }
        
        self.updateSupportedOrientations?()
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
        
        let globalOverlayContainerParent = GlobalOverlayContainerParent()
        self.displayNode.addSubnode(globalOverlayContainerParent)
        self.globalOverlayContainerParent = globalOverlayContainerParent
    }
    
    public func pushViewController(_ controller: ViewController) {
        self.pushViewController(controller, completion: {})
    }
    
    public func pushViewController(_ controller: ViewController, animated: Bool = true, completion: @escaping () -> Void) {
        self.pushViewController(controller, animated: animated)
        completion()
    }
    
    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        var controllers = self.viewControllers
        controllers.append(viewController)
        self.setViewControllers(controllers, animated: animated)
    }
    
    public func replaceTopController(_ controller: ViewController, animated: Bool, ready: ValuePromise<Bool>? = nil) {
        ready?.set(true)
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
        self._viewControllers = viewControllers.map { controller in
            let controller = controller as! ViewController
            controller.navigation_setNavigationController(self)
            return controller
        }
        if let layout = self.validLayout {
            self.updateContainers(layout: layout, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
        }
    }
    
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
                        strongSelf.globalOverlayControllersUpdated?()
                        break
                    }
                }
            } else {
                for i in 0 ..< strongSelf.overlayContainers.count {
                    let overlayContainer = strongSelf.overlayContainers[i]
                    if overlayContainer.controller === controller {
                        overlayContainer.removeFromSupernode()
                        strongSelf.overlayContainers.remove(at: i)
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
    
    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        preconditionFailure()
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
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
    
    public func setForceInCallStatusBar(_ forceInCallStatusBarText: String?, transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)) {
        if let forceInCallStatusBarText = forceInCallStatusBarText {
            let inCallStatusBar: StatusBar
            if let current = self.inCallStatusBar {
                inCallStatusBar = current
            } else {
                inCallStatusBar = StatusBar()
                inCallStatusBar.inCallNavigate = { [weak self] in
                    self?.scrollToTop(.master)
                }
                inCallStatusBar.alpha = 0.0
                self.inCallStatusBar = inCallStatusBar
                
                var bottomOverlayContainer: NavigationOverlayContainer?
                for overlayContainer in self.overlayContainers {
                    if overlayContainer.supernode != nil {
                        bottomOverlayContainer = overlayContainer
                        break
                    }
                }
                
                if let bottomOverlayContainer = bottomOverlayContainer {
                    self.displayNode.insertSubnode(inCallStatusBar, belowSubnode: bottomOverlayContainer)
                } else if let globalScrollToTopNode = self.globalScrollToTopNode {
                    self.displayNode.insertSubnode(inCallStatusBar, belowSubnode: globalScrollToTopNode)
                } else {
                    self.displayNode.addSubnode(inCallStatusBar)
                }
                transition.updateAlpha(node: inCallStatusBar, alpha: 1.0)
            }
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout, transition: transition)
                inCallStatusBar.updateState(statusBar: nil, withSafeInsets: !layout.safeInsets.top.isZero, inCallText: forceInCallStatusBarText, animated: false)
            }
        } else if let inCallStatusBar = self.inCallStatusBar {
            self.inCallStatusBar = nil
            transition.updateAlpha(node: inCallStatusBar, alpha: 0.0, completion: { [weak inCallStatusBar] _ in
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
}
