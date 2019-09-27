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
    override class var layerClass: AnyClass {
        return CATracingLayer.self
    }
}

public enum NavigationEmptyDetailsBackgoundMode {
    case image(UIImage)
    case wallpaper(UIImage)
}

private final class NavigationControllerView: UITracingLayerView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class var layerClass: AnyClass {
        return CATracingLayer.self
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
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
    
    private let mode: NavigationControllerMode
    private var theme: NavigationControllerTheme
    
    public private(set) weak var overlayPresentingController: ViewController?
    
    private var controllerView: NavigationControllerView {
        return self.view as! NavigationControllerView
    }
    
    private var rootContainer: RootContainer?
    private var rootModalFrame: NavigationModalFrame?
    private var modalContainers: [NavigationModalContainer] = []
    private var validLayout: ContainerViewLayout?
    private var validStatusBarStyle: NavigationStatusBarStyle?
    
    private var scheduledLayoutTransitionRequestId: Int = 0
    private var scheduledLayoutTransitionRequest: (Int, ContainedViewLayoutTransition)?
    
    private var _presentedViewController: UIViewController?
    open override var presentedViewController: UIViewController? {
        return self._presentedViewController
    }
    
    private var _viewControllers: [ViewController] = []
    override open var viewControllers: [UIViewController] {
        get {
            return self._viewControllers.map { $0 as! ViewController }
        } set(value) {
            self.setViewControllers(value, animated: false)
        }
    }
    
    override open var topViewController: UIViewController? {
        return self._viewControllers.last
    }
    
    private var _displayNode: ASDisplayNode?
    public var displayNode: ASDisplayNode {
        return self._displayNode!
    }
    
    var statusBarHost: StatusBarHost?
    var keyboardViewManager: KeyboardViewManager?
    
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
        if let controller = self.viewControllers.last {
            if let controller = controller as? ViewController {
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
        }
        return supportedOrientations
    }
    
    public func updateTheme(_ theme: NavigationControllerTheme) {
        let statusBarStyleUpdated = self.theme.statusBar != theme.statusBar
        self.theme = theme
        if self.isViewLoaded {
            if statusBarStyleUpdated {
                self.validStatusBarStyle = self.theme.statusBar
                let normalStatusBarStyle: UIStatusBarStyle
                switch self.theme.statusBar {
                case .black:
                    normalStatusBarStyle = .default
                case .white:
                    normalStatusBarStyle = .lightContent
                }
                self.statusBarHost?.setStatusBarStyle(normalStatusBarStyle, animated: false)
            }
            self.controllerView.backgroundColor = theme.emptyAreaColor
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
    
    private func updateContainers(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let navigationLayout = makeNavigationLayout(layout: layout, controllers: self._viewControllers)
        
        var transition = transition
        var statusBarStyle: StatusBarStyle = .Ignore
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
                modalContainer = NavigationModalContainer(theme: self.theme, controllerRemoved: { [weak self] controller in
                    self?.controllerRemoved(controller)
                })
                self.modalContainers.append(modalContainer)
                if !modalContainer.isReady {
                    modalContainer.isReadyUpdated = { [weak self, weak modalContainer] in
                        guard let strongSelf = self, let modalContainer = modalContainer else {
                            return
                        }
                        if let layout = strongSelf.validLayout {
                            strongSelf.updateContainers(layout: layout, transition: .animated(duration: 0.5, curve: .spring))
                        }
                    }
                }
                modalContainer.updateDismissProgress = { [weak self, weak modalContainer] _, transition in
                    guard let strongSelf = self, let modalContainer = modalContainer else {
                        return
                    }
                    if let layout = strongSelf.validLayout {
                        strongSelf.updateContainers(layout: layout, transition: transition)
                    }
                }
                modalContainer.interactivelyDismissed = { [weak self, weak modalContainer] in
                    guard let strongSelf = self, let modalContainer = modalContainer else {
                        return
                    }
                    let controllers = strongSelf._viewControllers.filter { controller in
                        return !modalContainer.container.controllers.contains(where: { $0 === controller })
                    }
                    strongSelf.setViewControllers(controllers, animated: false)
                }
            }
            modalContainers.append(modalContainer)
        }
        
        for container in self.modalContainers {
            if !modalContainers.contains(where: { $0 === container }) {
                transition = container.dismiss(transition: transition, completion: { [weak container] in
                    container?.removeFromSupernode()
                })
            }
        }
        self.modalContainers = modalContainers
        
        var previousModalContainer: NavigationModalContainer?
        var visibleModalCount = 0
        var topModalDismissProgress: CGFloat = 0.0
        
        for i in (0 ..< navigationLayout.modal.count).reversed() {
            let modalContainer = self.modalContainers[i]
            
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
                } else {
                    self.displayNode.addSubnode(modalContainer)
                }
                modalContainer.animateIn(transition: transition)
            }
            
            if modalContainer.supernode != nil {
                visibleModalCount += 1
                if previousModalContainer == nil {
                    topModalDismissProgress = modalContainer.dismissProgress
                    if case .compact = layout.metrics.widthClass {
                        modalContainer.container.keyboardViewManager = self.keyboardViewManager
                    } else {
                        modalContainer.container.keyboardViewManager = nil
                    }
                } else {
                    modalContainer.container.keyboardViewManager = nil
                }
                previousModalContainer = modalContainer
            }
        }
        
        switch navigationLayout.root {
        case let .flat(controllers):
            if let rootContainer = self.rootContainer {
                switch rootContainer {
                case let .flat(flatContainer):
                    if previousModalContainer == nil {
                        flatContainer.keyboardViewManager = self.keyboardViewManager
                    } else {
                        flatContainer.keyboardViewManager = nil
                    }
                    transition.updateFrame(node: flatContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
                    flatContainer.update(layout: layout, canBeClosed: false, controllers: controllers, transition: transition)
                case let .split(splitContainer):
                    let flatContainer = NavigationContainer(controllerRemoved: { [weak self] controller in
                        self?.controllerRemoved(controller)
                    })
                    flatContainer.statusBarStyleUpdated = { [weak self] transition in
                        guard let strongSelf = self, let layout = strongSelf.validLayout else {
                            return
                        }
                        strongSelf.updateContainers(layout: layout, transition: transition)
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
                    guard let strongSelf = self, let layout = strongSelf.validLayout else {
                        return
                    }
                    strongSelf.updateContainers(layout: layout, transition: transition)
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
                    })
                    self.displayNode.insertSubnode(splitContainer, at: 0)
                    self.rootContainer = .split(splitContainer)
                    splitContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
                    splitContainer.update(layout: layout, masterControllers: masterControllers, detailControllers: detailControllers, transition: .immediate)
                    flatContainer.statusBarStyleUpdated = nil
                    flatContainer.removeFromSupernode()
                case let .split(splitContainer):
                    transition.updateFrame(node: splitContainer, frame: CGRect(origin: CGPoint(), size: layout.size))
                    splitContainer.update(layout: layout, masterControllers: masterControllers, detailControllers: detailControllers, transition: transition)
                }
            } else {
                let splitContainer = NavigationSplitContainer(theme: self.theme, controllerRemoved: { [weak self] controller in
                    self?.controllerRemoved(controller)
                })
                self.displayNode.insertSubnode(splitContainer, at: 0)
                self.rootContainer = .split(splitContainer)
                splitContainer.frame = CGRect(origin: CGPoint(), size: layout.size)
                splitContainer.update(layout: layout, masterControllers: masterControllers, detailControllers: detailControllers, transition: .immediate)
            }
        }
        
        if let rootContainer = self.rootContainer {
            switch rootContainer {
            case let .flat(container):
                statusBarStyle = container.statusBarStyle
            case .split:
                break
            }
        }
        
        switch layout.metrics.widthClass {
        case .compact:
            if visibleModalCount != 0 {
                let effectiveRootModalDismissProgress: CGFloat
                let additionalModalFrameProgress: CGFloat
                if visibleModalCount == 1 {
                    effectiveRootModalDismissProgress = topModalDismissProgress
                    additionalModalFrameProgress = 0.0
                } else if visibleModalCount == 2 {
                    effectiveRootModalDismissProgress = 0.0
                    additionalModalFrameProgress = 1.0 - topModalDismissProgress
                } else {
                    effectiveRootModalDismissProgress = 0.0
                    additionalModalFrameProgress = 1.0
                }
                
                let rootModalFrame: NavigationModalFrame
                var modalFrameTransition: ContainedViewLayoutTransition = transition
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
                    if visibleModalCount == 1 {
                        maxScale = (layout.size.width - 16.0 * 2.0) / layout.size.width
                        maxOffset = (topInset - (layout.size.height - layout.size.height * maxScale) / 2.0)
                    } else {
                        maxScale = (layout.size.width - 16.0 * 2.0 * 2.0) / layout.size.width
                        maxOffset = (topInset + 10.0 - (layout.size.height - layout.size.height * maxScale) / 2.0)
                    }
                    
                    let scale = 1.0 * effectiveRootModalDismissProgress + (1.0 - effectiveRootModalDismissProgress) * maxScale
                    let offset = (1.0 - effectiveRootModalDismissProgress) * maxOffset
                    transition.updateSublayerTransformScaleAndOffset(node: rootContainerNode, scale: scale, offset: CGPoint(x: 0.0, y: offset))
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
                normalStatusBarStyle = .default
            case .white:
                normalStatusBarStyle = .lightContent
            }
            self.statusBarHost?.setStatusBarStyle(normalStatusBarStyle, animated: animateStatusBarStyleTransition)
        }
    }
    
    private func controllerRemoved(_ controller: ViewController) {
        self.filterController(controller, animated: false)
    }
    
    public func updateModalTransition(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
    }
    
    public func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation) {
        /*for record in self._viewControllers {
            if let controller = record.controller as? ContainableController {
                controller.updateToInterfaceOrientation(orientation)
            }
        }*/
    }
    
    open override func loadView() {
        self._displayNode = ASDisplayNode(viewBlock: {
            return NavigationControllerView()
        }, didLoad: nil)
        
        self.view = self.displayNode.view
        self.view.clipsToBounds = true
        self.view.autoresizingMask = []
        
        self.controllerView.backgroundColor = self.theme.emptyAreaColor
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.navigationBar.prefersLargeTitles = false
        }
        self.navigationBar.removeFromSuperview()
        
        /*let panRecognizer = InteractiveTransitionGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.delegate = self
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        self.view.addGestureRecognizer(panRecognizer)*/
    }
    
    public func pushViewController(_ controller: ViewController) {
        self.pushViewController(controller, completion: {})
    }
    
    public func pushViewController(_ controller: ViewController, animated: Bool = true, completion: @escaping () -> Void) {
        let navigateAction: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if !controller.hasActiveInput {
                //strongSelf.view.endEditing(true)
            }
            /*strongSelf.scheduleAfterLayout({
                guard let strongSelf = self else {
                    return
                }*/
                strongSelf.pushViewController(controller, animated: animated)
                completion()
            //})
        }
        
        /*if let lastController = self.viewControllers.last as? ViewController, !lastController.attemptNavigation(navigateAction) {
        } else {*/
            navigateAction()
        //}
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
            self.setViewControllers(controllers, animated: animated)
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
    
    override open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        preconditionFailure()
        /*if let controller = viewControllerToPresent as? NavigationController {
            controller.navigation_setDismiss({ [weak self] in
                if let strongSelf = self {
                    strongSelf.dismiss(animated: false, completion: nil)
                }
            }, rootController: self.view!.window!.rootViewController)
            self._presentedViewController = controller
            
            self.view.endEditing(true)
            if let validLayout = self.validLayout {
                controller.containerLayoutUpdated(validLayout, transition: .immediate)
            }
            
            var ready: Signal<Bool, NoError> = .single(true)
            
            if let controller = controller.topViewController as? ViewController {
                ready = controller.ready.get()
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue
            }
            
            self.currentPresentDisposable.set(ready.start(next: { [weak self] _ in
                if let strongSelf = self {
                    if flag {
                        controller.view.frame = strongSelf.view.bounds.offsetBy(dx: 0.0, dy: strongSelf.view.bounds.height)
                        strongSelf.view.addSubview(controller.view)
                        UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions(rawValue: 7 << 16), animations: {
                            controller.view.frame = strongSelf.view.bounds
                        }, completion: { _ in
                            if let completion = completion {
                                completion()
                            }
                        })
                    } else {
                        controller.view.frame = strongSelf.view.bounds
                        strongSelf.view.addSubview(controller.view)
                        
                        if let completion = completion {
                            completion()
                        }
                    }
                }
            }))
        } else {
            preconditionFailure("NavigationController can't present \(viewControllerToPresent). Only subclasses of NavigationController are allowed.")
        }*/
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
    
    private func requestLayout(transition: ContainedViewLayoutTransition) {
        if self.isViewLoaded, let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout, transition: transition)
        }
    }
}
