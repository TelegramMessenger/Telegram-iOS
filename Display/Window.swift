import Foundation
import AsyncDisplayKit

private class WindowRootViewController: UIViewController {
    var presentController: ((UIViewController, Bool, (() -> Void)?) -> Void)?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    /*override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let presentController = self.presentController {
            presentController(viewControllerToPresent, flag, completion)
        }
    }*/
}

private struct WindowLayout: Equatable {
    public let size: CGSize
    public let statusBarHeight: CGFloat?
    public let inputHeight: CGFloat?
    public let inputMinimized: Bool
}

private func ==(lhs: WindowLayout, rhs: WindowLayout) -> Bool {
    if !lhs.size.equalTo(rhs.size) {
        return false
    }
    
    if let lhsStatusBarHeight = lhs.statusBarHeight {
        if let rhsStatusBarHeight = rhs.statusBarHeight {
            if !lhsStatusBarHeight.isEqual(to: rhsStatusBarHeight) {
                return false
            }
        } else {
            return false
        }
    } else if let _ = rhs.statusBarHeight {
        return false
    }
    
    if let lhsInputHeight = lhs.inputHeight {
        if let rhsInputHeight = rhs.inputHeight {
            if !lhsInputHeight.isEqual(to: rhsInputHeight) {
                return false
            }
        } else {
            return false
        }
    } else if let _ = rhs.inputHeight {
        return false
    }
    
    if lhs.inputMinimized != rhs.inputMinimized {
        return false
    }
    
    return true
}

private struct UpdatingLayout {
    var layout: WindowLayout
    var transition: ContainedViewLayoutTransition
    
    mutating func update(transition: ContainedViewLayoutTransition, override: Bool) {
        var update = false
        if case .immediate = self.transition {
            update = true
        } else if override {
            update = true
        }
        if update {
            self.transition = transition
        }
    }
    
    mutating func update(size: CGSize, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: size, statusBarHeight: self.layout.statusBarHeight, inputHeight: self.layout.inputHeight, inputMinimized: self.layout.inputMinimized)
    }
    
    mutating func update(statusBarHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: statusBarHeight, inputHeight: self.layout.inputHeight, inputMinimized: self.layout.inputMinimized)
    }
    
    mutating func update(inputHeight: CGFloat?, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: self.layout.statusBarHeight, inputHeight: inputHeight, inputMinimized: self.layout.inputMinimized)
    }
    
    mutating func update(inputMinimized: Bool, transition: ContainedViewLayoutTransition, overrideTransition: Bool) {
        self.update(transition: transition, override: overrideTransition)
        
        self.layout = WindowLayout(size: self.layout.size, statusBarHeight: self.layout.statusBarHeight, inputHeight: self.layout.inputHeight, inputMinimized: inputMinimized)
    }
}

private let orientationChangeDuration: Double = UIDevice.current.userInterfaceIdiom == .pad ? 0.4 : 0.3
private let statusBarHiddenInLandscape: Bool = UIDevice.current.userInterfaceIdiom == .phone

private func containedLayoutForWindowLayout(_ layout: WindowLayout) -> ContainerViewLayout {
    var inputHeight: CGFloat? = layout.inputHeight
    if let inputHeightValue = inputHeight, layout.inputMinimized {
        inputHeight = floor(0.85 * inputHeightValue)
    }
    
    return ContainerViewLayout(size: layout.size, intrinsicInsets: UIEdgeInsets(), statusBarHeight: layout.statusBarHeight, inputHeight: inputHeight)
}

public class Window: UIWindow {
    public static let statusBarTracingTag: Int32 = 0
    public static let keyboardTracingTag: Int32 = 1
    
    private let statusBarHost: StatusBarHost?
    private let statusBarManager: StatusBarManager?
    private let keyboardManager: KeyboardManager?
    private var statusBarChangeObserver: AnyObject?
    private var keyboardFrameChangeObserver: AnyObject?
    
    private var windowLayout: WindowLayout
    private var updatingLayout: UpdatingLayout?
    
    public var isUpdatingOrientationLayout = false
    
    private let presentationContext: PresentationContext
    
    private var tracingStatusBarsInvalidated = false
    
    private var statusBarHidden = false
    
    public init(frame: CGRect, statusBarHost: StatusBarHost?) {
        self.statusBarHost = statusBarHost
        let statusBarHeight: CGFloat
        if let statusBarHost = statusBarHost {
            self.statusBarManager = StatusBarManager(host: statusBarHost)
            statusBarHeight = statusBarHost.statusBarFrame.size.height
            self.keyboardManager = KeyboardManager(host: statusBarHost)
        } else {
            self.statusBarManager = nil
            self.keyboardManager = nil
            statusBarHeight = 20.0
        }
        
        let minimized: Bool
        if let keyboardManager = self.keyboardManager {
            minimized = keyboardManager.minimized
        } else {
            minimized = false
        }
        
        self.windowLayout = WindowLayout(size: frame.size, statusBarHeight: statusBarHeight, inputHeight: 0.0, inputMinimized: minimized)
        self.presentationContext = PresentationContext()
        
        super.init(frame: frame)
        
        self.layer.setInvalidateTracingSublayers { [weak self] in
            self?.invalidateTracingStatusBars()
        }
        
        self.keyboardManager?.minimizedUpdated = { [weak self] in
            if let strongSelf = self {
                strongSelf.updateLayout { current in
                    current.update(inputMinimized: strongSelf.keyboardManager!.minimized, transition: .immediate, overrideTransition: false)
                }
            }
        }
        
        self.presentationContext.view = self
        self.presentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: .immediate)
        
        let rootViewController = WindowRootViewController()
        super.rootViewController = rootViewController
        rootViewController.viewWillAppear(false)
        rootViewController.viewDidAppear(false)
        rootViewController.view.isHidden = true
        
        rootViewController.presentController = { [weak self] controller, animated, completion in
            if let strongSelf = self {
                strongSelf.present(LegacyPresentedController(legacyController: controller, presentation: .custom))
                if let completion = completion {
                    completion()
                }
            }
        }
        
        self.statusBarChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillChangeStatusBarFrame, object: nil, queue: OperationQueue.main, using: { [weak self] notification in
            if let strongSelf = self {
                let statusBarHeight: CGFloat = max(20.0, (notification.userInfo?[UIApplicationStatusBarFrameUserInfoKey] as? NSValue)?.cgRectValue.height ?? 20.0)
                
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .easeInOut)
                strongSelf.updateLayout { $0.update(statusBarHeight: statusBarHeight, transition: transition, overrideTransition: false) }
            }
        })
        
        self.keyboardFrameChangeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil, queue: nil, using: { [weak self] notification in
            if let strongSelf = self {
                let keyboardFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect()
                let keyboardHeight = max(0.0, UIScreen.main.bounds.size.height - keyboardFrame.minY)
                var duration: Double = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
                if duration > DBL_EPSILON {
                    duration = 0.5
                }
                let curve: UInt = (notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
                
                let transitionCurve: ContainedViewLayoutTransitionCurve
                if curve == 7 {
                    transitionCurve = .spring
                } else {
                    transitionCurve = .easeInOut
                }
                
                strongSelf.updateLayout { $0.update(inputHeight: keyboardHeight.isLessThanOrEqualTo(0.0) ? nil : keyboardHeight, transition: .animated(duration: duration, curve: transitionCurve), overrideTransition: false) }
            }
        })
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let statusBarChangeObserver = self.statusBarChangeObserver {
            NotificationCenter.default.removeObserver(statusBarChangeObserver)
        }
        if let keyboardFrameChangeObserver = self.keyboardFrameChangeObserver {
            NotificationCenter.default.removeObserver(keyboardFrameChangeObserver)
        }
    }
    
    private func invalidateTracingStatusBars() {
        self.tracingStatusBarsInvalidated = true
        self.setNeedsLayout()
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.presentationContext.hitTest(point, with: event) {
            return result
        }
        return self.viewController?.view.hitTest(point, with: event)
    }
    
    public override var frame: CGRect {
        get {
            return super.frame
        }
        set(value) {
            let sizeUpdated = super.frame.size != value.size
            super.frame = value
            
            if sizeUpdated {
                let transition: ContainedViewLayoutTransition
                if self.isRotating() {
                    transition = .animated(duration: orientationChangeDuration, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                self.updateLayout { $0.update(size: value.size, transition: transition, overrideTransition: true) }
            }
        }
    }
    
    public override var bounds: CGRect {
        get {
            return super.frame
        }
        set(value) {
            let sizeUpdated = super.bounds.size != value.size
            super.bounds = value
            
            if sizeUpdated {
                let transition: ContainedViewLayoutTransition
                if self.isRotating() {
                    transition = .animated(duration: orientationChangeDuration, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                self.updateLayout { $0.update(size: value.size, transition: transition, overrideTransition: true) }
            }
        }
    }
    
    private var _rootController: ContainableController?
    public var viewController: ContainableController? {
        get {
            return _rootController
        }
        set(value) {
            if let rootController = self._rootController {
                rootController.view.removeFromSuperview()
            }
            self._rootController = value
            
            if let rootController = self._rootController {
                rootController.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: .immediate)
                
                self.addSubview(rootController.view)
            }
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if self.tracingStatusBarsInvalidated, let statusBarManager = statusBarManager, let keyboardManager = keyboardManager {
            self.tracingStatusBarsInvalidated = false
            
            if self.statusBarHidden {
                statusBarManager.surfaces = []
            } else {
                var statusBarSurfaces: [StatusBarSurface] = []
                for layers in self.layer.traceableLayerSurfaces(withTag: Window.statusBarTracingTag) {
                    let surface = StatusBarSurface()
                    for layer in layers {
                        let traceableInfo = layer.traceableInfo()
                        if let statusBar = traceableInfo?.userData as? StatusBar {
                            surface.addStatusBar(statusBar)
                        }
                    }
                    statusBarSurfaces.append(surface)
                }
                self.layer.adjustTraceableLayerTransforms(CGSize())
                statusBarManager.surfaces = statusBarSurfaces
            }
            
            var keyboardSurfaces: [KeyboardSurface] = []
            for layers in self.layer.traceableLayerSurfaces(withTag: Window.keyboardTracingTag) {
                for layer in layers {
                    if let view = layer.delegate as? UITracingLayerView {
                        keyboardSurfaces.append(KeyboardSurface(host: view))
                    }
                }
            }
            keyboardManager.surfaces = keyboardSurfaces
        }
        
        if !Window.isDeviceRotating() {
            if !self.isUpdatingOrientationLayout {
                self.commitUpdatingLayout()
            } else {
                self.addPostUpdateToInterfaceOrientationBlock(f: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.setNeedsLayout()
                    }
                })
            }
        } else {
            Window.addPostDeviceOrientationDidChange({ [weak self] in
                if let strongSelf = self {
                    strongSelf.setNeedsLayout()
                }
            })
        }
    }
    
    var postUpdateToInterfaceOrientationBlocks: [(Void) -> Void] = []
    
    override public func _update(toInterfaceOrientation arg1: Int32, duration arg2: Double, force arg3: Bool) {
        self.isUpdatingOrientationLayout = true
        super._update(toInterfaceOrientation: arg1, duration: arg2, force: arg3)
        self.isUpdatingOrientationLayout = false
        
        let blocks = self.postUpdateToInterfaceOrientationBlocks
        self.postUpdateToInterfaceOrientationBlocks = []
        for f in blocks {
            f()
        }
    }
    
    public func addPostUpdateToInterfaceOrientationBlock(f: @escaping (Void) -> Void) {
        postUpdateToInterfaceOrientationBlocks.append(f)
    }
    
    private func updateLayout(_ update: (inout UpdatingLayout) -> ()) {
        if self.updatingLayout == nil {
            self.updatingLayout = UpdatingLayout(layout: self.windowLayout, transition: .immediate)
        }
        update(&self.updatingLayout!)
        self.setNeedsLayout()
    }
    
    private func commitUpdatingLayout() {
        if let updatingLayout = self.updatingLayout {
            self.updatingLayout = nil
            if updatingLayout.layout != self.windowLayout {
                var statusBarHeight: CGFloat
                if let statusBarHost = self.statusBarHost {
                    statusBarHeight = statusBarHost.statusBarFrame.size.height
                } else {
                    statusBarHeight = 20.0
                }
                let statusBarWasHidden = self.statusBarHidden
                if statusBarHiddenInLandscape && updatingLayout.layout.size.width > updatingLayout.layout.size.height {
                    statusBarHeight = 0.0
                    self.statusBarHidden = true
                } else {
                    self.statusBarHidden = false
                }
                if self.statusBarHidden != statusBarWasHidden {
                    self.tracingStatusBarsInvalidated = true
                    self.setNeedsLayout()
                }
                self.windowLayout = WindowLayout(size: updatingLayout.layout.size, statusBarHeight: statusBarHeight, inputHeight: updatingLayout.layout.inputHeight, inputMinimized: updatingLayout.layout.inputMinimized)
                
                self._rootController?.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: updatingLayout.transition)
                self.presentationContext.containerLayoutUpdated(containedLayoutForWindowLayout(self.windowLayout), transition: updatingLayout.transition)
            }
        }
    }
    
    public func present(_ controller: ViewController) {
        self.presentationContext.present(controller)
    }
}
